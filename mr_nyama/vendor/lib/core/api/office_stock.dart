// Station stock in the office: returns to a kitchen or receiving store, the
// daily stock equation per vendor-day (stock days), returning a delivery's
// in-transit units to central, and the owner's late-entry window. The server
// computes every figure; parsing is null-safe so a field the server leaves
// out never breaks the screen.

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

int? _intOrNull(Object? v) => v == null ? null : _int(v);

/// Whole units, or kilograms as a decimal string.
num _num(Object? v) => switch (v) {
      num() => v,
      String() => num.tryParse(v) ?? 0,
      _ => 0,
    };

num? _numOrNull(Object? v) => v == null ? null : _num(v);

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

DateTime? _day(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    [for (final r in v is List ? v : const []) _map(r)];

/// A stock location (`GET /admin/locations`).
class OfficeStockLocation {
  final String id, code, name, kind;
  final bool active;
  const OfficeStockLocation(
      {required this.id,
      this.code = '',
      required this.name,
      required this.kind,
      this.active = true});

  /// Returns go to a kitchen or a receiving store.
  bool get takesReturns => active && (kind == 'kitchen' || kind == 'receiving');

  factory OfficeStockLocation.fromJson(Map<String, dynamic> j) =>
      OfficeStockLocation(
          id: _str(j['id']),
          code: _str(j['code']),
          name: _opt(j['name']) ?? _str(j['code']),
          kind: _str(j['kind']),
          active: j['active'] != false);
}

/// One product line of a return to send.
class ReturnLineDraft {
  final String product;
  final int quantity;
  const ReturnLineDraft(this.product, this.quantity);
  Map<String, Object> toJson() => {'product': product, 'quantity': quantity};
}

class StockReturnLot {
  final String lotId;
  final num quantity;
  final int? cost;
  const StockReturnLot(
      {required this.lotId, required this.quantity, this.cost});
  factory StockReturnLot.fromJson(Map<String, dynamic> j) => StockReturnLot(
      lotId: _str(j['lot_id']),
      quantity: _num(j['quantity']),
      cost: _intOrNull(j['cost_amount']));
}

class StockReturnLine {
  final int lineNo;
  final String product, name, unit;
  final num quantity;
  final int? cost;
  final List<StockReturnLot> lots;
  const StockReturnLine(
      {this.lineNo = 0,
      required this.product,
      required this.name,
      this.unit = '',
      required this.quantity,
      this.cost,
      this.lots = const []});
  factory StockReturnLine.fromJson(Map<String, dynamic> j) => StockReturnLine(
      lineNo: _int(j['line_no']),
      product: _str(j['product']),
      name: _opt(j['name']) ?? _str(j['product']),
      unit: _str(j['unit']),
      quantity: _num(j['quantity']),
      cost: _intOrNull(j['cost_amount']),
      lots: [for (final l in _rows(j['lots'])) StockReturnLot.fromJson(l)]);
}

/// A recorded return (`/staff/returns`). Whole shillings; null cost means
/// the server does not know it.
class OfficeStockReturn {
  final String id, clientId, stationId, stationName;
  final DateTime? businessDate, occurredAt, createdAt;
  final String destinationId, destinationCode, destinationName;
  final String reason, recordedBy;
  final int? cost;
  final List<StockReturnLine> lines;
  const OfficeStockReturn(
      {required this.id,
      this.clientId = '',
      this.stationId = '',
      this.stationName = '',
      this.businessDate,
      this.occurredAt,
      this.createdAt,
      this.destinationId = '',
      this.destinationCode = '',
      this.destinationName = '',
      this.reason = '',
      this.recordedBy = '',
      this.cost,
      this.lines = const []});
  factory OfficeStockReturn.fromJson(Map<String, dynamic> j) =>
      OfficeStockReturn(
          id: _str(j['id']),
          clientId: _str(j['client_id']),
          stationId: _str(j['station_id']),
          stationName: _str(j['station_name']),
          businessDate: _day(j['business_date']),
          occurredAt: _time(j['occurred_at']),
          createdAt: _time(j['created_at']),
          destinationId: _str(j['destination_location_id']),
          destinationCode: _str(j['destination_code']),
          destinationName:
              _opt(j['destination_name']) ?? _str(j['destination_code']),
          reason: _str(j['reason']),
          recordedBy: _str(j['recorded_by']),
          cost: _intOrNull(j['cost_amount']),
          lines: [
            for (final l in _rows(j['lines'])) StockReturnLine.fromJson(l)
          ]);
}

/// The server's word for a vendor-day's stock.
enum StockDayStatus {
  notTracked('not_tracked'),
  open('open'),
  reconciled('reconciled'),
  discrepancy('discrepancy'),
  needsReconciliation('needs_reconciliation');

  final String wire;
  const StockDayStatus(this.wire);
  static StockDayStatus? parse(Object? v) =>
      values.where((s) => s.wire == v).firstOrNull;
}

/// Why a day's closing cannot be confirmed yet.
class StockDayBlockers {
  final int unverifiedSales, pendingDamage, previousDayUnreconciled;
  const StockDayBlockers(
      {this.unverifiedSales = 0,
      this.pendingDamage = 0,
      this.previousDayUnreconciled = 0});
  bool get any =>
      unverifiedSales > 0 || pendingDamage > 0 || previousDayUnreconciled > 0;
  static StockDayBlockers? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = _map(v);
    return StockDayBlockers(
        unverifiedSales: _int(j['unverified_sales']),
        pendingDamage: _int(j['pending_damage']),
        previousDayUnreconciled: _int(j['previous_day_unreconciled']));
  }
}

