// The owner's money overview (`GET /owner/overview`): sales (mapato) and
// expenses (matumizi) per station and for all stations, and the expense
// categories that cost the most. Every figure is computed by the server;
// the app only shows it. Parsing is null-safe.

String _str(Object? v) => v == null ? '' : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

double _double(Object? v) => switch (v) {
      num() => v.toDouble(),
      String() => double.tryParse(v) ?? 0,
      _ => 0,
    };

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    v is List ? [for (final row in v) _map(row)] : const [];

/// The overview's period: one business day, its Monday–Sunday week or its
/// calendar month.
enum OwnerPeriod {
  day('day'),
  week('week'),
  month('month');

  final String wire;
  const OwnerPeriod(this.wire);
}

/// One expense category's approved spending and its share (percent) of the
/// spending it is listed under.
class OwnerExpenseCategory {
  final String category;
  final int amount;
  final double share;
  const OwnerExpenseCategory(
      {required this.category, required this.amount, required this.share});

  factory OwnerExpenseCategory.fromJson(Map<String, dynamic> m) =>
      OwnerExpenseCategory(
          category: _str(m['category']),
          amount: _int(m['amount']),
          share: _double(m['share']));
}

/// Sales and expenses of one station, or of all stations.
/// [sales] are recorded sales without voided ones ([verifiedSales] is the
/// verified part); [expenses] are approved, net of reversals; [balance] is
/// sales − expenses, not profit.
class OwnerMoneyFigures {
  final int sales, verifiedSales, expenses, pendingExpenses, balance;
  const OwnerMoneyFigures(
      {required this.sales,
      required this.verifiedSales,
      required this.expenses,
      required this.pendingExpenses,
      required this.balance});

  factory OwnerMoneyFigures.fromJson(Map<String, dynamic> m) =>
      OwnerMoneyFigures(
          sales: _int(m['sales']),
          verifiedSales: _int(m['verified_sales']),
          expenses: _int(m['expenses']),
          pendingExpenses: _int(m['pending_expenses']),
          balance: _int(m['balance']));
}

class OwnerStationMoney {
  final String id, name;
  final String? code;
  final OwnerMoneyFigures figures;
  final List<OwnerExpenseCategory> categories;
  const OwnerStationMoney(
      {required this.id,
      required this.name,
      this.code,
      required this.figures,
      required this.categories});

  factory OwnerStationMoney.fromJson(Map<String, dynamic> m) {
    final station = _map(m['station']);
    final code = _str(station['code']);
    return OwnerStationMoney(
        id: _str(station['id']),
        name: _str(station['name']),
        code: code.isEmpty ? null : code,
        figures: OwnerMoneyFigures.fromJson(m),
        categories: [
          for (final row in _rows(m['expense_categories']))
            OwnerExpenseCategory.fromJson(row)
        ]);
  }
}

class OwnerMoneyOverview {
  final OwnerPeriod period;
  final DateTime? from, to;
  final OwnerMoneyFigures totals;

  /// Stations open on a single day's report; null for other periods and
  /// servers that do not send it.
  final int? openStations;

  /// Cash handed over and recorded but not yet confirmed by finance, from
  /// the server (`with_supervisor`); null from a server that does not send it.
  final int? withSupervisor;
  final List<OwnerExpenseCategory> categories;
  final List<OwnerStationMoney> stations;
  const OwnerMoneyOverview(
      {required this.period,
      this.from,
      this.to,
      required this.totals,
      this.openStations,
      this.withSupervisor,
      required this.categories,
      required this.stations});

  factory OwnerMoneyOverview.fromJson(Map<String, dynamic> m) =>
      OwnerMoneyOverview(
          period: OwnerPeriod.values
                  .where((p) => p.wire == m['period'])
                  .firstOrNull ??
              OwnerPeriod.day,
          from: DateTime.tryParse(_str(m['from'])),
          to: DateTime.tryParse(_str(m['to'])),
          totals: OwnerMoneyFigures.fromJson(_map(m['totals'])),
          openStations: (m['open_stations'] as num?)?.toInt(),
          withSupervisor: (m['with_supervisor'] as num?)?.toInt(),
          categories: [
            for (final row in _rows(m['expense_categories']))
              OwnerExpenseCategory.fromJson(row)
          ],
          stations: [
            for (final row in _rows(m['stations']))
              OwnerStationMoney.fromJson(row)
          ]);
}

/// Owner-only reports. 403 for anyone else.
abstract interface class OwnerReportsRepository {
  Future<OwnerMoneyOverview> moneyOverview(OwnerPeriod period, {String? date});
}
