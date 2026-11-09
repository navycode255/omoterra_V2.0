import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/business_day.dart';
import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/payloads.dart';
import '../sales/sales_store.dart';

/// The local void reason that marks a void made by the office.
const officeVoidReason = 'office';

enum VoidState {
  none,

  /// Recorded on the phone, waiting for the server.
  pending,
  accepted,

  /// The server refused it (for example, staff had already verified the
  /// sale). The sale stands.
  rejected,
}

/// Reasons a vendor may give, matching the server contract.
enum VoidReason {
  wrongQuantity,
  wrongProduct,
  customerCancelled,
  duplicate,
  other
}

extension VoidReasonCode on VoidReason {
  String get code => switch (this) {
        VoidReason.wrongQuantity => 'wrong_quantity',
        VoidReason.wrongProduct => 'wrong_product',
        VoidReason.customerCancelled => 'customer_cancelled',
        VoidReason.duplicate => 'duplicate',
        VoidReason.other => 'other',
      };

  static VoidReason fromCode(String code) => VoidReason.values
      .firstWhere((r) => r.code == code, orElse: () => VoidReason.other);
}

/// Why a vendor may not void a sale. The phone hides the action for these;
/// the server checks them again (`decide_void` in the backend contract).
enum VoidBlock { notOwner, verified, notToday, alreadyVoided }

class VoidRefused implements Exception {
  final VoidBlock block;
  const VoidRefused(this.block);
}

class HistoryEntry {
  final String clientId;
  final DateTime recordedAt;
  final int total;
  final PaymentMethod payment;

  /// `saved` while only on this phone.
  final String syncStatus;
  final bool verified;
  final VoidState voidState;

  /// The void was made by the office (a cancellation), not by this vendor.
  final bool cancelledByOffice;

  /// First product and quantity, for the compact row ("Kuku mzima × 2").
  final String firstProduct;
  final int firstQuantity;
  final int lineCount;

  /// A credit sale's customer (MN018).
  final String? customer;

  const HistoryEntry(
      {required this.clientId,
      required this.recordedAt,
      required this.total,
      required this.payment,
      required this.syncStatus,
      required this.verified,
      required this.voidState,
      this.cancelledByOffice = false,
      required this.firstProduct,
      required this.firstQuantity,
      required this.lineCount,
      this.customer});

  bool get sent => syncStatus != 'saved';

  /// A void counts unless the server refused it.
  bool get voided =>
      voidState == VoidState.pending || voidState == VoidState.accepted;

  /// Short reference shown to vendors and staff: MN-1A2B3C4D.
  String get reference => saleReference(clientId);
}

String saleReference(String clientId) {
  final compact = clientId.replaceAll('-', '');
  // Client IDs are UUIDs; a shorter ID (never expected) must not crash.
  return 'MN-${compact.substring(0, math.min(8, compact.length)).toUpperCase()}';
}

class DetailLine {
  final String productName;
  final int quantity;
  final int unitPrice;
  final int lineTotal;
  const DetailLine(
      this.productName, this.quantity, this.unitPrice, this.lineTotal);
}

class VoidRecord {
  final String voidId;
  final String? note;
  final VoidReason reason;
  final String actorId;
  final DateTime requestedAt;
  final String syncStatus;
  final String? rejectionReason;
  const VoidRecord(
      {required this.voidId,
      this.note,
      required this.reason,
      required this.actorId,
      required this.requestedAt,
      required this.syncStatus,
      this.rejectionReason});

  VoidState get state => switch (syncStatus) {
        'accepted' => VoidState.accepted,
        'rejected' => VoidState.rejected,
        _ => VoidState.pending,
      };
}

class SaleDetail {
  final HistoryEntry entry;
  final String vendorId;
  final List<DetailLine> lines;
  final VoidRecord? voidRecord;
  const SaleDetail(
      {required this.entry,
      required this.vendorId,
      required this.lines,
      this.voidRecord});
}

/// Reads sales recorded on this phone and records voids.
class HistoryStore {
  final AppDatabase db;
  HistoryStore(this.db);

