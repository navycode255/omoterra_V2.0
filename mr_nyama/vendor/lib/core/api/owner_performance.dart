// The owner's performance view (Phase 8 server routes, owner plan Task 7):
// overview totals, what needs attention, the ranking, a person's scorecard,
// one station's figures and ratings. The server computes every figure, score
// and star; the app only shows them. Parsing is null-safe so a field the
// server leaves out never breaks the screen.

import 'office_money.dart';

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

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

DateTime? _day(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? [
        for (final r in v)
          if (r is Map) Map<String, dynamic>.from(r)
      ]
    : const [];

/// The period an owner view covers.
enum PerformancePeriod {
  day('day'),
  week('week'),
  month('month');

  final String wire;
  const PerformancePeriod(this.wire);
}

/// What needs the owner (`attention[]`).
enum AttentionKind {
  stockDifference('stock_difference'),
  moneyShort('money_short'),
  notSynced('not_synced'),
  expensePending('expense_pending'),
  targetMissed('target_missed_3_days');

  final String wire;
  const AttentionKind(this.wire);

  static AttentionKind? parse(Object? v) =>
      values.where((k) => k.wire == v).firstOrNull;
}

class AttentionItem {
  final AttentionKind? kind;
  final MoneyParty? station, vendor;
  final DateTime? businessDate;
  final Map<String, dynamic> detail;
  const AttentionItem(
      {this.kind,
      this.station,
      this.vendor,
      this.businessDate,
      this.detail = const {}});

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
      kind: AttentionKind.parse(j['kind']),
      station: MoneyParty.fromJson(j['station']),
      vendor: MoneyParty.fromJson(j['vendor']),
      businessDate: _day(j['business_date']),
      detail: _map(j['detail']));
}

/// One row of the ranking: a vendor, or a supervisor or manager.
class RankingEntry {
  final bool isVendor;
  final MoneyParty? person;
  final String? card;
  final int? score, stars;
  final int days;
  const RankingEntry(
      {required this.isVendor,
      this.person,
      this.card,
      this.score,
      this.stars,
      this.days = 0});

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
      isVendor: j['kind'] != 'staff',
      person: MoneyParty.fromJson(j['person']),
      card: _opt(j['card']),
      score: _intOrNull(j['score']),
      stars: _intOrNull(j['stars']),
      days: _int(j['days']));
}

class StationPerformance {
  final MoneyParty station;
  final int sales, verifiedSales, expenses;
  final String chickens;
  final int? profit, profitTarget;
  final int profitUnknownDays;
  final List<MoneyParty> vendors;
  const StationPerformance(
      {required this.station,
      this.sales = 0,
      this.verifiedSales = 0,
      this.expenses = 0,
      this.chickens = '0',
      this.profit,
      this.profitTarget,
      this.profitUnknownDays = 0,
      this.vendors = const []});

  factory StationPerformance.fromJson(Map<String, dynamic> j) =>
      StationPerformance(
          station: MoneyParty.fromJson(j['station']) ??
              const MoneyParty(id: '', name: ''),
          sales: _int(j['sales']),
          verifiedSales: _int(j['verified_sales']),
          expenses: _int(j['expenses']),
          chickens: _opt(j['chickens']) ?? '0',
          profit: _intOrNull(j['profit']),
          profitTarget: _intOrNull(j['profit_target']),
          profitUnknownDays: _int(j['profit_unknown_days']),
          vendors: [
            for (final v in _rows(j['vendors']))
              if (MoneyParty.fromJson(v) case final p?) p
          ]);
}

/// `GET /owner/overview`, the parts the performance screen shows.
class PerformanceOverview {
  final DateTime? from, to;
  final int sales, verifiedSales, expenses;
  final String chickens;
  final int profit, profitUnknownDays;
  final int bonusEarned, bonusEstimated, bonusAdjustments;
  final List<StationPerformance> stations;
  final List<AttentionItem> attention;
  final Map<String, int> attentionCounts;
  final List<RankingEntry> ranking;
  const PerformanceOverview(
      {this.from,
      this.to,
      this.sales = 0,
      this.verifiedSales = 0,
      this.expenses = 0,
      this.chickens = '0',
      this.profit = 0,
      this.profitUnknownDays = 0,
      this.bonusEarned = 0,
      this.bonusEstimated = 0,
      this.bonusAdjustments = 0,
      this.stations = const [],
      this.attention = const [],
      this.attentionCounts = const {},
      this.ranking = const []});

