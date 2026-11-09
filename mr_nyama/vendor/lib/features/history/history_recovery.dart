import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_history.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/data/database.dart';
import '../expenses/expense_store.dart';
import 'history_store.dart' show officeVoidReason;
import '../sales/sales_store.dart' show databaseProvider;

/// How far back a new phone recovers: the server's longest range.
const recoveryDays = 31;

/// Writes the vendor's server records into this phone's database (Phase 11,
/// sales history recovery across phones).
///
/// Every record written here is already on the server, so it is stored as
/// sent (sales `sent`, voids and receipts `accepted`, damage reports and
/// closing counts `sent`) and never put in the outbox: it can never be sent
/// twice, and the stock pool (which takes only `saved` sales) never counts
/// it again. A record the phone already holds (same id) is left as it is:
/// what was recorded on this phone wins.
class HistoryRecoveryStore {
  final AppDatabase db;
  HistoryRecoveryStore(this.db);

  static String _key(String vendorId) => 'history_recovered_$vendorId';

  static String _enteredKey(String vendorId) => 'history_office_entered_$vendorId';

  /// Sales of [vendorId] the office entered after a lost phone (MN036).
  Stream<Set<String>> watchOfficeEntered(String vendorId) => (db.select(db.settings)
        ..where((s) => s.key.equals(_enteredKey(vendorId))))
      .watchSingleOrNull()
      .map((row) => row == null
          ? <String>{}
          : {for (final id in jsonDecode(row.value) as List) '$id'});

  /// Whether the phone holds any sale of [vendorId].
  Future<bool> hasSales(String vendorId) async =>
      (await (db.select(db.sales)
            ..where((s) => s.vendorId.equals(vendorId))
            ..limit(1))
          .getSingleOrNull()) !=
      null;

  /// Sale ids this phone got back from the server for [vendorId].
  Stream<Set<String>> watchRecovered(String vendorId) => (db.select(db.settings)
        ..where((s) => s.key.equals(_key(vendorId))))
      .watchSingleOrNull()
      .map((row) => row == null
          ? <String>{}
          : {
              for (final id in (jsonDecode(row.value) as Map)['sales'] as List)
                '$id'
            });

  /// Stores what the phone does not hold yet; returns how many sales were
  /// added.
  Future<int> apply(String vendorId, VendorHistory history) =>
      db.transaction(() async {
        final added = <String>[];
        for (final s in history.sales) {
          if (s.clientId.isEmpty || s.recordedAt == null) continue;
          final known = await (db.select(db.sales)
                ..where((x) => x.clientId.equals(s.clientId)))
              .getSingleOrNull();
          if (known != null) continue;
          await db.into(db.sales).insert(SalesCompanion.insert(
              clientId: s.clientId,
              vendorId: vendorId,
              recordedAt: s.recordedAt!,
              paymentMethod: s.paymentMethod,
              total: s.total,
              creditCustomerId: Value(s.customerId),
              creditCustomerName: Value(s.customerName),
              syncStatus: const Value('sent'),
              verification: Value(s.verified ? 'verified' : 'unverified')));
          for (final l in s.lines) {
            await db.into(db.saleLines).insert(SaleLinesCompanion.insert(
                saleClientId: s.clientId,
                productId: l.productId,
                productName: l.productName,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
                priceVersion: Value(l.priceVersion),
                lineTotal: l.lineTotal));
          }
          final v = s.voided;
          if (v != null && v.voidId.isNotEmpty) {
            await db.into(db.saleVoids).insert(SaleVoidsCompanion.insert(
                voidId: v.voidId,
                saleClientId: s.clientId,
                reason: v.byStaff ? officeVoidReason : v.reason,
                note: Value(v.note),
                actorId: v.byStaff ? 'office' : vendorId,
                requestedAt: v.requestedAt ?? s.recordedAt!,
                syncStatus: const Value('accepted')));
          }
          added.add(s.clientId);
        }
        for (final r in history.receipts) {
          if (r.receiptId.isEmpty || r.receivedAt == null) continue;
          final known = await (db.select(db.receipts)
                ..where((x) =>
                    x.receiptId.equals(r.receiptId) |
                    x.eventId.equals(r.eventId)))
              .get();
          if (known.isNotEmpty) continue;
          await db.into(db.receipts).insert(ReceiptsCompanion.insert(
              receiptId: r.receiptId,
              eventId: r.eventId,
              consignmentId: r.consignmentId,
              consignmentVersion: r.consignmentVersion,
              stationKey: r.stationKey ?? '',
              actorId: vendorId,
              receivedAt: r.receivedAt!,
              syncStatus: const Value('accepted')));
          for (final l in r.lines) {
            await db.into(db.receiptLines).insert(ReceiptLinesCompanion.insert(
                receiptId: r.receiptId,
                lineId: l.lineId,
                accepted: l.accepted,
                rejected: l.rejected,
                reason: Value(l.reason),
                note: Value(l.note)));
          }
        }
        for (final d in history.damageReports) {
          if (d.reportId.isEmpty || d.reportedAt == null) continue;
          final known = await (db.select(db.damageReports)
                ..where((x) => x.reportId.equals(d.reportId)))
              .getSingleOrNull();
          if (known != null) continue;
          await db.into(db.damageReports).insert(DamageReportsCompanion.insert(
              reportId: d.reportId,
              productId: d.productId,
              productName: d.productName,
              quantity: d.quantity,
              reason: d.reason,
              note: Value(d.note),
              stationKey: d.stationKey ?? '',
              actorId: vendorId,
              reportedAt: d.reportedAt!,
              syncStatus: const Value('sent'),
              review: Value(d.review)));
        }
        for (final c in history.closingCounts) {
          if (c.countId.isEmpty || c.countedAt == null) continue;
          // One count per vendor, station and day: a count already on the
          // phone for that day stays.
          final known = await (db.select(db.closingCounts)
                ..where((x) =>
                    x.countId.equals(c.countId) |
                    (x.vendorId.equals(vendorId) &
                        x.stationKey.equals(c.stationKey ?? '') &
                        x.businessDate.equals(c.businessDate))))
              .get();
          if (known.isNotEmpty) continue;
          await db.into(db.closingCounts).insert(ClosingCountsCompanion.insert(
              countId: c.countId,
              businessDate: c.businessDate,
              vendorId: vendorId,
              stationKey: c.stationKey ?? '',
              countedAt: c.countedAt!,
              syncStatus: const Value('sent'),
              officeStatus: Value(c.officeStatus)));
          for (final l in c.lines) {
            await db.into(db.closingCountLines).insert(
                ClosingCountLinesCompanion.insert(
                    countId: c.countId,
                    productId: l.productId,
                    productName: l.productName,
                    counted: l.counted,
                    reason: Value(l.reason),
                    note: Value(l.note)));
          }
        }
        // Remember which the office entered, so history can say so.
        final entered = [
          for (final s in history.sales)
            if (s.officeEntered && s.clientId.isNotEmpty) s.clientId
        ];
        if (entered.isNotEmpty) {
          final enteredKey = _enteredKey(vendorId);
          final held = await (db.select(db.settings)
                ..where((s) => s.key.equals(enteredKey)))
              .getSingleOrNull();
          await db.into(db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(
                  key: enteredKey,
                  value: jsonEncode({
                    if (held != null)
                      for (final id in jsonDecode(held.value) as List) '$id',
                    ...entered,
                  }.toList())));
        }
        // Remember which sales came back from the server, so history can
        // say so.
        final key = _key(vendorId);
        final old = await (db.select(db.settings)
              ..where((s) => s.key.equals(key)))
            .getSingleOrNull();
        final ids = <String>{
          if (old != null)
            for (final id in (jsonDecode(old.value) as Map)['sales'] as List)
              '$id',
          ...added,
        };
        await db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
                key: key, value: jsonEncode({'sales': ids.toList()})));
        return added.length;
      });
}