  static const _entrySql = '''
SELECT s.client_id, s.vendor_id, s.recorded_at, s.total, s.payment_method,
  s.credit_customer_name, s.sync_status, s.verification,
  v.sync_status AS void_status, v.reason AS void_reason,
  (SELECT COUNT(*) FROM sale_lines l WHERE l.sale_client_id = s.client_id)
    AS line_count,
  (SELECT l.product_name FROM sale_lines l WHERE l.sale_client_id = s.client_id
    ORDER BY l.id LIMIT 1) AS first_product,
  (SELECT l.quantity FROM sale_lines l WHERE l.sale_client_id = s.client_id
    ORDER BY l.id LIMIT 1) AS first_quantity
FROM sales s LEFT JOIN sale_voids v ON v.sale_client_id = s.client_id''';

  HistoryEntry _entry(QueryRow r) {
    final voidStatus = r.readNullable<String>('void_status');
    return HistoryEntry(
      clientId: r.read<String>('client_id'),
      recordedAt: r.read<DateTime>('recorded_at'),
      total: r.read<int>('total'),
      customer: r.readNullable<String>('credit_customer_name'),
      payment: PaymentMethod.values.byName(r.read<String>('payment_method')),
      syncStatus: r.read<String>('sync_status'),
      verified: r.read<String>('verification') == 'verified',
      voidState: switch (voidStatus) {
        null => VoidState.none,
        'accepted' => VoidState.accepted,
        'rejected' => VoidState.rejected,
        _ => VoidState.pending,
      },
      cancelledByOffice: r.readNullable<String>('void_reason') == officeVoidReason,
      firstProduct: r.readNullable<String>('first_product') ?? '',
      firstQuantity: r.readNullable<int>('first_quantity') ?? 0,
      lineCount: r.read<int>('line_count'),
    );
  }

  /// Sales recorded during business date [day], newest first.
  Stream<List<HistoryEntry>> watchDay(DateTime day) {
    final (start, end) = businessDayRange(day);
    return db
        .customSelect(
          '$_entrySql WHERE s.recorded_at >= ? AND s.recorded_at < ? '
          'ORDER BY s.recorded_at DESC',
          variables: [Variable(start), Variable(end)],
          readsFrom: {db.sales, db.saleLines, db.saleVoids},
        )
        .watch()
        .map((rows) => rows.map(_entry).toList());
  }

  Selectable<QueryRow> _saleQuery(String clientId) =>
      db.customSelect('$_entrySql WHERE s.client_id = ?',
          variables: [Variable(clientId)],
          readsFrom: {db.sales, db.saleLines, db.saleVoids});

  Stream<SaleDetail?> watchSale(String clientId) => _saleQuery(clientId)
      .watchSingleOrNull()
      .asyncMap((row) => row == null ? null : _detail(row));

  Future<SaleDetail?> sale(String clientId) async {
    final row = await _saleQuery(clientId).getSingleOrNull();
    return row == null ? null : _detail(row);
  }

  Future<SaleDetail> _detail(QueryRow row) async {
    final clientId = row.read<String>('client_id');
    final lines = await (db.select(db.saleLines)
          ..where((l) => l.saleClientId.equals(clientId))
          ..orderBy([(l) => OrderingTerm(expression: l.id)]))
        .get();
    final v = await (db.select(db.saleVoids)
          ..where((v) => v.saleClientId.equals(clientId)))
        .getSingleOrNull();
    return SaleDetail(
      entry: _entry(row),
      vendorId: row.read<String>('vendor_id'),
      lines: [
        for (final l in lines)
          DetailLine(l.productName, l.quantity, l.unitPrice, l.lineTotal)
      ],
      voidRecord: v == null
          ? null
          : VoidRecord(
              voidId: v.voidId,
              note: v.note,
              reason: VoidReasonCode.fromCode(v.reason),
              actorId: v.actorId,
              requestedAt: v.requestedAt,
              syncStatus: v.syncStatus,
              rejectionReason: v.rejectionReason),
    );
  }

