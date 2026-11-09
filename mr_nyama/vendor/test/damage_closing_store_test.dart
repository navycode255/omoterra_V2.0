import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/business_day.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/damage/damage_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'helpers.dart';

/// 9 October 2026, 20:00 in Dar es Salaam.
final now = DateTime.utc(2026, 10, 9, 17);

void main() {
  late AppDatabase db;
  late SalesStore sales;
  late DamageStore damage;
  late ClosingStore closing;
  late List<Product> products;

  setUp(() async {
    db = testDatabase();
    sales = SalesStore(db);
    damage = DamageStore(db);
    closing = ClosingStore(db);
    await sales.replaceCatalog(testCatalog);
    products = await sales.watchProducts().first;
  });
  tearDown(() => db.close());

  Product product(String id) => products.firstWhere((p) => p.id == id);

  Future<DamageEntry> report(
          {String id = 'r1', int qty = 2, String productId = 'kuku'}) =>
      damage.submit(
          reportId: id,
          product: product(productId),
          quantity: qty,
          reason: DamageReason.burnt,
          stationKey: 'S1',
          actorId: 'v1',
          now: now);

  group('damage reports', () {
    test('saved as a report; not a loss, but no longer for sale', () async {
      final r = await report();
      expect(r.syncStatus, 'saved');
      expect(r.review, 'reported');
      final kuku =
          (await sales.watchProducts().first).firstWhere((p) => p.id == 'kuku');
      // The server's stock is untouched (a report is a claim the office
      // verifies); what the vendor can sell drops (owner, 26 October 2026).
      expect(kuku.available, 8);
      expect(kuku.remaining, 6);
      expect(await sales.watchUnsentCount().first, 1);
    });

    test('a note never exceeds what the server accepts', () async {
      final r = await damage.submit(
          reportId: 'long',
          product: product('kuku'),
          quantity: 1,
          reason: DamageReason.other,
          note: 'x' * 250,
          stationKey: 'S1',
          actorId: 'v1',
          now: now);
      expect(r.note, hasLength(damageNoteMaxLength));
    });

    test('a positive quantity and a known product are required', () async {
      expect(() => report(qty: 0), throwsA(isA<DamageRefused>()));
      expect(
          () => damage.submit(
              reportId: 'x',
              product: const Product(id: 'gone', name: 'Gone', price: 1),
              quantity: 1,
              reason: DamageReason.other,
              stationKey: 'S1',
              actorId: 'v1',
              now: now),
          throwsA(isA<DamageRefused>()));
    });

    test('the same report twice is stored once; a similar one is spotted',
        () async {
      await report();
      await report();
      expect(await db.select(db.damageReports).get(), hasLength(1));
      final similar = await damage.recentSimilar(
          productId: 'kuku',
          quantity: 2,
          reason: DamageReason.burnt,
          now: now.add(const Duration(minutes: 2)));
      expect(similar, isNotNull);
      final later = await damage.recentSimilar(
          productId: 'kuku',
          quantity: 2,
          reason: DamageReason.burnt,
          now: now.add(const Duration(minutes: 10)));
      expect(later, isNull);
    });
  });

  group('closing count', () {
    Future<ClosingView> close(
            {String id = 'c1', Map<String, int>? counted, DateTime? at}) =>
        closing.submit(
            countId: id,
            vendorId: 'v1',
            stationKey: 'S1',
            now: at ?? now,
            products: products,
            counted: counted ?? {'kuku': 6, 'paja': 0});

    test('every tracked product is counted; untracked ones are not asked',
        () async {
      expect(productsToCount(products).map((p) => p.id), ['kuku', 'paja']);
      final view = await close();
      expect(view.status, ClosingStatus.savedOnPhone);
      expect(view.businessDate, businessDate(now));
      expect({for (final l in view.lines) l.productId: l.counted},
          {'kuku': 6, 'paja': 0});
      expect({for (final l in view.lines) l.productId: l.recorded},
          {'kuku': 8, 'paja': 3});
    });

    test('a missing or negative count is refused', () async {
      expect(
          () => close(counted: {'kuku': 6}),
          throwsA(isA<ClosingRefused>()
              .having((e) => e.block, 'block', ClosingBlock.missingProducts)));
      expect(
          () => close(counted: {'kuku': -1, 'paja': 0}),
          throwsA(isA<ClosingRefused>()
              .having((e) => e.block, 'block', ClosingBlock.invalid)));
      expect(await db.select(db.closingCounts).get(), isEmpty);
    });

    test('a retry stores one count; a second count is staff-only', () async {
      await close();
      await close();
      expect(await db.select(db.closingCounts).get(), hasLength(1));
      expect(
          () => close(id: 'c2', counted: {'kuku': 7, 'paja': 0}),
          throwsA(isA<ClosingRefused>()
              .having((e) => e.block, 'block', ClosingBlock.alreadyClosed)));
      // The next business day starts fresh.
      await close(id: 'c3', at: now.add(const Duration(days: 1)));
      expect(await db.select(db.closingCounts).get(), hasLength(2));
    });

    test('status moves only as the server says, never contradicting itself',
        () async {
      Future<ClosingStatus> status() async => (await closing
              .watchForDay(
                  vendorId: 'v1',
                  stationKey: 'S1',
                  businessDay: businessDate(now))
              .first)!
          .status;
      await close();
      expect(await status(), ClosingStatus.savedOnPhone);
      await closing.applyResult('c1');
      expect(await status(), ClosingStatus.awaitingOffice);
      await closing.applyResult('c1', officeConfirmed: true);
      expect(await status(), ClosingStatus.confirmed);
      await closing.applyResult('c1', officeConfirmed: true);
      expect(await status(), ClosingStatus.confirmed);
    });
  });
}
