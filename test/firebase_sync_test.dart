// Partage des données entre appareils par Firestore : numérotation commune,
// envoi, réception, suppressions et modifications en attente. Un faux
// serveur Firestore (en mémoire) remplace Internet.

import 'dart:convert';

import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/core/database/shared_ids.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/core/firebase/firebase_sync.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Faux Firestore : documents par chemin `collection/id`, heure serveur
/// croissante à chaque écriture.
class FakeFirestore {
  final documents = <String, Map<String, Object?>>{};
  final queries = <Map<String, Object?>>[];
  var _clock = DateTime.utc(2026, 11, 2, 10);
  var online = true;

  MockClient get client => MockClient((request) async {
    if (!online) throw http.ClientException('hors ligne');
    final path = request.url.path;
    if (path.endsWith(':commit')) return _commit(request);
    if (path.endsWith(':runQuery')) return _runQuery(request);
    if (request.method == 'GET') {
      final document = documents[path.split('/documents/').last];
      return document == null
          ? http.Response('{}', 404)
          : _json({'name': path, 'fields': document});
    }
    return http.Response('{}', 404);
  });

  http.Response _commit(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    for (final write in body['writes']! as List) {
      final update = (write as Map)['update'] as Map;
      // Comme le vrai Firestore : le nom commence par « projects/ ».
      final name = update['name'].toString();
      if (!name.startsWith('projects/')) {
        return _json({
          'error': {'message': 'Document name lacks "projects"'},
        }, 400);
      }
      final key = name.split('/documents/').last;
      if (write['currentDocument'] case {'exists': false}
          when documents.containsKey(key)) {
        return _json({
          'error': {'message': 'ALREADY_EXISTS: Document already exists'},
        }, 409);
      }
      _clock = _clock.add(const Duration(seconds: 1));
      documents[key] = {
        ...Map<String, Object?>.from(update['fields'] as Map),
        'syncedAt': {'timestampValue': _clock.toIso8601String()},
      };
    }
    return _json({'writeResults': []});
  }

  http.Response _runQuery(http.Request request) {
    final query = (jsonDecode(request.body) as Map)['structuredQuery'] as Map;
    queries.add(Map<String, Object?>.from(query));
    // Requête sur une sous-collection : …/documents/users/uid:runQuery.
    final parent = request.url.path
        .split('/documents')
        .last
        .replaceFirst(':runQuery', '')
        .replaceFirst(RegExp('^/'), '');
    final name = ((query['from'] as List).first as Map)['collectionId'];
    final collection = parent.isEmpty ? name : '$parent/$name';
    final since =
        (query['where'] as Map?)?['fieldFilter']?['value']?['timestampValue'];
    return _json([
      for (final MapEntry(:key, :value) in documents.entries)
        if (key.startsWith('$collection/') &&
            (since == null ||
                DateTime.parse(
                  (value['syncedAt']! as Map)['timestampValue'] as String,
                ).isAfter(DateTime.parse(since as String))))
          {
            'document': {'name': 'projects/p/documents/$key', 'fields': value},
          },
      {'readTime': _clock.toIso8601String()},
    ]);
  }

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  Object? field(String key, String name) =>
      FirebaseRest.decodeValue(documents[key]?[name]);
}

/// Laisse finir les envois lancés en arrière-plan.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// Nouveau téléphone : base locale vide, même compte Firestore.
Future<void> newDevice() async {
  FirebaseSync.resetForTesting();
  await CrowdTechDatabase.useMemoryForTesting();
  FirebaseSync.install();
}

