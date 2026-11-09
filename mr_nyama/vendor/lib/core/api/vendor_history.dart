// The vendor's own records as the server has them (`GET /vendor/history`),
// so a new phone (or the same phone after a reinstall) can show its history
// again. Everything here is already on the server: the phone stores it as
// sent and never queues it again. Parsing is null-safe: a field the server
// leaves out never breaks recovery.

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

DateTime? _time(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? [
        for (final r in v)
          if (r is Map) Map<String, dynamic>.from(r)
      ]
    : const [];

class RecoveredSaleLine {
  final String productId, productName;
  final int quantity, unitPrice, lineTotal;
  final String? priceVersion;
  const RecoveredSaleLine(
      {required this.productId,
      required this.productName,
      required this.quantity,
      required this.unitPrice,
      required this.lineTotal,
      this.priceVersion});

  factory RecoveredSaleLine.fromJson(Map<String, dynamic> j) {
    final quantity = _int(j['quantity']);
    final price = _int(j['unit_price']);
    return RecoveredSaleLine(
        productId: _str(j['product_id']),
        productName: _str(j['product_name']),
        quantity: quantity,
        unitPrice: price,
        lineTotal:
            j['line_total'] == null ? quantity * price : _int(j['line_total']),
        priceVersion: _opt(j['price_version']));
  }
}

class RecoveredVoid {
  final String voidId, reason;
  final String? note;
  final DateTime? requestedAt;

  /// A staff correction of a verified sale rather than the vendor's own void.
  final bool byStaff;
  const RecoveredVoid(
      {required this.voidId,
      required this.reason,
      this.note,
      this.requestedAt,
      this.byStaff = false});

  static RecoveredVoid? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return RecoveredVoid(
        voidId: _str(j['void_id']),
        reason: _opt(j['reason']) ?? 'other',
        note: _opt(j['note']),
        requestedAt: _time(j['requested_at']),
        byStaff: j['by_staff'] == true);
  }
}

class RecoveredSale {
  final String clientId, paymentMethod, status;
  final DateTime? recordedAt;
  final String? stationKey, customerId, customerName;
  final int total;
  final List<RecoveredSaleLine> lines;
  final RecoveredVoid? voided;

  /// The office entered this sale after a lost phone (MN036).
  final bool officeEntered;
  const RecoveredSale(
      {required this.clientId,
      required this.paymentMethod,
      required this.status,
      required this.recordedAt,
      required this.total,
      this.stationKey,
      this.customerId,
      this.customerName,
      this.lines = const [],
      this.voided,
      this.officeEntered = false});

  bool get verified => status == 'verified';

  factory RecoveredSale.fromJson(Map<String, dynamic> j) => RecoveredSale(
      clientId: _str(j['client_id']),
      paymentMethod: _opt(j['payment_method']) ?? 'cash',
      status: _opt(j['status']) ?? 'reported',
      recordedAt: _time(j['recorded_at']),
      total: _int(j['total']),
      stationKey: _opt(j['station_key']),
      customerId: _opt(j['customer_id']),
      customerName: _opt(j['customer_name']),
      lines: [for (final l in _rows(j['lines'])) RecoveredSaleLine.fromJson(l)],
      voided: RecoveredVoid.fromJson(j['void']),
      officeEntered: j['office_entered'] == true);
}

class RecoveredReceiptLine {
  final String lineId;
  final int accepted, rejected;
  final String? reason, note;
  const RecoveredReceiptLine(
      {required this.lineId,
      required this.accepted,
      required this.rejected,
      this.reason,
      this.note});

  factory RecoveredReceiptLine.fromJson(Map<String, dynamic> j) =>
      RecoveredReceiptLine(
          lineId: _str(j['line_id']),
          accepted: _int(j['accepted']),
          rejected: _int(j['rejected']),
          reason: _opt(j['reason']),
          note: _opt(j['note']));
}

class RecoveredReceipt {
  final String receiptId, eventId, consignmentId;
  final int consignmentVersion;
  final String? stationKey;
  final DateTime? receivedAt;
  final List<RecoveredReceiptLine> lines;
  const RecoveredReceipt(
      {required this.receiptId,
      required this.eventId,
      required this.consignmentId,
      required this.consignmentVersion,
      this.stationKey,
      this.receivedAt,
      this.lines = const []});

