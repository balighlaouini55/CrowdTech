// Base de données SQLite : lecture, ajout, modification, suppression,
// transactions métier (achat de pack, commande) et journal des opérations.

import 'dart:convert';

import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/collections.dart';
import 'package:crowdtech/core/database/database_factory.dart';
import 'package:crowdtech/core/database/shared_ids.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

export 'package:crowdtech/core/errors/rule_exception.dart';

/// Accès unique à la base SQLite de l'application.
///
/// Toutes les données sont dans une seule table `content_items` :
/// `id` | `collection` (news, funding, products…) | `payload` (JSON).
///
/// Sommaire :
/// 1. Ouverture de la base ............ [database]
/// 2. CRUD générique .................. [getItems], [insertItem],
///                                      [updateItem], [deleteItem]
/// 3. Données d'exemple et import HTTP  [loadSeededItems], [importItems]
/// 4. Journal des opérations .......... [logActivity]
/// 5. Transactions métier ............. [saveInvestment],
///                                      [createOrderAndClearCart]
/// 6. Outils pour les tests ........... [useMemoryForTesting], [resetForTesting]
class CrowdTechDatabase {
  CrowdTechDatabase._();

  /// Appelé après chaque ajout, modification (données) ou suppression
  /// (null) : sert à copier les données vers Firestore quand Firebase est
  /// configuré (voir FirebaseSync).
  static void Function(String collection, int id, Map<String, Object?>? data)?
  onChange;

  /// Appelé après l'insertion d'un exemple de démonstration ou d'un élément
  /// importé : copié vers Firestore seulement s'il n'y est pas déjà.
  static void Function(String collection, int id, Map<String, Object?> data)?
  onShared;

  /// Numérotation partagée entre appareils (installée par FirebaseSync) ;
  /// null : numérotation automatique de SQLite.
  static SharedIds? sharedIds;

  /// Nom du fichier SQLite (modifiable dans les tests).
  @visibleForTesting
  static String databaseFileName = 'crowdtech.db';

  static Future<Database>? _databaseFuture;
  static bool _useMemoryForTesting = false;
  static int _nextMemoryId = 1;
  static final Map<String, List<Map<String, Object?>>> _memoryItems = {};

  static Future<Database> get database {
    final cachedDatabase = _databaseFuture;
    if (cachedDatabase != null) return cachedDatabase;
    final openingDatabase = _openDatabase();
    late final Future<Database> trackedDatabase;
    trackedDatabase = openingDatabase.catchError((Object error) {
      if (identical(_databaseFuture, trackedDatabase)) {
        _databaseFuture = null;
      }
      throw error;
    });
    _databaseFuture = trackedDatabase;
    return trackedDatabase;
  }

