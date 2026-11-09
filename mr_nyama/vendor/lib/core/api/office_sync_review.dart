// Office review of phone records the server kept as conflicts (MN014): the
// list, retry and reject, and the past station day that fixes a record made
// before the vendor had a station. The server decides every outcome; the
// office only shows what it answers.

String _str(Object? v) => v == null ? '' : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

class OfficeConflictStation {
  final String id, code, name;
  const OfficeConflictStation(
      {required this.id, required this.code, required this.name});

  static OfficeConflictStation? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = _map(json);
    return OfficeConflictStation(
        id: _str(m['id']), code: _str(m['code']), name: _str(m['name']));
  }
}

class OfficeConflictSaleLine {
  final String productKey;
  final String? name;
  final int quantity, unitPrice;
  const OfficeConflictSaleLine(
      {required this.productKey,
      this.name,
      required this.quantity,
      required this.unitPrice});
}

class OfficeConflictSale {
  final DateTime? recordedAt;
  final String paymentMethod;
  final List<OfficeConflictSaleLine> lines;
  final int total;
  const OfficeConflictSale(
      {this.recordedAt,
      required this.paymentMethod,
      required this.lines,
      required this.total});

  static OfficeConflictSale? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = _map(json);
    return OfficeConflictSale(
        recordedAt: _time(m['recorded_at']),
        paymentMethod: _str(m['payment_method']),
        total: _int(m['total']),
        lines: [
          for (final l in m['lines'] is List ? m['lines'] as List : const [])
            OfficeConflictSaleLine(
                productKey: _str(_map(l)['product_key']),
                name: _map(l)['name'] as String?,
                quantity: _int(_map(l)['quantity']),
                unitPrice: _int(_map(l)['unit_price']))
        ]);
  }
}

class OfficeConflictReview {
  final String action, reason, resultStatus, decidedBy;
  final String? resultReason;
  final DateTime? decidedAt;
  const OfficeConflictReview(
      {required this.action,
      required this.reason,
      required this.resultStatus,
      this.resultReason,
      required this.decidedBy,
      this.decidedAt});
}

/// One record waiting for the office: what the phone sent and why the
/// server kept it.
class OfficeSyncConflict {
  final String opId, opType;

  /// The server's reason, such as `not_assigned` or `wrong_station`.
  final String reason;
  final String vendorId, vendorCode, vendorName;

  /// Where the phone said it was, and the vendor's station now.
  final OfficeConflictStation? station, vendorStation;

  /// `YYYY-MM-DD`, as the phone recorded it.
  final String? businessDate;
  final DateTime? phoneCreatedAt, receivedAt;
  final OfficeConflictSale? sale;
  final List<OfficeConflictReview> reviews;

  const OfficeSyncConflict(
      {required this.opId,
      required this.opType,
      required this.reason,
      required this.vendorId,
      required this.vendorCode,
      required this.vendorName,
      this.station,
      this.vendorStation,
      this.businessDate,
      this.phoneCreatedAt,
      this.receivedAt,
      this.sale,
      this.reviews = const []});

  factory OfficeSyncConflict.fromJson(Map<String, dynamic> m) {
    final vendor = _map(m['vendor']);
    return OfficeSyncConflict(
        opId: _str(m['op_id']),
        opType: _str(m['op_type']),
        reason: _str(m['reason']),
        vendorId: _str(vendor['id']),
        vendorCode: _str(vendor['code']),
        vendorName: _str(vendor['name']),
        station: OfficeConflictStation.fromJson(m['station']),
        vendorStation: OfficeConflictStation.fromJson(m['vendor_station']),
        businessDate: m['business_date'] as String?,
        phoneCreatedAt: _time(m['phone_created_at']),
        receivedAt: _time(m['received_at']),
        sale: OfficeConflictSale.fromJson(m['sale']),
        reviews: [
          for (final r
              in m['reviews'] is List ? m['reviews'] as List : const [])
            OfficeConflictReview(
                action: _str(_map(r)['action']),
                reason: _str(_map(r)['reason']),
                resultStatus: _str(_map(r)['result_status']),
                resultReason: _map(r)['result_reason'] as String?,
                decidedBy: _str(_map(r)['decided_by']),
                decidedAt: _time(_map(r)['decided_at']))
        ]);
  }

  /// The station a past station day would use: where the phone said it
  /// was, else the vendor's station now.
  OfficeConflictStation? get suggestedStation => station ?? vendorStation;
}

/// The server's answer to a review.
class OfficeConflictOutcome {
  /// `accepted`, `conflict` (still waiting) or `rejected`.
  final String status;
  final String? reason;
  const OfficeConflictOutcome(this.status, this.reason);

  factory OfficeConflictOutcome.fromJson(Map<String, dynamic> m) =>
      OfficeConflictOutcome(
          _str(m['result_status']), m['result_reason'] as String?);
}

abstract interface class OfficeSyncReviewRepository {
  /// Records whose current decision is a conflict, oldest first.
  Future<List<OfficeSyncConflict>> syncConflicts();

  /// Decides the stored record again (after its cause was fixed).
  Future<OfficeConflictOutcome> retryConflict(String opId,
      {required String reason});

  /// Refuses the record for good; it is not recorded.
  Future<OfficeConflictOutcome> rejectConflict(String opId,
      {required String reason});

  /// Records that the vendor worked at [stationId] on a past
  /// [businessDate] (`YYYY-MM-DD`) when no station covered that day.
  Future<void> assignVendorPastDay(
      {required String vendorId,
      required String stationId,
      required String businessDate,
      required String reason});
}
