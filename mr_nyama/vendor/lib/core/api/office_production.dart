// Recipes and production runs in the office. A recipe version is drafted by
// an operations admin or the owner and approved by the owner (never by its
// drafter); kitchen staff record runs against the version in force. Every
// yield, cost and variance is the server's; the app prefills no number.
// Money here is a decimal string ("71998.00") or null when cost is unknown.

import 'office_repository.dart' show StaffProfile;

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

num _num(Object? v) => switch (v) {
      num() => v,
      String() => num.tryParse(v) ?? 0,
      _ => 0,
    };

num? _numOrNull(Object? v) => switch (v) {
      num() => v,
      String() => num.tryParse(v),
      _ => null,
    };

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    [for (final r in v is List ? v : const []) _map(r)];

/// How a run's input cost is shared between its outputs.
enum AllocationMethod {
  weight('weight', 'unit_weight'),
  sellingValue('selling_value', 'unit_value'),
  fixedShares('fixed_shares', 'share_bps');

  final String wire;

  /// The per-output field this method needs.
  final String basisField;
  const AllocationMethod(this.wire, this.basisField);
  static AllocationMethod? parse(Object? v) =>
      values.where((m) => m.wire == v).firstOrNull;
}

class RecipeLine {
  final int line;
  final String product, name, unit;
  final num quantity;

  /// The basis for the version's method (weight, value or share in basis
  /// points); null on inputs.
  final num? basis;
  const RecipeLine(
      {this.line = 0,
      required this.product,
      required this.name,
      this.unit = '',
      required this.quantity,
      this.basis});
  factory RecipeLine.fromJson(Map<String, dynamic> j) => RecipeLine(
      line: _int(j['line']),
      product: _str(j['product']),
      name: _opt(j['name']) ?? _str(j['product']),
      unit: _str(j['unit']),
      quantity: _num(j['quantity']),
      basis: _numOrNull(j['unit_weight']) ??
          _numOrNull(j['unit_value']) ??
          _numOrNull(j['share_bps']));
}

class RecipeVersion {
  final String id, recipeId;
  final int version;
  final String status;
  final bool inForce;
  final AllocationMethod? method;
  final String wasteKind;
  final num wasteValue;
  final num maxOutputRatio;
  final DateTime? effectiveFrom, decidedAt, createdAt;
  final String reason, draftedBy;
  final String? decidedBy, decisionReason;
  final List<RecipeLine> inputs, outputs;
  const RecipeVersion(
      {required this.id,
      this.recipeId = '',
      required this.version,
      this.status = 'draft',
      this.inForce = false,
      this.method,
      this.wasteKind = 'quantity',
      this.wasteValue = 0,
      this.maxOutputRatio = 1,
      this.effectiveFrom,
      this.reason = '',
      this.draftedBy = '',
      this.decidedBy,
      this.decidedAt,
      this.decisionReason,
      this.createdAt,
      this.inputs = const [],
      this.outputs = const []});

  bool get draft => status == 'draft';
  bool get approved => status == 'approved';
  bool get rejected => status == 'rejected';

  /// The primary input (line 1); waste is in its unit.
  RecipeLine? get primaryInput => inputs.firstOrNull;

  factory RecipeVersion.fromJson(Map<String, dynamic> j) {
    final waste = _map(j['waste_allowance']);
    return RecipeVersion(
        id: _str(j['id']),
        recipeId: _str(j['recipe_id']),
        version: _int(j['version']),
        status: _opt(j['status']) ?? 'draft',
        inForce: j['in_force'] == true,
        method: AllocationMethod.parse(j['allocation_method']),
        wasteKind: _opt(waste['kind']) ?? 'quantity',
        wasteValue: _num(waste['value']),
        maxOutputRatio: _num(j['max_output_ratio']),
        effectiveFrom: _time(j['effective_from']),
        reason: _str(j['reason']),
        draftedBy: _str(j['drafted_by']),
        decidedBy: _opt(j['decided_by']),
        decidedAt: _time(j['decided_at']),
        decisionReason: _opt(j['decision_reason']),
        createdAt: _time(j['created_at']),
        inputs: [for (final l in _rows(j['inputs'])) RecipeLine.fromJson(l)],
        outputs: [for (final l in _rows(j['outputs'])) RecipeLine.fromJson(l)]);
  }
}

