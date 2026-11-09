import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/business_day.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';

/// Schema 1 as shipped in the Phase 2.4 preview build (sales without a
/// verification column, no voids table), with one sale in it.
void createVersion1(dynamic raw) {
  raw.execute('''CREATE TABLE catalog_products (id TEXT NOT NULL,
    name TEXT NOT NULL, price INTEGER NULL, price_version TEXT NULL,
    category TEXT NOT NULL DEFAULT '', image_key TEXT NULL,
    available INTEGER NULL, sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (id))''');
  raw.execute('''CREATE TABLE settings (key TEXT NOT NULL, value TEXT NOT NULL,
    PRIMARY KEY (key))''');
  raw.execute('''CREATE TABLE sales (client_id TEXT NOT NULL,
    vendor_id TEXT NOT NULL, recorded_at INTEGER NOT NULL,
    payment_method TEXT NOT NULL, total INTEGER NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'saved', PRIMARY KEY (client_id))''');
  raw.execute('''CREATE TABLE sale_lines (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    sale_client_id TEXT NOT NULL REFERENCES sales (client_id),
    product_id TEXT NOT NULL, product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL, unit_price INTEGER NOT NULL,
    price_version TEXT NULL, line_total INTEGER NOT NULL,
    exceeds_recorded_stock INTEGER NOT NULL DEFAULT 0
      CHECK (exceeds_recorded_stock IN (0, 1)))''');
  final at = DateTime.utc(2026, 10, 9, 9).millisecondsSinceEpoch ~/ 1000;
  raw.execute("INSERT INTO sales VALUES ('old-sale-1', 'v1', $at, 'cash', "
      "9000, 'saved')");
  raw.execute("INSERT INTO sale_lines (sale_client_id, product_id, "
      "product_name, quantity, unit_price, line_total) VALUES "
      "('old-sale-1', 'kuku', 'Kuku mzima', 1, 9000, 9000)");
  raw.execute('PRAGMA user_version = 1');
}

void main() {
  test('a phone with schema 1 keeps its sales and gains voids', () async {
    final db = AppDatabase(DatabaseConnection(
        NativeDatabase.memory(setup: createVersion1),
        closeStreamsSynchronously: true));
    addTearDown(db.close);
    final history = HistoryStore(db);
    final day = await history
        .watchDay(businessDate(DateTime.utc(2026, 10, 9, 9)))
        .first;
    expect(day.single.clientId, 'old-sale-1');
    expect(day.single.total, 9000);
    expect(day.single.verified, isFalse);
    // Its unsent sale was queued for sync with its original ID.
    final queued = (await db.select(db.outbox).get()).single;
    expect([queued.opId, queued.opType, queued.status],
        ['old-sale-1', 'sale', 'saved']);
    await history.voidSale(
        voidId: 'void-1',
        saleClientId: 'old-sale-1',
        reason: VoidReason.duplicate,
        actorId: 'v1',
        now: DateTime.utc(2026, 10, 9, 10));
    expect(await db.select(db.saleVoids).get(), hasLength(1));
  });
}