  factory RecoveredReceipt.fromJson(Map<String, dynamic> j) => RecoveredReceipt(
          receiptId: _str(j['receipt_id']),
          eventId: _str(j['event_id']),
          consignmentId: _str(j['consignment_id']),
          consignmentVersion: _int(j['consignment_version']),
          stationKey: _opt(j['station_key']),
          receivedAt: _time(j['received_at']),
          lines: [
            for (final l in _rows(j['lines'])) RecoveredReceiptLine.fromJson(l)
          ]);
}

class RecoveredDamage {
  final String reportId, productId, productName, reason, review;
  final int quantity;
  final String? note, stationKey;
  final DateTime? reportedAt;
  const RecoveredDamage(
      {required this.reportId,
      required this.productId,
      required this.productName,
      required this.reason,
      required this.review,
      required this.quantity,
      this.note,
      this.stationKey,
      this.reportedAt});

  factory RecoveredDamage.fromJson(Map<String, dynamic> j) => RecoveredDamage(
      reportId: _str(j['report_id']),
      productId: _str(j['product_id']),
      productName: _str(j['product_name']),
      reason: _opt(j['reason']) ?? 'other',
      review: _opt(j['review']) ?? 'reported',
      quantity: _int(j['quantity']),
      note: _opt(j['note']),
      stationKey: _opt(j['station_key']),
      reportedAt: _time(j['reported_at']));
}

class RecoveredCountLine {
  final String productId, productName;
  final int counted;
  final String? reason, note;
  const RecoveredCountLine(
      {required this.productId,
      required this.productName,
      required this.counted,
      this.reason,
      this.note});

  factory RecoveredCountLine.fromJson(Map<String, dynamic> j) =>
      RecoveredCountLine(
          productId: _str(j['product_id']),
          productName: _str(j['product_name']),
          counted: _int(j['counted']),
          reason: _opt(j['reason']),
          note: _opt(j['note']));
}

class RecoveredCount {
  final String countId, businessDate, officeStatus;
  final String? stationKey;
  final DateTime? countedAt;
  final List<RecoveredCountLine> lines;
  const RecoveredCount(
      {required this.countId,
      required this.businessDate,
      required this.officeStatus,
      this.stationKey,
      this.countedAt,
      this.lines = const []});

  factory RecoveredCount.fromJson(Map<String, dynamic> j) => RecoveredCount(
          countId: _str(j['count_id']),
          businessDate: _str(j['business_date']),
          officeStatus: _opt(j['office_status']) ?? 'pending',
          stationKey: _opt(j['station_key']),
          countedAt: _time(j['counted_at']),
          lines: [
            for (final l in _rows(j['lines'])) RecoveredCountLine.fromJson(l)
          ]);
}

class VendorHistory {
  final String from, to;
  final List<RecoveredSale> sales;
  final List<RecoveredReceipt> receipts;
  final List<RecoveredDamage> damageReports;
  final List<RecoveredCount> closingCounts;

  /// Expense claims as `/vendor/expenses` returns them (the expense store
  /// keeps these rows as they are).
  final List<Map<String, dynamic>> expenses;
  const VendorHistory(
      {this.from = '',
      this.to = '',
      this.sales = const [],
      this.receipts = const [],
      this.damageReports = const [],
      this.closingCounts = const [],
      this.expenses = const []});

  factory VendorHistory.fromJson(Map<String, dynamic> j) => VendorHistory(
      from: _str(j['from']),
      to: _str(j['to']),
      sales: [for (final r in _rows(j['sales'])) RecoveredSale.fromJson(r)],
      receipts: [
        for (final r in _rows(j['receipts'])) RecoveredReceipt.fromJson(r)
      ],
      damageReports: [
        for (final r in _rows(j['damage_reports'])) RecoveredDamage.fromJson(r)
      ],
      closingCounts: [
        for (final r in _rows(j['closing_counts'])) RecoveredCount.fromJson(r)
      ],
      expenses: _rows(j['expenses']));
}

/// Optional (Phase 11): a server without it leaves the phone's history as is.
abstract interface class VendorHistoryRepository {
  /// [from] and [to] are business dates `yyyy-mm-dd`; at most 31 days.
  Future<VendorHistory> history(String token, {String? from, String? to});
}
