// Sale cancellations (MN034): a reported sale the vendor can no longer void
// is cancelled by two people. One asks, a different finance person or the
// owner decides. Nothing here changes a sale until the server says so.

String _str(Object? v) => v == null ? '' : '$v';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

class CancelPerson {
  final String id, name;
  const CancelPerson({required this.id, required this.name});
  static CancelPerson? fromJson(Object? json) => json is! Map
      ? null
      : CancelPerson(id: _str(json['id']), name: _str(json['name']));
}

class CancelLine {
  final String name;
  final num quantity;
  final int amount;
  const CancelLine(
      {required this.name, required this.quantity, required this.amount});
}

class SaleCancellation {
  final String id, saleId, stationId, businessDate, status, reason;
  final CancelPerson? requestedBy, decidedBy;
  final bool requestedByMe;
  final String? decisionReason;
  final String vendorName, payment;
  final String? customer;
  final int total;
  final List<CancelLine> lines;
  const SaleCancellation(
      {required this.id,
      required this.saleId,
      required this.stationId,
      required this.businessDate,
      required this.status,
      required this.reason,
      this.requestedBy,
      this.decidedBy,
      this.requestedByMe = false,
      this.decisionReason,
      this.vendorName = '',
      this.payment = '',
      this.customer,
      this.total = 0,
      this.lines = const []});

  bool get isOpen => status == 'open';

  factory SaleCancellation.fromJson(Map<String, dynamic> j) {
    final sale = _map(j['sale']);
    return SaleCancellation(
        id: _str(j['id']),
        saleId: _str(j['sale_id']),
        stationId: _str(j['station_id']),
        businessDate: _str(j['business_date']),
        status: _str(j['status']),
        reason: _str(j['reason']),
        requestedBy: CancelPerson.fromJson(j['requested_by']),
        decidedBy: CancelPerson.fromJson(j['decided_by']),
        requestedByMe: j['requested_by_me'] == true,
        decisionReason: j['decision_reason'] as String?,
        vendorName: _str(sale['vendor_name']),
        payment: _str(sale['payment']),
        customer: sale['customer'] as String?,
        total: (sale['total'] as num?)?.toInt() ?? 0,
        lines: [
          for (final l in sale['lines'] as List? ?? const [])
            CancelLine(
                name: _str(_map(l)['name']),
                quantity: _map(l)['quantity'] as num? ?? 0,
                amount: (_map(l)['amount'] as num?)?.toInt() ?? 0)
        ]);
  }
}

abstract interface class OfficeSaleCancelRepository {
  Future<List<SaleCancellation>> saleCancellations(
      {String? stationId, String? status});

  /// A retry with the same [clientId] returns the first request.
  Future<SaleCancellation> askToCancelSale(
      {required String clientId,
      required String saleId,
      required String reason});

  Future<SaleCancellation> decideSaleCancellation(String id,
      {required bool approve, required String reason});

  /// The one who asked takes it back. A repeat finds the same result.
  Future<SaleCancellation> withdrawSaleCancellation(String id);
}
