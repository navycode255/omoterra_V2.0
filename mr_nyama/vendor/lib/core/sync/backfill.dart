import 'package:drift/drift.dart';

import '../data/database.dart';
import 'outbox.dart';
import 'payloads.dart';

/// Queues records saved before the sync queue existed (schema < 5) that were
/// never sent. Each keeps its original idempotency ID, so if any of them
/// somehow reached the server already, the server answers "duplicate".
Future<void> backfillOutbox(AppDatabase db) async {
  final now = DateTime.now();

  for (final s in await (db.select(db.sales)
        ..where((s) => s.syncStatus.equals('saved')))
      .get()) {
    final lines = await (db.select(db.saleLines)
          ..where((l) => l.saleClientId.equals(s.clientId))
          ..orderBy([(l) => OrderingTerm(expression: l.id)]))
        .get();
    await enqueueOperation(db,
        opId: s.clientId,
        opType: 'sale',
        vendorId: s.vendorId,
        stationKey: '',
        occurredAt: s.recordedAt,
        createdAt: now,
        payload: salePayload(
            clientId: s.clientId,
            recordedAt: s.recordedAt,
            paymentMethod: s.paymentMethod,
            lines: [
              for (final l in lines)
                (
                  productId: l.productId,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                  priceVersion: l.priceVersion,
                  exceeds: l.exceedsRecordedStock
                )
            ]));
  }

  for (final v in await (db.select(db.saleVoids)
        ..where((v) => v.syncStatus.equals('saved')))
      .get()) {
    await enqueueOperation(db,
        opId: v.voidId,
        opType: 'sale_void',
        vendorId: v.actorId,
        stationKey: '',
        occurredAt: v.requestedAt,
        createdAt: now,
        payload: voidPayload(
            voidId: v.voidId,
            saleClientId: v.saleClientId,
            reason: v.reason,
            note: v.note,
            requestedAt: v.requestedAt));
  }

  for (final r in await (db.select(db.receipts)
        ..where((r) => r.syncStatus.equals('saved')))
      .get()) {
    final lines = await (db.select(db.receiptLines)
          ..where((l) => l.receiptId.equals(r.receiptId)))
        .get();
    await enqueueOperation(db,
        opId: r.eventId,
        opType: 'receipt',
        vendorId: r.actorId,
        stationKey: r.stationKey,
        occurredAt: r.receivedAt,
        createdAt: now,
        payload: receiptPayload(
            eventId: r.eventId,
            receiptId: r.receiptId,
            consignmentId: r.consignmentId,
            consignmentVersion: r.consignmentVersion,
            receivedAt: r.receivedAt,
            notes: {
              for (final l in lines)
                if (l.note != null) l.lineId: l.note!
            },
            lines: [
              for (final l in lines)
                (
                  lineId: l.lineId,
                  accepted: l.accepted,
                  rejected: l.rejected,
                  reason: l.reason
                )
            ]));
  }

  for (final d in await (db.select(db.damageReports)
        ..where((d) => d.syncStatus.equals('saved')))
      .get()) {
    await enqueueOperation(db,
        opId: d.reportId,
        opType: 'damage_report',
        vendorId: d.actorId,
        stationKey: d.stationKey,
        occurredAt: d.reportedAt,
        createdAt: now,
        payload: damagePayload(
            reportId: d.reportId,
            productId: d.productId,
            quantity: d.quantity,
            reason: d.reason,
            note: d.note,
            reportedAt: d.reportedAt));
  }

  for (final c in await (db.select(db.closingCounts)
        ..where((c) => c.syncStatus.equals('saved')))
      .get()) {
    final lines = await (db.select(db.closingCountLines)
          ..where((l) => l.countId.equals(c.countId)))
        .get();
    await enqueueOperation(db,
        opId: c.countId,
        opType: 'closing_count',
        vendorId: c.vendorId,
        stationKey: c.stationKey,
        occurredAt: c.countedAt,
        createdAt: now,
        payload: closingPayload(
            countId: c.countId,
            businessDate: c.businessDate,
            countedAt: c.countedAt,
            reasons: {
              for (final l in lines)
                if (l.reason != null) l.productId: l.reason!
            },
            notes: {
              for (final l in lines)
                if (l.note != null) l.productId: l.note!
            },
            counted: {
              for (final l in lines) l.productId: l.counted
            }));
  }
}
