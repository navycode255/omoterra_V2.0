import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/backfill.dart';

part 'database.g.dart';

/// The vendor's products as last received from the server. Prices and
/// holdings are server values; the phone never edits them.
class CatalogProducts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Whole shillings. Null when the server has no price for it yet: such a
  /// product is shown but cannot be sold.
  IntColumn get price => integer().nullable()();
  TextColumn get priceVersion => text().nullable()();
  TextColumn get category => text().withDefault(const Constant(''))();

  /// Key of a bundled, approved product photo, if one exists.
  TextColumn get imageKey => text().nullable()();

  /// Units the server last recorded with this vendor; null when stock is
  /// not tracked yet.
  IntColumn get available => integer().nullable()();

  /// The server's own stock of this product (whole-number string), and the
  /// product it is cut from with how many one gives. Unsent sales of pieces
  /// cut what they come from (`stock_pool.dart`). Null when not sent.
  TextColumn get held => text().nullable()();
  TextColumn get cutFrom => text().nullable()();
  IntColumn get cutCount => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Server-provided settings, such as the M-Pesa number customers pay.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One recorded sale. Append-only: the phone's time, prices and quantities
/// are kept as recorded (VR10). [syncStatus] is delivery only; staff
/// verification happens on the server.
class Sales extends Table {
  /// UUID made on the phone; the server accepts each one once.
  TextColumn get clientId => text()();
  TextColumn get vendorId => text()();
  DateTimeColumn get recordedAt => dateTime()();

  /// `cash`, `mpesa` or `credit`, as the vendor chose. An M-Pesa choice is
  /// the vendor's report, not a verified payment.
  TextColumn get paymentMethod => text()();
  IntColumn get total => integer()();

  /// A credit sale's customer (MN018), and their name as shown then.
  TextColumn get creditCustomerId => text().nullable()();
  TextColumn get creditCustomerName => text().nullable()();

  /// `saved` (on the phone only) until the sync milestone sends it.
  TextColumn get syncStatus => text().withDefault(const Constant('saved'))();

  /// Set only from the server: `unverified` or `verified` (staff checked
  /// it). Vendors cannot change or void a verified sale (VR9).
  TextColumn get verification =>
      text().withDefault(const Constant('unverified'))();

  @override
  Set<Column> get primaryKey => {clientId};
}

class SaleLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get saleClientId => text().references(Sales, #clientId)();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  IntColumn get quantity => integer()();

  /// The price the vendor saw, and its version, at the moment of sale.
  IntColumn get unitPrice => integer()();
  TextColumn get priceVersion => text().nullable()();
  IntColumn get lineTotal => integer()();

  /// The phone's records showed fewer units than sold. The sale is still
  /// recorded; the server raises an "oversold" exception for staff.
  BoolColumn get exceedsRecordedStock =>
      boolean().withDefault(const Constant(false))();
}

/// A vendor's request to void one of their sales. Append-only: the sale
/// itself is never changed or deleted. At most one void per sale.
class SaleVoids extends Table {
  TextColumn get note => text().nullable()();

  /// UUID made on the phone; the server accepts each one once.
  TextColumn get voidId => text()();
  TextColumn get saleClientId => text().unique().references(Sales, #clientId)();

  /// `wrong_quantity`, `wrong_product`, `customer_cancelled`, `duplicate`
  /// or `other` (the server contract's reasons).
  TextColumn get reason => text()();

  /// The vendor who asked, from the signed-in session.
  TextColumn get actorId => text()();
  DateTimeColumn get requestedAt => dateTime()();

  /// `saved` (waiting to be sent), `accepted` or `rejected` by the server.
  TextColumn get syncStatus => text().withDefault(const Constant('saved'))();

  /// Why the server refused, e.g. `already_verified`.
  TextColumn get rejectionReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {voidId};
}

/// Delivery manifests addressed to the vendor's station, as last received
/// from the Mr. Nyama receiving service. Replaced on refresh.
class Deliveries extends Table {
  TextColumn get consignmentId => text()();
  IntColumn get version => integer()();
  TextColumn get reference => text()();
  TextColumn get sender => text()();
  TextColumn get stationKey => text()();
  TextColumn get stationName => text()();
  DateTimeColumn get dispatchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {consignmentId};
}

class DeliveryLines extends Table {
  TextColumn get consignmentId => text()();
  TextColumn get lineId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  IntColumn get quantity => integer()();
  TextColumn get imageKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {consignmentId, lineId};
}

/// The vendor's own count of a delivery. Append-only; it never changes
/// stock on the phone. Stock moves only when the server accepts it.
class Receipts extends Table {
  TextColumn get receiptId => text()();