  factory PerformanceOverview.fromJson(Map<String, dynamic> j) {
    final t = _map(j['totals']);
    return PerformanceOverview(
        from: _day(j['from']),
        to: _day(j['to']),
        sales: _int(t['sales']),
        verifiedSales: _int(t['verified_sales']),
        expenses: _int(t['expenses']),
        chickens: _opt(t['chickens']) ?? '0',
        profit: _int(t['profit']),
        profitUnknownDays: _int(t['profit_unknown_days']),
        bonusEarned: _int(t['bonus_earned']),
        bonusEstimated: _int(t['bonus_estimated']),
        bonusAdjustments: _int(t['bonus_adjustments']),
        stations: [
          for (final s in _rows(j['stations'])) StationPerformance.fromJson(s)
        ],
        attention: [
          for (final a in _rows(j['attention'])) AttentionItem.fromJson(a)
        ],
        attentionCounts: {
          for (final e in _map(j['attention_counts']).entries)
            e.key: _int(e.value)
        },
        ranking: [
          for (final r in _rows(j['ranking'])) RankingEntry.fromJson(r)
        ]);
  }

  /// How many of [kind] there are in all (the list keeps the newest).
  int countOf(AttentionKind kind) =>
      attentionCounts[kind.wire] ??
      attention.where((a) => a.kind == kind).length;
}

/// One day of a scorecard.
class ScoreDay {
  final DateTime? businessDate;
  final MoneyParty? station;
  final int? score, stars;
  final Map<String, int?> areas;
  final Map<String, String> reasons;

  /// How many times an area of this day was corrected by hand.
  final int ratingChanges;
  const ScoreDay(
      {this.businessDate,
      this.station,
      this.score,
      this.stars,
      this.areas = const {},
      this.reasons = const {},
      this.ratingChanges = 0});

  factory ScoreDay.fromJson(Map<String, dynamic> j) => ScoreDay(
      businessDate: _day(j['business_date']),
      station: MoneyParty.fromJson(j['station']),
      score: _intOrNull(j['score']),
      stars: _intOrNull(j['stars']),
      areas: {
        for (final e in _map(j['areas']).entries) e.key: _intOrNull(e.value)
      },
      reasons: {
        for (final e in _map(j['reasons']).entries)
          if (e.value != null) e.key: _str(e.value)
      },
      ratingChanges: _int(j['rating_changes']));
}

/// The bonus part of a vendor's scorecard (`bonus` in `/owner/vendors/{id}`).
class ScorecardBonus {
  final int earned, estimated, adjustments;
  final String chickens;
  const ScorecardBonus(
      {this.earned = 0,
      this.estimated = 0,
      this.adjustments = 0,
      this.chickens = '0'});

  factory ScorecardBonus.fromJson(Map<String, dynamic> j) => ScorecardBonus(
      earned: _int(j['earned']),
      estimated: _int(j['estimated']),
      adjustments: _int(j['adjustments']),
      chickens: _opt(j['chicken_equivalents']) ?? '0');
}

/// A vendor's or staff member's scorecard for a period.
class Scorecard {
  final MoneyParty? person;
  final bool isVendor;

  /// `supervisor` or `manager` for staff; null when the person has no card.
  final String? card;
  final DateTime? from, to;
  final int? score, stars;
  final Map<String, int?> areas;
  final Map<String, int> weights;
  final List<ScoreDay> days;
  final ScorecardBonus? bonus;
  const Scorecard(
      {this.person,
      this.isVendor = true,
      this.card,
      this.from,
      this.to,
      this.score,
      this.stars,
      this.areas = const {},
      this.weights = const {},
      this.days = const [],
      this.bonus});

  /// Scores need the owner's weights; without them only the areas show.
  bool get weightsSet => weights.isNotEmpty;

  factory Scorecard.fromJson(Map<String, dynamic> j) {
    final vendor = j.containsKey('vendor');
    return Scorecard(
        person: MoneyParty.fromJson(vendor ? j['vendor'] : j['staff']),
        isVendor: vendor,
        card: vendor ? 'vendor' : _opt(j['card']),
        from: _day(j['from']),
        to: _day(j['to']),
        score: _intOrNull(j['score']),
        stars: _intOrNull(j['stars']),
        areas: {
          for (final e in _map(j['areas']).entries) e.key: _intOrNull(e.value)
        },
        weights: {
          for (final e in _map(j['weights']).entries) e.key: _int(e.value)
        },
        days: [for (final d in _rows(j['days'])) ScoreDay.fromJson(d)],
        bonus: j['bonus'] is Map
            ? ScorecardBonus.fromJson(_map(j['bonus']))
            : null);
  }
}

class StationDayFigures {
  final DateTime? businessDate;
  final int sales, verifiedSales, expenses;
  final int? profit;
  final String chickens;
  final int vendorsSharing;
  const StationDayFigures(
      {this.businessDate,
      this.sales = 0,
      this.verifiedSales = 0,
      this.expenses = 0,
      this.profit,
      this.chickens = '0',
      this.vendorsSharing = 0});

  factory StationDayFigures.fromJson(Map<String, dynamic> j) =>
      StationDayFigures(
          businessDate: _day(j['business_date']),
          sales: _int(j['sales']),
          verifiedSales: _int(j['verified_sales']),
          expenses: _int(j['expenses']),
          profit: _intOrNull(j['profit']),
          chickens: _opt(j['chickens']) ?? '0',
          vendorsSharing: _int(j['vendors_sharing']));
}

