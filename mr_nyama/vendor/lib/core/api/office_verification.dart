// What the office verifies: vendor sales, damage reports and Funga Siku
// closing counts, with the open problems the server raised. Parsing is
// null-safe so a field the server leaves out never breaks the screen; the
// server stays the only judge of what is verified.

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

/// Quantities are whole units except kilograms, which the server may send
/// as a decimal string.
num _num(Object? v) => switch (v) {
      num() => v,
      String() => num.tryParse(v) ?? 0,
      _ => 0,
    };

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `YYYY-MM-DD` (a business date) as a date-only value.
DateTime? _day(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    [for (final r in v is List ? v : const []) _map(r)];

/// One station and what is waiting there (`GET /staff/verification`).
class OfficeVerificationStation {
  final String id, code, name;
  final int pendingSales, pendingSalesAmount;
  final int reportedDamage, recordedClosings, openExceptions;
  final DateTime? oldestPendingDate;

  /// Live automatic checks made today: verified, and held and still waiting.
  final int autoVerifiedToday, heldToday;
  const OfficeVerificationStation(
      {required this.id,
      required this.code,
      required this.name,
      this.pendingSales = 0,
      this.pendingSalesAmount = 0,
      this.reportedDamage = 0,
      this.recordedClosings = 0,
      this.openExceptions = 0,
      this.oldestPendingDate,
      this.autoVerifiedToday = 0,
      this.heldToday = 0});

  bool get hasWork =>
      pendingSales > 0 ||
      reportedDamage > 0 ||
      recordedClosings > 0 ||
      openExceptions > 0;

  factory OfficeVerificationStation.fromJson(Map<String, dynamic> j) {
    final station = _map(j['station']);
    return OfficeVerificationStation(
        id: _str(station['id']),
        code: _str(station['code']),
        name: _str(station['name']),
        pendingSales: _int(j['pending_sales']),
        pendingSalesAmount: _int(j['pending_sales_amount']),
        reportedDamage: _int(j['reported_damage']),
        recordedClosings: _int(j['recorded_closings']),
        openExceptions: _int(j['open_exceptions']),
        oldestPendingDate: _day(j['oldest_pending_date']),
        autoVerifiedToday: _int(j['auto_verified_today']),
        heldToday: _int(j['held_today']));
  }
}

class OfficeSaleLine {
  final String productCode, name;
  final num quantity;
  final int unitPrice, amount;
  const OfficeSaleLine(
      {required this.productCode,
      required this.name,
      required this.quantity,
      required this.unitPrice,
      required this.amount});

  factory OfficeSaleLine.fromJson(Map<String, dynamic> j) => OfficeSaleLine(
      productCode: _str(j['product_code']),
      name: _str(j['name']),
      quantity: _num(j['quantity']),
      unitPrice: _int(j['unit_price']),
      amount: _int(j['amount']));
}

/// One automatic check of a sale (MN033). `shadow` verified nothing.
class OfficeAutoCheck {
  final String mode, result;
  final List<String> reasons;
  const OfficeAutoCheck(
      {required this.mode, required this.result, this.reasons = const []});

  static OfficeAutoCheck? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = _map(v);
    return OfficeAutoCheck(
        mode: _str(j['mode']),
        result: _str(j['result']),
        reasons: [
          for (final r
              in j['reasons'] is List ? j['reasons'] as List : const [])
            '$r'
        ]);
  }
}

/// What a trial of automatic verification found over a period
/// (`GET /owner/auto-verify/summary`): the owner's evidence for going live.
class OfficeShadowSummary {
  final int checked, wouldPass, wouldHold, staffVerifiedWouldHold, unchecked;
  final Map<String, int> heldByReason;
  const OfficeShadowSummary(
      {this.checked = 0,
      this.wouldPass = 0,
      this.wouldHold = 0,
      this.staffVerifiedWouldHold = 0,
      this.unchecked = 0,
      this.heldByReason = const {}});

