import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/payloads.dart';
import '../sales/sales_store.dart';
import 'frozen_count.dart';

/// Where a closing count stands. Each step says only what is true.
enum ClosingStatus {
  /// Saved on the phone; waiting to be sent.
  savedOnPhone,

  /// Sent to the office; waiting for staff to confirm the count.
  awaitingOffice,

  /// Staff confirmed the count. Sales, money and stock reconciliation are
  /// still separate steps.
  confirmed,

  /// The server did not record this count (for example, a count for today
  /// already came from another phone). The local count is kept for review.
  conflict,
}

class ClosingLineView {
  final String productId;
  final String productName;
  final int? recorded;
  final int counted;
  final String? reason, note;
  const ClosingLineView(
      this.productId, this.productName, this.recorded, this.counted,
      [this.reason, this.note]);
}

class ClosingView {
  final String countId;
  final DateTime businessDate;
  final DateTime countedAt;
  final ClosingStatus status;
  final List<ClosingLineView> lines;

  /// The server's reason when [status] is [ClosingStatus.conflict].
  final String? conflictReason;
  const ClosingView(
      {required this.countId,
      required this.businessDate,
      required this.countedAt,
      required this.status,
      required this.lines,
      this.conflictReason});
}

enum ClosingBlock { alreadyClosed, missingProducts, invalid, nothingToCount }

/// Yesterday's Funga Siku as this phone sees it (owner decision 26 October
/// 2026): a day the vendor worked and did not close may still be closed this
/// morning, until today's first sale or receipt; today's selling waits for it.
enum YesterdayClosing {
  /// Nothing to close: no work yesterday on this phone, or no tracked stock.
  none,

  /// Worked yesterday, not closed, and nothing done today yet: close it first.
  open,

  /// Not closed, but today's selling or receiving has begun: too late; the
  /// office handles yesterday's count.
  missed,

  /// Yesterday's count was saved (whatever the office answered).
  closed,
}

class ClosingRefused implements Exception {
  final ClosingBlock block;
  const ClosingRefused(this.block);
}

String dateKey(DateTime businessDay) =>
    '${businessDay.year.toString().padLeft(4, '0')}-'
    '${businessDay.month.toString().padLeft(2, '0')}-'
    '${businessDay.day.toString().padLeft(2, '0')}';

/// Products that need a closing count: those whose stock the server tracks.
List<Product> productsToCount(List<Product> products) =>
    products.where((p) => p.available != null).toList();

/// Funga Siku on this phone. One count per vendor, station and business
/// day; the phone never edits it afterwards (corrections are staff-only).
class ClosingStore {
  final AppDatabase db;
  ClosingStore(this.db);

  Stream<ClosingView?> watchForDay(
          {required String vendorId,
          required String stationKey,
          required DateTime businessDay}) =>
      db
          .customSelect(
              'SELECT count_id FROM closing_counts WHERE vendor_id = ? AND '
              'station_key = ? AND business_date = ?',
              variables: [
                Variable(vendorId),
                Variable(stationKey),
                Variable(dateKey(businessDay))
              ],
              readsFrom: {
                db.closingCounts,
                db.closingCountLines
              })
          .watchSingleOrNull()
          .asyncMap((row) =>
              row == null ? null : _view(row.read<String>('count_id')));

  Future<ClosingView?> _view(String countId) async {
    final c = await (db.select(db.closingCounts)
          ..where((x) => x.countId.equals(countId)))
        .getSingleOrNull();
    if (c == null) return null;
    final lines = await (db.select(db.closingCountLines)
          ..where((l) => l.countId.equals(countId))
          ..orderBy([(l) => OrderingTerm(expression: l.productName)]))
        .get();
    final parts = c.businessDate.split('-').map(int.parse).toList();
    return ClosingView(
      countId: c.countId,
      businessDate: DateTime.utc(parts[0], parts[1], parts[2]),
      countedAt: c.countedAt,
      status: switch (c.officeStatus) {
        'confirmed' => ClosingStatus.confirmed,
        'conflict' => ClosingStatus.conflict,
        _ => c.syncStatus == 'saved'
            ? ClosingStatus.savedOnPhone
            : ClosingStatus.awaitingOffice,
      },
      conflictReason: c.officeStatus == 'conflict' ? c.conflictReason : null,
      lines: [
        for (final l in lines)
          ClosingLineView(l.productId, l.productName, l.recorded, l.counted,
              l.reason, l.note)
      ],
    );
  }

