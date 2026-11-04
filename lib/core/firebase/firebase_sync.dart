// Partage des données entre appareils par Cloud Firestore (si Firebase est
// configuré). SQLite reste la base de travail : l'application continue de
// fonctionner hors ligne.
//
// - Envoi : chaque ajout, modification ou suppression est copié dans
//   Firestore en arrière-plan. Un envoi échoué est gardé en attente et
//   réessayé à la synchronisation suivante.
// - Réception : à la connexion puis toutes les deux minutes, l'application
//   lit seulement les documents changés depuis la dernière fois (heure du
//   serveur) et les applique à SQLite. Les écrans se rechargent alors.
// - Suppression : le document est gardé avec `deleted: true`, pour que les
//   autres appareils apprennent aussi la suppression.
// - Données personnelles (panier, favoris, profil, journal…) : rangées dans
//   l'espace du compte, `users/{uid}/…`, et reçues seulement par lui.

import 'dart:async';

import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/core/database/shared_ids.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:flutter/foundation.dart';

/// Changement à envoyer : collection SQLite, chemin Firestore, identifiant
/// et données (null pour une suppression).
typedef _Change = ({
  String collection,
  String path,
  int id,
  Map<String, Object?>? data,
});

class FirebaseSync {
  FirebaseSync._();

  /// Collections partagées entre tous les utilisateurs.
  static const sharedCollections = {
    'news',
    'news_comments',
    'news_votes',
    'comment_reports',
    'funding',
    'investments',
    'project_features',
    'project_questions',
    'project_updates',
    'milestones',
    'token_packs',
    'token_listings',
    'exchange_rates',
    'products',
    'orders',
    'seller_reviews',
    'events',
    'reservations',
    'waitlist',
  };

  /// Collections personnelles : chaque compte ne voit que les siennes.
  static const personalCollections = {
    'cart',
    'favorites',
    'investor_profiles',
    'simulations',
    'referrals',
    'notifications',
    'profiles',
    'activity_log',
  };

  /// Toutes les collections copiées dans Firestore. Seuls les comptes
  /// (empreintes de mots de passe) restent sur l'appareil : Firebase Auth
  /// gère les mots de passe et `users/{uid}` la fiche publique du compte.
  static const syncedCollections = {
    ...sharedCollections,
    ...personalCollections,
  };

  /// Intervalle de lecture des changements des autres appareils.
  static const pullInterval = Duration(minutes: 2);

  /// Augmente à chaque fois que des données reçues ont changé SQLite : les
  /// écrans principaux l'écoutent pour se recharger.
  static final revision = ValueNotifier<int>(0);

  /// Nombre d'envois échoués (affiché dans le profil).
  static int failures = 0;

  /// Heure de la dernière réception réussie.
  static DateTime? lastPull;

  /// Changements locaux pas encore confirmés par Firestore.
  static final Map<String, _Change> _pending = {};

  /// File d'envoi enregistrée dans SQLite (collection technique, jamais
  /// copiée) : un changement fait juste avant de fermer l'application, ou
  /// hors ligne, est envoyé au lancement suivant.
  static const queueCollection = 'sync_queue';

  /// Ligne de la file d'envoi de chaque changement en attente.
  static final Map<String, int> _queueIds = {};
  static bool _restored = false;

  /// Heure serveur du dernier document reçu, par chemin Firestore.
  static final Map<String, String> _cursors = {};

  static Timer? _timer;
  static Future<int>? _pulling;

  /// Active le partage si Firestore est configuré.
  static void install() {
    if (!FirebaseRest.firestoreEnabled) return;
    CrowdTechDatabase.sharedIds = SharedIds();
    CrowdTechDatabase.onChange = _onChange;
    CrowdTechDatabase.onShared = _onShared;
  }

  /// Lance la réception automatique (après la connexion).
  static void start() {
    if (!FirebaseRest.firestoreEnabled) return;
    _timer?.cancel();
    _timer = Timer.periodic(pullInterval, (_) => unawaited(pull()));
    unawaited(pull());
  }

