import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_factory.dart';

class CrowdTechDatabase {
  CrowdTechDatabase._();

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
        ? 'crowdtech.db'
        : join(await getDatabasesPath(), 'crowdtech.db');
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
    if (_useMemoryForTesting) {
      final items = _memoryItems.putIfAbsent(collection, () => []);
      if (items.isEmpty) {
        for (final sample in samples) {
          items.add({'id': _nextMemoryId++, ...sample});
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
      for (final sample in samples) {
        await transaction.insert('content_items', {
          'collection': collection,
          'payload': jsonEncode(sample),
        });
      }
    });
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

  static Future<int> insertItem(
    String collection,
    Map<String, Object?> payload,
  ) async {
    if (_useMemoryForTesting) {
      final id = _nextMemoryId++;
      _memoryItems.putIfAbsent(collection, () => []).add({
        'id': id,
        ...payload,
      });
      return id;
    }
    final db = await database;
    return db.insert('content_items', {
      'collection': collection,
      'payload': jsonEncode(payload),
    });
  }

  static Future<int> updateItem(
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

  static Future<int> deleteItem(String collection, int id) async {
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

  static Future<int> createOrderAndClearCart(
    Map<String, Object?> orderPayload,
  ) async {
    if (_useMemoryForTesting) {
      final orderId = _nextMemoryId++;
      _memoryItems.putIfAbsent('orders', () => []).add({
        'id': orderId,
        ...orderPayload,
      });
      _memoryItems.remove('cart');
      return orderId;
    }
    final db = await database;
    return db.transaction((transaction) async {
      final orderId = await transaction.insert('content_items', {
        'collection': 'orders',
        'payload': jsonEncode(orderPayload),
      });
      await transaction.delete(
        'content_items',
        where: 'collection = ?',
        whereArgs: ['cart'],
      );
      return orderId;
    });
  }

  static Future<int> saveInvestment({
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
      final investmentId = _nextMemoryId++;
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
        'collection': 'investments',
        'payload': jsonEncode(investment),
      });
    });
  }

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
    final databasePath = join(await getDatabasesPath(), 'crowdtech.db');
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
