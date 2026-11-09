import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/providers.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/business_day.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/core/sync/sync_engine.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/home/dashboard.dart';
import 'package:mr_nyama_vendor/features/receiving/receiving_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';

import 'helpers.dart';

/// A signed-in vendor on [db], with a fake server and a movable clock.
class Harness {
  final AppDatabase db;
  final FakeVendorRepository api;
  final InMemoryStore store;
  DateTime now;
  late final ProviderContainer container;

  Harness(this.db, {FakeVendorRepository? api, InMemoryStore? store})
      : api = api ?? (FakeVendorRepository()..syncFailure = null),
        store = store ?? (InMemoryStore()..signIn()),
        now = DateTime.now() {
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      vendorRepositoryProvider.overrideWithValue(this.api),
      keyValueStoreProvider.overrideWithValue(this.store),
      clockProvider.overrideWithValue(() => now),
    ]);
    // Keep the counters subscribed, as the app's screens do.
    container.listen(queueCountsProvider, (_, __) {});
    container.listen(unsentCountProvider, (_, __) {});
  }

  /// The global indicator once the counters have caught up.
  Future<MNSyncStatus> status() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return container.read(syncStatusProvider);
  }

  Future<void> ready() => container.read(sessionProvider.future);
  SyncEngine get engine => container.read(syncEngineProvider.notifier);
  Future<void> sync() => engine.syncNow();

  Future<List<OutboxData>> outbox() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
          .get();

  Future<void> sale(String id, {int qty = 1}) =>
      SalesStore(db).saveSale(SaleDraft(
          clientId: id,
          vendorId: 'v1',
          stationKey: 'S1',
          recordedAt: now,
          payment: PaymentMethod.cash,
          lines: [
            DraftLine(
                productId: 'kuku',
                productName: 'Kuku mzima',
                quantity: qty,
                unitPrice: 9000,
                priceVersion: 'v1')
          ]));
}

