import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/business_day.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'helpers.dart';

/// 9 October 2026, 15:00 in Dar es Salaam.
final now = DateTime.utc(2026, 10, 9, 12);

Future<void> recordSale(SalesStore store, String id, DateTime at,
        {String vendor = 'v1', int qty = 2, int price = 2000}) =>
    store.saveSale(SaleDraft(
        clientId: id,
        vendorId: vendor,
        recordedAt: at,
        payment: PaymentMethod.cash,
        lines: [
          DraftLine(
              productId: 'paja',
              productName: 'Paja (Robo)',
              quantity: qty,
              unitPrice: price)
        ]));

void main() {
  late AppDatabase db;
  late SalesStore sales;
  late HistoryStore history;

  setUp(() async {
    db = testDatabase();
    sales = SalesStore(db);
    history = HistoryStore(db);
    await sales.replaceCatalog(testCatalog);
  });
  tearDown(() => db.close());

  Future<VoidRecord> voidIt(String saleId,
          {String voidId = 'void-0001', String actor = 'v1', DateTime? at}) =>
      history.voidSale(
          voidId: voidId,
          saleClientId: saleId,
          reason: VoidReason.wrongQuantity,
          actorId: actor,
          now: at ?? now);

  test('a day is the Dar es Salaam calendar day, newest first', () async {
    // 23:59 EAT on the 8th and 00:01 EAT on the 9th.
    await recordSale(sales, 'late-0008', DateTime.utc(2026, 10, 8, 20, 59));
    await recordSale(sales, 'early-0009', DateTime.utc(2026, 10, 8, 21, 1));
    await recordSale(sales, 'noon-00009', DateTime.utc(2026, 10, 9, 9));
    final today = await history.watchDay(businessDate(now)).first;
    expect(today.map((e) => e.clientId), ['noon-00009', 'early-0009']);
    final yesterday = await history
        .watchDay(businessDate(now).subtract(const Duration(days: 1)))
        .first;
    expect(yesterday.map((e) => e.clientId), ['late-0008']);
  });

  test('a void is a separate record; the sale and its lines stay', () async {
    await recordSale(sales, 'sale-0001', now);
    final record = await voidIt('sale-0001');
    expect(record.state, VoidState.pending);
    expect(record.actorId, 'v1');
    expect(record.reason, VoidReason.wrongQuantity);
    expect(await db.select(db.sales).get(), hasLength(1));
    expect(await db.select(db.saleLines).get(), hasLength(1));
    final entry = (await history.watchDay(businessDate(now)).first).single;
    expect(entry.voided, isTrue);
    expect(entry.total, 4000); // the original amount is kept
  });

  test('repeating the same void records one; a second void is refused',
      () async {
    await recordSale(sales, 'sale-0001', now);
    final first = await voidIt('sale-0001');
    final again = await voidIt('sale-0001');
    expect(again.voidId, first.voidId);
    expect(await db.select(db.saleVoids).get(), hasLength(1));
    expect(
        () => voidIt('sale-0001', voidId: 'void-0002'),
        throwsA(isA<VoidRefused>()
            .having((e) => e.block, 'block', VoidBlock.alreadyVoided)));
  });

  test('ineligible voids are refused by the store, not only hidden', () async {
    await recordSale(sales, 'other-001', now, vendor: 'v2');
    await recordSale(sales, 'old-00001', now.subtract(const Duration(days: 1)));
    await recordSale(sales, 'checked-1', now);
    await history.markVerified('checked-1');
    for (final (id, block) in [
      ('other-001', VoidBlock.notOwner),
      ('old-00001', VoidBlock.notToday),
      ('checked-1', VoidBlock.verified),
    ]) {
      expect(() => voidIt(id, voidId: 'v-$id'),
          throwsA(isA<VoidRefused>().having((e) => e.block, 'block', block)),
          reason: id);
    }
    expect(await db.select(db.saleVoids).get(), isEmpty);
  });

  test('offline conflict: verified before the queued void arrived', () async {
    await recordSale(sales, 'sale-0001', now);
    await voidIt('sale-0001');
    // The server answers when the phone syncs.
    await history.markVerified('sale-0001');
    await history.applyVoidResult('void-0001',
        accepted: false, rejectionReason: 'already_verified');
    final detail = (await history.sale('sale-0001'))!;
    expect(detail.entry.voided, isFalse);
    expect(detail.entry.verified, isTrue);
    expect(detail.voidRecord!.state, VoidState.rejected);
    expect(detail.voidRecord!.rejectionReason, 'already_verified');
    expect(HistoryStore.voidBlock(detail, 'v1', now), VoidBlock.verified);
  });

  test('voids wait to sync; a voided sale no longer takes stock', () async {
    await recordSale(sales, 'sale-0001', now, qty: 2);
    expect(await sales.watchUnsentCount().first, 1);
    var paja =
        (await sales.watchProducts().first).firstWhere((p) => p.id == 'paja');
    expect(paja.pendingSold, 2);
    await voidIt('sale-0001');
    expect(await sales.watchUnsentCount().first, 2);
    paja =
        (await sales.watchProducts().first).firstWhere((p) => p.id == 'paja');
    expect(paja.pendingSold, 0);
  });

  test('references are short and stable', () {
    expect(
        saleReference('3f2a9c1b-0000-4000-8000-000000000000'), 'MN-3F2A9C1B');
    // Never expected from the server, but it must not crash the history.
    expect(saleReference('s1'), 'MN-S1');
  });
}