  factory OfficeShadowSummary.fromJson(Map<String, dynamic> j) =>
      OfficeShadowSummary(
          checked: _int(j['checked']),
          wouldPass: _int(j['would_pass']),
          wouldHold: _int(j['would_hold']),
          staffVerifiedWouldHold: _int(j['staff_verified_would_hold']),
          unchecked: _int(j['unchecked']),
          heldByReason: {
            for (final MapEntry(:key, :value)
                in _map(j['held_by_reason']).entries)
              key: _int(value)
          });
}

abstract interface class OfficeAutoVerifyRepository {
  /// A station's sales the system verified, for the list kept apart.
  Future<List<OfficeSale>> autoVerifiedSales(String stationId);

  /// Owner only. [from] and [to] are business dates, `YYYY-MM-DD`.
  Future<OfficeShadowSummary> autoVerifySummary(
      {required String from, required String to});
}

/// One sale as the server recorded it (`GET /staff/sales`). [saleId] is
/// the server id that verification names; [clientId] is the phone's id.
class OfficeSale {
  final String saleId, clientId, vendorId, vendorName;
  final String? vendorCode;
  final DateTime? businessDate, recordedAt;
  final String payment, status;
  final int amount;
  final bool voided;
  final List<OfficeSaleLine> lines;

  /// The server's one-line summary, for a sale sent without lines.
  final String product;
  final num quantity;

  /// A credit sale's customer (MN018).
  final String? customer;

  /// `staff` or `auto` once verified (MN033).
  final String? verificationMethod;
  final OfficeAutoCheck? autoCheck;

  /// An open request to cancel this sale (MN034); the sale waits for it.
  final String? cancelRequestId;

  /// The office entered this sale after a lost phone (MN036): who asked, who allowed.
  final String? enteredBy, enteredAllowedBy;
  bool get officeEntered => enteredBy != null;

  /// The signed-in person asked for this office entry: someone else verifies it.
  final bool enteredByMe;
  const OfficeSale(
      {required this.saleId,
      this.clientId = '',
      required this.vendorId,
      required this.vendorName,
      this.vendorCode,
      this.businessDate,
      this.recordedAt,
      this.payment = '',
      required this.amount,
      this.status = 'reported',
      this.voided = false,
      this.lines = const [],
      this.product = '',
      this.quantity = 0,
      this.customer,
      this.verificationMethod,
      this.autoCheck,
      this.cancelRequestId,
      this.enteredBy,
      this.enteredAllowedBy,
      this.enteredByMe = false});

  bool get verified => status == 'verified';
  bool get autoVerified => verificationMethod == 'auto';

  /// Waiting for a person because a live check held it. A trial's check
  /// holds nothing, so it is never shown as held.
  bool get heldForReview =>
      !verified &&
      !voided &&
      autoCheck?.mode == 'live' &&
      autoCheck?.result == 'held';

  /// Voided and already verified sales are never sent for verification.
  bool get selectable =>
      !voided &&
      !verified &&
      saleId.isNotEmpty &&
      cancelRequestId == null &&
      !enteredByMe;

  /// Staff may ask for the office to cancel a reported sale not already waiting.
  bool get cancellable =>
      !voided && !verified && saleId.isNotEmpty && cancelRequestId == null;

  factory OfficeSale.fromJson(Map<String, dynamic> j) => OfficeSale(
      saleId: _str(j['sale_id']),
      clientId: _str(j['id']),
      vendorId: _str(j['vendor_id']),
      vendorName: _str(j['vendor_name']),
      vendorCode: _opt(j['vendor_code']),
      businessDate: _day(j['business_date']),
      recordedAt: _time(j['recorded_at']),
      payment: _str(j['payment']),
      amount: _int(j['amount']),
      status: _opt(j['status']) ?? 'reported',
      voided: j['voided'] == true,
      lines: [for (final l in _rows(j['lines'])) OfficeSaleLine.fromJson(l)],
      product: _str(j['product']),
      quantity: _num(j['quantity']),
      customer: _opt(j['customer']),
      verificationMethod: _opt(j['verification_method']),
      autoCheck: OfficeAutoCheck.fromJson(j['auto_check']),
      cancelRequestId: _opt(j['cancel_request_id']),
      enteredBy: j['office_entry'] is Map
          ? _str((j['office_entry'] as Map)['requested_by'])
          : null,
      enteredAllowedBy: j['office_entry'] is Map
          ? _str((j['office_entry'] as Map)['decided_by'])
          : null,
      enteredByMe: j['office_entry'] is Map &&
          (j['office_entry'] as Map)['requested_by_me'] == true);
}

