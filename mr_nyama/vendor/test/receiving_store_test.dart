import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/features/receiving/receiving_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'helpers.dart';

DeliveryManifest manifest({int version = 1, String station = 'S1'}) =>
    DeliveryManifest(
        consignmentId: 'c1',
        version: version,
        reference: 'OMT-2041',
        sender: 'Omoterra',
        stationKey: station,
        stationName: 'Kariakoo',
        dispatchedAt: DateTime.utc(2026, 10, 9, 5),
        lines: const [
          ManifestLine(
              lineId: 'L1',
              productId: 'kuku',
              productName: 'Kuku mzima',
              quantity: 50),
          ManifestLine(
              lineId: 'L2',
              productId: 'paja',
              productName: 'Paja (Robo)',
              quantity: 30),
        ]);

void main() {
  late AppDatabase db;
  late ReceivingStore store;

  setUp(() async {
    db = testDatabase();
    store = ReceivingStore(db);
    await SalesStore(db).replaceCatalog(testCatalog);
    await store.replaceDeliveries([manifest()]);
  });
  tearDown(() => db.close());

  Future<ReceiptView> submit(List<LineCount> counts,
          {String eventId = 'event-1',
          String receiptId = 'receipt-1',
          String station = 'S1',
          int version = 1}) =>
      store.submitReceipt(
          receiptId: receiptId,
          eventId: eventId,
          consignmentId: 'c1',
          consignmentVersion: version,
          sessionStationKey: station,
          actorId: 'v1',
          receivedAt: DateTime.utc(2026, 10, 9, 6),
          counts: counts);

  Matcher refused(ReceiptBlock block) =>
      throwsA(isA<ReceiptRefused>().having((e) => e.block, 'block', block));

  const full = [LineCount('L1', 50), LineCount('L2', 30)];

  test('full receipt: saved on the phone, nothing accepted yet', () async {
    final receipt = await submit(full);
    expect(receipt.status, ReceivingStatus.savedOnPhone);
    final d = (await store.delivery('c1'))!;
    expect(d.receivedUnits, 80);
    expect(d.lines.every((l) => l.received!.reason == null), isTrue);
  });

  test('partial receipt keeps missing and refused units apart', () async {
    await submit(const [
      LineCount('L1', 48, DiscrepancyReason.damaged),
      LineCount('L2', 25, DiscrepancyReason.short),
    ]);
    final lines = (await db.select(db.receiptLines).get())
      ..sort((a, b) => a.lineId.compareTo(b.lineId));
    expect([lines[0].accepted, lines[0].rejected, lines[0].reason],
        [48, 2, 'damaged']);
    expect([lines[1].accepted, lines[1].rejected, lines[1].reason],
        [25, 0, 'short']);
  });

  test('a different count needs a reason; it is never assumed', () async {
    expect(() => submit(const [LineCount('L1', 48), LineCount('L2', 30)]),
        refused(ReceiptBlock.missingReason));
    expect(await db.select(db.receipts).get(), isEmpty);
  });

  test('invalid quantities are refused', () async {
    expect(
        () => submit(const [
              LineCount('L1', 51, DiscrepancyReason.other),
              LineCount('L2', 30)
            ]),
        refused(ReceiptBlock.aboveDispatched));
    expect(() => submit(const [LineCount('L1', -1), LineCount('L2', 30)]),
        refused(ReceiptBlock.invalid));
    expect(() => submit(const [LineCount('L1', 50)]),
        refused(ReceiptBlock.invalid));
    expect(
        () => submit(const [
              LineCount('L1', 0, DiscrepancyReason.short),
              LineCount('L2', 0, DiscrepancyReason.short)
            ]),
        refused(ReceiptBlock.nothingReceived));
  });

  test('the same acknowledgment twice records one receipt', () async {
    final first = await submit(full);
    final again = await submit(full);
    expect(again.receiptId, first.receiptId);
    expect(await db.select(db.receipts).get(), hasLength(1));
    expect(await db.select(db.receiptLines).get(), hasLength(2));
    // A different acknowledgment for the same delivery is refused.
    expect(() => submit(full, eventId: 'event-2', receiptId: 'receipt-2'),
        refused(ReceiptBlock.alreadyReceived));
  });

  test('another station\'s delivery cannot be received', () async {
    expect(
        () => submit(full, station: 'S2'), refused(ReceiptBlock.wrongStation));
  });

  test('a manifest changed offline is a conflict, never overwritten', () async {
    await submit(full);
    await store.replaceDeliveries([manifest(version: 2)]);
    final d = (await store.delivery('c1'))!;
    expect(d.receipt!.status, ReceivingStatus.conflict);
    expect(d.receipt!.conflictReason, 'manifest_changed');
    expect(d.receipt!.consignmentVersion, 1);
    // The count still reads against what was counted.
    expect(d.receivedUnits, 80);
  });

  test('counting against a stale version is refused', () async {
    await store.replaceDeliveries([manifest(version: 2)]);
    expect(
        () => submit(full, version: 1), refused(ReceiptBlock.manifestChanged));
  });

  test('receiving never changes stock on the phone', () async {
    await submit(full);
    final products = await db.select(db.catalogProducts).get();
    expect({for (final p in products) p.id: p.available},
        {'kuku': 8, 'paja': 3, 'kidali': null, 'maini': null});
  });

  test('server answers apply once; repeating them changes nothing', () async {
    await submit(full);
    expect(await SalesStore(db).watchUnsentCount().first, 1);
    for (var i = 0; i < 2; i++) {
      await store.applyReceiptResult('event-1',
          status: ReceivingStatus.accepted);
    }
    final receipts = await db.select(db.receipts).get();
    expect(receipts.single.syncStatus, 'accepted');
    expect(await SalesStore(db).watchUnsentCount().first, 0);
  });

  test('deliveries no longer listed disappear unless received', () async {
    await store.replaceDeliveries([]);
    expect(await store.delivery('c1'), isNull);
    await store.replaceDeliveries([manifest()]);
    await submit(full);
    await store.replaceDeliveries([]);
    expect(await store.delivery('c1'), isNotNull);
  });
}