  /// Arrête la réception automatique (à la déconnexion).
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Chemin Firestore de [collection] : la collection elle-même, ou l'espace
  /// du compte connecté pour une collection personnelle (null si personne
  /// n'est connecté à Firebase).
  static String? _pathOf(String collection) {
    if (sharedCollections.contains(collection)) return collection;
    if (!personalCollections.contains(collection)) return null;
    final uid = FirebaseRest.uid;
    return uid == null ? null : 'users/$uid/$collection';
  }

  /// Propriétaire d'un élément personnel (`ownerKey`, ou `accountKey` pour
  /// le profil).
  static String? _ownerOf(Map<String, Object?> data) =>
      (data['ownerKey'] ?? data['accountKey'])?.toString().toLowerCase();

  // ---------------------------------------------------------------------
  // Envoi

  static void _onChange(String collection, int id, Map<String, Object?>? data) {
    if (!SharedIds.isShared(id)) return;
    final path = _pathOf(collection);
    if (path == null) return;
    // Un élément personnel n'est rangé que dans l'espace de son propriétaire
    // (pas les tentatives de connexion d'un autre email, par exemple).
    if (personalCollections.contains(collection) &&
        data != null &&
        _ownerOf(data) != CrowdTechSession.accountKey?.toLowerCase()) {
      return;
    }
    final change = (collection: collection, path: path, id: id, data: data);
    _pending['$path/$id'] = change;
    unawaited(() async {
      await _persist(change);
      await _push(change);
    }());
  }

  static String _keyOf(_Change change) => '${change.path}/${change.id}';

  /// Enregistre [change] dans la file d'envoi (remplace le précédent
  /// changement du même élément).
  static Future<void> _persist(_Change change) async {
    final key = _keyOf(change);
    try {
      await _unqueue(key);
      _queueIds[key] = await CrowdTechDatabase.insertLocal(queueCollection, {
        'key': key,
        'collection': change.collection,
        'path': change.path,
        'itemId': change.id,
        'data': change.data,
      });
    } on Exception catch (error) {
      debugPrint('File d’envoi non enregistrée : $error');
    }
  }

  static Future<void> _unqueue(String key) async {
    final queued = _queueIds.remove(key);
    if (queued != null) {
      await CrowdTechDatabase.deleteLocal(queueCollection, queued);
    }
  }