/// A later entry that reopened a reconciled day.
class StockDayReopen {
  final String movementId, movementType, previousStatus, by;
  final DateTime? occurredAt, at, businessDate;
  const StockDayReopen(
      {this.movementId = '',
      required this.movementType,
      this.previousStatus = '',
      this.by = '',
      this.occurredAt,
      this.at,
      this.businessDate});
  factory StockDayReopen.fromJson(Map<String, dynamic> j) => StockDayReopen(
      movementId: _str(j['movement_id']),
      movementType: _str(j['movement_type']),
      previousStatus: _str(j['previous_status']),
      by: _str(j['by']),
      occurredAt: _time(j['occurred_at']),
      at: _time(j['at']),
      businessDate: _day(j['business_date']));
}

/// One product's stock equation for the day. Counted and difference are
/// null until a closing count exists.
class StockDayProduct {
  final String productId, productCode, name, unit;
  final num opening, received, sold, returned, lost, movedOut, expected;
  final num? counted, difference;

  /// Pieces counted that were cut from the whole product they come from
  /// (`stock.cut_from`); their part is in that product's count.
  final num cutPieces;
  const StockDayProduct(
      {this.productId = '',
      this.productCode = '',
      required this.name,
      this.unit = '',
      this.opening = 0,
      this.received = 0,
      this.sold = 0,
      this.returned = 0,
      this.lost = 0,
      this.movedOut = 0,
      this.expected = 0,
      this.counted,
      this.difference,
      this.cutPieces = 0});
  factory StockDayProduct.fromJson(Map<String, dynamic> j) => StockDayProduct(
      productId: _str(j['product_id']),
      productCode: _str(j['product_code']),
      name: _opt(j['name']) ?? _str(j['product_code']),
      unit: _str(j['unit']),
      opening: _num(j['opening']),
      received: _num(j['received']),
      sold: _num(j['sold']),
      returned: _num(j['returned']),
      lost: _num(j['lost']),
      movedOut: _num(j['moved_out']),
      expected: _num(j['expected_closing']),
      counted: _numOrNull(j['counted_closing']),
      difference: _numOrNull(j['difference']),
      cutPieces: _num(j['cut_pieces']));
}

/// One vendor-day at a station (`GET /staff/stock-days`).
class OfficeStockDay {
  final String vendorDayId, vendorId, vendorName, stationId;
  final DateTime? businessDate, previousBusinessDate;

  /// Null when the server sent a word this app does not know ([statusWire]).
  final StockDayStatus? status;
  final String statusWire;
  final String? closingId, closingStatus, previousStockStatus;
  final int revision;
  final StockDayBlockers? blockers;
  final List<StockDayReopen> reopenedBy;
  final List<StockDayProduct> products;
  const OfficeStockDay(
      {required this.vendorDayId,
      this.vendorId = '',
      required this.vendorName,
      this.stationId = '',
      this.businessDate,
      this.status,
      this.statusWire = '',
      this.closingId,
      this.closingStatus,
      this.revision = 0,
      this.previousBusinessDate,
      this.previousStockStatus,
      this.blockers,
      this.reopenedBy = const [],
      this.products = const []});

  /// A reconciled day that a later entry reopened: its closing can be
  /// confirmed again.
  bool get canConfirmAgain =>
      status == StockDayStatus.needsReconciliation && closingId != null;

  factory OfficeStockDay.fromJson(Map<String, dynamic> j) => OfficeStockDay(
          vendorDayId: _str(j['vendor_day_id']),
          vendorId: _str(j['vendor_id']),
          vendorName: _str(j['vendor_name']),
          stationId: _str(j['station_id']),
          businessDate: _day(j['business_date']),
          status: StockDayStatus.parse(j['stock_status']),
          statusWire: _str(j['stock_status']),
          closingId: _opt(j['closing_id']),
          closingStatus: _opt(j['closing_status']),
          revision: _int(j['revision']),
          previousBusinessDate: _day(j['previous_business_date']),
          previousStockStatus: _opt(j['previous_stock_status']),
          blockers: StockDayBlockers.fromJson(j['blockers']),
          reopenedBy: [
            for (final r in _rows(j['reopened_by'])) StockDayReopen.fromJson(r)
          ],
          products: [
            for (final p in _rows(j['products'])) StockDayProduct.fromJson(p)
          ]);
}

