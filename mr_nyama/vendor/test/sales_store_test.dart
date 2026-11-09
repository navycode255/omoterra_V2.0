import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late SalesStore store;

  setUp(() async {
    db = testDatabase();
    store = SalesStore(db);
    await store.replaceCatalog(testCatalog);
  });
  tearDown(() => db.close());

  SaleDraft draft(String id, List<DraftLine> lines,
          {PaymentMethod payment = PaymentMethod.cash}) =>
      SaleDraft(
          clientId: id,
          vendorId: 'v1',
          recordedAt: DateTime(2026, 10, 9, 11, 25),
          payment: payment,
          lines: lines);

  DraftLine line(String id, int qty, int price) => DraftLine(
      productId: id,
      productName: id,
      quantity: qty,
      unitPrice: price,
      priceVersion: 'v1');

  test('a single-line sale is saved with its exact total', () async {
    final sale = await store.saveSale(draft('s1', [line('kuku', 1, 9000)]));
    expect(sale.total, 9000);
    expect(sale.itemCount, 1);
    expect(sale.syncStatus, 'saved');
    expect(sale.payment, PaymentMethod.cash);
  });

  test('multi-line totals are exact integers, even for large sales', () async {
    final sale = await store.saveSale(draft('s2', [
      line('kidali', 3, 2500),
      line('kuku', 7, 9000),
      line('paja', 999, 2000),
    ]));
    expect(sale.total, 3 * 2500 + 7 * 9000 + 999 * 2000);
    expect(sale.total, 2068500);
    expect(sale.itemCount, 1009);
    final lines = await db.select(db.saleLines).get();
    expect(lines.map((l) => l.lineTotal), [7500, 63000, 1998000]);
    expect(lines.map((l) => l.priceVersion), everyElement('v1'));
  });

  test('saving the same client ID twice records one sale', () async {
    final first = await store.saveSale(draft('dup', [line('kuku', 1, 9000)]));
    final second = await store.saveSale(
        draft('dup', [line('kuku', 5, 9000)], payment: PaymentMethod.mpesa));
    expect(second.total, first.total);
    expect(second.payment, PaymentMethod.cash);
    expect(await db.select(db.sales).get(), hasLength(1));
    expect(await db.select(db.saleLines).get(), hasLength(1));
  });

  test('empty or non-positive sales are refused', () async {
    expect(() => store.saveSale(draft('e', [])), throwsArgumentError);
    expect(() => store.saveSale(draft('z', [line('kuku', 0, 9000)])),
        throwsArgumentError);
    expect(await db.select(db.sales).get(), isEmpty);
  });

  test(
      'unsent sales lower what the phone shows as remaining; never more '
      'stock is created', () async {
    await store.saveSale(draft('s3', [line('paja', 5, 2000)]));
    final products = await store.watchProducts().first;
    final paja = products.firstWhere((p) => p.id == 'paja');
    expect(paja.available, 3); // the server's figure is untouched
    expect(paja.pendingSold, 5);
    expect(paja.remaining, -2);
    final kidali = products.firstWhere((p) => p.id == 'kidali');
    expect(kidali.remaining, isNull); // not tracked: no warning possible
    expect(await store.watchUnsentCount().first, 1);
  });

  test(
      'catalogue replacement keeps server prices and clears a removed '
      'M-Pesa number', () async {
    expect(await store.watchMpesaRecipient().first, '123456');
    await store.replaceCatalog(const CatalogSnapshot(products: [
      CatalogItem(id: 'kuku', name: 'Kuku mzima', price: 9500),
    ]));
    expect(await store.watchMpesaRecipient().first, isNull);
    final products = await store.watchProducts().first;
    expect(products.single.price, 9500);
  });

  group('the phone follows the same stock lifecycle as the server', () {
    // Receive 40, sell 15: Imesalia is 25 until staff act.
    final at = DateTime.utc(2026, 10, 9, 12);
    const kuku = CatalogItem(
        id: 'kuku',
        name: 'Kuku mzima',
        price: 9000,
        priceVersion: 'v1',
        category: 'kuku',
        available: 40,
        held: '40');

    Future<int?> remaining() async => (await store.watchProducts().first)
        .firstWhere((p) => p.id == 'kuku')
        .remaining;

    Future<void> sell() async {
      await store.replaceCatalog(const CatalogSnapshot(products: [kuku]));
      expect(await remaining(), 40);
      await store.saveSale(SaleDraft(
          clientId: 'life-1',
          vendorId: 'v1',
          recordedAt: at,
          payment: PaymentMethod.cash,
          lines: [line('kuku', 15, 9000)]));
      expect(await remaining(), 25);
    }

    test('sent and accepted: still 25 once the catalogue refreshes', () async {
      await sell();
      await (db.update(db.sales)..where((x) => x.clientId.equals('life-1')))
          .write(const SalesCompanion(syncStatus: Value('sent')));
      // The server now takes the 15 off its own figure.
      await store.replaceCatalog(const CatalogSnapshot(products: [
        CatalogItem(
            id: 'kuku',
            name: 'Kuku mzima',
            price: 9000,
            priceVersion: 'v1',
            category: 'kuku',
            available: 25,
            held: '25')
      ]));
      expect(await remaining(), 25);
    });

    test('a voided sale restores 40', () async {
      await sell();
      await HistoryStore(db).voidSale(
          voidId: 'void-life',
          saleClientId: 'life-1',
          reason: VoidReason.wrongQuantity,
          actorId: 'v1',
          now: at);
      expect(await remaining(), 40);
    });

    test('a refused sale restores 40', () async {
      await sell();
      await (db.update(db.sales)..where((x) => x.clientId.equals('life-1')))
          .write(const SalesCompanion(syncStatus: Value('rejected')));
      expect(await remaining(), 40);
    });
  });
}
