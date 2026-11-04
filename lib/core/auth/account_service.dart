// Comptes utilisateurs : inscription, connexion, mot de passe chiffré (SHA-256 salé).

import 'dart:convert';
import 'dart:math';

import 'package:crowdtech/core/auth/account_repository.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/core/firebase/firebase_sync.dart';
import 'package:crowdtech/modules/profile/data/profile_repository.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class AccountException implements Exception {
  final String message;
  const AccountException(this.message);

  @override
  String toString() => message;
}

/// Comptes utilisateurs enregistrés dans SQLite (collection `accounts`).
/// Le mot de passe n’est jamais stocké en clair : seul un hash SHA-256 salé
/// est conservé.
class AccountService {
  AccountService._();

  static const _hashRounds = 2000;

  static String _normalize(String email) => email.trim().toLowerCase();

  static String _newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
  }

  static String _hash(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password'));
    for (var round = 1; round < _hashRounds; round++) {
      digest = sha256.convert([...digest.bytes, ...utf8.encode(salt)]);
    }
    return digest.toString();
  }

  static Future<Map<String, Object?>?> _findAccount(String email) async {
    final key = _normalize(email);
    return (await AccountRepository.accounts.all())
        .where((account) => account['email'] == key)
        .firstOrNull;
  }

  static CrowdUser _userOf(Map<String, Object?> account) => CrowdUser(
    name: account['name']! as String,
    email: account['email']! as String,
    role: account['role']! as String,
  );

  /// Compte administrateur créé automatiquement s'il n'existe pas encore.
  /// C'est le seul compte qui peut changer les rôles des autres.
  static const defaultAdminEmail = 'admin@crowdtech.app';
  static const defaultAdminPassword = 'Admin1234';

  /// Vrai pour le mot de passe public de l'administrateur par défaut : il doit
  /// être changé dès la connexion.
  static bool isDefaultAdminPassword(String email, String password) =>
      _normalize(email) == defaultAdminEmail &&
      password == defaultAdminPassword;

  static Future<void> ensureDefaultAdmin() async {
    if (await _findAccount(defaultAdminEmail) != null) return;
    final salt = _newSalt();
    await AccountRepository.accounts.add({
      'name': 'Administrateur',
      'email': defaultAdminEmail,
      'role': UserRoles.admin,
      'salt': salt,
      'passwordHash': _hash(defaultAdminPassword, salt),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<CrowdUser> register({
    required String name,
    required String email,
    required String password,
    required String role,
    Map<String, String> details = const {},
  }) async {
    await ensureDefaultAdmin();
    final key = _normalize(email);
    if (await _findAccount(key) != null) {
      throw const AccountException('Un compte existe déjà avec cet email.');
    }
    // Personne ne peut s'inscrire directement comme administrateur.
    final safeRole = UserRoles.selfService.contains(role)
        ? role
        : UserRoles.reader;
    final user = CrowdUser(name: name.trim(), email: key, role: safeRole);
    // Firebase Auth (si configuré) : le compte est aussi créé dans Firebase.
    if (FirebaseRest.authEnabled) {
      try {
        await FirebaseRest.signUp(key, password);
      } on FirebaseException catch (error) {
        throw AccountException(error.message);
      }
    }
    final salt = _newSalt();
    CrowdTechSession.start(user);
    await AccountRepository.accounts.add({
      'name': user.name,
      'email': key,
      'role': safeRole,
      'salt': salt,
      'passwordHash': _hash(password, salt),
      'createdAt': DateTime.now().toIso8601String(),
      // Informations personnelles saisies à l'inscription : date de
      // naissance, téléphone, adresse, ville, code postal, pays.
      for (final MapEntry(:key, :value) in details.entries)
        if (detailKeys.contains(key) && value.trim().isNotEmpty)
          key: value.trim(),
    });
    if (FirebaseRest.idToken != null) {
      await _publishUser(user, details);
      FirebaseSync.start();
    }
    return user;
  }

  /// Fiche publique du compte dans Firestore (`users/{uid}`, sans mot de
  /// passe) : retrouvée quand on se connecte depuis un autre appareil.
  static Future<void> _publishUser(
    CrowdUser user,
    Map<String, String> details,
  ) async {
    final uid = FirebaseRest.uid;
    if (!FirebaseRest.firestoreEnabled || uid == null) return;
    try {
      await FirebaseRest.setDocument('users', uid, {
        'name': user.name,
        'email': user.email,
        'role': user.role,
        for (final MapEntry(:key, :value) in details.entries)
          if (detailKeys.contains(key) && value.trim().isNotEmpty)
            key: value.trim(),
      });
    } on FirebaseException catch (error) {
      debugPrint('Fiche Firestore non enregistrée : $error');
    }
  }

  /// Fiche Firestore du compte connecté, ou vide (hors ligne, mode local).
  static Future<Map<String, Object?>> _fetchUser() async {
    final uid = FirebaseRest.uid;
    if (!FirebaseRest.firestoreEnabled || uid == null) return const {};
    try {
      return await FirebaseRest.getDocument('users', uid) ?? const {};
    } on FirebaseException {
      return const {};
    }
  }

  /// Informations personnelles enregistrées avec le compte.
  static const detailKeys = [
    'birthDate',
    'phone',
    'address',
    'city',
    'postalCode',
    'country',
  ];

  /// Informations personnelles d'un compte (jamais le mot de passe).
  static Future<Map<String, String>> detailsOf(String email) async {
    final account = await _findAccount(email);
    return {
      for (final key in detailKeys)
        if (account?[key] case final String value) key: value,
    };
  }

  /// Champs de coordonnées repris pour pré-remplir les formulaires.
  static const contactKeys = [
    'name',
    'email',
    'phone',
    'address',
    'city',
    'postalCode',
    'country',
  ];

  /// Coordonnées d'un compte pour pré-remplir les formulaires (commande,
  /// réservation). Le profil est prioritaire ; un champ vide du profil est
  /// complété par les informations saisies à l'inscription.
  static Future<Map<String, String>> contactOf(String email) async {
    final key = _normalize(email);
    final account = await _findAccount(key) ?? const {};
    final profile = (await ProfileRepository.profiles.all())
        .where((row) => row['accountKey']?.toString().toLowerCase() == key)
        .firstOrNull;
    String pick(String field) {
      final fromProfile = profile?[field]?.toString().trim() ?? '';
      if (fromProfile.isNotEmpty) return fromProfile;
      return account[field]?.toString().trim() ?? '';
    }

    return {for (final field in contactKeys) field: pick(field)};
  }

  /// Enregistre des coordonnées dans le profil (créé s'il n'existe pas),
  /// pour qu'elles soient proposées automatiquement la prochaine fois.
  static Future<void> saveContact(
    String email,
    Map<String, String> values,
  ) async {
    final accountKey = _normalize(email);
    final changes = {
      for (final MapEntry(:key, :value) in values.entries)
        if (contactKeys.contains(key) && key != 'email') key: value.trim(),
    };
    final profile = (await ProfileRepository.profiles.all())
        .where(
          (row) => row['accountKey']?.toString().toLowerCase() == accountKey,
        )
        .firstOrNull;
    final id = profile?['id'];
    if (profile != null && id is int) {
      await ProfileRepository.profiles.update(
        id,
        {...profile, ...changes}..remove('id'),
      );
      return;
    }
    final account = await _findAccount(accountKey);
    await ProfileRepository.profiles.add({
      'accountKey': accountKey,
      'name': account?['name'] ?? values['name'] ?? '',
      'email': accountKey,
      'role': account?['role'] ?? UserRoles.reader,
      ...await detailsOf(accountKey),
      ...changes,
    });
  }

  /// Tous les comptes (sans les mots de passe), pour la page d'administration.
  static Future<List<CrowdUser>> listAccounts() async => [
    for (final account in await AccountRepository.accounts.all())
      _userOf(account),
  ];

  static Future<CrowdUser> login({
    required String email,
    required String password,
  }) async {
    await ensureDefaultAdmin();
    var account = await _findAccount(email);
    final salt = account?['salt'];
    final localOk =
        account != null &&
        salt is String &&
        account['passwordHash'] == _hash(password, salt);
    if (localOk && FirebaseRest.authEnabled) {
      // Jeton Firebase pour Firestore / Storage (sans bloquer hors ligne).
      try {
        await FirebaseRest.signIn(_normalize(email), password);
      } on FirebaseException {
        // Compte local seulement (ex. administrateur par défaut).
      }
    }
    if (!localOk && FirebaseRest.authEnabled) {
      // Mot de passe changé par l'email Firebase, ou compte créé sur un
      // autre appareil : Firebase fait foi, le compte local est mis à jour.
      try {
        await FirebaseRest.signIn(_normalize(email), password);
        account = await _syncFromFirebase(email, password, account);
      } on FirebaseException {
        account = null;
      }
    }
    if (account == null || (!localOk && FirebaseRest.idToken == null)) {
      await CrowdTechDatabase.logActivity(
        module: 'Compte',
        action: 'Échec de connexion',
        details: _normalize(email),
        accountKey: _normalize(email),
      );
      throw const AccountException('Email ou mot de passe incorrect.');
    }
    final user = _userOf(account);
    CrowdTechSession.start(user);
    if (FirebaseRest.idToken != null) FirebaseSync.start();
    await CrowdTechDatabase.logActivity(
      module: 'Compte',
      action: 'Connexion',
      details: user.email,
    );
    return user;
  }

  /// Crée ou met à jour le compte local après une connexion Firebase.
  static Future<Map<String, Object?>> _syncFromFirebase(
    String email,
    String password,
    Map<String, Object?>? account,
  ) async {
    final key = _normalize(email);
    final salt = _newSalt();
    // Nom, rôle et coordonnées saisis à l'inscription sur l'autre appareil.
    // Le rôle administrateur n'est jamais repris d'une fiche Firestore.
    final remote = await _fetchUser();
    final remoteRole = remote['role'];
    final values = {
      ...?account,
      for (final field in detailKeys)
        if (remote[field] case final String value when value.isNotEmpty)
          field: account?[field] ?? value,
      'name': account?['name'] ?? remote['name'] ?? key.split('@').first,
      'email': key,
      'role':
          account?['role'] ??
          (UserRoles.selfService.contains(remoteRole)
              ? remoteRole
              : UserRoles.reader),
      'salt': salt,
      'passwordHash': _hash(password, salt),
      'createdAt': account?['createdAt'] ?? DateTime.now().toIso8601String(),
    };
    final id = account?['id'];
    if (id is int) {
      await AccountRepository.accounts.update(id, {...values}..remove('id'));
      return {...values, 'id': id};
    }
    final newId = await AccountRepository.accounts.add(values);
    return {...values, 'id': newId};
  }

  /// Envoie l'email Firebase de réinitialisation du mot de passe.
  /// Retourne false si Firebase n'est pas configuré (mode local).
  static Future<bool> sendResetEmail(String email) async {
    if (!FirebaseRest.authEnabled) return false;
    try {
      await FirebaseRest.sendPasswordReset(_normalize(email));
      return true;
    } on FirebaseException catch (error) {
      throw AccountException(error.message);
    }
  }

  static Future<void> logout() async {
    FirebaseSync.stop();
    FirebaseRest.signOut();
    if (CrowdTechSession.accountKey != null) {
      await CrowdTechDatabase.logActivity(
        module: 'Compte',
        action: 'Déconnexion',
      );
    }
    CrowdTechSession.clear();
  }

  /// Change le mot de passe d’un compte. Le titulaire doit le prouver : être
  /// connecté à ce compte ou, en mode local (sans email possible), donner la
  /// date de naissance et le téléphone de l'inscription. Avec Firebase, un
  /// compte non connecté passe par l'email de réinitialisation. Un compte
  /// administrateur ne se réinitialise jamais sans être connecté.
  static Future<void> resetPassword({
    required String email,
    required String newPassword,
    String birthDate = '',
    String phone = '',
  }) async {
    const refused = AccountException(
      'Ces informations ne correspondent pas à un compte.',
    );
    if (isDefaultAdminPassword(email, newPassword)) {
      throw const AccountException('Choisissez un autre mot de passe.');
    }
    final account = await _findAccount(email);
    final id = account?['id'];
    if (account == null || id is! int) throw refused;
    if (CrowdTechSession.accountKey?.toLowerCase() != _normalize(email)) {
      if (FirebaseRest.authEnabled) {
        throw const AccountException(
          'Utilisez le lien de réinitialisation reçu par email.',
        );
      }
      if (account['role'] == UserRoles.admin ||
          !_matchesIdentity(account, birthDate, phone)) {
        throw refused;
      }
    }
    final salt = _newSalt();
    await AccountRepository.accounts.update(
      id,
      {...account, 'salt': salt, 'passwordHash': _hash(newPassword, salt)}
        ..remove('id'),
    );
  }

  /// Compare la date de naissance et le téléphone à ceux de l'inscription
  /// (faux si le compte n'en a pas).
  static bool _matchesIdentity(
    Map<String, Object?> account,
    String birthDate,
    String phone,
  ) {
    String digits(Object? value) =>
        value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    final savedDate = parseFlexibleDate(account['birthDate']?.toString());
    final savedPhone = digits(account['phone']);
    return savedDate != null &&
        savedPhone.isNotEmpty &&
        savedDate == parseFlexibleDate(birthDate) &&
        savedPhone == digits(phone);
  }

  /// Met à jour le nom et le rôle enregistrés dans le compte.
  static Future<void> updateAccount(
    String email, {
    String? name,
    String? role,
  }) async {
    final account = await _findAccount(email);
    final id = account?['id'];
    if (account == null || id is! int) return;
    await AccountRepository.accounts.update(
      id,
      {...account, 'name': ?name, 'role': ?role}..remove('id'),
    );
  }

  /// Change le rôle d'un compte. Réservé à l'administrateur, qui ne peut pas
  /// retirer son propre rôle (sinon plus personne ne pourrait administrer).
  static Future<void> changeRole(String email, String role) async {
    if (!Permissions.isAdmin) {
      throw const AccountException(Permissions.adminOnlyMessage);
    }
    final key = _normalize(email);
    if (key == CrowdTechSession.accountKey || key == defaultAdminEmail) {
      throw const AccountException(
        'Le rôle de ce compte administrateur ne peut pas être modifié.',
      );
    }
    if (!UserRoles.all.contains(role)) {
      throw const AccountException('Rôle inconnu.');
    }
    await updateAccount(key, role: role);
    // Le badge affiché dans le profil suit le rôle du compte.
    for (final profile in await ProfileRepository.profiles.all()) {
      final id = profile['id'];
      if (profile['accountKey'] == key && id is int) {
        await ProfileRepository.profiles.update(
          id,
          {...profile, 'role': role}..remove('id'),
        );
      }
    }
  }
}
