// Lost sale entries (MN036): a sale remembered after a lost phone, entered for
// its own day by two people. One asks, a different finance person or the owner
// decides. Prices are never sent: the server uses that day's price. And ending a
// phone's access without suspending the vendor.

String _str(Object? v) => v == null ? '' : '$v';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    [for (final row in v is List ? v : const []) _map(row)];

class LostSaleLine {
  final String productCode, name;
  final int quantity, unitPrice, amount;
  const LostSaleLine(
      {required this.productCode,
      required this.name,
      required this.quantity,
      required this.unitPrice,
      required this.amount});
  factory LostSaleLine.fromJson(Map<String, dynamic> j) => LostSaleLine(
      productCode: _str(j['product_code']),
      name: _str(j['name']),
      quantity: _int(j['quantity']),
      unitPrice: _int(j['unit_price']),
      amount: _int(j['amount']));
}

class LostSaleEntry {
  final String id, vendorId, vendorName, stationId, stationName, businessDate;
  final String paymentMethod, reason, status;
  final String? customer, requestedBy, decidedBy, decisionReason, saleId;
  final bool requestedByMe;
  final int total;
  final List<LostSaleLine> lines;
  final DateTime? requestedAt;

  /// Approved, and the sale it made was cancelled afterwards.
  final bool saleCancelled;

  /// A closing count exists for that station and day. Without one, a sale
  /// entered there shows the day as a day without a count.
  final bool dayCounted;
  const LostSaleEntry(
      {required this.id,
      this.vendorId = '',
      this.vendorName = '',
      this.stationId = '',
      this.stationName = '',
      this.businessDate = '',
      this.paymentMethod = 'cash',
      this.reason = '',
      this.status = 'open',
      this.customer,
      this.requestedBy,
      this.decidedBy,
      this.decisionReason,
      this.saleId,
      this.requestedByMe = false,
      this.total = 0,
      this.lines = const [],
      this.requestedAt,
      this.saleCancelled = false,
      this.dayCounted = true});

  bool get isOpen => status == 'open';
  bool get isCash => paymentMethod == 'cash';

  factory LostSaleEntry.fromJson(Map<String, dynamic> j) => LostSaleEntry(
      id: _str(j['id']),
      vendorId: _str(j['vendor_id']),
      vendorName: _str(j['vendor_name']),
      stationId: _str(j['station_id']),
      stationName: _str(j['station_name']),
      businessDate: _str(j['business_date']),
      paymentMethod: _str(j['payment_method']),
      reason: _str(j['reason']),
      status: _str(j['status']),
      customer: j['customer'] as String?,
      requestedBy: _map(j['requested_by'])['name'] as String?,
      decidedBy: _map(j['decided_by'])['name'] as String?,
      decisionReason: j['decision_reason'] as String?,
      saleId: j['sale_id'] as String?,
      requestedByMe: j['requested_by_me'] == true,
      total: _int(j['total']),
      lines: [for (final l in _rows(j['lines'])) LostSaleLine.fromJson(l)],
      requestedAt: DateTime.tryParse(_str(j['requested_at'])),
      saleCancelled: j['sale_cancelled'] == true,
      dayCounted: j['day_counted'] != false);
}

class LostSaleProduct {
  final String code, name;
  final int unitPrice;
  const LostSaleProduct(
      {required this.code, required this.name, required this.unitPrice});
  factory LostSaleProduct.fromJson(Map<String, dynamic> j) => LostSaleProduct(
      code: _str(j['code']),
      name: _str(j['name']),
      unitPrice: _int(j['unit_price']));
}

/// What the form shows for one business day: its station, and the products
/// that can be entered, each at the price in force that day.
class LostSaleDay {
  final String businessDate, stationId, stationName;
  final bool otherDecider;
  final List<LostSaleProduct> products;
  const LostSaleDay(
      {required this.businessDate,
      required this.stationId,
      required this.stationName,
      required this.otherDecider,
      required this.products});
  factory LostSaleDay.fromJson(Map<String, dynamic> j) => LostSaleDay(
      businessDate: _str(j['business_date']),
      stationId: _str(j['station_id']),
      stationName: _str(j['station_name']),
      otherDecider: j['other_decider'] == true,
      products: [
        for (final p in _rows(j['products'])) LostSaleProduct.fromJson(p)
      ]);
}

abstract interface class OfficeLostSalesRepository {
  Future<List<LostSaleEntry>> lostSaleEntries(
      {String? stationId, String? vendorId, String? status});

  /// [businessDate] is `YYYY-MM-DD`. A refused day throws its reason.
  Future<LostSaleDay> lostSaleDay(String vendorId, String businessDate);

  /// A retry with the same [clientId] returns the first request. There is no
  /// price here: [quantities] maps product codes to how many.
  Future<LostSaleEntry> askLostSale(
      {required String clientId,
      required String vendorId,
      required String stationId,
      required String businessDate,
      required String paymentMethod,
      String? customerId,
      required Map<String, int> quantities,
      required String reason});

  Future<LostSaleEntry> decideLostSale(String id,
      {required bool approve, required String reason});

  /// The one who asked takes it back. A repeat finds the same result.
  Future<LostSaleEntry> withdrawLostSale(String id);

  /// Ends every sign-in, offline grant and fingerprint key of the vendor. The
  /// account stays active, so a new phone can sign in.
  Future<void> endPhoneAccess(String vendorId, {required String reason});
}