  /// Recharge la file d'envoi enregistrée (une fois par lancement).
  static Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    for (final row in await CrowdTechDatabase.getItems(queueCollection)) {
      final (key, collection, path, id) = (
        row['key'],
        row['collection'],
        row['path'],
        row['itemId'],
      );
      if (key is! String || collection is! String) continue;
      if (path is! String || id is! int) continue;
      final rowId = row['id'];
      // Plusieurs lignes pour le même élément : la plus récente gagne.
      if (_queueIds[key] case final older?) {
        await CrowdTechDatabase.deleteLocal(queueCollection, older);
      }
      _queueIds[key] = rowId! as int;
      _pending[key] ??= (
        collection: collection,
        path: path,
        id: id,
        data: (row['data'] as Map?)?.cast<String, Object?>(),
      );
    }
  }

  /// Exemples de démonstration et éléments importés : envoyés seulement
  /// s'ils ne sont pas déjà dans Firestore (sans écraser les modifications
  /// faites sur un autre appareil).
  static void _onShared(String collection, int id, Map<String, Object?> data) {
    if (!SharedIds.isShared(id) || !sharedCollections.contains(collection)) {
      return;
    }
    unawaited(() async {
      try {
        await FirebaseRest.setDocument(
          collection,
          '$id',
          _documentOf(id, data),
          createOnly: true,
        );
      } on Exception catch (error) {
        debugPrint('Firestore ($collection/$id) : $error');
      }
    }());
  }

  static Map<String, Object?> _documentOf(int id, Map<String, Object?> data) {
    final copy = {...data}..remove('id');
    // Les photos en base64 sont trop lourdes pour Firestore.
    for (final field in CrowdTechDatabase.deviceOnlyFields) {
      copy.remove(field);
    }
    return {...copy, 'localId': id};
  }

  static Future<bool> _push(_Change change) async {
    final (:collection, :path, :id, :data) = change;
    try {
      await FirebaseRest.setDocument(
        path,
        '$id',
        data == null ? {'deleted': true, 'localId': id} : _documentOf(id, data),
      );
      // Retiré de l'attente, sauf si un changement plus récent l'a remplacé.
      final key = _keyOf(change);
      if (identical(_pending[key], change)) {
        _pending.remove(key);
        await _unqueue(key);
      }
      return true;
    } on Exception catch (error) {
      failures++;
      debugPrint('Firestore ($path/$id) : $error');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Réception

  /// Envoie les changements en attente puis applique ceux des autres
  /// appareils. Retourne le nombre d'éléments modifiés dans SQLite.
  static Future<int> pull() {
    if (!FirebaseRest.firestoreEnabled) return Future.value(0);
    return _pulling ??= _pull().whenComplete(() => _pulling = null);
  }

  static Future<int> _pull() async {
    await _restore();
    final uid = FirebaseRest.uid;
    for (final change in _pending.values.toList()) {
      // Données personnelles : envoyées seulement pour le compte connecté.
      if (change.path.startsWith('users/') &&
          !change.path.startsWith('users/$uid/')) {
        continue;
      }
      if (!await _push(change)) break;
    }
    var changed = 0;
    try {
      for (final collection in syncedCollections) {
        changed += await _pullCollection(collection);
      }
      lastPull = DateTime.now();
    } on Exception catch (error) {
      debugPrint('Firestore (réception) : $error');
    }
    if (changed > 0) revision.value++;
    return changed;
  }

  static Future<int> _pullCollection(String collection) async {
    final path = _pathOf(collection);
    if (path == null) return 0;
    final documents = await FirebaseRest.changedSince(path, _cursors[path]);
    final remote = <int, Map<String, Object?>>{};
    final deleted = <int>{};
    for (final document in documents) {
      final syncedAt = document['syncedAt'];
      if (syncedAt is String && _isAfter(syncedAt, _cursors[path])) {
        _cursors[path] = syncedAt;
      }
      final id = switch (document['localId']) {
        final int id => id,
        _ => int.tryParse('${document['documentId']}'),
      };
      if (id == null || !SharedIds.isShared(id)) continue;
      if (document['deleted'] == true) {
        deleted.add(id);
        continue;
      }
      remote[id] = {...document}
        ..remove('documentId')
        ..remove('syncedAt')
        ..remove('localId')
        ..remove('deleted');
    }
    if (remote.isEmpty && deleted.isEmpty) return 0;
    return CrowdTechDatabase.applyCloud(
      collection,
      remote: remote,
      deleted: deleted,
      skip: {
        for (final change in _pending.values)
          if (change.collection == collection) change.id,
      },
    );
  }

  /// Compare deux heures Firestore (RFC 3339, précision variable).
  static bool _isAfter(String time, String? reference) {
    if (reference == null) return true;
    final parsed = DateTime.tryParse(time);
    final other = DateTime.tryParse(reference);
    if (parsed == null || other == null) return false;
    return parsed.isAfter(other) || (parsed == other && time != reference);
  }

  /// Remet l'état à zéro (tests).
  @visibleForTesting
  static void resetForTesting() {
    stop();
    _pending.clear();
    _queueIds.clear();
    _restored = false;
    _cursors.clear();
    failures = 0;
    lastPull = null;
    CrowdTechDatabase.sharedIds = null;
    CrowdTechDatabase.onChange = null;
    CrowdTechDatabase.onShared = null;
  }

  /// État lisible de l'intégration Firebase.
  static String get status {
    if (!FirebaseRest.authEnabled) {
      return 'Mode local (SQLite). Ajoutez config.json pour activer '
          'Firebase.';
    }
    final pulled = lastPull;
    final parts = [
      'Auth ✓',
      if (FirebaseRest.firestoreEnabled) 'Firestore ✓',
      if (FirebaseRest.storageEnabled) 'Storage ✓',
      if (pulled != null)
        'synchronisé à ${pulled.hour.toString().padLeft(2, '0')}:'
            '${pulled.minute.toString().padLeft(2, '0')}',
      if (_pending.isNotEmpty) '${_pending.length} envoi(s) en attente',
    ];
    return parts.join(' · ');
  }
}
