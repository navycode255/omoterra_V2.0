// Vendor bonuses for the owner (Phase 7 server, Phase 9 screens): earned on
// locked days, estimated on the others (never paid), adjustments; the owner's
// correction of a verified sale; and the bonus and score settings. The
// server computes every figure; payments go through vendor pay.

import 'office_money.dart' show MoneyParty;

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

int? _intOrNull(Object? v) => v == null ? null : _int(v);

num _num(Object? v) => switch (v) {
      num() => v,
      String() => num.tryParse(v) ?? 0,
      _ => 0,
    };

DateTime? _day(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? [
        for (final r in v)
          if (r is Map) Map<String, dynamic>.from(r)
      ]
    : const [];

/// One vendor-day's bonus.
class OwnerBonusDay {
  final String vendorDayId;
  final DateTime? businessDate;
  final MoneyParty? station;
  final bool locked;
  final num chickens;
  final int chickenBonus, profitBonus, adjustments, vendorsSharing;
  final int? profit;
  final bool usedStandardCost, profitKnown;
  const OwnerBonusDay(
      {this.vendorDayId = '',
      this.businessDate,
      this.station,
      this.locked = false,
      this.chickens = 0,
      this.chickenBonus = 0,
      this.profitBonus = 0,
      this.adjustments = 0,
      this.vendorsSharing = 1,
      this.profit,
      this.usedStandardCost = false,
      this.profitKnown = true});

  int get total => chickenBonus + profitBonus;
  bool get shared => vendorsSharing > 1;

  factory OwnerBonusDay.fromJson(Map<String, dynamic> j) => OwnerBonusDay(
      vendorDayId: _str(j['vendor_day_id']),
      businessDate: _day(j['business_date']),
      station: MoneyParty.fromJson(j['station']),
      locked: j['locked'] == true,
      chickens: _num(j['chicken_equivalents']),
      chickenBonus: _int(j['chicken_bonus']),
      profitBonus: _int(j['profit_bonus']),
      adjustments: _int(j['adjustments']),
      vendorsSharing: _intOrNull(j['vendors_sharing']) ?? 1,
      profit: _intOrNull(j['profit']),
      usedStandardCost: j['used_standard_cost'] == true,
      profitKnown: j['profit_known'] != false);
}

/// One vendor's bonuses in a period.
class OwnerVendorBonus {
  final MoneyParty vendor;
  final DateTime? from, to;
  final int earned, estimated, adjustments;
  final num chickens;
  final List<OwnerBonusDay> days;
  const OwnerVendorBonus(
      {required this.vendor,
      this.from,
      this.to,
      this.earned = 0,
      this.estimated = 0,
      this.adjustments = 0,
      this.chickens = 0,
      this.days = const []});

  factory OwnerVendorBonus.fromJson(Map<String, dynamic> j) => OwnerVendorBonus(
      vendor: MoneyParty.fromJson(j['vendor']) ??
          const MoneyParty(id: '', name: ''),
      from: _day(j['from']),
      to: _day(j['to']),
      earned: _int(j['earned']),
      estimated: _int(j['estimated']),
      adjustments: _int(j['adjustments']),
      chickens: _num(j['chicken_equivalents']),
      days: [for (final d in _rows(j['days'])) OwnerBonusDay.fromJson(d)]);
}

/// Every vendor's bonuses in a period (`GET /owner/bonuses`).
class OwnerBonusPeriod {
  final String period;
  final DateTime? from, to;
  final int earned, estimated, adjustments;
  final List<OwnerVendorBonus> vendors;
  const OwnerBonusPeriod(
      {this.period = 'week',
      this.from,
      this.to,
      this.earned = 0,
      this.estimated = 0,
      this.adjustments = 0,
      this.vendors = const []});

  factory OwnerBonusPeriod.fromJson(Map<String, dynamic> j) => OwnerBonusPeriod(
          period: _opt(j['period']) ?? 'week',
          from: _day(j['from']),
          to: _day(j['to']),
          earned: _int(j['earned']),
          estimated: _int(j['estimated']),
          adjustments: _int(j['adjustments']),
          vendors: [
            for (final v in _rows(j['vendors'])) OwnerVendorBonus.fromJson(v)
          ]);
}

/// One cumulative chicken step: reaching [at] chickens adds [amount].
class ChickenStep {
  final int at, amount;
  const ChickenStep(this.at, this.amount);
  Map<String, Object> toJson() => {'at': at, 'amount': amount};
}

/// `bonus.chicken`.
class ChickenRulesSetting {
  final int target, perExtra;
  final List<ChickenStep> steps;
  const ChickenRulesSetting(
      {required this.target, required this.steps, required this.perExtra});

  static ChickenRulesSetting? fromJson(Object? v) {
    if (v is! Map) return null;
    return ChickenRulesSetting(
        target: _int(v['target']),
        perExtra: _int(v['per_extra']),
        steps: [
          for (final s in _rows(v['steps']))
            ChickenStep(_int(s['at']), _int(s['amount']))
        ]);
  }

  Map<String, Object> toJson() => {
        'target': target,
        'steps': [for (final s in steps) s.toJson()],
        'per_extra': perExtra,
      };
}

/// `bonus.profit`.
class ProfitRulesSetting {
  final int defaultTarget;
  final String sharePercent;
  final Map<String, int> stationTargets;
  const ProfitRulesSetting(
      {required this.defaultTarget,
      required this.sharePercent,
      this.stationTargets = const {}});

  static ProfitRulesSetting? fromJson(Object? v) {
    if (v is! Map) return null;
    final targets = v['station_targets'];
    return ProfitRulesSetting(
        defaultTarget: _int(v['default_target']),
        sharePercent: _str(v['share_percent']),
        stationTargets: {
          if (targets is Map)
            for (final e in targets.entries) '${e.key}': _int(e.value)
        });
  }

  Map<String, Object> toJson() => {
        'default_target': defaultTarget,
        'share_percent': sharePercent,
        'station_targets': stationTargets,
      };
}

/// The owner's bonus, cost and score settings (`GET /admin/settings`). Null
/// means not set: nothing is invented.
class OwnerPerformanceSettings {
  static const chickenKey = 'bonus.chicken';
  static const equivalentsKey = 'bonus.chicken_equivalents';
  static const profitKey = 'bonus.profit';
  static const payPeriodKey = 'bonus.pay_period';
  static const standardCostKey = 'cost.standard';
  static const vendorWeightsKey = 'score.weights.vendor';
  static const supervisorWeightsKey = 'score.weights.supervisor';
  static const managerWeightsKey = 'score.weights.manager';

  /// The areas each score card weighs (backend `WEIGHT_AREAS`), in order.
  static const weightAreas = {
    vendorWeightsKey: ['sales', 'money', 'stock', 'discipline', 'conduct'],
    supervisorWeightsKey: ['stations', 'speed', 'problems', 'money', 'rating'],
    managerWeightsKey: ['on_time', 'open_items', 'rating'],
  };

  final ChickenRulesSetting? chicken;
  final Map<String, String>? equivalents;
  final ProfitRulesSetting? profit;
  final String? payPeriod;
  final Map<String, int>? standardCost;
  final Map<String, Map<String, int>?> weights;
  const OwnerPerformanceSettings(
      {this.chicken,
      this.equivalents,
      this.profit,
      this.payPeriod,
      this.standardCost,
      this.weights = const {}});

  factory OwnerPerformanceSettings.fromJson(Map<String, dynamic> j) {
    Map<String, int>? ints(Object? v) => v is Map
        ? {for (final e in v.entries) '${e.key}': _int(e.value)}
        : null;
    final eq = j[equivalentsKey];
    final period = j[payPeriodKey];
    return OwnerPerformanceSettings(
        chicken: ChickenRulesSetting.fromJson(j[chickenKey]),
        equivalents: eq is Map
            ? {for (final e in eq.entries) '${e.key}': _str(e.value)}
            : null,
        profit: ProfitRulesSetting.fromJson(j[profitKey]),
        payPeriod: period is String ? period : null,
        standardCost: ints(j[standardCostKey]),
        weights: {for (final k in weightAreas.keys) k: ints(j[k])});
  }
}

abstract interface class OwnerBonusesRepository {
  Future<OwnerBonusPeriod> bonuses({required String period, String? date});
  Future<OwnerVendorBonus> vendorBonus(String vendorId,
      {required String period, String? date});

  /// Owner only: voids a verified sale with a reason; its stock returns and a
  /// locked day's bonus changes by an adjustment (server).
  Future<void> correctSale(String saleId, {required String reason});

  /// The bonus and score settings; saving goes through `saveSetting`.
  Future<OwnerPerformanceSettings> performanceSettings();
}
