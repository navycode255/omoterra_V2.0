import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/payloads.dart';
import 'stock_pool.dart';

/// A product for sale, combining the server's catalogue with sales saved on
/// this phone but not yet sent.
class Product {
  final String id;
  final String name;

  /// From the server's product configuration; null means "no price yet".
  final int? price;
  final String? priceVersion;
  final String category;
  final String? imageKey;

  /// Units the server recorded with the vendor (null: not tracked).
  final int? available;

  /// Units in sales and damage reports saved on this phone and not yet sent.
  final int pendingSold;

  /// With pieces cut at the station (`stock_pool.dart`, set by
  /// [SalesStore.watchProducts]): what lies at the station once the cuts
  /// unsent sales need are made, and what can be sold including cutting.
  final int? pooledRemaining, pooledSellable;

  /// The server's own stock and cut rule, so the grid can also apply the
  /// cart being built (`saleStockProvider`).
  final String? held, cutFrom;
  final int? cutCount;

  const Product(
      {required this.id,
      required this.name,
      required this.price,
      this.priceVersion,
      this.category = '',
      this.imageKey,
      this.available,
      this.pendingSold = 0,
      this.pooledRemaining,
      this.pooledSellable,
      this.held,
      this.cutFrom,
      this.cutCount});

  bool get sellable => price != null;

  /// What the phone's records say lies at the station (pieces as they are:
  /// 2 birds, 1 Nusu, 1 Kidali). Can go below zero: sales are never blocked
  /// (an offline phone may be behind), only flagged.
  int? get remaining =>
      available == null ? null : pooledRemaining ?? available! - pendingSold;

  /// What can still be sold, counting what can be cut from the units above
  /// (a Paja while birds remain). Selling beyond it is flagged.
  int? get availableToSell => available == null
      ? null
      // A piece whose cut rule the phone lacks: the server counts more than
      // its own stock (it can be cut), so trust that less unsent sales.
      : cutFrom == null && available! > (int.tryParse(held ?? '') ?? available!)
          ? available! - pendingSold
          : pooledSellable ?? remaining;
}

/// One line of a sale about to be saved, priced from [Product] at that
/// moment.
class DraftLine {
  final String productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final String? priceVersion;
  final bool exceedsRecordedStock;
  const DraftLine(
      {required this.productId,
      required this.productName,
      required this.quantity,
      required this.unitPrice,
      this.priceVersion,
      this.exceedsRecordedStock = false});

  int get lineTotal => quantity * unitPrice;
}

class SaleDraft {
  final String clientId;
  final String vendorId;

  /// The session's station, for the sync queue (the server re-checks it).
  final String stationKey;
  final DateTime recordedAt;
  final PaymentMethod payment;
  final List<DraftLine> lines;

  /// The credit customer of a credit sale (MN018), and their name.
  final String? customerId, customerName;
  const SaleDraft(
      {required this.clientId,
      required this.vendorId,
      this.stationKey = '',
      required this.recordedAt,
      required this.payment,
      required this.lines,
      this.customerId,
      this.customerName});

  int get total => lines.fold(0, (sum, l) => sum + l.lineTotal);
}

/// A sale as stored on the phone.
class SavedSale {
  final String clientId;
  final DateTime recordedAt;
  final PaymentMethod payment;
  final int total;
  final int itemCount;

  /// `saved`: on this phone, waiting to be sent.
  final String syncStatus;

  /// A credit sale's customer.
  final String? customerName;
  const SavedSale(
      {required this.clientId,
      required this.recordedAt,
      required this.payment,
      required this.total,
      required this.itemCount,
      required this.syncStatus,
      this.customerName});

  bool get sent => syncStatus != 'saved';
}

const _mpesaKey = 'mpesa_recipient';

/// Local persistence for the catalogue and recorded sales.
class SalesStore {
  final AppDatabase db;
  SalesStore(this.db);

