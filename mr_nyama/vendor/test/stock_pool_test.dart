import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/features/sales/stock_pool.dart';

import 'helpers.dart';

// The same cases as the server's tests/test_cuts.py, so both sides agree.
const toHalf = CutRule('KUKU-MZIMA', 2);
const toLeg = CutRule('NUSU-KUKU', 1);
const toBreast = CutRule('NUSU-KUKU', 1);

List<PoolEntry> shop({int birds = 3, int legs = 0, int breasts = 0}) => [
      PoolEntry(id: 'KUKU-MZIMA', held: '$birds'),
      const PoolEntry(id: 'NUSU-KUKU', held: '0', cut: toHalf),
      PoolEntry(id: 'PAJA-ROBO', held: '0', pendingSold: legs, cut: toLeg),
      PoolEntry(
          id: 'KIDALI-ROBO', held: '0', pendingSold: breasts, cut: toBreast),
    ];

void main() {
  test('pieces are sellable from whole birds', () {
    final s = poolStock(shop());
    expect(s.remaining,
        {'KUKU-MZIMA': 3, 'NUSU-KUKU': 0, 'PAJA-ROBO': 0, 'KIDALI-ROBO': 0});
    expect(s.sellable,
        {'KUKU-MZIMA': 3, 'NUSU-KUKU': 6, 'PAJA-ROBO': 6, 'KIDALI-ROBO': 6});
  });

  test('a Paja sold from a bird leaves a Nusu and a Kidali', () {
    // The owner's example: 3 birds, one Paja sold.
    final s = poolStock(shop(legs: 1));
    expect(s.remaining,
        {'KUKU-MZIMA': 2, 'NUSU-KUKU': 1, 'PAJA-ROBO': 0, 'KIDALI-ROBO': 1});
    expect(s.sellable['PAJA-ROBO'], 5);
    expect(s.sellable['KIDALI-ROBO'], 6);
  });

  test('a Kidali sold leaves a Paja, and both leave a Nusu', () {
    expect(poolStock(shop(breasts: 1)).remaining,
        {'KUKU-MZIMA': 2, 'NUSU-KUKU': 1, 'PAJA-ROBO': 1, 'KIDALI-ROBO': 0});
    expect(poolStock(shop(legs: 1, breasts: 1)).remaining,
        {'KUKU-MZIMA': 2, 'NUSU-KUKU': 1, 'PAJA-ROBO': 0, 'KIDALI-ROBO': 0});
  });

  test('an oversold bird shows below zero', () {
    final s = poolStock(shop(birds: 0, legs: 1));
    expect(s.remaining['KUKU-MZIMA'], -1);
    // The Kidali and the other Nusu that cut would leave, as on the server;
    // the sale lines carry the oversold flag.
    expect(s.sellable['KIDALI-ROBO'], 2);
  });

  test('the sales store cuts for unsent sales like the server', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = SalesStore(db);
    CatalogItem item(String id, int price, {CutRule? cut}) => CatalogItem(
        id: id,
        name: id,
        price: price,
        priceVersion: 'p-$id',
        available: 3,
        held: id == 'KUKU-MZIMA' ? '3' : '0',
        cutFrom: cut?.from,
        cutCount: cut?.count);
    await store.replaceCatalog(CatalogSnapshot(products: [
      item('KUKU-MZIMA', 9000),
      item('NUSU-KUKU', 4500, cut: toHalf),
      item('PAJA-ROBO', 2000, cut: toLeg),
      item('KIDALI-ROBO', 2500, cut: toBreast),
    ]));
    await store.saveSale(SaleDraft(
        clientId: 's1',
        vendorId: 'v1',
        recordedAt: DateTime(2026, 10, 25, 12),
        payment: PaymentMethod.cash,
        lines: const [
          DraftLine(
              productId: 'PAJA-ROBO',
              productName: 'Paja',
              quantity: 1,
              unitPrice: 2000,
              priceVersion: 'p-PAJA-ROBO')
        ]));
    final products = {
      for (final p in await store.watchProducts().first) p.id: p
    };
    expect(products['KUKU-MZIMA']!.remaining, 2);
    expect(products['NUSU-KUKU']!.remaining, 1);
    expect(products['KIDALI-ROBO']!.remaining, 1);
    expect(products['PAJA-ROBO']!.remaining, 0);
    // Still sellable by cutting: 1 from the Nusu, 4 from the 2 birds.
    expect(products['PAJA-ROBO']!.availableToSell, 5);
  });
}