  /// Why [actorId] may not void [sale] at [now], or null if they may.
  static VoidBlock? voidBlock(SaleDetail sale, String actorId, DateTime now) {
    if (sale.vendorId != actorId) return VoidBlock.notOwner;
    if (sale.voidRecord != null &&
        sale.voidRecord!.state != VoidState.rejected) {
      return VoidBlock.alreadyVoided;
    }
    // A refused void means the server found a reason; no second attempt.
    if (sale.voidRecord?.state == VoidState.rejected) {
      return sale.entry.verified ? VoidBlock.verified : VoidBlock.alreadyVoided;
    }
    if (sale.entry.verified) return VoidBlock.verified;
    if (businessDate(sale.entry.recordedAt) != businessDate(now)) {
      return VoidBlock.notToday;
    }
    return null;
  }

  /// Records a void request. Checked here as well as in the UI, inside one
  /// transaction with the read. Repeating the same [voidId] returns the
  /// record already stored; a different void for the same sale is refused.
  Future<VoidRecord> voidSale(
      {required String voidId,
      required String saleClientId,
      required VoidReason reason,
      String? note,
      required String actorId,
      String stationKey = '',
      required DateTime now}) {
    return db.transaction(() async {
      final sale = await this.sale(saleClientId);
      if (sale == null) throw const VoidRefused(VoidBlock.notOwner);
      final existing = sale.voidRecord;
      if (existing != null && existing.voidId == voidId) return existing;
      final block = voidBlock(sale, actorId, now);
      if (block != null) throw VoidRefused(block);
      await db.into(db.saleVoids).insert(SaleVoidsCompanion.insert(
          voidId: voidId,
          saleClientId: saleClientId,
          reason: reason.code,
          note: Value(note?.trim()),
          actorId: actorId,
          requestedAt: now));
      await enqueueOperation(db,
          opId: voidId,
          opType: 'sale_void',
          vendorId: actorId,
          stationKey: stationKey,
          occurredAt: now,
          createdAt: now,
          payload: voidPayload(
              voidId: voidId,
              saleClientId: saleClientId,
              reason: reason.code,
              note: note?.trim(),
              requestedAt: now));
      return (await this.sale(saleClientId))!.voidRecord!;
    });
  }

  /// Applies the server's answer to a queued void (sync milestone).
  Future<void> applyVoidResult(String voidId,
          {required bool accepted, String? rejectionReason}) =>
      // An office cancellation stands whatever the server says to a late vendor void.
      (db.update(db.saleVoids)
            ..where((v) =>
                v.voidId.equals(voidId) & v.reason.equals(officeVoidReason).not()))
          .write(
          SaleVoidsCompanion(
              syncStatus: Value(accepted ? 'accepted' : 'rejected'),
              rejectionReason: Value(accepted ? null : rejectionReason)));

  /// Records that the office cancelled a sale (from the server). The local
  /// void row, if the vendor had asked too, becomes the office's; a sale this
  /// phone does not hold is learned through history recovery instead.
  Future<void> markCancelledByOffice(
      String saleClientId, String voidId, DateTime at) async {
    final sale = await (db.select(db.sales)
          ..where((s) => s.clientId.equals(saleClientId)))
        .getSingleOrNull();
    if (sale == null) return;
    final existing = await (db.select(db.saleVoids)
          ..where((v) => v.saleClientId.equals(saleClientId)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.saleVoids).insert(SaleVoidsCompanion.insert(
          voidId: voidId,
          saleClientId: saleClientId,
          reason: officeVoidReason,
          actorId: 'office',
          requestedAt: at,
          syncStatus: const Value('accepted')));
    } else if (existing.reason != officeVoidReason) {
      await (db.update(db.saleVoids)
            ..where((v) => v.voidId.equals(existing.voidId)))
          .write(const SaleVoidsCompanion(
              reason: Value(officeVoidReason),
              syncStatus: Value('accepted'),
              rejectionReason: Value(null)));
    }
  }

  /// Records that staff verified a sale (from the server).
  Future<void> markVerified(String clientId) =>
      (db.update(db.sales)..where((s) => s.clientId.equals(clientId)))
          .write(const SalesCompanion(verification: Value('verified')));
}

final historyStoreProvider =
    Provider<HistoryStore>((ref) => HistoryStore(ref.watch(databaseProvider)));