class OfficeRecipe {
  final String id, name, product, productName, createdBy;
  final DateTime? createdAt;
  final String? activeVersionId;
  final List<RecipeVersion> versions;
  const OfficeRecipe(
      {required this.id,
      required this.name,
      this.product = '',
      this.productName = '',
      this.createdBy = '',
      this.createdAt,
      this.activeVersionId,
      this.versions = const []});

  /// The approved version runs are recorded against now, if any.
  RecipeVersion? get inForce => versions.where((v) => v.inForce).firstOrNull;

  /// Newest first.
  List<RecipeVersion> get newestFirst =>
      [...versions]..sort((a, b) => b.version.compareTo(a.version));

  factory OfficeRecipe.fromJson(Map<String, dynamic> j) => OfficeRecipe(
          id: _str(j['id']),
          name: _str(j['name']),
          product: _str(j['product']),
          productName: _opt(j['product_name']) ?? _str(j['product']),
          createdBy: _str(j['created_by']),
          createdAt: _time(j['created_at']),
          activeVersionId: _opt(j['active_version_id']),
          versions: [
            for (final v in _rows(j['versions'])) RecipeVersion.fromJson(v)
          ]);
}

/// A recipe line to send: [quantity] is an int (whole units) or a decimal
/// string (kilograms); [basis] the value the method needs, or null.
class RecipeLineDraft {
  final String product;
  final Object quantity;
  final Object? basis;
  const RecipeLineDraft(this.product, this.quantity, [this.basis]);
}

/// Fixed shares are basis points that total exactly 10000 (100%).
const fullShareBps = 10000;

/// Percent text ("62.5") as basis points (6250); null when not a number
/// above 0 and at most 100 with at most two decimals.
int? percentToBps(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(t)) return null;
  final bps = (double.parse(t) * 100).round();
  return bps > 0 && bps <= fullShareBps ? bps : null;
}

/// A decimal quantity typed for kilograms ("1.5"); null when not a number
/// above zero with at most three decimals.
String? parseDecimalQuantity(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,7}(\.\d{1,3})?$').hasMatch(t)) return null;
  return double.parse(t) > 0 ? t : null;
}

class RunInputLine {
  final String kind, product, name, unit;
  final String? lotId;
  final num quantity;
  final num? unitCost, cost;
  const RunInputLine(
      {this.kind = 'input',
      required this.product,
      this.name = '',
      this.unit = '',
      this.lotId,
      required this.quantity,
      this.unitCost,
      this.cost});
  bool get waste => kind == 'waste';
  factory RunInputLine.fromJson(Map<String, dynamic> j) => RunInputLine(
      kind: _opt(j['kind']) ?? 'input',
      product: _str(j['product']),
      name: _str(j['name']),
      unit: _str(j['unit']),
      lotId: _opt(j['lot_id']),
      quantity: _num(j['quantity']),
      unitCost: _numOrNull(j['unit_cost']),
      cost: _numOrNull(j['cost']));
}

class RunOutputLot {
  final String lotId, costState;
  final num quantity;
  final num? unitCost;
  const RunOutputLot(
      {required this.lotId,
      required this.quantity,
      this.unitCost,
      this.costState = 'unknown'});
  factory RunOutputLot.fromJson(Map<String, dynamic> j) => RunOutputLot(
      lotId: _str(j['lot_id']),
      quantity: _num(j['quantity']),
      unitCost: _numOrNull(j['unit_cost']),
      costState: _opt(j['cost_state']) ?? 'unknown');
}

class RunOutputLine {
  final int line;
  final String product, name, unit;
  final num quantity;
  final num? expected, allocatedCost;
  final List<RunOutputLot> lots;
  const RunOutputLine(
      {this.line = 0,
      required this.product,
      required this.name,
      this.unit = '',
      required this.quantity,
      this.expected,
      this.allocatedCost,
      this.lots = const []});
  factory RunOutputLine.fromJson(Map<String, dynamic> j) => RunOutputLine(
      line: _int(j['line']),
      product: _str(j['product']),
      name: _opt(j['name']) ?? _str(j['product']),
      unit: _str(j['unit']),
      quantity: _num(j['quantity']),
      expected: _numOrNull(j['expected_quantity']),
      allocatedCost: _numOrNull(j['allocated_cost']),
      lots: [for (final l in _rows(j['lots'])) RunOutputLot.fromJson(l)]);
}

