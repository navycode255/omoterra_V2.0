import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_history.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/sync/sync_engine.dart';
import 'package:mr_nyama_vendor/features/history/history_recovery.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'helpers.dart';

/// 9 October 2026, 15:00 in Dar es Salaam.
final now = DateTime.utc(2026, 10, 9, 12);
const sw = Strings('sw');

/// The fake vendor API, plus the server's history of this vendor.
class HistoryApi extends FakeVendorRepository
    implements VendorHistoryRepository {
  VendorHistory value = const VendorHistory();
  Object? failure;
  final historyCalls = <String>[];

  @override
  Future<VendorHistory> history(String token,
      {String? from, String? to}) async {
    historyCalls.add('$from..$to');
    if (failure != null) throw failure!;
    return value;
  }
}

/// What the server holds: a verified sale and a voided one today, a receipt,
/// a damage report and yesterday's count.
VendorHistory serverHistory({String extraSale = 'srv-2'}) =>
    VendorHistory(from: '2026-09-09', to: '2026-10-09', sales: [
      RecoveredSale(
          clientId: 'srv-1',
          paymentMethod: 'cash',
          status: 'verified',
          recordedAt: DateTime.utc(2026, 10, 9, 7),
          total: 18000,
          stationKey: 'S1',
          lines: const [
            RecoveredSaleLine(
                productId: 'kuku',
                productName: 'Kuku mzima',
                quantity: 2,
                unitPrice: 9000,
                lineTotal: 18000,
                priceVersion: 'v1')
          ]),
      RecoveredSale(
          clientId: extraSale,
          paymentMethod: 'cash',
          status: 'reported',
          recordedAt: DateTime.utc(2026, 10, 9, 8),
          total: 2000,
          lines: const [
            RecoveredSaleLine(
                productId: 'paja',
                productName: 'Paja (Robo)',
                quantity: 1,
                unitPrice: 2000,
                lineTotal: 2000)
          ],
          voided: RecoveredVoid(
              voidId: 'void-1',
              reason: 'duplicate',
              requestedAt: DateTime.utc(2026, 10, 9, 8, 5))),
    ], receipts: [
      RecoveredReceipt(
          receiptId: 'rcp-1',
          eventId: 'evt-1',
          consignmentId: 'con-1',
          consignmentVersion: 1,
          stationKey: 'S1',
          receivedAt: DateTime.utc(2026, 10, 9, 5),
          lines: const [
            RecoveredReceiptLine(lineId: 'line-1', accepted: 10, rejected: 0)
          ])
    ], damageReports: [
      RecoveredDamage(
          reportId: 'dmg-1',
          productId: 'kuku',
          productName: 'Kuku mzima',
          reason: 'burnt',
          review: 'verified',
          quantity: 1,
          stationKey: 'S1',
          reportedAt: DateTime.utc(2026, 10, 9, 6))
    ], closingCounts: [
      RecoveredCount(
          countId: 'cnt-1',
          businessDate: '2026-10-08',
          officeStatus: 'confirmed',
          stationKey: 'S1',
          countedAt: DateTime.utc(2026, 10, 8, 17),
          lines: const [
            RecoveredCountLine(
                productId: 'kuku', productName: 'Kuku mzima', counted: 8)
          ])
    ]);