  /// Products in catalogue order, with unsent quantities applied.
  Stream<List<Product>> watchProducts() => db
      .customSelect(
        'SELECT c.*, COALESCE((SELECT SUM(l.quantity) FROM sale_lines l '
        'JOIN sales s ON s.client_id = l.sale_client_id '
        "WHERE s.sync_status = 'saved' AND l.product_id = c.id "
        // A voided sale no longer takes stock (unless the server refused
        // the void).
        'AND NOT EXISTS (SELECT 1 FROM sale_voids v WHERE '
        "v.sale_client_id = s.client_id AND v.sync_status <> 'rejected')), 0) "
        // Damage reported on this phone and not sent yet is no longer for
        // sale either (the server takes off what it has received).
        '+ COALESCE((SELECT SUM(d.quantity) FROM damage_reports d '
        "WHERE d.sync_status = 'saved' AND d.product_id = c.id), 0) "
        'AS pending FROM catalog_products c ORDER BY c.sort_order, c.name',
        readsFrom: {
          db.catalogProducts,
          db.sales,
          db.saleLines,
          db.saleVoids,
          db.damageReports
        },
      )
      .watch()
      .map((rows) {
        // Unsent sales of pieces come out of the whole product they are
        // cut from, as the server counts them.
        final pooled = poolStock([
          for (final r in rows)
            PoolEntry(
                id: r.read<String>('id'),
                held: r.readNullable<String>('held'),
                pendingSold: r.read<int>('pending'),
                cut: switch ((
                  r.readNullable<String>('cut_from'),
                  r.readNullable<int>('cut_count')
                )) {
                  (final String from, final int count) => CutRule(from, count),
                  _ => null,
                }),
        ]);
        return [
          for (final r in rows)
            Product(
                id: r.read<String>('id'),
                name: r.read<String>('name'),
                price: r.readNullable<int>('price'),
                priceVersion: r.readNullable<String>('price_version'),
                category: r.read<String>('category'),
                imageKey: r.readNullable<String>('image_key'),
                available: r.readNullable<int>('available'),
                pendingSold: r.read<int>('pending'),
                pooledRemaining: pooled.remaining[r.read<String>('id')],
                pooledSellable: pooled.sellable[r.read<String>('id')],
                held: r.readNullable<String>('held'),
                cutFrom: r.readNullable<String>('cut_from'),
                cutCount: r.readNullable<int>('cut_count')),
        ];
      });