final historyRecoveryStoreProvider = Provider<HistoryRecoveryStore>(
    (ref) => HistoryRecoveryStore(ref.watch(databaseProvider)));

/// Sales on this phone that came back from the server, for the signed-in
/// vendor.
final recoveredSalesProvider = StreamProvider<Set<String>>((ref) {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return Stream.value(const <String>{});
  return ref
      .watch(historyRecoveryStoreProvider)
      .watchRecovered(auth.profile.id);
});

/// Sales on this phone the office entered after a lost phone.
final officeEnteredSalesProvider = StreamProvider<Set<String>>((ref) {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return Stream.value(const <String>{});
  return ref
      .watch(historyRecoveryStoreProvider)
      .watchOfficeEntered(auth.profile.id);
});

enum RecoveryStatus { idle, running, done, failed }

class RecoveryState {
  final RecoveryStatus status;

  /// Sales added by the last recovery.
  final int added;
  const RecoveryState(this.status, {this.added = 0});
}

/// Fetches the vendor's records from the server and stores what the phone
/// lacks. Runs by itself once per app run on a phone with no sales of the
/// signed-in vendor (a new phone or a reinstall), and on request from the
/// history screen. Never blocks selling: a failure only offers a retry.
class HistoryRecovery extends Notifier<RecoveryState> {
  bool _triedThisRun = false;

  @override
  RecoveryState build() => const RecoveryState(RecoveryStatus.idle);

  /// Recovers when the phone holds no sales of the signed-in vendor.
  Future<void> recoverIfEmpty() async {
    if (_triedThisRun) return;
    final auth = ref.read(sessionProvider).valueOrNull;
    if (auth is! SignedIn) return;
    if (ref.read(vendorRepositoryProvider) is! VendorHistoryRepository) return;
    _triedThisRun = true;
    if (await ref
        .read(historyRecoveryStoreProvider)
        .hasSales(auth.profile.id)) {
      return;
    }
    await recover();
  }

  /// Fetches the last [recoveryDays] business days and stores them.
  Future<void> recover() async {
    if (state.status == RecoveryStatus.running) return;
    final auth = ref.read(sessionProvider).valueOrNull;
    final repository = ref.read(vendorRepositoryProvider);
    if (auth is! SignedIn || repository is! VendorHistoryRepository) return;
    state = const RecoveryState(RecoveryStatus.running);
    try {
      final today = businessDate(ref.read(clockProvider)());
      final from = today.subtract(const Duration(days: recoveryDays - 1));
      final history = await ref.read(sessionProvider.notifier).authorised(
          (token) => (repository as VendorHistoryRepository)
              .history(token, from: _key(from), to: _key(today)));
      final vendorId = auth.profile.id;
      final added =
          await ref.read(historyRecoveryStoreProvider).apply(vendorId, history);
      if (history.expenses.isNotEmpty) {
        await ref
            .read(expenseStoreProvider)
            .cacheReviews(vendorId, history.expenses);
      }
      state = RecoveryState(RecoveryStatus.done, added: added);
    } catch (_) {
      state = const RecoveryState(RecoveryStatus.failed);
    }
  }

  static String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final historyRecoveryProvider =
    NotifierProvider<HistoryRecovery, RecoveryState>(HistoryRecovery.new);
