import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sales/sales_store.dart';
import '../../core/auth/session.dart';
import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../../shared/widgets/expense_fields.dart';

class VendorExpense {
  final String id, category, status;
  final int amount;
  final DateTime spentAt;
  final String? note;

  /// What was bought (MN017); null on older records.
  final String? item;
  const VendorExpense(
      {required this.id,
      required this.category,
      required this.amount,
      required this.spentAt,
      required this.status,
      this.note,
      this.item});
}

/// The existing durable outbox is the append-only record for expense claims.
/// Server review is cached separately; acceptance by sync is not approval.
class ExpenseStore {
  final AppDatabase db;
  ExpenseStore(this.db);

  /// The owner's expense categories from the last catalogue download; null
  /// until a catalogue has been downloaded, empty when none are configured.
  Stream<List<String>?> watchCategories() => (db.select(db.settings)
        ..where((s) => s.key.equals('expense_categories')))
      .watchSingleOrNull()
      .map((row) =>
          row == null ? null : (jsonDecode(row.value) as List).cast<String>());

  /// What can be bought under each category, from the last catalogue.
  Stream<Map<String, List<String>>> watchItems() =>
      (db.select(db.settings)..where((s) => s.key.equals('expense_items')))
          .watchSingleOrNull()
          .map((row) => row == null ? const {} : _items(row.value));

  static Map<String, List<String>> _items(String json) => {
        for (final MapEntry(:key, :value) in (jsonDecode(json) as Map).entries)
          '$key': [for (final i in value as List) '$i']
      };

  Future<void> submit(
          {required String id,
          required String vendorId,
          required String stationKey,
          required String category,
          required int amount,
          required DateTime spentAt,
          String? item,
          String? note}) =>
      db.transaction(() async {
        final existing = await (db.select(db.outbox)
              ..where((o) => o.opId.equals(id)))
            .getSingleOrNull();
        if (existing != null) return;
        final settings = await (db.select(db.settings)
              ..where((s) => s.key.equals('expense_categories')))
            .getSingleOrNull();
        final allowed = [
          if (settings != null)
            ...(jsonDecode(settings.value) as List).cast<String>(),
          expenseOther,
        ];
        final itemsRow = await (db.select(db.settings)
              ..where((s) => s.key.equals('expense_items')))
            .getSingleOrNull();
        final checked = expenseItemFor(
            category: category,
            items: itemsRow == null ? const {} : _items(itemsRow.value),
            chosen: item,
            written: category == expenseOther ? item ?? '' : '');
        final cleanNote = note?.trim();
        if (!allowed.contains(category) ||
            checked.missing ||
            (checked.item != null && checked.item != item?.trim()) ||
            amount <= 0 ||
            amount > 100000000 ||
            (cleanNote?.length ?? 0) > 200 ||
            vendorId.isEmpty ||
            stationKey.isEmpty) {
          throw const FormatException('invalid expense claim');
        }
        await enqueueOperation(db,
            opId: id,
            opType: 'expense',
            vendorId: vendorId,
            stationKey: stationKey,
            occurredAt: spentAt,
            createdAt: spentAt,
            payload: {
              'client_id': id,
              'category': category,
              if (checked.item != null) 'item': checked.item,
              'amount': amount,
              'note': cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
              'spent_at': spentAt.toUtc().toIso8601String(),
            });
      });

  Future<void> cacheReviews(String vendorId, List<Map<String, dynamic>> rows) =>
      db.transaction(() async {
        final key = 'expense_history_$vendorId';
        final old = await (db.select(db.settings)
              ..where((s) => s.key.equals(key)))
            .getSingleOrNull();
        final merged = <String, dynamic>{
          if (old != null)
            for (final row in jsonDecode(old.value) as List)
              '${row['id']}': row,
          for (final row in rows) '${row['id']}': row,
        };
        await db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
                key: key, value: jsonEncode(merged.values.toList())));
      });

  Stream<List<VendorExpense>> watchExpenses(String vendorId) => db
      .customSelect(
          "SELECT 'remote' AS kind, value AS body, '' AS sync_status FROM settings WHERE key = ? "
          "UNION ALL SELECT 'local', payload, status FROM outbox WHERE op_type = 'expense' AND vendor_id = ?",
          variables: [
            Variable('expense_history_$vendorId'),
            Variable(vendorId)
          ],
          readsFrom: {
            db.settings,
            db.outbox
          })
      .watch()
      .map((rows) {
        final records = <String, VendorExpense>{};
        for (final row
            in rows.where((r) => r.read<String>('kind') == 'remote')) {
          for (final raw in jsonDecode(row.read<String>('body')) as List) {
            if (raw['reverses_id'] != null) continue;
            final id = '${raw['client_id'] ?? raw['id']}';
            records[id] = VendorExpense(
                id: id,
                category: raw['category'] as String,
                amount: raw['amount'] as int,
                spentAt: DateTime.parse(raw['business_date'] as String),
                status: raw['reversed_by_id'] != null
                    ? 'reversed'
                    : raw['status'] as String,
                note: raw['note'] as String?,
                item: raw['item'] as String?);
          }
        }
        for (final row
            in rows.where((r) => r.read<String>('kind') == 'local')) {
          final data = jsonDecode(row.read<String>('body')) as Map;
          final id = data['client_id'] as String;
          records.putIfAbsent(
              id,
              () => VendorExpense(
                  id: id,
                  category: data['category'] as String,
                  amount: data['amount'] as int,
                  spentAt: DateTime.parse(data['spent_at'] as String),
                  status: switch (row.read<String>('sync_status')) {
                    'synchronized' => 'pending',
                    'failed' || 'conflict' => 'rejected',
                    _ => 'saved',
                  },
                  note: data['note'] as String?,
                  item: data['item'] as String?));
        }
        return records.values.toList()
          ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
      });
}

final expenseStoreProvider =
    Provider((ref) => ExpenseStore(ref.watch(databaseProvider)));
final expenseCategoriesProvider =
    StreamProvider((ref) => ref.watch(expenseStoreProvider).watchCategories());
final expenseItemsProvider =
    StreamProvider((ref) => ref.watch(expenseStoreProvider).watchItems());
final vendorExpensesProvider = StreamProvider<List<VendorExpense>>((ref) {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return Stream.value([]);
  return ref.watch(expenseStoreProvider).watchExpenses(auth.profile.id);
});
