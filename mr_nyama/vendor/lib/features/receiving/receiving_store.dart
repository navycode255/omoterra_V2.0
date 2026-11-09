import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/payloads.dart';
import '../sales/sales_store.dart';

/// Where a delivery stands from this phone's point of view. Stock changes
/// only at [accepted], and only on the server.
enum ReceivingStatus {
  /// Nobody has counted it on this phone yet.
  pending,

  /// Counted and saved on the phone; waiting to be sent.
  savedOnPhone,

  /// The receiving service accepted the count.
  accepted,

  /// Needs staff review (for example, the manifest changed after the count).
  conflict,

  /// The service refused the count.
  rejected,
}

/// Why a count differs from what was dispatched. Chosen by the vendor;
/// never assumed. Only damaged and wrong-product goods are recorded as
/// refused; short goods simply did not arrive.
enum DiscrepancyReason { short, damaged, wrongProduct, other }

extension DiscrepancyReasonCode on DiscrepancyReason {
  String get code => switch (this) {
        DiscrepancyReason.short => 'short',
        DiscrepancyReason.damaged => 'damaged',
        DiscrepancyReason.wrongProduct => 'wrong_product',
        DiscrepancyReason.other => 'other',
      };

  bool get refuses =>
      this == DiscrepancyReason.damaged ||
      this == DiscrepancyReason.wrongProduct;

  static DiscrepancyReason? fromCode(String? code) => code == null
      ? null
      : DiscrepancyReason.values.firstWhere((r) => r.code == code,
          orElse: () => DiscrepancyReason.other);
}

class ReceivedLine {
  final int accepted;
  final int rejected;
  final String? note;
  final DiscrepancyReason? reason;
  const ReceivedLine(this.accepted, this.rejected, this.reason, [this.note]);
}

class DeliveryLineView {
  final String lineId;
  final String productId;
  final String productName;
  final int dispatched;
  final String? imageKey;
  final ReceivedLine? received;
  const DeliveryLineView(
      {required this.lineId,
      required this.productId,
      required this.productName,
      required this.dispatched,
      this.imageKey,
      this.received});
}

class ReceiptView {
  final String receiptId;
  final String eventId;
  final int consignmentVersion;
  final DateTime receivedAt;
  final ReceivingStatus status;
  final String? conflictReason;
  const ReceiptView(
      {required this.receiptId,
      required this.eventId,
      required this.consignmentVersion,
      required this.receivedAt,
      required this.status,
      this.conflictReason});
}

class DeliveryView {
  final String consignmentId;
  final int version;
  final String reference;
  final String sender;
  final String stationKey;
  final String stationName;
  final DateTime dispatchedAt;
  final List<DeliveryLineView> lines;
  final ReceiptView? receipt;
  const DeliveryView(
      {required this.consignmentId,
      required this.version,
      required this.reference,
      required this.sender,
      required this.stationKey,
      required this.stationName,
      required this.dispatchedAt,
      required this.lines,
      this.receipt});

  ReceivingStatus get status => receipt?.status ?? ReceivingStatus.pending;
  int get dispatchedUnits => lines.fold(0, (n, l) => n + l.dispatched);
  int get receivedUnits =>
      lines.fold(0, (n, l) => n + (l.received?.accepted ?? 0));
}

/// The vendor's count of one line, as entered.
class LineCount {
  final String lineId;
  final int received;
  final DiscrepancyReason? reason;
  const LineCount(this.lineId, this.received, [this.reason]);
}

enum ReceiptBlock {
  notFound,
  wrongStation,
  manifestChanged,
  alreadyReceived,
  missingReason,
  aboveDispatched,
  nothingReceived,
  invalid,
}

class ReceiptRefused implements Exception {
  final ReceiptBlock block;
  final String? lineId;
  const ReceiptRefused(this.block, [this.lineId]);
  @override
  String toString() => 'ReceiptRefused($block, $lineId)';
}

/// Local receiving: cached manifests and the vendor's counts. Nothing here
/// changes stock; the server's stock movement service does that once it
/// accepts a receipt.
class ReceivingStore {
  final AppDatabase db;
  ReceivingStore(this.db);