void main() {
  late AppDatabase db;
  setUp(() async {
    db = testDatabase();
    await SalesStore(db).replaceCatalog(testCatalog);
  });
  tearDown(() => db.close());

  test('every queued operation carries the required fields', () async {
    final h = Harness(db);
    await h.ready();
    await h.sale('sale-1');
    final op = (await h.outbox()).single;
    expect(op.opId, 'sale-1');
    expect(op.opType, 'sale');
    expect(op.vendorId, 'v1');
    expect(op.stationKey, 'S1');
    expect(op.businessDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(op.status, 'saved');
    expect(op.attempts, 0);
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    expect(payload['client_id'], 'sale-1');
    expect(payload['lines'][0]['unit_price'], 9000);
    expect(payload['recorded_at'], endsWith('Z'));
  });

  test('offline: sales stay saved and waiting; nothing is marked sent',
      () async {
    final h = Harness(db,
        api: FakeVendorRepository()
          ..syncFailure = const AuthFailure(AuthFailureKind.offline));
    await h.ready();
    for (final id in ['s1', 's2', 's3']) {
      await h.sale(id);
    }
    await h.sync();
    final ops = await h.outbox();
    expect(ops.map((o) => o.status), everyElement('waiting'));
    expect(ops.map((o) => o.lastError), everyElement('offline'));
    expect(ops.map((o) => o.attempts), everyElement(1));
    expect(ops.every((o) => o.nextAttemptAt!.isAfter(h.now)), isTrue);
    final sales = await db.select(db.sales).get();
    expect(sales.map((s) => s.syncStatus), everyElement('saved'));
    expect(await h.status(), MNSyncStatus.waiting);
  });

  test('a record queued without a station is sent with the session\'s',
      () async {
    final h = Harness(db);
    await h.ready();
    await SalesStore(db).saveSale(SaleDraft(
        clientId: 'legacy',
        vendorId: 'v1',
        recordedAt: h.now,
        payment: PaymentMethod.cash,
        lines: const [
          DraftLine(
              productId: 'kuku',
              productName: 'Kuku mzima',
              quantity: 1,
              unitPrice: 9000)
        ]));
    await h.sync();
    expect(h.api.syncedBatches.single.single.stationKey, 'S1');
  });

  test('multiple queued sales go in one batch when the network returns',
      () async {
    final h = Harness(db);
    await h.ready();
    for (final id in ['s1', 's2', 's3']) {
      await h.sale(id);
    }
    await h.sync();
    expect(h.api.syncedBatches, hasLength(1));
    expect(h.api.syncedBatches.single.map((o) => o.opId), ['s1', 's2', 's3']);
    expect(
        (await h.outbox()).map((o) => o.status), everyElement('synchronized'));
    expect((await db.select(db.sales).get()).map((s) => s.syncStatus),
        everyElement('sent'));
  });

  test(
      'retries never duplicate: synchronized operations are not resent, '
      'and "duplicate" counts as accepted', () async {
    final h = Harness(db);
    h.api.syncDecision =
        (op) => OperationResult(op.opId, OperationOutcome.duplicate);
    await h.ready();
    await h.sale('s1');
    await h.sync();
    await h.sync();
    expect(h.api.syncedBatches, hasLength(1));
    expect((await h.outbox()).single.status, 'synchronized');
  });

  test('partial sync: only the operations the server answered are done',
      () async {
    final h = Harness(db);
    h.api.syncDecision = (op) => op.opId == 's2'
        ? null
        : OperationResult(op.opId, OperationOutcome.accepted);
    await h.ready();
    for (final id in ['s1', 's2', 's3']) {
      await h.sale(id);
    }
    await h.sync();
    final byId = {for (final o in await h.outbox()) o.opId: o};
    expect(byId['s1']!.status, 'synchronized');
    expect(byId['s2']!.status, 'waiting');
    expect(byId['s2']!.lastError, 'not_processed');
    // Later, only s2 is sent again.
    h.api.syncDecision = null;
    h.now = h.now.add(const Duration(minutes: 1));
    await h.sync();
    expect(h.api.syncedBatches.last.map((o) => o.opId), ['s2']);
  });

  test('network interruption: back-off is respected, then it retries',
      () async {
    final h = Harness(db,
        api: FakeVendorRepository()
          ..syncFailure = const AuthFailure(AuthFailureKind.offline));
    await h.ready();
    await h.sale('s1');
    await h.sync();
    h.api.syncFailure = null;
    await h.sync(); // still inside the 30 s back-off
    expect(h.api.syncedBatches, isEmpty);
    h.now = h.now.add(const Duration(seconds: 31));
    await h.sync();
    expect((await h.outbox()).single.status, 'synchronized');
  });

  test('app restart: an interrupted request is resent safely', () async {
    final first = Harness(db);
    await first.ready();
    await first.sale('s1');
    // The app died while the request was in flight.
    await (db.update(db.outbox))
        .write(const OutboxCompanion(status: Value('synchronizing')));
    first.container.dispose();

    final second = Harness(db);
    await second.ready();
    await second.sync();
    expect((await second.outbox()).single.status, 'synchronized');
  });

  test('device restart: the queue survives on disk', () async {
    final dir = await Directory.systemTemp.createTemp('mr_nyama_sync');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.db');
    AppDatabase open() => AppDatabase(DatabaseConnection(NativeDatabase(file),
        closeStreamsSynchronously: true));

    final before = open();
    await SalesStore(before).replaceCatalog(testCatalog);
    final h1 = Harness(before,
        api: FakeVendorRepository()
          ..syncFailure = const AuthFailure(AuthFailureKind.offline));
    await h1.ready();
    await h1.sale('s1');
    await h1.sync();
    h1.container.dispose();
    await before.close();

    final after = open();
    addTearDown(after.close);
    final h2 = Harness(after);
    h2.now = h2.now.add(const Duration(minutes: 1));
    await h2.ready();
    expect((await h2.outbox()).single.status, 'waiting');
    await h2.sync();
    expect((await h2.outbox()).single.status, 'synchronized');
  });

  test('expired session: nothing is lost; it syncs after the PIN', () async {
    final h = Harness(db,
        api: FakeVendorRepository()
          ..syncFailure = const AuthFailure(AuthFailureKind.sessionExpired));
    await h.ready();
    await h.sale('s1');
    await h.sync();
    expect(h.container.read(sessionProvider).valueOrNull, isA<Locked>());
    final op = (await h.outbox()).single;
    expect([op.status, op.lastError, op.nextAttemptAt],
        ['waiting', 'session_expired', null]);
    h.api.syncFailure = null;
    await h.container
        .read(sessionProvider.notifier)
        .signIn('+255712345678', '2580');
    await h.sync();
    expect((await h.outbox()).single.status, 'synchronized');
  });

  test('conflict: a sale verified before the queued void arrived', () async {
    final h = Harness(db);
    await h.ready();
    await h.sale('s1');
    await HistoryStore(db).voidSale(
        voidId: 'v-1',
        saleClientId: 's1',
        reason: VoidReason.wrongQuantity,
        actorId: 'v1',
        now: h.now);
    h.api
      ..verifiedSales = ['s1']
      ..syncDecision = (op) => op.opType == 'sale_void'
          ? OperationResult(
              op.opId, OperationOutcome.conflict, 'already_verified')
          : OperationResult(op.opId, OperationOutcome.accepted);
    await h.sync();
    final detail = (await HistoryStore(db).sale('s1'))!;
    expect(detail.entry.verified, isTrue);
    expect(detail.entry.voided, isFalse); // the sale stands
    expect(detail.voidRecord!.state, VoidState.rejected);
    final voidOp = (await h.outbox()).firstWhere((o) => o.opId == 'v-1');
    expect(
        [voidOp.status, voidOp.resultReason], ['conflict', 'already_verified']);
    // The local void is preserved for staff, and the indicator says so.
    expect(await db.select(db.saleVoids).get(), hasLength(1));
    expect(await h.status(), MNSyncStatus.attention);
  });

  test(
      'conflict: the manifest changed before the receipt arrived; '
      'queued receipts otherwise are accepted', () async {
    final h = Harness(db);
    await h.ready();
    final receiving = ReceivingStore(db);
    await receiving.replaceDeliveries([
      for (final id in ['c1', 'c2'])
        DeliveryManifest(
            consignmentId: id,
            version: 1,
            reference: id,
            sender: 'Omoterra',
            stationKey: 'S1',
            stationName: 'Kariakoo',
            dispatchedAt: h.now,
            lines: const [
              ManifestLine(
                  lineId: 'L1',
                  productId: 'kuku',
                  productName: 'Kuku',
                  quantity: 5)
            ])
    ]);
    for (final id in ['c1', 'c2']) {
      await receiving.submitReceipt(
          receiptId: 'r-$id',
          eventId: 'e-$id',
          consignmentId: id,
          consignmentVersion: 1,
          sessionStationKey: 'S1',
          actorId: 'v1',
          receivedAt: h.now,
          counts: const [LineCount('L1', 5)]);
    }
    h.api.syncDecision = (op) => op.opId == 'e-c1'
        ? OperationResult(
            op.opId, OperationOutcome.conflict, 'manifest_changed')
        : OperationResult(op.opId, OperationOutcome.accepted);
    await h.sync();
    expect((await receiving.delivery('c1'))!.status, ReceivingStatus.conflict);
    expect((await receiving.delivery('c2'))!.status, ReceivingStatus.accepted);
  });

  test(
      'conflict: today\'s count already came from another phone; queued '
      'counts otherwise wait for the office', () async {
    final h = Harness(db);
    await h.ready();
    final products = await SalesStore(db).watchProducts().first;
    final closing = ClosingStore(db);
    await closing.submit(
        countId: 'count-1',
        vendorId: 'v1',
        stationKey: 'S1',
        now: h.now,
        products: products,
        counted: {'kuku': 3, 'paja': 1});
    h.api.syncDecision = (op) =>
        OperationResult(op.opId, OperationOutcome.conflict, 'already_closed');
    await h.sync();
    Future<ClosingView?> view() => closing
        .watchForDay(
            vendorId: 'v1', stationKey: 'S1', businessDay: businessDate(h.now))
        .first;
    final v = (await view())!;
    expect(v.status, ClosingStatus.conflict);
    expect(v.conflictReason, 'already_closed');
    expect(v.lines, hasLength(2)); // local count preserved
  });

  test('accepted closing counts show as sent and awaiting the office',
      () async {
    final h = Harness(db);
    await h.ready();
    final products = await SalesStore(db).watchProducts().first;
    final closing = ClosingStore(db);
    await closing.submit(
        countId: 'count-1',
        vendorId: 'v1',
        stationKey: 'S1',
        now: h.now,
        products: products,
        counted: {'kuku': 3, 'paja': 1});
    await h.sync();
    final row = (await db.select(db.closingCounts).get()).single;
    expect([row.syncStatus, row.officeStatus], ['sent', 'pending']);
  });

  test('the log keeps outcomes, never tokens, PINs or payloads', () async {
    final h = Harness(db,
        api: FakeVendorRepository()
          ..syncFailure = const AuthFailure(AuthFailureKind.offline));
    await h.ready();
    await h.sale('s1');
    await h.sync();
    final log = await db.select(db.syncLog).get();
    expect(log.single.outcome, 'offline');
    expect(log.single.sent, 1);
    final everything = [
      for (final row in log) row.toJson().toString(),
      for (final row in await h.outbox()) row.toJson().toString(),
    ].join(' ');
    expect(everything, isNot(contains('token-1')));
    expect(everything, isNot(contains('2580')));
    expect(log.single.detail, isNull);
  });

  test('another vendor\'s queued operations are never sent', () async {
    final h = Harness(db);
    await h.ready();
    await SalesStore(db).saveSale(SaleDraft(
        clientId: 'other',
        vendorId: 'v2',
        recordedAt: h.now,
        payment: PaymentMethod.cash,
        lines: const [
          DraftLine(
              productId: 'kuku',
              productName: 'Kuku',
              quantity: 1,
              unitPrice: 9000)
        ]));
    await h.sync();
    expect(h.api.syncedBatches, isEmpty);
    expect((await h.outbox()).single.status, 'saved');
  });
}
