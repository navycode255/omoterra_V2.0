/// Resolving problems by approval tier, and the owner's thresholds and alert
/// settings (MN027, business policies §1 and §11).
class ApprovalItem {
  final String id, kind, resolution, reason, requestedBy;
  final String? station, vendor;
  final int tier;
  final int? value, countedValue;
  final bool canDecide;
  const ApprovalItem(
      {required this.id,
      required this.kind,
      required this.resolution,
      required this.reason,
      required this.requestedBy,
      required this.tier,
      required this.canDecide,
      this.station,
      this.vendor,
      this.value,
      this.countedValue});

  factory ApprovalItem.fromJson(Map<String, dynamic> j) => ApprovalItem(
      id: j['id'] as String,
      kind: j['kind'] as String,
      resolution: j['resolution'] as String,
      reason: j['reason'] as String? ?? '',
      requestedBy: j['requested_by'] as String? ?? '',
      tier: (j['tier'] as num).toInt(),
      canDecide: j['can_decide'] as bool? ?? false,
      station: j['station'] as String?,
      vendor: j['vendor'] as String?,
      value: (j['value'] as num?)?.toInt(),
      countedValue: (j['counted_value'] as num?)?.toInt());
}

/// What resolving did: settled now, or sent to the tier's approver.
class ResolveResult {
  final bool resolved;
  final int tier;
  const ResolveResult({required this.resolved, required this.tier});
}

/// The owner's Phase 13 settings. A null value is unset: that alert is off,
/// and an unset threshold sends its band up a tier.
class AlertSettings {
  static const supervisorLimit = 'threshold.supervisor';
  static const financeLimit = 'threshold.finance_officer';
  static const managerLimit = 'threshold.finance_manager';
  static const approvers = 'approval.independent_approvers';
  static const closingDue = 'alerts.closing_due_time';
  static const silentMinutes = 'alerts.silent_phone_minutes';
  static const lowSales = 'alerts.low_sales';
  static const summaryTime = 'alerts.owner_summary_time';
  static const supervisorSms = 'alerts.supervisor_sms';
  static const escalation = 'escalation.after_hours';

  final Map<String, dynamic> values;
  const AlertSettings(this.values);

  int? number(String key) => (values[key] as num?)?.toInt();
  String? clock(String key) => values[key] as String?;
  bool get smsOn => values[supervisorSms] == true;
  List<String> get approverIds =>
      [for (final id in values[approvers] as List? ?? const []) '$id'];
  int? get lowSalesShare =>
      ((values[lowSales] as Map?)?['share_percent'] as num?)?.toInt();
  String? get lowSalesTime =>
      (values[lowSales] as Map?)?['check_time'] as String?;
  int? escalationHours(String severity) =>
      ((values[escalation] as Map?)?[severity] as num?)?.toInt();
}

abstract interface class OfficeApprovalsRepository {
  Future<ResolveResult> resolveException(String id,
      {required String resolution, required String reason});
  Future<List<ApprovalItem>> approvals();
  Future<void> decideApproval(String id,
      {required bool approve, required String reason});
  Future<AlertSettings> alertSettings();

  /// A null [value] unsets it.
  Future<void> saveAlertSetting(String key,
      {required Object? value, required String reason});
}