  static Future<Database> _openDatabase() async {
    initializeDatabaseFactory();
    final databasePath = kIsWeb
        ? databaseFileName
        : join(await databaseDirectory(), databaseFileName);
    return openDatabase(
      databasePath,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE content_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collection TEXT NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX content_items_collection '
          'ON content_items(collection)',
        );
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'CREATE INDEX content_items_collection '
            'ON content_items(collection)',
          );
        }
      },
    );
  }

  static Future<List<Map<String, Object?>>> loadSeededItems(
    String collection,
    List<Map<String, Object?>> samples,
  ) async {
    final ids = sharedIds;
    if (_useMemoryForTesting) {
      final items = _memoryItems.putIfAbsent(collection, () => []);
      if (items.isEmpty) {
        for (final (index, sample) in samples.indexed) {
          final id = ids?.seed(collection, index) ?? _nextMemoryId++;
          items.add({'id': id, ...sample});
          onShared?.call(collection, id, sample);
        }
      }
      return items.map(Map<String, Object?>.from).toList();
    }
    final db = await database;
    final rows = await db.query(
      'content_items',
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'id ASC',
    );
    if (rows.isNotEmpty) {
      return rows.map(_decodeRow).toList();
    }

    await db.transaction((transaction) async {
      for (final (index, sample) in samples.indexed) {
        await transaction.insert('content_items', {
          'id': ?ids?.seed(collection, index),
          'collection': collection,
          'payload': jsonEncode(sample),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    if (ids != null) {
      for (final (index, sample) in samples.indexed) {
        onShared?.call(collection, ids.seed(collection, index), sample);
      }
    }
    final insertedRows = await db.query(
      'content_items',
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'id ASC',
    );
    return insertedRows.map(_decodeRow).toList();
  }

  static Future<List<Map<String, Object?>>> getItems(String collection) async {
    if (_useMemoryForTesting) {
      return (_memoryItems[collection] ?? [])
          .map(Map<String, Object?>.from)
          .toList();
    }
    final db = await database;
    final rows = await db.query(
      'content_items',
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'id ASC',
    );
    return rows.map(_decodeRow).toList();
  }

  /// Élément [id] de [collection], ou null. Lecture directe par la clé
  /// primaire (sans relire toute la collection).
  static Future<Map<String, Object?>?> getItem(
    String collection,
    int id,
  ) async {
    if (_useMemoryForTesting) {
      final item = (_memoryItems[collection] ?? const [])
          .where((row) => row['id'] == id)
          .firstOrNull;
      return item == null ? null : Map<String, Object?>.from(item);
    }
    final db = await database;
    final rows = await db.query(
      'content_items',
      where: 'id = ? AND collection = ?',
      whereArgs: [id, collection],
      limit: 1,
    );
    return rows.isEmpty ? null : _decodeRow(rows.first);
  }

  static Future<int> insertItem(
    String collection,
    Map<String, Object?> payload,
  ) async {
    final id = await _insertRaw(collection, payload);
    await _logChange(collection, 'Ajout', payload);
    onChange?.call(collection, id, payload);
    return id;
  }

  static Future<int> updateItem(
    String collection,
    int id,
    Map<String, Object?> payload,
  ) async {
    final rows = await _updateRaw(collection, id, payload);
    if (rows > 0) await _logChange(collection, 'Modification', payload);
    if (rows > 0) onChange?.call(collection, id, payload);
    return rows;
  }

  /// Supprime un élément en gardant les données cohérentes :
  /// - un projet qui a reçu des investissements, ou un événement qui a des
  ///   billets réservés, ne peut pas être supprimé (argent / billets des
  ///   autres utilisateurs) ;
  /// - supprimer une actualité supprime ses commentaires et ses notes ;
  /// - supprimer un produit le retire des paniers.
  static Future<int> deleteItem(String collection, int id) async {
    final deleted = await getItem(collection, id);
    final blockers = switch (collection) {
      'funding' => (
        await _linkedIds('investments', 'projectId', id),
        'investissement(s) déjà reçu(s) par ce projet',
      ),
      'events' => (
        await _linkedIds('reservations', 'eventId', id),
        'billet(s) déjà réservé(s) pour cet événement',
      ),
      _ => (const <int>[], ''),
    };
    if (blockers.$1.isNotEmpty) {
      throw RuleException('${blockers.$1.length} ${blockers.$2}.');
    }
    final rows = await _deleteRaw(collection, id);
    if (rows > 0) {
      await _logChange(collection, 'Suppression', deleted ?? const {});
      onChange?.call(collection, id, null);
      final dependents = switch (collection) {
        'news' => [('news_comments', 'articleId'), ('news_votes', 'articleId')],
        'products' => [('cart', 'productId')],
        _ => const <(String, String)>[],
      };
      for (final (child, key) in dependents) {
        for (final childId in await _linkedIds(child, key, id)) {
          if (await _deleteRaw(child, childId) > 0) {
            onChange?.call(child, childId, null);
          }
        }
      }
    }
    return rows;
  }

  /// Identifiants des éléments de [collection] dont [key] vaut [id].
  static Future<List<int>> _linkedIds(
    String collection,
    String key,
    int id,
  ) async => [
    for (final item in await getItems(collection))
      if (item[key] == id && item['id'] is int) item['id']! as int,
  ];

  /// Enregistrement technique propre à l'appareil (file d'envoi vers
  /// Firestore…) : ni journal ni [onChange].
  static Future<int> insertLocal(
    String collection,
    Map<String, Object?> payload,
  ) => _insertRaw(collection, payload);

  /// Suppression technique, sans journal ni [onChange].
  static Future<int> deleteLocal(String collection, int id) =>
      _deleteRaw(collection, id);

  static Future<int> _insertRaw(
    String collection,
    Map<String, Object?> payload,
  ) async {
    final sharedId = sharedIds?.next();
    if (_useMemoryForTesting) {
      final id = sharedId ?? _nextMemoryId++;
      _memoryItems.putIfAbsent(collection, () => []).add({
        'id': id,
        ...payload,
      });
      return id;
    }
    final db = await database;
    return db.insert('content_items', {
      'id': ?sharedId,
      'collection': collection,
      'payload': jsonEncode(payload),
    });
  }

  static Future<int> _updateRaw(
    String collection,
    int id,
    Map<String, Object?> payload,
  ) async {
    if (_useMemoryForTesting) {
      final items = _memoryItems[collection];
      if (items == null) return 0;
      final index = items.indexWhere((item) => item['id'] == id);
      if (index < 0) return 0;
      items[index] = {'id': id, ...payload};
      return 1;
    }
    final db = await database;
    return db.update(
      'content_items',
      {'payload': jsonEncode(payload)},
      where: 'id = ? AND collection = ?',
      whereArgs: [id, collection],
    );
  }

  static Future<int> _deleteRaw(String collection, int id) async {
    if (_useMemoryForTesting) {
      final items = _memoryItems[collection];
      if (items == null) return 0;
      final before = items.length;
      items.removeWhere((item) => item['id'] == id);
      return before - items.length;
    }
    final db = await database;
    return db.delete(
      'content_items',
      where: 'id = ? AND collection = ?',
      whereArgs: [id, collection],
    );
  }

  /// Enregistre les éléments reçus par HTTP en ignorant ceux dont la valeur
  /// [uniqueKey] existe déjà. Retourne le nombre d’éléments ajoutés.
  static Future<int> importItems(
    String collection,
    List<Map<String, Object?>> items, {
    required String uniqueKey,
  }) async {
    final existing = (await getItems(collection))
        .map((item) => item[uniqueKey]?.toString().toLowerCase())
        .toSet();
    final newItems = [
      for (final item in items)
        if (existing.add(item[uniqueKey]?.toString().toLowerCase())) item,
    ];
    if (newItems.isEmpty) return 0;
    final ids = sharedIds;
    int? idOf(Map<String, Object?> item) =>
        ids?.imported(collection, '${item[uniqueKey]}');
    if (_useMemoryForTesting) {
      for (final item in newItems) {
        final id = idOf(item) ?? _nextMemoryId++;
        _memoryItems.putIfAbsent(collection, () => []).add({'id': id, ...item});
      }
    } else {
      final db = await database;
      await db.transaction((transaction) async {
        for (final item in newItems) {
          await transaction.insert('content_items', {
            'id': ?idOf(item),
            'collection': collection,
            'payload': jsonEncode(item),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });
    }
    if (ids != null) {
      for (final item in newItems) {
        onShared?.call(collection, idOf(item)!, item);
      }
    }
    await logActivity(
      module: _moduleOf(collection),
      action: 'Import Internet',
      details: '${newItems.length} ${_entityOf(collection)}(s) importé(s)',
    );
    return newItems.length;
  }

  // ---------------------------------------------------------------------
  // Journal des opérations : chaque écriture est tracée dans `activity_log`.

  static String _moduleOf(String collection) =>
      collectionModules[collection] ?? collection;

  static String _entityOf(String collection) =>
      collectionEntities[collection] ?? 'élément';

  static String _labelOf(Map<String, Object?> payload) {
    for (final key in [
      'title',
      'name',
      'productName',
      'projectTitle',
      'eventTitle',
      'attendeeName',
      'author',
      'email',
    ]) {
      final value = payload[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return '';
  }

  static Future<void> _logChange(
    String collection,
    String action,
    Map<String, Object?> payload,
  ) {
    if (collection == 'activity_log') return Future.value();
    final label = _labelOf(payload);
    return logActivity(
      module: _moduleOf(collection),
      action: '$action ${_entityOf(collection)}',
      details: label,
    );
  }

  /// Ajoute une ligne au journal pour l’utilisateur connecté. Une erreur
  /// d’écriture du journal n’annule jamais l’opération elle-même.
  static Future<void> logActivity({
    required String module,
    required String action,
    String details = '',
    String? accountKey,
  }) async {
    try {
      final entry = {
        'ownerKey': accountKey ?? CrowdTechSession.accountKey ?? 'invité',
        'module': module,
        'action': action,
        'details': details,
        'createdAt': DateTime.now().toIso8601String(),
      };
      final id = await _insertRaw('activity_log', entry);
      onChange?.call('activity_log', id, entry);
    } on Exception catch (error) {
      debugPrint('Journal non enregistré : $error');
    }
  }

  static Future<int> createOrderAndClearCart(
    Map<String, Object?> orderPayload,
  ) async {
    final cartIds = [
      for (final line in await getItems('cart'))
        if (line['ownerKey'] == orderPayload['ownerKey'] && line['id'] is int)
          line['id']! as int,
    ];
    final orderId = await _createOrderAndClearCart(orderPayload);
    onChange?.call('orders', orderId, orderPayload);
    if (onChange != null) {
      // Panier vidé dans la transaction.
      for (final id in cartIds) {
        onChange?.call('cart', id, null);
      }
      // Stock des produits commandés, mis à jour dans la transaction.
      final lines = orderPayload['items'];
      final ordered = {
        if (lines is List)
          for (final line in lines)
            if (line is Map && line['productId'] is int) line['productId'],
      };
      for (final product in await getItems('products')) {
        if (ordered.contains(product['id'])) {
          onChange?.call(
            'products',
            product['id']! as int,
            {...product}..remove('id'),
          );
        }
      }
    }
    final total = orderPayload['total'];
    await logActivity(
      module: 'Marketplace',
      action: 'Commande validée',
      details: total is num ? 'Total : ${total.toStringAsFixed(2)} €' : '',
    );
    return orderId;
  }

  static Future<int> _createOrderAndClearCart(
    Map<String, Object?> orderPayload,
  ) async {
    // Quantités commandées par produit, pour mettre à jour le stock.
    final ordered = <int, int>{};
    final lines = orderPayload['items'];
    if (lines is List) {
      for (final line in lines) {
        if (line is! Map) continue;
        final productId = line['productId'];
        final quantity = line['quantity'];
        if (productId is int && quantity is int) {
          ordered.update(
            productId,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
      }
    }
    Map<String, Object?> withLowerStock(Map<String, Object?> product) {
      final stock = product['stock'];
      final quantity = ordered[product['id']];
      if (stock is! num || quantity == null) return product;
      return {
        ...product,
        'stock': (stock.toInt() - quantity).clamp(0, 1 << 30),
      };
    }

    /// Vérifie, au moment de payer, que chaque produit existe encore et que
    /// le stock suffit (un autre client a pu acheter entre-temps).
    void checkStock(List<Map<String, Object?>> products) {
      for (final MapEntry(key: id, value: quantity) in ordered.entries) {
        final product = products.where((row) => row['id'] == id).firstOrNull;
        if (product == null) {
          throw const RuleException(
            'Un produit de votre panier n’est plus disponible.',
          );
        }
        final stock = product['stock'];
        if (stock is num && quantity > stock) {
          throw RuleException(
            stock <= 0
                ? '« ${product['name']} » est en rupture de stock.'
                : 'Stock insuffisant pour « ${product['name']} » : '
                      '${stock.toInt()} disponible(s), $quantity demandé(s).',
          );
        }
      }
    }

    if (_useMemoryForTesting) {
      checkStock(_memoryItems['products'] ?? const []);
      final orderId = sharedIds?.next() ?? _nextMemoryId++;
      _memoryItems.putIfAbsent('orders', () => []).add({
        'id': orderId,
        ...orderPayload,
      });
      _memoryItems['cart']?.removeWhere(
        (item) => item['ownerKey'] == orderPayload['ownerKey'],
      );
      final products = _memoryItems['products'] ?? [];
      for (var index = 0; index < products.length; index++) {
        products[index] = withLowerStock(products[index]);
      }
      return orderId;
    }
    final db = await database;
    return db.transaction((transaction) async {
      final products = (await transaction.query(
        'content_items',
        where: 'collection = ?',
        whereArgs: ['products'],
      )).map(_decodeRow).toList();
      checkStock(products);
      final orderId = await transaction.insert('content_items', {
        'id': ?sharedIds?.next(),
        'collection': 'orders',
        'payload': jsonEncode(orderPayload),
      });
      // Vide seulement le panier de l'acheteur, pas celui des autres comptes.
      final cartRows = await transaction.query(
        'content_items',
        where: 'collection = ?',
        whereArgs: ['cart'],
      );
      for (final row in cartRows.map(_decodeRow)) {
        if (row['ownerKey'] != orderPayload['ownerKey']) continue;
        await transaction.delete(
          'content_items',
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      if (ordered.isNotEmpty) {
        for (final row in products) {
          final updated = withLowerStock(row);
          if (identical(updated, row)) continue;
          await transaction.update(
            'content_items',
            {'payload': jsonEncode(updated..remove('id'))},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      return orderId;
    });
  }

  static Future<int> saveInvestment({
    required int projectId,
    required Map<String, Object?> updatedProject,
    required Map<String, Object?> investment,
  }) async {
    final investmentId = await _saveInvestment(
      projectId: projectId,
      updatedProject: updatedProject,
      investment: investment,
    );
    if (investmentId != 0) {
      onChange?.call('funding', projectId, updatedProject);
      onChange?.call('investments', investmentId, investment);
      final amount = investment['amount'];
      await logActivity(
        module: 'Crowdfunding',
        action: 'Achat pack ${investment['pack'] ?? ''}'.trim(),
        details:
            '${investment['projectTitle']} • ${investment['tokens']} jetons'
            '${amount is num ? ' • ${amount.toStringAsFixed(2)} €' : ''}',
      );
    }
    return investmentId;
  }

  static Future<int> _saveInvestment({
    required int projectId,
    required Map<String, Object?> updatedProject,
    required Map<String, Object?> investment,
  }) async {
    if (_useMemoryForTesting) {
      final projects = _memoryItems['funding'];
      if (projects == null) return 0;
      final index = projects.indexWhere((item) => item['id'] == projectId);
      if (index < 0) return 0;
      projects[index] = {'id': projectId, ...updatedProject};
      final investmentId = sharedIds?.next() ?? _nextMemoryId++;
      _memoryItems.putIfAbsent('investments', () => []).add({
        'id': investmentId,
        ...investment,
      });
      return investmentId;
    }
    final db = await database;
    return db.transaction((transaction) async {
      final rowsUpdated = await transaction.update(
        'content_items',
        {'payload': jsonEncode(updatedProject)},
        where: 'id = ? AND collection = ?',
        whereArgs: [projectId, 'funding'],
      );
      if (rowsUpdated != 1) {
        throw Exception('Le projet à mettre à jour est introuvable.');
      }
      return transaction.insert('content_items', {
        'id': ?sharedIds?.next(),
        'collection': 'investments',
        'payload': jsonEncode(investment),
      });
    });
  }

  // ---------------------------------------------------------------------
  // Données reçues des autres appareils (Firestore, voir FirebaseSync).

  /// Champs gardés seulement sur l'appareil (non envoyés à Firestore) :
  /// conservés quand l'élément est remplacé par sa version reçue.
  static const deviceOnlyFields = {'imageData'};

  /// Applique à [collection] les éléments reçus : ajout ou remplacement de
  /// [remote] (identifiant → données) et suppression de [deleted]. Les
  /// identifiants de [skip] (modifications locales pas encore envoyées) ne
  /// sont pas touchés. Ni journal ni [onChange] : ces changements viennent
  /// déjà de Firestore. Retourne le nombre d'éléments modifiés.
  static Future<int> applyCloud(
    String collection, {
    Map<int, Map<String, Object?>> remote = const {},
    Set<int> deleted = const {},
    Set<int> skip = const {},
  }) async {
    final local = {
      for (final row in await getItems(collection))
        if (row['id'] case final int id) id: {...row}..remove('id'),
    };
    final upserts = <int, Map<String, Object?>>{};
    for (final MapEntry(key: id, value: data) in remote.entries) {
      if (skip.contains(id)) continue;
      final current = local[id];
      final merged = {
        ...data,
        for (final field in deviceOnlyFields)
          if (current?[field] != null && data[field] == null)
            field: current![field],
      };
      if (current == null || _canonical(current) != _canonical(merged)) {
        upserts[id] = merged;
      }
    }
    final removals = [
      for (final id in deleted)
        if (!skip.contains(id) && local.containsKey(id)) id,
    ];
    if (upserts.isEmpty && removals.isEmpty) return 0;

    if (_useMemoryForTesting) {
      final items = _memoryItems.putIfAbsent(collection, () => []);
      for (final MapEntry(key: id, value: data) in upserts.entries) {
        final index = items.indexWhere((item) => item['id'] == id);
        final row = {'id': id, ...data};
        index < 0 ? items.add(row) : items[index] = row;
      }
      items.removeWhere((item) => removals.contains(item['id']));
      return upserts.length + removals.length;
    }
    final db = await database;
    await db.transaction((transaction) async {
      for (final MapEntry(key: id, value: data) in upserts.entries) {
        final payload = jsonEncode(data);
        if (local.containsKey(id)) {
          await transaction.update(
            'content_items',
            {'payload': payload},
            where: 'id = ? AND collection = ?',
            whereArgs: [id, collection],
          );
        } else {
          await transaction.insert('content_items', {
            'id': id,
            'collection': collection,
            'payload': payload,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final id in removals) {
        await transaction.delete(
          'content_items',
          where: 'id = ? AND collection = ?',
          whereArgs: [id, collection],
        );
      }
    });
    return upserts.length + removals.length;
  }

  /// Texte JSON aux clés triées, pour comparer deux éléments.
  static String _canonical(Object? value) => jsonEncode(_sorted(value));

  static Object? _sorted(Object? value) => switch (value) {
    final Map<Object?, Object?> map => {
      for (final key in map.keys.map((key) => '$key').toList()..sort())
        key: _sorted(map[key]),
    },
    final List<Object?> list => list.map(_sorted).toList(),
    _ => value,
  };

  static Map<String, Object?> _decodeRow(Map<String, Object?> row) {
    final payload =
        jsonDecode(row['payload']! as String) as Map<String, dynamic>;
    return {
      'id': row['id'],
      ...payload.map((key, value) => MapEntry(key, value as Object?)),
    };
  }

  static Future<void> close() async {
    if (_useMemoryForTesting) return;
    final openDatabaseFuture = _databaseFuture;
    _databaseFuture = null;
    final db = await openDatabaseFuture;
    await db?.close();
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _useMemoryForTesting = false;
    _memoryItems.clear();
    _nextMemoryId = 1;
    await close();
    final databasePath = join(await databaseDirectory(), databaseFileName);
    await databaseFactory.deleteDatabase(databasePath);
  }

  @visibleForTesting
  static Future<void> useMemoryForTesting() async {
    await close();
    _useMemoryForTesting = true;
    _memoryItems.clear();
    _nextMemoryId = 1;
  }
}