/// A vendor's damage report (`GET /staff/damage-reports`). Not a loss until
/// staff approve it.
class OfficeDamageReport {
  final String id, reportId, vendorId, vendorName;
  final String stationId, stationName;
  final String productId, productCode, productName, unit;
  final num quantity;
  final String reason;
  final String? note;
  final String? imageUrl;
  final DateTime? reportedAt;
  final String status;
  final num? shortfall;
  final String? decidedBy, decisionReason;
  final DateTime? decidedAt;
  const OfficeDamageReport(
      {required this.id,
      this.reportId = '',
      this.vendorId = '',
      required this.vendorName,
      this.stationId = '',
      this.stationName = '',
      this.productId = '',
      this.productCode = '',
      required this.productName,
      this.unit = '',
      required this.quantity,
      this.reason = '',
      this.note,
      this.imageUrl,
      this.reportedAt,
      this.status = 'reported',
      this.shortfall,
      this.decidedBy,
      this.decidedAt,
      this.decisionReason});

  bool get pending => status == 'reported';

  factory OfficeDamageReport.fromJson(Map<String, dynamic> j) =>
      OfficeDamageReport(
          id: _str(j['id']),
          reportId: _str(j['report_id']),
          vendorId: _str(j['vendor_id']),
          vendorName: _str(j['vendor_name']),
          stationId: _str(j['station_id']),
          stationName: _str(j['station_name']),
          productId: _str(j['product_id']),
          productCode: _str(j['product_code']),
          productName: _opt(j['product_name']) ?? _str(j['product_code']),
          unit: _str(j['unit']),
          quantity: _num(j['quantity']),
          reason: _str(j['reason']),
          note: _opt(j['note']),
          imageUrl: _opt(j['image_url']),
          reportedAt: _time(j['reported_at']),
          status: _opt(j['status']) ?? 'reported',
          shortfall: j['shortfall'] == null ? null : _num(j['shortfall']),
          decidedBy: _opt(j['decided_by']),
          decidedAt: _time(j['decided_at']),
          decisionReason: _opt(j['decision_reason']));
}

class OfficeClosingLine {
  final String productId, productCode, name;
  final num expected, counted, difference;
  const OfficeClosingLine(
      {this.productId = '',
      this.productCode = '',
      required this.name,
      required this.expected,
      required this.counted,
      required this.difference});

  factory OfficeClosingLine.fromJson(Map<String, dynamic> j) =>
      OfficeClosingLine(
          productId: _str(j['product_id']),
          productCode: _str(j['product_code']),
          name: _opt(j['name']) ?? _str(j['product_code']),
          expected: _num(j['expected']),
          counted: _num(j['counted']),
          difference: _num(j['difference']));
}

/// What the vendor counted, before the office fixes the results.
class OfficeCountedLine {
  final String productId, productCode, name;
  final num counted;
  const OfficeCountedLine(
      {this.productId = '',
      this.productCode = '',
      required this.name,
      required this.counted});

  factory OfficeCountedLine.fromJson(Map<String, dynamic> j) =>
      OfficeCountedLine(
          productId: _str(j['product_id']),
          productCode: _str(j['product_code']),
          name: _opt(j['name']) ?? _str(j['product_code']),
          counted: _num(j['counted']));
}

/// A Funga Siku closing count (`GET /staff/closing-counts`). The server
/// refuses to confirm it while [unverifiedSales] or [pendingDamage] remain.
/// Until it is confirmed only [countedLines] exist; expected, counted and
/// difference ([lines]) are fixed by the server on confirmation.
class OfficeClosingCount {
  final String id, countId, vendorId, vendorName;
  final String stationId, stationName;
  final DateTime? businessDate;
  final String status;
  final String? result;
  final List<OfficeClosingLine> lines;
  final List<OfficeCountedLine> countedLines;
  final int unverifiedSales, pendingDamage;