  /// Idempotency key: the server records each event once.
  TextColumn get eventId => text().unique()();
  TextColumn get consignmentId => text()();

  /// The manifest version the vendor counted against.
  IntColumn get consignmentVersion => integer()();
  TextColumn get stationKey => text()();
  TextColumn get actorId => text()();
  DateTimeColumn get receivedAt => dateTime()();

  /// `saved` (only on the phone), `accepted` by the server, `conflict`
  /// (needs staff review, e.g. the manifest changed) or `rejected`.
  TextColumn get syncStatus => text().withDefault(const Constant('saved'))();
  TextColumn get conflictReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {receiptId};
}

class ReceiptLines extends Table {
  TextColumn get note => text().nullable()();
  TextColumn get receiptId => text().references(Receipts, #receiptId)();
  TextColumn get lineId => text()();

  /// Units taken into stock, and units that arrived but were refused.
  IntColumn get accepted => integer()();
  IntColumn get rejected => integer()();

  /// `short`, `damaged`, `wrong_product` or `other` when the count differs
  /// from what was dispatched; never assumed.
  TextColumn get reason => text().nullable()();

  @override
  Set<Column> get primaryKey => {receiptId, lineId};
}

/// A vendor's report of damaged goods. A claim for staff to verify, never
/// a stock loss on its own; the phone deducts nothing.
class DamageReports extends Table {
  /// UUID made on the phone; the server records each report once.
  TextColumn get reportId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  IntColumn get quantity => integer()();

  /// `spoiled`, `burnt`, `spilled` or `other`.
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get stationKey => text()();
  TextColumn get actorId => text()();
  DateTimeColumn get reportedAt => dateTime()();

  /// `saved` (only on the phone) or `sent`.
  TextColumn get syncStatus => text().withDefault(const Constant('saved'))();

  /// From the server: `reported`, `verified` (a loss) or `rejected`.
  TextColumn get review => text().withDefault(const Constant('reported'))();

  @override
  Set<Column> get primaryKey => {reportId};
}

/// Funga Siku: the vendor's physical count at the end of a business day.
/// One per vendor, station and day; corrections are staff-only. It records
/// a count and nothing more: not verified sales, settled money, reconciled
/// stock or an approved day.
class ClosingCounts extends Table {
  TextColumn get countId => text()();

  /// The Dar es Salaam business date, `yyyy-mm-dd`.
  TextColumn get businessDate => text()();
  TextColumn get vendorId => text()();
  TextColumn get stationKey => text()();
  DateTimeColumn get countedAt => dateTime()();

  /// `saved` (only on the phone) or `sent`.
  TextColumn get syncStatus => text().withDefault(const Constant('saved'))();

  /// From the server: `pending` until staff confirm the count, then
  /// `confirmed`; `conflict` if the server did not record it.
  TextColumn get officeStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get conflictReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {countId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {vendorId, stationKey, businessDate}
      ];
}

class ClosingCountLines extends Table {
  TextColumn get reason => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get countId => text().references(ClosingCounts, #countId)();
  TextColumn get productId => text()();
  TextColumn get productName => text()();

  /// What the phone's records showed at the time (for staff), if tracked.
  IntColumn get recorded => integer().nullable()();
  IntColumn get counted => integer()();

  @override
  Set<Column> get primaryKey => {countId, productId};
}

/// The sync queue: one row per operation recorded on the phone (sale, void,
/// receipt, damage report, closing count), written in the same transaction
/// as the record itself. [opId] is the operation's own idempotency key, so a
/// resend can never create a second record on the server.
class Outbox extends Table {
  TextColumn get opId => text()();

  /// `sale`, `sale_void`, `receipt`, `damage_report` or `closing_count`.
  TextColumn get opType => text()();
  TextColumn get vendorId => text()();
  TextColumn get stationKey => text()();