void main() {
  late FakeFirestore server;

  setUp(() async {
    server = FakeFirestore();
    FirebaseRest.enabledOverride = true;
    FirebaseRest.client = server.client;
    await newDevice();
  });

  tearDown(() {
    CrowdTechSession.clear();
    FirebaseRest.signOut();
    FirebaseSync.resetForTesting();
    FirebaseRest.enabledOverride = null;
    FirebaseRest.client = http.Client();
  });

  group('numérotation partagée', () {
    test('mêmes numéros pour les exemples et les imports, partout', () {
      final a = SharedIds();
      final b = SharedIds();
      expect(a.seed('news', 2), b.seed('news', 2));
      expect(a.seed('news', 2), isNot(a.seed('products', 2)));
      expect(a.imported('news', 'HN-1'), b.imported('news', 'hn-1'));
      expect(a.imported('news', 'HN-1'), isNot(a.imported('news', 'HN-2')));
      for (final id in [a.seed('events', 0), a.imported('news', 'x')]) {
        expect(SharedIds.isShared(id), isTrue);
        expect(id, lessThan(1 << 53));
      }
      expect(SharedIds.isShared(42), isFalse);
    });

    test('nouveaux numéros uniques et croissants', () {
      final ids = SharedIds(clock: () => DateTime.utc(2026, 11, 2));
      final generated = [for (var i = 0; i < 500; i++) ids.next()];
      expect(generated.toSet(), hasLength(500));
      for (var i = 1; i < generated.length; i++) {
        expect(generated[i], greaterThan(generated[i - 1]));
      }
      expect(generated.first, greaterThan(SharedIds.firstShared));
    });

    test('numéros affichés courts', () {
      expect(displayNumber(42), '00042');
      expect(displayNumber(42, width: 6), '000042');
      expect(displayNumber(179363643612345), hasLength(lessThan(11)));
    });
  });

  group('envoi vers Firestore', () {
    test('ajout, modification puis suppression (document marqué)', () async {
      final id = await CrowdTechDatabase.insertItem('products', {
        'name': 'Clavier',
        'stock': 3,
        'imageData': 'base64…',
      });
      await settle();
      expect(server.field('products/$id', 'name'), 'Clavier');
      expect(server.field('products/$id', 'localId'), id);
      // Les photos restent sur l'appareil.
      expect(server.documents['products/$id'], isNot(contains('imageData')));

      await CrowdTechDatabase.updateItem('products', id, {
        'name': 'Clavier',
        'stock': 2,
      });
      await settle();
      expect(server.field('products/$id', 'stock'), 2);

      await CrowdTechDatabase.deleteItem('products', id);
      await settle();
      expect(server.field('products/$id', 'deleted'), isTrue);
    });

    test('les comptes (mots de passe) ne sont jamais envoyés', () async {
      await CrowdTechDatabase.insertItem('accounts', {'email': 'a@b.c'});
      await settle();
      expect(server.documents, isEmpty);
    });

    test('données personnelles : dans l’espace du compte seulement', () async {
      CrowdTechSession.accountKey = 'ada@x.com';
      FirebaseRest.uid = 'uid-ada';
      final mine = await CrowdTechDatabase.insertItem('cart', {
        'ownerKey': 'ada@x.com',
        'productId': 1,
      });
      // Tentative de connexion d'un autre email : jamais rangée chez Ada.
      await CrowdTechDatabase.insertItem('activity_log', {
        'ownerKey': 'autre@x.com',
      });
      await settle();
      expect(server.documents.keys, contains('users/uid-ada/cart/$mine'));
      expect(server.documents.keys, everyElement(startsWith('users/uid-ada/')));
      expect(
        server.documents.values.map(
          (fields) => FirebaseRest.decodeValue(fields['ownerKey']),
        ),
        isNot(contains('autre@x.com')),
      );

      // Ada sur un nouveau téléphone retrouve son panier.
      await newDevice();
      await FirebaseSync.pull();
      final cart = await CrowdTechDatabase.getItems('cart');
      expect(cart.single['productId'], 1);
    });

    test('envoi échoué : gardé puis renvoyé à la synchronisation', () async {
      server.online = false;
      final id = await CrowdTechDatabase.insertItem('events', {
        'title': 'Meetup',
      });
      await settle();
      expect(server.documents, isEmpty);
      expect(FirebaseSync.status, contains('1 envoi(s) en attente'));

      server.online = true;
      await FirebaseSync.pull();
      expect(server.field('events/$id', 'title'), 'Meetup');
      expect(FirebaseSync.status, isNot(contains('en attente')));
    });
  });

  test('envoi en attente gardé après la fermeture de l’application', () async {
    server.online = false;
    final id = await CrowdTechDatabase.insertItem('investments', {
      'projectTitle': 'AI Ops Dashboard',
      'tokens': 5,
    });
    await settle();
    expect(server.documents, isEmpty);
    expect(
      await CrowdTechDatabase.getItems(FirebaseSync.queueCollection),
      hasLength(1),
    );

    // Redémarrage : la mémoire est vidée, la base SQLite reste.
    FirebaseSync.resetForTesting();
    FirebaseSync.install();
    server.online = true;
    await FirebaseSync.pull();
    expect(server.field('investments/$id', 'tokens'), 5);
    // Envoi confirmé : la file est vide, et elle n'est jamais copiée.
    expect(
      await CrowdTechDatabase.getItems(FirebaseSync.queueCollection),
      isEmpty,
    );
    expect(
      server.documents.keys.where((key) => key.contains('sync_queue')),
      isEmpty,
    );
  });

  group('réception sur un autre appareil', () {
    test('les éléments créés ailleurs arrivent avec leurs liens', () async {
      // Téléphone A : un article et une note qui pointe vers lui.
      final articleId = await CrowdTechDatabase.insertItem('news', {
        'title': 'Flutter 4',
      });
      await CrowdTechDatabase.insertItem('news_votes', {
        'articleId': articleId,
        'stars': 5,
      });
      await settle();

      // Téléphone B : base vide, reçoit tout.
      await newDevice();
      final revision = FirebaseSync.revision.value;
      expect(await FirebaseSync.pull(), 2);
      final news = await CrowdTechDatabase.getItems('news');
      final votes = await CrowdTechDatabase.getItems('news_votes');
      expect(news.single['title'], 'Flutter 4');
      expect(votes.single['articleId'], news.single['id']);
      expect(FirebaseSync.revision.value, revision + 1);
      // Rien de nouveau : aucune modification au deuxième passage.
      expect(await FirebaseSync.pull(), 0);
    });

    test('lecture des seuls changements récents', () async {
      await CrowdTechDatabase.insertItem('events', {'title': 'A'});
      await settle();
      await FirebaseSync.pull();
      server.queries.clear();
      await FirebaseSync.pull();
      final eventsQuery = server.queries.firstWhere(
        (query) => (query['from']! as List).first['collectionId'] == 'events',
      );
      expect(eventsQuery['where'], isNotNull);
    });

    test('une suppression faite ailleurs est appliquée', () async {
      final id = await CrowdTechDatabase.insertItem('events', {'title': 'A'});
      await settle();
      await newDevice();
      await FirebaseSync.pull();
      expect(await CrowdTechDatabase.getItems('events'), hasLength(1));

      // Un autre appareil supprime l'événement.
      server.documents['events/$id'] = {
        'deleted': {'booleanValue': true},
        'localId': {'integerValue': '$id'},
        'syncedAt': {'timestampValue': '2027-01-01T00:00:00Z'},
      };
      await FirebaseSync.pull();
      expect(await CrowdTechDatabase.getItems('events'), isEmpty);
    });

    test('une modification locale non envoyée n’est pas écrasée', () async {
      final id = await CrowdTechDatabase.insertItem('products', {'stock': 5});
      await settle();
      server.online = false;
      await CrowdTechDatabase.updateItem('products', id, {'stock': 1});
      await settle();
      // Le serveur a encore l'ancienne valeur, et redevient joignable
      // seulement pour la lecture : la valeur locale est gardée.
      server.online = true;
      server.documents['products/$id']!['stock'] = {'integerValue': '9'};
      await FirebaseSync.pull();
      final product = (await CrowdTechDatabase.getItems('products')).single;
      expect(product['stock'], 1);
      expect(server.field('products/$id', 'stock'), 1);
    });

    test('les exemples ne remplacent pas leur version modifiée', () async {
      final samples = [
        {'title': 'Exemple 1', 'votes': 0},
        {'title': 'Exemple 2', 'votes': 0},
      ];
      final rows = await CrowdTechDatabase.loadSeededItems('news', samples);
      await settle();
      final first = rows.first['id']! as int;
      expect(first, SharedIds().seed('news', 0));
      // Téléphone A note le premier exemple.
      await CrowdTechDatabase.updateItem('news', first, {
        'title': 'Exemple 1',
        'votes': 7,
      });
      await settle();

      // Téléphone B installe l'application : ses exemples ont les mêmes
      // numéros et n'écrasent pas la version de A.
      await newDevice();
      final seeded = await CrowdTechDatabase.loadSeededItems('news', samples);
      await settle();
      expect(seeded.first['id'], first);
      expect(server.field('news/$first', 'votes'), 7);
      await FirebaseSync.pull();
      final updated = (await CrowdTechDatabase.getItems('news')).first;
      expect(updated['votes'], 7);
    });

    test(
      'la photo locale est gardée quand le produit est mis à jour',
      () async {
        final id = await CrowdTechDatabase.insertItem('products', {
          'name': 'Souris',
          'imageData': 'photo',
        });
        await settle();
        server.documents['products/$id']!['name'] = {
          'stringValue': 'Souris Pro',
        };
        server.documents['products/$id']!['syncedAt'] = {
          'timestampValue': '2027-01-01T00:00:00Z',
        };
        await FirebaseSync.pull();
        final product = (await CrowdTechDatabase.getItems('products')).single;
        expect(product['name'], 'Souris Pro');
        expect(product['imageData'], 'photo');
      },
    );
  });

  test('sans Firebase : numérotation locale et aucun envoi', () async {
    FirebaseSync.resetForTesting();
    FirebaseRest.enabledOverride = false;
    await CrowdTechDatabase.useMemoryForTesting();
    FirebaseSync.install();
    final id = await CrowdTechDatabase.insertItem('news', {'title': 'Local'});
    await settle();
    expect(id, 1);
    expect(server.documents, isEmpty);
    expect(await FirebaseSync.pull(), 0);
  });
}