class StationVendorFigures {
  final MoneyParty? vendor;
  final String chickens;
  final int earned, estimated, days;
  const StationVendorFigures(
      {this.vendor,
      this.chickens = '0',
      this.earned = 0,
      this.estimated = 0,
      this.days = 0});

  factory StationVendorFigures.fromJson(Map<String, dynamic> j) =>
      StationVendorFigures(
          vendor: MoneyParty.fromJson(j['vendor']),
          chickens: _opt(j['chickens']) ?? '0',
          earned: _int(j['earned']),
          estimated: _int(j['estimated']),
          days: _int(j['days']));
}

/// `GET /owner/stations/{id}`.
class StationPerformanceDetail {
  final MoneyParty? station;
  final int sales, verifiedSales, expenses, pendingExpenses, balance;
  final String chickens;
  final int? profit, profitTarget;
  final int profitUnknownDays, openExceptions;
  final List<StationDayFigures> days;
  final List<StationVendorFigures> vendors;
  const StationPerformanceDetail(
      {this.station,
      this.sales = 0,
      this.verifiedSales = 0,
      this.expenses = 0,
      this.pendingExpenses = 0,
      this.balance = 0,
      this.chickens = '0',
      this.profit,
      this.profitTarget,
      this.profitUnknownDays = 0,
      this.openExceptions = 0,
      this.days = const [],
      this.vendors = const []});

  factory StationPerformanceDetail.fromJson(Map<String, dynamic> j) =>
      StationPerformanceDetail(
          station: MoneyParty.fromJson(j['station']),
          sales: _int(j['sales']),
          verifiedSales: _int(j['verified_sales']),
          expenses: _int(j['expenses']),
          pendingExpenses: _int(j['pending_expenses']),
          balance: _int(j['balance']),
          chickens: _opt(j['chickens']) ?? '0',
          profit: _intOrNull(j['profit']),
          profitTarget: _intOrNull(j['profit_target']),
          profitUnknownDays: _int(j['profit_unknown_days']),
          openExceptions: _int(j['open_exceptions']),
          days: [
            for (final d in _rows(j['days'])) StationDayFigures.fromJson(d)
          ],
          vendors: [
            for (final v in _rows(j['vendors']))
              StationVendorFigures.fromJson(v)
          ]);
}

class OwnerRating {
  final String id;
  final int stars;
  final String? comment;
  final DateTime? ratingDate, createdAt;
  final MoneyParty? ratedBy;
  const OwnerRating(
      {required this.id,
      required this.stars,
      this.comment,
      this.ratingDate,
      this.createdAt,
      this.ratedBy});

  factory OwnerRating.fromJson(Map<String, dynamic> j) => OwnerRating(
      id: _str(j['id']),
      stars: _int(j['stars']),
      comment: _opt(j['comment']),
      ratingDate: _day(j['rating_date']),
      createdAt: _time(j['created_at']),
      ratedBy: MoneyParty.fromJson(j['rated_by']));
}

/// One correction of one area of one day (`POST /staff/area-ratings`). [id] is
/// null when the value was already that, so nothing was recorded.
class AreaRating {
  final String? id;
  final String area;
  final int score;
  final int? previousScore;
  final DateTime? businessDate, createdAt;
  final MoneyParty? ratedBy;
  const AreaRating(
      {this.id,
      required this.area,
      required this.score,
      this.previousScore,
      this.businessDate,
      this.createdAt,
      this.ratedBy});

  factory AreaRating.fromJson(Map<String, dynamic> j) => AreaRating(
      id: _opt(j['id']),
      area: _str(j['area']),
      score: _int(j['score']),
      previousScore: _intOrNull(j['previous_score']),
      businessDate: _day(j['business_date']),
      createdAt: _time(j['created_at']),
      ratedBy: MoneyParty.fromJson(j['rated_by']));
}

/// A whole number of chicken-equivalents shown without trailing zeros.
String chickensText(String value) {
  final n = _num(value);
  return n == n.roundToDouble() ? '${n.round()}' : '$n';
}

abstract interface class OwnerPerformanceRepository {
  Future<PerformanceOverview> performanceOverview(PerformancePeriod period,
      {String? date, int attentionLimit = 20});
  Future<Scorecard> vendorScorecard(String vendorId, PerformancePeriod period,
      {String? date});
  Future<Scorecard> staffScorecard(String staffId, PerformancePeriod period,
      {String? date});
  Future<StationPerformanceDetail> stationPerformance(
      String stationId, PerformancePeriod period,
      {String? date});

  /// Exactly one of [vendorId] and [staffId].
  Future<OwnerRating> rate(
      {String? vendorId, String? staffId, required int stars, String? comment});
  Future<List<OwnerRating>> ratings({String? vendorId, String? staffId});

  /// Exactly one of [vendorId] and [staffId]; [date] is `yyyy-mm-dd`.
  Future<AreaRating> rateArea(
      {String? vendorId,
      String? staffId,
      required String date,
      required String area,
      required int score});
  Future<List<AreaRating>> areaRatings(
      {String? vendorId, String? staffId, required String date});
}
