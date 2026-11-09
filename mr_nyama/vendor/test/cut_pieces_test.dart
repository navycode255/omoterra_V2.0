import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'helpers.dart';
import 'sales_flow_test.dart' show tapProduct;

/// One bird at the station; Nusu, Paja and Kidali are cut from it.
const oneBird = CatalogSnapshot(products: [
  CatalogItem(
      id: 'KUKU-MZIMA',
      name: 'Kuku mzima',
      price: 9000,
      priceVersion: 'p1',
      available: 1,
      held: '1'),
  CatalogItem(
      id: 'NUSU-KUKU',
      name: 'Nusu kuku',
      price: 4500,
      priceVersion: 'p2',
      available: 2,
      held: '0',
      cutFrom: 'KUKU-MZIMA',
      cutCount: 2),
  CatalogItem(
      id: 'PAJA-ROBO',
      name: 'Paja (Robo)',
      price: 2000,
      priceVersion: 'p3',
      available: 2,
      held: '0',
      cutFrom: 'NUSU-KUKU',
      cutCount: 1),
  CatalogItem(
      id: 'KIDALI-ROBO',
      name: 'Kidali (Robo)',
      price: 2500,
      priceVersion: 'p4',
      available: 2,
      held: '0',
      cutFrom: 'NUSU-KUKU',
      cutCount: 1),
]);

void main() {
  testWidgets('a Paja in the cart cuts the bird: Nusu 1, Kidali 1, Kuku 0',
      (tester) async {
    await pumpApp(tester,
        api: FakeVendorRepository()..catalogSnapshot = oneBird,
        initial: MNRoutes.sales);
    await tester.pumpAndSettle();
    // Before: the bird, and pieces sellable by cutting.
    expect(find.text('Imesalia: 1'), findsOneWidget);
    expect(find.text('Imesalia: kwa kukata'), findsNWidgets(3));
    await tapProduct(tester, 'Paja (Robo)');
    // After adding one Paja: the bird is cut into its pieces.
    expect(find.text('Imesalia: 0'), findsOneWidget); // Kuku mzima
    expect(find.text('Imesalia: 1'), findsNWidgets(2)); // Nusu, Kidali
    expect(find.text('Imesalia: kwa kukata'),
        findsOneWidget); // Paja, from the Nusu
    expect(tester.takeException(), isNull);
  });

  test('a phone left with cut_fraction instead of cut_count is repaired',
      () async {
    final directory = await Directory.systemTemp.createTemp('mrnyama-cut-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/phone.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').get(); // create at the current schema
    // The development build of 25 October: schema 8 without cut_count.
    await db
        .customStatement('ALTER TABLE catalog_products DROP COLUMN cut_count');
    await db.customStatement(
        'ALTER TABLE catalog_products ADD COLUMN cut_fraction TEXT NULL');
    await db.customStatement('PRAGMA user_version = 8');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await SalesStore(db).replaceCatalog(oneBird);
    final products = {
      for (final p in await SalesStore(db).watchProducts().first) p.id: p
    };
    expect(products['PAJA-ROBO']!.availableToSell, 2);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 10);
  });

  test('a piece whose rule the phone lacks is not counted as zero', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = SalesStore(db);
    await store.replaceCatalog(const CatalogSnapshot(products: [
      CatalogItem(
          id: 'KUKU-MZIMA',
          name: 'Kuku mzima',
          price: 9000,
          priceVersion: 'p1',
          available: 1,
          held: '1'),
      // The server can cut 2 from the bird; the rule did not reach the phone.
      CatalogItem(
          id: 'NUSU-KUKU',
          name: 'Nusu kuku',
          price: 4500,
          priceVersion: 'p2',
          available: 2,
          held: '0'),
    ]));
    final products = {
      for (final p in await store.watchProducts().first) p.id: p
    };
    expect(products['NUSU-KUKU']!.availableToSell, 2);
    expect(products['KUKU-MZIMA']!.availableToSell, 1);
  });
}
