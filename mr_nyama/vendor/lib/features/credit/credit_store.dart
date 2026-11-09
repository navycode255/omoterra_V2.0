import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../sales/sales_store.dart';

/// A credit customer of the station as this phone sees them (MN018): the
/// server's figures plus what this phone has not sent yet.
class CreditCustomer {
  final CreditCustomerData data;

  /// Credit sales and repayments saved on this phone and not yet sent.
  final int unsentSales, unsentRepaid, unsentCount;
  const CreditCustomer(this.data,
      {this.unsentSales = 0, this.unsentRepaid = 0, this.unsentCount = 0});

  String get id => data.id;
  String get name => data.name;
  int? get creditLimit => data.creditLimit;
  bool get creditAllowed => data.creditAllowed;
  bool get suspended => data.status != 'active';

  /// What the customer owes as far as this phone knows.
  int get owed => data.owed + unsentSales - unsentRepaid;

  /// Whether a credit sale of [amount] would take them over their limit.
  bool wouldExceed(int amount) =>
      creditLimit != null && owed + amount > creditLimit!;
}

/// The station's credit customers are cached on the phone (settings), so
/// credit sales and repayments work offline. The cache is the server's list;
/// unsent records are added on top until they are sent.
class CreditStore {
  final AppDatabase db;
  CreditStore(this.db);

  static const _key = 'credit_customers';

  Future<void> cache(List<CreditCustomerData> customers) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(
          key: _key,
          value: jsonEncode([for (final c in customers) c.toJson()])));

  /// Re-read on every write to the tables it depends on (a constant query
  /// would not do: drift emits a query again only when its result changes).
  Stream<List<CreditCustomer>> watch() async* {
    yield await load();
    await for (final _ in db.tableUpdates(TableUpdateQuery.onAllTables(
        [db.settings, db.sales, db.saleVoids, db.outbox]))) {
      yield await load();
    }
  }

  Future<List<CreditCustomer>> load() async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(_key)))
        .getSingleOrNull();
    if (row == null) return const [];
    final customers = [
      for (final c in jsonDecode(row.value) as List)
        CreditCustomerData.fromJson(Map<String, dynamic>.from(c as Map))
    ];
    // Credit sales not sent yet (a void the server did not refuse cancels one).
    final sales = await db.customSelect(
        "SELECT credit_customer_id AS id, SUM(total) AS amount, COUNT(*) AS n "
        "FROM sales s WHERE payment_method = 'credit' AND sync_status = 'saved' "
        'AND NOT EXISTS (SELECT 1 FROM sale_voids v WHERE '
        "v.sale_client_id = s.client_id AND v.sync_status <> 'rejected') "
        'GROUP BY credit_customer_id',
        readsFrom: {db.sales, db.saleVoids}).get();
    final unsentSales = {
      for (final r in sales)
        r.read<String>('id'): (r.read<int>('amount'), r.read<int>('n'))
    };
    // Repayments the server has not decided yet.
    final repaid = <String, (int, int)>{};
    for (final o in await (db.select(db.outbox)
          ..where((o) =>
              o.opType.equals('credit_repayment') &
              o.status.isNotIn(const ['synchronized', 'failed', 'conflict'])))
        .get()) {
      final p = jsonDecode(o.payload) as Map;
      final id = '${p['customer_id']}';
      final (sum, n) = repaid[id] ?? (0, 0);
      repaid[id] = (sum + (p['amount'] as int), n + 1);
    }
    return [
      for (final c in customers)
        CreditCustomer(c,
            unsentSales: unsentSales[c.id]?.$1 ?? 0,
            unsentRepaid: repaid[c.id]?.$1 ?? 0,
            unsentCount: (unsentSales[c.id]?.$2 ?? 0) + (repaid[c.id]?.$2 ?? 0))
    ];
  }

  /// A repayment the vendor took, queued for the office. Saving the same
  /// [id] again changes nothing.
  Future<void> submitRepayment(
          {required String id,
          required String vendorId,
          required String stationKey,
          required String customerId,
          required int amount,
          required String method,
          required DateTime receivedAt,
          String? note}) =>
      db.transaction(() async {
        if (amount <= 0 ||
            amount > 100000000 ||
            !const ['cash', 'mpesa'].contains(method) ||
            vendorId.isEmpty ||
            stationKey.isEmpty) {
          throw const FormatException('invalid credit repayment');
        }
        final cleanNote = note?.trim();
        await enqueueOperation(db,
            opId: id,
            opType: 'credit_repayment',
            vendorId: vendorId,
            stationKey: stationKey,
            occurredAt: receivedAt,
            createdAt: receivedAt,
            payload: {
              'client_id': id,
              'customer_id': customerId,
              'amount': amount,
              'method': method,
              'received_at': receivedAt.toUtc().toIso8601String(),
              'note': cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
            });
      });
}

final creditStoreProvider =
    Provider((ref) => CreditStore(ref.watch(databaseProvider)));

final creditCustomersProvider = StreamProvider<List<CreditCustomer>>(
    (ref) => ref.watch(creditStoreProvider).watch());

/// Downloads the station's customers into the phone's cache. Offline, the
/// cache stays as it was.
final creditRefreshProvider = FutureProvider.autoDispose<void>((ref) async {
  final repository = ref.read(vendorRepositoryProvider);
  if (repository is! VendorCreditRepository) return;
  final auth = ref.read(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return;
  final customers = await ref.read(sessionProvider.notifier).authorised(
      (token) => (repository as VendorCreditRepository).creditCustomers(token));
  await ref.read(creditStoreProvider).cache(customers);
});