  Stream<String?> watchMpesaRecipient() =>
      (db.select(db.settings)..where((s) => s.key.equals(_mpesaKey)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  /// Replaces the cached catalogue with the server's. Products the server
  /// no longer lists disappear; a missing M-Pesa number is cleared.
  Future<void> replaceCatalog(CatalogSnapshot snapshot) =>
      db.transaction(() async {
        await db.delete(db.catalogProducts).go();
        await db.batch((b) => b.insertAll(db.catalogProducts, [
              for (final (i, p) in snapshot.products.indexed)
                CatalogProductsCompanion.insert(
                    id: p.id,
                    name: p.name,
                    price: Value(p.price),
                    priceVersion: Value(p.priceVersion),
                    category: Value(p.category),
                    imageKey: Value(p.imageKey),
                    available: Value(p.available),
                    held: Value(p.held),
                    cutFrom: Value(p.cutFrom),
                    cutCount: Value(p.cutCount),
                    sortOrder: Value(i)),
            ]));
        if (snapshot.expenseCategories != null) {
          await db.into(db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(
                  key: 'expense_categories',
                  value: jsonEncode(snapshot.expenseCategories)));
          await db.into(db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(
                  key: 'expense_items',
                  value: jsonEncode(snapshot.expenseItems ?? const {})));
        }
        if (snapshot.mpesaRecipient == null) {
          await (db.delete(db.settings)..where((s) => s.key.equals(_mpesaKey)))
              .go();
        } else {
          await db.into(db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(
                  key: _mpesaKey, value: snapshot.mpesaRecipient!));
        }
      });

  /// Saves [draft] durably in one transaction. Saving the same client ID
  /// again returns the sale already stored and writes nothing, so a retry
  /// or a double tap can never record a sale twice.
  Future<SavedSale> saveSale(SaleDraft draft) async {
    if (draft.lines.isEmpty || draft.lines.any((l) => l.quantity <= 0)) {
      throw ArgumentError('A sale needs at least one positive line.');
    }
    if ((draft.payment == PaymentMethod.credit) != (draft.customerId != null)) {
      throw ArgumentError('A credit sale, and only a credit sale, names its '
          'customer.');
    }
    return db.transaction(() async {
      final existing = await sale(draft.clientId);
      if (existing != null) return existing;
      await db.into(db.sales).insert(SalesCompanion.insert(
          clientId: draft.clientId,
          vendorId: draft.vendorId,
          recordedAt: draft.recordedAt,
          paymentMethod: draft.payment.name,
          total: draft.total,
          creditCustomerId: Value(draft.customerId),
          creditCustomerName: Value(draft.customerName)));
      await db.batch((b) => b.insertAll(db.saleLines, [
            for (final l in draft.lines)
              SaleLinesCompanion.insert(
                  saleClientId: draft.clientId,
                  productId: l.productId,
                  productName: l.productName,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                  priceVersion: Value(l.priceVersion),
                  lineTotal: l.lineTotal,
                  exceedsRecordedStock: Value(l.exceedsRecordedStock)),
          ]));
      await enqueueOperation(db,
          opId: draft.clientId,
          opType: 'sale',
          vendorId: draft.vendorId,
          stationKey: draft.stationKey,
          occurredAt: draft.recordedAt,
          createdAt: draft.recordedAt,
          payload: salePayload(
              clientId: draft.clientId,
              recordedAt: draft.recordedAt,
              paymentMethod: draft.payment.name,
              customerId: draft.customerId,
              lines: [
                for (final l in draft.lines)
                  (
                    productId: l.productId,
                    quantity: l.quantity,
                    unitPrice: l.unitPrice,
                    priceVersion: l.priceVersion,
                    exceeds: l.exceedsRecordedStock
                  )
              ]));
      return (await sale(draft.clientId))!;
    });
  }

  Future<SavedSale?> sale(String clientId) async {
    final row = await (db.select(db.sales)
          ..where((s) => s.clientId.equals(clientId)))
        .getSingleOrNull();
    if (row == null) return null;
    final count = db.saleLines.quantity.sum();
    final items = await (db.selectOnly(db.saleLines)
          ..addColumns([count])
          ..where(db.saleLines.saleClientId.equals(clientId)))
        .map((r) => r.read(count) ?? 0)
        .getSingle();
    return SavedSale(
        clientId: row.clientId,
        recordedAt: row.recordedAt,
        payment: PaymentMethod.values.byName(row.paymentMethod),
        total: row.total,
        itemCount: items,
        syncStatus: row.syncStatus,
        customerName: row.creditCustomerName);
  }

  /// The sale's sync status as stored (`saved`, `sent`, `conflict`,
  /// `rejected`), updated live. It becomes `sent` only when the server
  /// accepts the sale (see the sync engine), so "sent" is never claimed early.
  Stream<String?> watchSaleStatus(String clientId) =>
      (db.select(db.sales)..where((s) => s.clientId.equals(clientId)))
          .watchSingleOrNull()
          .map((row) => row?.syncStatus);

  /// Records saved on the phone and not yet sent: sales, voids, receipts,
  /// damage reports and closing counts.
  Stream<int> watchUnsentCount() => db
      .customSelect(
        "SELECT (SELECT COUNT(*) FROM sales WHERE sync_status = 'saved') + "
        "(SELECT COUNT(*) FROM sale_voids WHERE sync_status = 'saved') + "
        "(SELECT COUNT(*) FROM receipts WHERE sync_status = 'saved') + "
        "(SELECT COUNT(*) FROM damage_reports WHERE sync_status = 'saved') + "
        "(SELECT COUNT(*) FROM closing_counts WHERE sync_status = 'saved') AS n",
        readsFrom: {
          db.sales,
          db.saleVoids,
          db.receipts,
          db.damageReports,
          db.closingCounts
        },
      )
      .watchSingle()
      .map((r) => r.read<int>('n'));
}

/// The app database. Tests override it with an in-memory one.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final salesStoreProvider =
    Provider<SalesStore>((ref) => SalesStore(ref.watch(databaseProvider)));

final productsProvider = StreamProvider<List<Product>>(
    (ref) => ref.watch(salesStoreProvider).watchProducts());

final mpesaRecipientProvider = StreamProvider<String?>(
    (ref) => ref.watch(salesStoreProvider).watchMpesaRecipient());

final unsentCountProvider = StreamProvider<int>(
    (ref) => ref.watch(salesStoreProvider).watchUnsentCount());