/// A recorded production run (`/staff/production-runs`).
class OfficeProductionRun {
  final String id, clientId, kitchenId, recipeId, recipeName, versionId;
  final int version;
  final AllocationMethod? method;
  final String operatorId;
  final DateTime? occurredAt, recordedAt;
  final num batches;
  final bool costKnown;
  final num? inputCost, abnormalLossCost;
  final num wasteQuantity, wasteAllowed, wasteAbnormal;
  final bool variance;
  final String? exceptionId, note;
  final List<RunInputLine> inputs;
  final List<RunOutputLine> outputs;
  const OfficeProductionRun(
      {required this.id,
      this.clientId = '',
      this.kitchenId = '',
      this.recipeId = '',
      this.recipeName = '',
      this.versionId = '',
      this.version = 0,
      this.method,
      this.operatorId = '',
      this.occurredAt,
      this.recordedAt,
      this.batches = 0,
      this.costKnown = false,
      this.inputCost,
      this.abnormalLossCost,
      this.wasteQuantity = 0,
      this.wasteAllowed = 0,
      this.wasteAbnormal = 0,
      this.variance = false,
      this.exceptionId,
      this.note,
      this.inputs = const [],
      this.outputs = const []});

  factory OfficeProductionRun.fromJson(Map<String, dynamic> j) {
    final waste = _map(j['waste']);
    return OfficeProductionRun(
        id: _str(j['id']),
        clientId: _str(j['client_id']),
        kitchenId: _str(j['kitchen_location_id']),
        recipeId: _str(j['recipe_id']),
        recipeName: _str(j['recipe_name']),
        versionId: _str(j['recipe_version_id']),
        version: _int(j['version']),
        method: AllocationMethod.parse(j['allocation_method']),
        operatorId: _str(j['operator_id']),
        occurredAt: _time(j['occurred_at']),
        recordedAt: _time(j['recorded_at']),
        batches: _num(j['batches']),
        costKnown: j['cost_state'] == 'known',
        inputCost: _numOrNull(j['input_cost']),
        abnormalLossCost: _numOrNull(j['abnormal_loss_cost']),
        wasteQuantity: _num(waste['quantity']),
        wasteAllowed: _num(waste['allowed']),
        wasteAbnormal: _num(waste['abnormal_quantity']),
        variance: j['variance'] == true,
        exceptionId: _opt(j['exception_id']),
        note: _opt(j['note']),
        inputs: [
          for (final l in _rows(j['inputs'])) RunInputLine.fromJson(l)
        ],
        outputs: [
          for (final l in _rows(j['outputs'])) RunOutputLine.fromJson(l)
        ]);
  }
}

/// Recipe and production calls; implemented by the HTTP office repository.
abstract interface class OfficeProductionRepository {
  /// The signed-in person as the server sees them now (`GET /staff/me`),
  /// including the kitchens on their kitchen-staff grants.
  Future<StaffProfile> staffMe();
  Future<List<OfficeRecipe>> recipes();
  Future<OfficeRecipe> recipe(String id);
  Future<OfficeRecipe> createRecipe(
      {required String name, required String product, required String reason});

  /// [inputs] line 1 is the primary input. [wasteValue] and [maxOutputRatio]
  /// are sent as typed (decimal strings).
  Future<RecipeVersion> draftVersion(String recipeId,
      {required List<RecipeLineDraft> inputs,
      required List<RecipeLineDraft> outputs,
      required AllocationMethod method,
      required String wasteKind,
      required String wasteValue,
      required String maxOutputRatio,
      required String reason});

  /// Owner only, and never on a version they drafted.
  Future<RecipeVersion> decideVersion(String versionId,
      {required bool approve, required String reason});
  Future<OfficeProductionRun> recordRun(
      {required String clientId,
      required String kitchenId,
      required String versionId,
      required List<RecipeLineDraft> inputs,
      required List<RecipeLineDraft> outputs,
      required Object wasteQuantity,
      DateTime? occurredAt,
      String? note});
  Future<List<OfficeProductionRun>> productionRuns(
      {String? kitchenId, String? from, String? to});
  Future<OfficeProductionRun> productionRun(String id);
}