  /// Business date of the operation, `yyyy-mm-dd` (Dar es Salaam).
  TextColumn get businessDate => text()();

  /// JSON body matching the server contract for [opType].
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// `saved` (never tried), `waiting` (will retry), `synchronizing`,
  /// `synchronized`, `conflict` (staff review) or `failed` (refused).
  TextColumn get status => text().withDefault(const Constant('saved'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Technical cause of the last failed attempt, e.g. `offline`.
  TextColumn get lastError => text().nullable()();

  /// The server's reason for a conflict or refusal.
  TextColumn get resultReason => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {opId};
}

/// Technical record of sync attempts for support. Counts and error codes
/// only: never tokens, PINs, phone numbers or payloads.
class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();

  /// `ok`, `offline`, `not_configured`, `session_expired` or `error`.
  TextColumn get outcome => text()();
  IntColumn get sent => integer().withDefault(const Constant(0))();
  IntColumn get accepted => integer().withDefault(const Constant(0))();
  IntColumn get conflicts => integer().withDefault(const Constant(0))();
  IntColumn get rejected => integer().withDefault(const Constant(0))();

  /// Error type name only, for diagnosis.
  TextColumn get detail => text().nullable()();
}

@DriftDatabase(tables: [
  CatalogProducts,
  Settings,
  Sales,
  SaleLines,
  SaleVoids,
  Deliveries,
  DeliveryLines,
  Receipts,
  ReceiptLines,
  DamageReports,
  ClosingCounts,
  ClosingCountLines,
  Outbox,
  SyncLog,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'mr_nyama'));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(sales, sales.verification);
            await m.createTable(saleVoids);
          }
          if (from < 3) {
            await m.createTable(deliveries);
            await m.createTable(deliveryLines);
            await m.createTable(receipts);
            await m.createTable(receiptLines);
          }
          if (from < 4) {
            await m.createTable(damageReports);
            await m.createTable(closingCounts);
            await m.createTable(closingCountLines);
          }
          if (from < 6) {
            if (from >= 2) await m.addColumn(saleVoids, saleVoids.note);
            if (from >= 3) await m.addColumn(receiptLines, receiptLines.note);
            if (from >= 4) {
              await m.addColumn(closingCountLines, closingCountLines.reason);
              await m.addColumn(closingCountLines, closingCountLines.note);
            }
          }
          if (from < 5) {
            // Tables created above already have it; only schema 4 needs it.
            if (from == 4) {
              await m.addColumn(closingCounts, closingCounts.conflictReason);
            }
            await m.createTable(outbox);
            await m.createTable(syncLog);
            // Records saved before the queue existed still need sending.
            await backfillOutbox(this);
          }
          // Schemas 7 and 8 are ensured column by column: a development
          // build once shipped schema 7 with `cut_fraction` instead of
          // `cut_count` (25 October 2026), so a phone may lack a column its
          // version promises. The catalogue is a cache, refilled on refresh.
          if (from < 9) {
            await _addMissing(m, catalogProducts, [
              catalogProducts.held,
              catalogProducts.cutFrom,
              catalogProducts.cutCount
            ]);
            await _addMissing(
                m, sales, [sales.creditCustomerId, sales.creditCustomerName]);
          }
          if (from < 10) {
            await _addMissing(m, damageReports, [damageReports.imagePath]);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Every open, not only on upgrade: a phone whose schema number
          // promises columns it lacks (see `from < 9`) repairs itself.
          if (!details.wasCreated) {
            final m = createMigrator();
            await _addMissing(m, catalogProducts, [
              catalogProducts.held,
              catalogProducts.cutFrom,
              catalogProducts.cutCount
            ]);
            await _addMissing(
                m, sales, [sales.creditCustomerId, sales.creditCustomerName]);
            await _addMissing(m, damageReports, [damageReports.imagePath]);
          }
        },
      );

  /// Adds the [columns] the table does not have yet.
  Future<void> _addMissing(Migrator m, TableInfo<Table, dynamic> table,
      List<GeneratedColumn<Object>> columns) async {
    final existing = {
      for (final row
          in await customSelect('PRAGMA table_info(${table.actualTableName})')
              .get())
        row.read<String>('name')
    };
    for (final column in columns) {
      if (!existing.contains(column.name)) await m.addColumn(table, column);
    }
  }
}