  /// Yesterday's state for this vendor and station at [now].
  Future<YesterdayClosing> yesterdayState(
      {required String vendorId,
      required String stationKey,
      required DateTime now,
      required bool tracksStock}) async {
    final today = businessDate(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final closed = await (db.select(db.closingCounts)
          ..where((c) =>
              c.vendorId.equals(vendorId) &
              c.stationKey.equals(stationKey) &
              c.businessDate.equals(dateKey(yesterday))))
        .getSingleOrNull();
    if (closed != null) return YesterdayClosing.closed;
    if (!tracksStock) return YesterdayClosing.none;
    Future<bool> active(DateTime day) async {
      final (start, end) = businessDayRange(day);
      final sold = await (db.select(db.sales)
            ..where((s) =>
                s.vendorId.equals(vendorId) &
                s.recordedAt.isBiggerOrEqualValue(start) &
                s.recordedAt.isSmallerThanValue(end))
            ..limit(1))
          .get();
      if (sold.isNotEmpty) return true;
      final received = await (db.select(db.receipts)
            ..where((r) =>
                r.stationKey.equals(stationKey) &
                r.receivedAt.isBiggerOrEqualValue(start) &
                r.receivedAt.isSmallerThanValue(end))
            ..limit(1))
          .get();
      return received.isNotEmpty;
    }

    if (!await active(yesterday)) return YesterdayClosing.none;
    return await active(today)
        ? YesterdayClosing.missed
        : YesterdayClosing.open;
  }

  /// Saves the closing count of [businessDay] (today unless given; yesterday
  /// only while [YesterdayClosing.open]). Every tracked product must be
  /// counted. The same [countId] again returns the stored count; a second,
  /// different count for the same day is refused. [frozen]: the figures were
  /// frozen before today's work began, so yesterday stays open to this count.
  Future<ClosingView> submit({
    required String countId,
    required String vendorId,
    required String stationKey,
    required DateTime now,
    required List<Product> products,
    required Map<String, int> counted,
    Map<String, String> reasons = const {},
    Map<String, String> notes = const {},
    DateTime? businessDay,
    bool frozen = false,
  }) =>
      db.transaction(() async {
        final same = await _view(countId);
        if (same != null) return same;
        final today = businessDate(now);
        final target = businessDay ?? today;
        final day = dateKey(target);
        if (day != dateKey(today) &&
            (day != dateKey(today.subtract(const Duration(days: 1))) ||
                (!frozen &&
                    await yesterdayState(
                            vendorId: vendorId,
                            stationKey: stationKey,
                            now: now,
                            tracksStock: true) !=
                        YesterdayClosing.open))) {
          throw const ClosingRefused(ClosingBlock.invalid);
        }
        final existing = await (db.select(db.closingCounts)
              ..where((c) =>
                  c.vendorId.equals(vendorId) &
                  c.stationKey.equals(stationKey) &
                  c.businessDate.equals(day)))
            .getSingleOrNull();
        if (existing != null) {
          throw const ClosingRefused(ClosingBlock.alreadyClosed);
        }
        final required = productsToCount(products);
        if (required.isEmpty) {
          throw const ClosingRefused(ClosingBlock.nothingToCount);
        }
        if (required.any((p) => counted[p.id] == null)) {
          throw const ClosingRefused(ClosingBlock.missingProducts);
        }
        if (counted.values.any((v) => v < 0)) {
          throw const ClosingRefused(ClosingBlock.invalid);
        }
        await db.into(db.closingCounts).insert(ClosingCountsCompanion.insert(
            countId: countId,
            businessDate: day,
            vendorId: vendorId,
            stationKey: stationKey,
            countedAt: now));
        await db.batch((b) => b.insertAll(db.closingCountLines, [
              for (final p in required)
                ClosingCountLinesCompanion.insert(
                    countId: countId,
                    productId: p.id,
                    productName: p.name,
                    recorded: Value(p.remaining),
                    counted: counted[p.id]!,
                    reason: Value(reasons[p.id]),
                    note: Value(notes[p.id]?.trim())),
            ]));
        await enqueueOperation(db,
            opId: countId,
            opType: 'closing_count',
            vendorId: vendorId,
            stationKey: stationKey,
            occurredAt: now,
            createdAt: now,
            payload: closingPayload(
                countId: countId,
                businessDate: day,
                countedAt: now,
                reasons: reasons,
                notes: notes,
                counted: {for (final p in required) p.id: counted[p.id]!}));
        return (await _view(countId))!;
      });

  /// Applies the server's answer. [conflictReason] marks a count the server
  /// did not record (kept locally for staff review).
  Future<void> applyResult(String countId,
          {bool sent = true,
          bool officeConfirmed = false,
          String? conflictReason}) =>
      (db.update(db.closingCounts)..where((c) => c.countId.equals(countId)))
          .write(ClosingCountsCompanion(
              syncStatus: Value(sent ? 'sent' : 'saved'),
              officeStatus: Value(conflictReason != null
                  ? 'conflict'
                  : officeConfirmed
                      ? 'confirmed'
                      : 'pending'),
              conflictReason: Value(conflictReason)));
}

final closingStoreProvider =
    Provider<ClosingStore>((ref) => ClosingStore(ref.watch(databaseProvider)));

final frozenCountStoreProvider = Provider<FrozenCountStore>(
    (ref) => FrozenCountStore(ref.watch(databaseProvider)));

/// Yesterday's Funga Siku state for the signed-in vendor, kept current as
/// sales, receipts and counts are saved.
final yesterdayClosingProvider =
    StreamProvider.autoDispose<YesterdayClosing>((ref) {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return Stream.value(YesterdayClosing.none);
  final tracks = productsToCount(
          ref.watch(productsProvider).valueOrNull ?? const <Product>[])
      .isNotEmpty;
  final store = ref.watch(closingStoreProvider);
  final db = ref.watch(databaseProvider);
  final now = ref.watch(clockProvider);
  Future<YesterdayClosing> read() => store.yesterdayState(
      vendorId: auth.profile.id,
      stationKey: auth.profile.stationKey,
      now: now(),
      tracksStock: tracks);
  // Re-read on every write to these tables (see CreditStore.watch).
  return () async* {
    yield await read();
    await for (final _ in db.tableUpdates(TableUpdateQuery.onAllTables(
        [db.closingCounts, db.sales, db.receipts]))) {
      yield await read();
    }
  }();
});