  /// Stores the server's manifests. A receipt counted against an older
  /// version of a manifest is never re-pointed or overwritten: it is marked
  /// as a conflict for staff review. Deliveries the server no longer lists
  /// are dropped unless they have a receipt (history).
  Future<void> replaceDeliveries(List<DeliveryManifest> manifests) =>
      db.transaction(() async {
        for (final m in manifests) {
          await (db.update(db.receipts)
                ..where((r) =>
                    r.consignmentId.equals(m.consignmentId) &
                    r.consignmentVersion.isSmallerThanValue(m.version) &
                    r.syncStatus.equals('saved')))
              .write(const ReceiptsCompanion(
                  syncStatus: Value('conflict'),
                  conflictReason: Value('manifest_changed')));
          await db.into(db.deliveries).insertOnConflictUpdate(
              DeliveriesCompanion.insert(
                  consignmentId: m.consignmentId,
                  version: m.version,
                  reference: m.reference,
                  sender: m.sender,
                  stationKey: m.stationKey,
                  stationName: m.stationName,
                  dispatchedAt: m.dispatchedAt));
          final hasReceipt = await _receiptFor(m.consignmentId) != null;
          // Lines stay as counted once a receipt exists, so the count is
          // always shown against the manifest it was made for.
          if (!hasReceipt) {
            await (db.delete(db.deliveryLines)
                  ..where((l) => l.consignmentId.equals(m.consignmentId)))
                .go();
            await db.batch((b) => b.insertAll(db.deliveryLines, [
                  for (final l in m.lines)
                    DeliveryLinesCompanion.insert(
                        consignmentId: m.consignmentId,
                        lineId: l.lineId,
                        productId: l.productId,
                        productName: l.productName,
                        quantity: l.quantity,
                        imageKey: Value(l.imageKey)),
                ]));
          }
        }
        final listed = manifests.map((m) => m.consignmentId).toList();
        final stale = await (db.select(db.deliveries)
              ..where((d) => d.consignmentId.isNotIn(listed)))
            .get();
        for (final d in stale) {
          if (await _receiptFor(d.consignmentId) != null) continue;
          await (db.delete(db.deliveryLines)
                ..where((l) => l.consignmentId.equals(d.consignmentId)))
              .go();
          await (db.delete(db.deliveries)
                ..where((x) => x.consignmentId.equals(d.consignmentId)))
              .go();
        }
      });

  Future<Receipt?> _receiptFor(String consignmentId) => (db.select(db.receipts)
        ..where((r) => r.consignmentId.equals(consignmentId)))
      .getSingleOrNull();

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables =>
      {db.deliveries, db.deliveryLines, db.receipts, db.receiptLines};

  /// All cached deliveries, newest first; re-emits when a count is saved
  /// or a server answer arrives.
  Stream<List<DeliveryView>> watchDeliveries() => db
      .customSelect(
          'SELECT consignment_id FROM deliveries ORDER BY dispatched_at DESC',
          readsFrom: _tables)
      .watch()
      .asyncMap((rows) async => [
            for (final r in rows)
              (await delivery(r.read<String>('consignment_id')))!
          ]);

  Stream<DeliveryView?> watchDelivery(String consignmentId) => db
      .customSelect('SELECT 1 FROM deliveries WHERE consignment_id = ?',
          variables: [Variable(consignmentId)], readsFrom: _tables)
      .watch()
      .asyncMap((_) => delivery(consignmentId));

  Future<DeliveryView?> delivery(String consignmentId) async {
    final row = await (db.select(db.deliveries)
          ..where((d) => d.consignmentId.equals(consignmentId)))
        .getSingleOrNull();
    return row == null ? null : _view(row);
  }

  Future<DeliveryView> _view(Delivery d) async {
    final lines = await (db.select(db.deliveryLines)
          ..where((l) => l.consignmentId.equals(d.consignmentId))
          ..orderBy([(l) => OrderingTerm(expression: l.lineId)]))
        .get();
    final receipt = await _receiptFor(d.consignmentId);
    final counted = receipt == null
        ? <String, ReceiptLine>{}
        : {
            for (final l in await (db.select(db.receiptLines)
                  ..where((l) => l.receiptId.equals(receipt.receiptId)))
                .get())
              l.lineId: l
          };
    return DeliveryView(
      consignmentId: d.consignmentId,
      version: d.version,
      reference: d.reference,
      sender: d.sender,
      stationKey: d.stationKey,
      stationName: d.stationName,
      dispatchedAt: d.dispatchedAt,
      lines: [
        for (final l in lines)
          DeliveryLineView(
            lineId: l.lineId,
            productId: l.productId,
            productName: l.productName,
            dispatched: l.quantity,
            imageKey: l.imageKey,
            received: counted[l.lineId] == null
                ? (receipt == null ? null : const ReceivedLine(0, 0, null))
                : ReceivedLine(
                    counted[l.lineId]!.accepted,
                    counted[l.lineId]!.rejected,
                    DiscrepancyReasonCode.fromCode(counted[l.lineId]!.reason),
                    counted[l.lineId]!.note),
          ),
      ],
      receipt: receipt == null
          ? null
          : ReceiptView(
              receiptId: receipt.receiptId,
              eventId: receipt.eventId,
              consignmentVersion: receipt.consignmentVersion,
              receivedAt: receipt.receivedAt,
              status: switch (receipt.syncStatus) {
                'accepted' => ReceivingStatus.accepted,
                'conflict' => ReceivingStatus.conflict,
                'rejected' => ReceivingStatus.rejected,
                _ => ReceivingStatus.savedOnPhone,
              },
              conflictReason: receipt.conflictReason),
    );
  }