  /// 1 while the previous business day at this station is not reconciled.
  final int previousDayUnreconciled;
  const OfficeClosingCount(
      {required this.id,
      this.countId = '',
      this.vendorId = '',
      required this.vendorName,
      this.stationId = '',
      this.stationName = '',
      this.businessDate,
      this.status = 'recorded',
      this.result,
      this.lines = const [],
      this.countedLines = const [],
      this.unverifiedSales = 0,
      this.pendingDamage = 0,
      this.previousDayUnreconciled = 0});

  bool get confirmed => status == 'confirmed';
  bool get blocked =>
      unverifiedSales > 0 || pendingDamage > 0 || previousDayUnreconciled > 0;

  factory OfficeClosingCount.fromJson(Map<String, dynamic> j) {
    final blockers = _map(j['blockers']);
    return OfficeClosingCount(
        id: _str(j['id']),
        countId: _str(j['count_id']),
        vendorId: _str(j['vendor_id']),
        vendorName: _str(j['vendor_name']),
        stationId: _str(j['station_id']),
        stationName: _str(j['station_name']),
        businessDate: _day(j['business_date']),
        status: _opt(j['status']) ?? 'recorded',
        result: _opt(j['result']),
        lines: [
          for (final l in _rows(j['lines'])) OfficeClosingLine.fromJson(l)
        ],
        countedLines: [
          for (final l in _rows(j['counted_lines']))
            OfficeCountedLine.fromJson(l)
        ],
        unverifiedSales: _int(blockers['unverified_sales']),
        pendingDamage: _int(blockers['pending_damage']),
        previousDayUnreconciled: _int(blockers['previous_day_unreconciled']));
  }
}

/// A problem the server opened (`GET /staff/exceptions`). Read-only here.
class OfficeException {
  final String id, kind, severity, status;
  final String? stationId, stationName, vendorId, vendorName;
  final String? productId, productName;
  final String sourceType, sourceId;
  final Map<String, dynamic> detail;
  final DateTime? openedAt, resolvedAt;
  final String? resolution, resolutionReason;

  /// How staff may resolve it here; empty when it has its own screen.
  final List<String> resolutions;
  const OfficeException(
      {required this.id,
      required this.kind,
      this.severity = 'warning',
      this.status = 'open',
      this.stationId,
      this.stationName,
      this.vendorId,
      this.vendorName,
      this.productId,
      this.productName,
      this.sourceType = '',
      this.sourceId = '',
      this.detail = const {},
      this.openedAt,
      this.resolvedAt,
      this.resolution,
      this.resolutionReason,
      this.resolutions = const []});

  factory OfficeException.fromJson(Map<String, dynamic> j) => OfficeException(
      id: _str(j['id']),
      kind: _str(j['kind']),
      resolutions: [
        for (final r in j['resolutions'] as List? ?? const []) '$r'
      ],
      severity: _opt(j['severity']) ?? 'warning',
      status: _opt(j['status']) ?? 'open',
      stationId: _opt(j['station_id']),
      stationName: _opt(j['station_name']),
      vendorId: _opt(j['vendor_id']),
      vendorName: _opt(j['vendor_name']),
      productId: _opt(j['product_id']),
      productName: _opt(j['product_name']),
      sourceType: _str(j['source_type']),
      sourceId: _str(j['source_id']),
      detail: _map(j['detail']),
      openedAt: _time(j['opened_at']),
      resolvedAt: _time(j['resolved_at']),
      resolution: _opt(j['resolution']),
      resolutionReason: _opt(j['resolution_reason']));
}

/// Parses a list response; anything that is not a JSON object is skipped.
List<T> parseRows<T>(List<dynamic> rows, T Function(Map<String, dynamic>) f) =>
    [
      for (final r in rows)
        if (r is Map) f(Map<String, dynamic>.from(r))
    ];