void main() {
  testWidgets('a new phone gets the vendor\'s records back, as already sent',
      (tester) async {
    final api = HistoryApi()..value = serverHistory();
    final app = await pumpApp(tester, repository: api, now: now);
    // The shell recovers by itself: the phone held no sales of this vendor.
    expect(api.historyCalls, ['2026-09-09..2026-10-09']);
    final db = app.db;
    final sales = await (db.select(db.sales)
          ..orderBy([(s) => OrderingTerm(expression: s.recordedAt)]))
        .get();
    expect([for (final s in sales) (s.clientId, s.syncStatus, s.verification)],
        [('srv-1', 'sent', 'verified'), ('srv-2', 'sent', 'unverified')]);
    expect((await db.select(db.saleLines).get()).length, 2);
    expect((await db.select(db.saleVoids).getSingle()).syncStatus, 'accepted');
    expect((await db.select(db.receipts).getSingle()).syncStatus, 'accepted');
    expect((await db.select(db.damageReports).getSingle()).review, 'verified');
    final count = await db.select(db.closingCounts).getSingle();
    expect((count.syncStatus, count.officeStatus), ('sent', 'confirmed'));
    // Nothing is queued: the server already has all of it.
    expect(await db.select(db.outbox).get(), isEmpty);
    await app.container.read(syncEngineProvider.notifier).syncNow();
    expect(api.syncedBatches, isEmpty);

    // History shows them, saying where they came from.
    app.router.push(MNRoutes.history);
    await tester.pumpAndSettle();
    expect(find.text(sw.recoveryDone(2)), findsOneWidget);
    expect(find.textContaining(sw.recoveredFromOffice), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records on this phone win; only what is missing is added',
      (tester) async {
    final api = HistoryApi()..failure = Exception('offline');
    final app = await pumpApp(tester, repository: api, now: now);
    expect(api.historyCalls, hasLength(1)); // tried once, failed quietly
    // The vendor sells while offline: saved on the phone, not yet sent.
    await app.container.read(salesStoreProvider).saveSale(SaleDraft(
            clientId: 'srv-2',
            vendorId: 'v1',
            recordedAt: DateTime.utc(2026, 10, 9, 8),
            payment: PaymentMethod.cash,
            lines: const [
              DraftLine(
                  productId: 'paja',
                  productName: 'Paja (Robo)',
                  quantity: 1,
                  unitPrice: 2000)
            ]));
    api
      ..failure = null
      ..value = serverHistory();
    await app.container.read(historyRecoveryProvider.notifier).recover();
    final db = app.db;
    final kept = await (db.select(db.sales)
          ..where((s) => s.clientId.equals('srv-2')))
        .getSingle();
    expect(kept.syncStatus, 'saved'); // the phone's record stands
    expect(await db.select(db.saleVoids).get(), isEmpty);
    expect((await db.select(db.sales).get()).length, 2);
    // Only the phone's own sale is queued.
    expect(
        [for (final o in await db.select(db.outbox).get()) o.opId], ['srv-2']);
    expect(app.container.read(historyRecoveryProvider).added, 1);
  });

  testWidgets('recovered sales are not taken off the stock again',
      (tester) async {
    final api = HistoryApi()..value = serverHistory();
    final app = await pumpApp(tester, repository: api, now: now);
    final store = app.container.read(salesStoreProvider);
    await store.replaceCatalog(testCatalog);
    final products = await store.watchProducts().first;
    final kuku = products.firstWhere((p) => p.id == 'kuku');
    // The server's 8 already reflect its sales; the recovered sale is not
    // counted as unsent.
    expect((kuku.pendingSold, kuku.remaining), (0, 8));
  });

  testWidgets('a phone that holds sales is not recovered by itself',
      (tester) async {
    final api = HistoryApi()..value = serverHistory();
    final app = await pumpApp(tester, repository: api, now: now);
    expect(api.historyCalls, hasLength(1));
    // The next start of the app (a fresh notifier): the sales are there.
    app.container.invalidate(historyRecoveryProvider);
    await app.container.read(historyRecoveryProvider.notifier).recoverIfEmpty();
    expect(api.historyCalls, hasLength(1));
  });

  testWidgets('a failure offers a retry and never blocks the history',
      (tester) async {
    final api = HistoryApi()..failure = Exception('offline');
    final app = await pumpApp(tester, repository: api, now: now);
    app.router.push(MNRoutes.history);
    await tester.pumpAndSettle();
    expect(find.text(sw.recoveryFailed), findsOneWidget);
    expect(find.text(sw.noSalesDay), findsOneWidget);
    api
      ..failure = null
      ..value = serverHistory();
    await tester.tap(find.widgetWithText(MNButton, sw.retry));
    await tester.pumpAndSettle();
    expect(find.text(sw.recoveryDone(2)), findsOneWidget);
    expect(find.textContaining('Kuku mzima'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
