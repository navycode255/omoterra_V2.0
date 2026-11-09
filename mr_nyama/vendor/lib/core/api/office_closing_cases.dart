// Missed-closing cases (MN031): the days nobody counted, and the estimate or
// "not counted" case that explains one. A case is information; the server
// never turns it into a count, and the office never shows it as one.

String _str(Object? v) => v == null ? '' : '$v';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

class CasePerson {
  final String id, name;
  const CasePerson({required this.id, required this.name});
  static CasePerson? fromJson(Object? json) {
    if (json is! Map) return null;
    return CasePerson(id: _str(json['id']), name: _str(json['name']));
  }
}

class ClosingCaseLine {
  final String productCode, name, unit;
  final num estimated;
  const ClosingCaseLine(
      {required this.productCode,
      required this.name,
      required this.unit,
      required this.estimated});
  factory ClosingCaseLine.fromJson(Map<String, dynamic> j) => ClosingCaseLine(
      productCode: _str(j['product_code']),
      name: _str(j['name']),
      unit: _str(j['unit']),
      estimated: j['estimated'] is num
          ? j['estimated'] as num
          : num.tryParse(_str(j['estimated'])) ?? 0);
}

class ClosingCase {
  final String id, stationId, businessDate, outcome, status, basis;
  final CasePerson? openedBy, decidedBy;
  final DateTime? openedAt, decidedAt;
  final String? decisionReason;
  final bool openedByMe;
  final List<ClosingCaseLine> lines;
  const ClosingCase(
      {required this.id,
      required this.stationId,
      required this.businessDate,
      required this.outcome,
      required this.status,
      required this.basis,
      this.openedBy,
      this.decidedBy,
      this.openedAt,
      this.decidedAt,
      this.decisionReason,
      this.openedByMe = false,
      this.lines = const []});

  bool get isOpen => status == 'open';
  bool get isEstimate => outcome == 'estimate';

  factory ClosingCase.fromJson(Map<String, dynamic> j) => ClosingCase(
      id: _str(j['id']),
      stationId: _str(j['station_id']),
      businessDate: _str(j['business_date']),
      outcome: _str(j['outcome']),
      status: _str(j['status']),
      basis: _str(j['basis']),
      openedBy: CasePerson.fromJson(j['opened_by']),
      decidedBy: CasePerson.fromJson(j['decided_by']),
      openedAt: DateTime.tryParse(_str(j['opened_at'])),
      decidedAt: DateTime.tryParse(_str(j['decided_at'])),
      decisionReason: j['decision_reason'] as String?,
      openedByMe: j['opened_by_me'] == true,
      lines: [
        for (final l in j['lines'] as List? ?? const [])
          ClosingCaseLine.fromJson(_map(l))
      ]);
}

class MissedDayVendor {
  final String id, name;
  const MissedDayVendor({required this.id, required this.name});
}

/// A station-day with vendor activity and no count.
class MissedDay {
  final String stationId, stationName, businessDate;
  final List<MissedDayVendor> vendors;

  /// The live case, or the latest refused one; null when there is none.
  final ClosingCase? current;

  /// Older cases of the same day, newest first.
  final List<ClosingCase> history;
  const MissedDay(
      {required this.stationId,
      required this.stationName,
      required this.businessDate,
      required this.vendors,
      this.current,
      this.history = const []});

  /// A new case can be opened unless one is open or approved.
  bool get canOpen => current == null || current!.status == 'rejected';

  factory MissedDay.fromJson(Map<String, dynamic> j) {
    final station = _map(j['station']);
    return MissedDay(
        stationId: _str(station['id']),
        stationName: _str(station['name']),
        businessDate: _str(j['business_date']),
        vendors: [
          for (final v in j['vendors'] as List? ?? const [])
            MissedDayVendor(
                id: _str(_map(v)['id']), name: _str(_map(v)['name']))
        ],
        current: j['case'] == null ? null : ClosingCase.fromJson(_map(j['case'])),
        history: [
          for (final c in j['history'] as List? ?? const [])
            ClosingCase.fromJson(_map(c))
        ]);
  }
}

/// An estimated quantity of one product, by the product's code.
class CaseLineDraft {
  final String product;
  final int estimated;
  const CaseLineDraft(this.product, this.estimated);
  Map<String, Object> toJson() => {'product': product, 'estimated': estimated};
}

/// Approval was refused because the day still has sales to verify or damage
/// to decide. Nothing was decided.
class ClosingCaseBlocked implements Exception {
  final int unverifiedSales, pendingDamage;
  const ClosingCaseBlocked(
      {required this.unverifiedSales, required this.pendingDamage});
  @override
  String toString() =>
      'ClosingCaseBlocked($unverifiedSales sales, $pendingDamage damage)';
}

abstract interface class OfficeClosingCasesRepository {
  /// The missed days of one station, or of every station the person sees.
  Future<List<MissedDay>> missedDays({String? stationId});

  /// A retry with the same [clientId] returns the first case.
  Future<ClosingCase> openClosingCase(
      {required String clientId,
      required String stationId,
      required String businessDate,
      required String outcome,
      required String basis,
      List<CaseLineDraft> lines = const []});

  /// Throws [ClosingCaseBlocked] when an approval is refused for that reason.
  Future<ClosingCase> decideClosingCase(String id,
      {required bool approve, required String reason});
}