  /// Checks a count against the manifest without saving it. Mirrors the
  /// server's `decide_receipt`.
  static void validate(DeliveryView delivery, List<LineCount> counts) {
    final byLine = {for (final c in counts) c.lineId: c};
    var physical = 0;
    for (final line in delivery.lines) {
      final count = byLine[line.lineId];
      if (count == null || count.received < 0) {
        throw ReceiptRefused(ReceiptBlock.invalid, line.lineId);
      }
      if (count.received > line.dispatched) {
        throw ReceiptRefused(ReceiptBlock.aboveDispatched, line.lineId);
      }
      final differs = count.received != line.dispatched;
      if (differs && count.reason == null) {
        throw ReceiptRefused(ReceiptBlock.missingReason, line.lineId);
      }
      physical += count.received +
          (differs && count.reason!.refuses
              ? line.dispatched - count.received
              : 0);
    }
    if (byLine.length != delivery.lines.length) {
      throw const ReceiptRefused(ReceiptBlock.invalid);
    }
    if (physical == 0) throw const ReceiptRefused(ReceiptBlock.nothingReceived);
  }

  /// Saves the vendor's count. Repeating the same [eventId] returns the
  /// receipt already stored and writes nothing, so a retry never records
  /// a second receipt. Checked here as well as in the UI.
  Future<ReceiptView> submitReceipt({
    required String receiptId,
    required String eventId,
    required String consignmentId,
    required int consignmentVersion,
    required String sessionStationKey,
    required String actorId,
    required DateTime receivedAt,
    DateTime? recordedAt,
    required List<LineCount> counts,
    Map<String, String> notes = const {},
  }) =>
      db.transaction(() async {
        final existing = await (db.select(db.receipts)
              ..where((r) => r.eventId.equals(eventId)))
            .getSingleOrNull();
        if (existing != null) return (await delivery(consignmentId))!.receipt!;
        final d = await delivery(consignmentId);
        if (d == null) throw const ReceiptRefused(ReceiptBlock.notFound);
        if (d.stationKey != sessionStationKey) {
          throw const ReceiptRefused(ReceiptBlock.wrongStation);
        }
        if (d.version != consignmentVersion) {
          throw const ReceiptRefused(ReceiptBlock.manifestChanged);
        }
        if (d.receipt != null) {
          throw const ReceiptRefused(ReceiptBlock.alreadyReceived);
        }
        validate(d, counts);
        await db.into(db.receipts).insert(ReceiptsCompanion.insert(
            receiptId: receiptId,
            eventId: eventId,
            consignmentId: consignmentId,
            consignmentVersion: consignmentVersion,
            stationKey: sessionStationKey,
            actorId: actorId,
            receivedAt: receivedAt));
        final dispatched = {for (final l in d.lines) l.lineId: l.dispatched};
        await db.batch((b) => b.insertAll(db.receiptLines, [
              for (final c in counts)
                ReceiptLinesCompanion.insert(
                    receiptId: receiptId,
                    lineId: c.lineId,
                    note: Value(notes[c.lineId]?.trim()),
                    accepted: c.received,
                    rejected: c.reason?.refuses == true
                        ? dispatched[c.lineId]! - c.received
                        : 0,
                    reason: Value(c.received == dispatched[c.lineId]
                        ? null
                        : c.reason?.code)),
            ]));
        await enqueueOperation(db,
            opId: eventId,
            opType: 'receipt',
            vendorId: actorId,
            stationKey: sessionStationKey,
            occurredAt: receivedAt,
            createdAt: recordedAt ?? DateTime.now().toUtc(),
            payload: receiptPayload(
                eventId: eventId,
                receiptId: receiptId,
                consignmentId: consignmentId,
                consignmentVersion: consignmentVersion,
                receivedAt: receivedAt,
                notes: notes,
                lines: [
                  for (final c in counts)
                    (
                      lineId: c.lineId,
                      accepted: c.received,
                      rejected: c.reason?.refuses == true
                          ? dispatched[c.lineId]! - c.received
                          : 0,
                      reason: c.received == dispatched[c.lineId]
                          ? null
                          : c.reason?.code
                    )
                ]));
        return (await delivery(consignmentId))!.receipt!;
      });

  /// Applies the receiving service's answer (sync milestone). Applying the
  /// same answer again changes nothing.
  Future<void> applyReceiptResult(String eventId,
          {required ReceivingStatus status, String? reason}) =>
      (db.update(db.receipts)..where((r) => r.eventId.equals(eventId))).write(
          ReceiptsCompanion(
              syncStatus: Value(switch (status) {
                ReceivingStatus.accepted => 'accepted',
                ReceivingStatus.conflict => 'conflict',
                ReceivingStatus.rejected => 'rejected',
                _ => 'saved',
              }),
              conflictReason:
                  Value(status == ReceivingStatus.accepted ? null : reason)));
}

final receivingStoreProvider = Provider<ReceivingStore>(
    (ref) => ReceivingStore(ref.watch(databaseProvider)));
