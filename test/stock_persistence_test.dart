// Le stock diminué par une commande reste enregistré après fermeture et
// réouverture de la vraie base SQLite (comme un redémarrage de l'application).

import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    CrowdTechDatabase.databaseFileName = 'crowdtech_stock_persistence.db';
  });
  setUp(CrowdTechDatabase.resetForTesting);
  tearDownAll(CrowdTechDatabase.resetForTesting);

  test('le stock à 0 est conservé après redémarrage', () async {
    const samples = [
      {'name': 'Casque', 'price': 100.0, 'category': 'Audio', 'stock': 2},
    ];
    final products = await CrowdTechDatabase.loadSeededItems(
      'products',
      samples,
    );
    final id = products.single['id']! as int;

    await CrowdTechDatabase.createOrderAndClearCart({
      'ownerKey': 'client@example.com',
      'items': [
        {'productId': id, 'productName': 'Casque', 'quantity': 2},
      ],
      'total': 200.0,
    });

    // « Redémarrage » : la base est fermée puis rouverte depuis le disque.
    await CrowdTechDatabase.close();
    final reloaded = await CrowdTechDatabase.loadSeededItems(
      'products',
      samples,
    );

    expect(reloaded, hasLength(1));
    expect(reloaded.single['stock'], 0);
  });
}