/// A station's stock days for a range (oldest first, as the server sends).
class OfficeStockDays {
  final String stationId;
  final DateTime? from, to;
  final List<OfficeStockDay> days;
  const OfficeStockDays(
      {required this.stationId, this.from, this.to, this.days = const []});
  factory OfficeStockDays.fromJson(Map<String, dynamic> j) => OfficeStockDays(
      stationId: _str(j['station_id']),
      from: _day(j['from']),
      to: _day(j['to']),
      days: [for (final d in _rows(j['days'])) OfficeStockDay.fromJson(d)]);
}

/// The server's answer to a resolved receipt mismatch.
class ResolvedProblem {
  final String id, kind, status, resolution, reason;
  final DateTime? resolvedAt;
  const ResolvedProblem(
      {required this.id,
      this.kind = '',
      this.status = '',
      this.resolution = '',
      this.reason = '',
      this.resolvedAt});
  factory ResolvedProblem.fromJson(Map<String, dynamic> j) => ResolvedProblem(
      id: _str(j['id']),
      kind: _str(j['kind']),
      status: _str(j['status']),
      resolution: _str(j['resolution']),
      reason: _str(j['resolution_reason']),
      resolvedAt: _time(j['resolved_at']));
}

/// The owner's late-entry window (`stock.late_entry_hours`) is at most
/// 30 days.
const maxLateEntryHours = 720;

/// Parses typed hours: a whole number from 0 to 720, otherwise null.
int? parseLateEntryHours(String text) {
  final t = text.trim();
  if (!RegExp(r'^\d{1,4}$').hasMatch(t)) return null;
  final n = int.parse(t);
  return n <= maxLateEntryHours ? n : null;
}

/// The longest range one stock-days request covers.
const maxStockDaysRange = 62;

/// Office stock calls; implemented by the HTTP office repository.
abstract interface class OfficeStockRepository {
  /// Every stock location (`inventory.view`).
  Future<List<OfficeStockLocation>> stockLocations();
  Future<OfficeStockReturn> recordReturn(
      {required String clientId,
      required String stationId,
      required String businessDate,
      required String destinationLocationId,
      required String reason,
      required List<ReturnLineDraft> lines});
  Future<List<OfficeStockReturn>> stockReturns(
      {String? stationId, String? from, String? to});
  Future<OfficeStockDays> stockDays(
      {required String stationId, String? from, String? to});

  /// A receipt mismatch's units still in transit: `delivered_later` or
  /// `returned_to_central` (receiving.manage), `transit_loss` (finance or
  /// the owner). Only a return names a destination.
  Future<ResolvedProblem> resolveTransit(String exceptionId,
      {required String resolution,
      required String reason,
      String? destinationLocationId});

  /// Owner only; null removes the window (not set).
  Future<void> saveLateEntryHours(int? hours, {required String reason});
}

/// The last physical count of a product (`last_count` of a stock measure).
class OfficeLastCount {
  final num counted;
  final DateTime? businessDate;
  final String status;
  const OfficeLastCount(
      {required this.counted, this.businessDate, this.status = ''});
  factory OfficeLastCount.fromJson(Map<String, dynamic> j) => OfficeLastCount(
      counted: _num(j['counted']),
      businessDate: _day(j['business_date']),
      status: _str(j['status']));
}

/// One product's stock figures, each with one meaning everywhere
/// (`GET /staff/stock-measures`). The server computes every figure.
class OfficeStockMeasure {
  final String productCode, productName;

  /// Stock recorded in the official books.
  final num book;

  /// Sold and sent, not yet verified.
  final num pendingSales;

  /// Reported, not yet decided.
  final num pendingDamage;

  /// Sold, but held by the server for review. Never subtracted.
  final num heldPhoneSales;

  /// The server's own estimate of what is available.
  final num estimatedAvailable;
  final OfficeLastCount? lastCount;

  /// Counted minus expected, at the last confirmation.
  final num? lastVariance;

  /// A count that differs from the books and that nothing has posted.
  final num countGap;
  const OfficeStockMeasure(
      {required this.productCode,
      required this.productName,
      this.book = 0,
      this.pendingSales = 0,
      this.pendingDamage = 0,
      this.heldPhoneSales = 0,
      this.estimatedAvailable = 0,
      this.lastCount,
      this.lastVariance,
      this.countGap = 0});

  factory OfficeStockMeasure.fromJson(Map<String, dynamic> j) {
    final product = _map(j['product']);
    final count = j['last_count'];
    return OfficeStockMeasure(
        productCode: _str(product['code']),
        productName: _opt(product['name']) ?? _str(product['code']),
        book: _num(j['book']),
        pendingSales: _num(j['pending_sales']),
        pendingDamage: _num(j['pending_damage']),
        heldPhoneSales: _num(j['held_phone_sales']),
        estimatedAvailable: _num(j['estimated_available']),
        lastCount:
            count is Map ? OfficeLastCount.fromJson(_map(count)) : null,
        lastVariance: _numOrNull(j['last_variance']),
        countGap: _num(j['count_gap']));
  }
}

/// `GET /staff/stock-measures` (inventory.view, the caller's stations).
abstract interface class OfficeStockMeasuresRepository {
  Future<List<OfficeStockMeasure>> stockMeasures(String stationId);
}
