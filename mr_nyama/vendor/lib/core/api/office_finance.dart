// The finance books (Phase 12, docs/mr_nyama/implementation/
// phase-12-finance-api-contract.md): accounts, the posting map, posting,
// periods, the journal and reports. The server posts and computes every
// figure; amounts arrive as strings with two decimals ("1500.00").

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

num _amount(Object? v) => switch (v) {
      num() => v,
      String() => num.tryParse(v.trim()) ?? 0,
      _ => 0,
    };

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => int.tryParse(v) ?? 0,
      _ => 0,
    };

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

DateTime? _day(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? [
        for (final r in v)
          if (r is Map) Map<String, dynamic>.from(r)
      ]
    : const [];

/// The events the server knows how to post, in the contract's order.
const financeEvents = [
  'sale_cash',
  'sale_credit',
  'sale_mpesa',
  'cost_of_sales',
  'sale_correction',
  'handover_confirmed',
  'expense_office',
  'expense_vendor',
  'stock_loss',
  'credit_repayment',
  'credit_write_off',
  'vendor_debit',
  'vendor_credit',
  'bonus_earned',
  'vendor_payment',
];

/// Account kinds (the contract's `kind`).
const financeAccountKinds = [
  'asset',
  'liability',
  'equity',
  'income',
  'expense'
];

/// A person or party the server names: `{"id","name","code"}`.
class FinanceRef {
  final String id, name;
  final String? code;
  const FinanceRef({required this.id, required this.name, this.code});
  static FinanceRef? fromJson(Object? v) {
    final m = _map(v);
    if (m == null) return null;
    return FinanceRef(
        id: _str(m['id']), name: _str(m['name']), code: _opt(m['code']));
  }

  /// "1100 · Cash box" for an account, the name otherwise.
  String get label => code == null ? name : '$code · $name';
}

class FinanceAccount {
  final String id, code, name, kind;
  final bool active;
  final num balance;
  const FinanceAccount(
      {required this.id,
      required this.code,
      required this.name,
      this.kind = 'asset',
      this.active = true,
      this.balance = 0});
  String get label => '$code · $name';
  factory FinanceAccount.fromJson(Map<String, dynamic> j) => FinanceAccount(
      id: _str(j['id']),
      code: _str(j['code']),
      name: _str(j['name']),
      kind: _opt(j['kind']) ?? 'asset',
      active: j['active'] != false,
      balance: _amount(j['balance']));
}

class PostingRule {
  final String event;
  final FinanceRef? debit, credit, setBy;
  final bool configured;
  final DateTime? setAt;
  const PostingRule(
      {required this.event,
      this.debit,
      this.credit,
      this.configured = false,
      this.setBy,
      this.setAt});
  factory PostingRule.fromJson(Map<String, dynamic> j) => PostingRule(
      event: _str(j['event']),
      debit: FinanceRef.fromJson(j['debit_account']),
      credit: FinanceRef.fromJson(j['credit_account']),
      configured: j['configured'] == true,
      setBy: FinanceRef.fromJson(j['set_by']),
      setAt: _time(j['set_at']));
}

class FinanceStatus {
  final Map<String, int> unposted;
  final List<String> unconfigured;
  final DateTime? lastPostedAt;
  final String? openFrom;
  const FinanceStatus(
      {this.unposted = const {},
      this.unconfigured = const [],
      this.lastPostedAt,
      this.openFrom});
  int get totalUnposted => unposted.values.fold(0, (a, b) => a + b);
  factory FinanceStatus.fromJson(Map<String, dynamic> j) => FinanceStatus(
          unposted: {
            for (final e in (_map(j['unposted']) ?? const {}).entries)
              e.key: _int(e.value)
          },
          unconfigured: [
            for (final e
                in (j['unconfigured'] is List ? j['unconfigured'] : []))
              '$e'
          ],
          lastPostedAt: _time(j['last_posted_at']),
          openFrom: _opt(j['open_from']));
}

class PostResult {
  final Map<String, int> posted;
  final List<String> unconfigured;
  final int entries;
  const PostResult(
      {this.posted = const {}, this.unconfigured = const [], this.entries = 0});
  factory PostResult.fromJson(Map<String, dynamic> j) => PostResult(posted: {
        for (final e in (_map(j['posted']) ?? const {}).entries)
          e.key: _int(e.value)
      }, unconfigured: [
        for (final e in (j['unconfigured'] is List ? j['unconfigured'] : []))
          '$e'
      ], entries: _int(j['entries']));
}

class FinancePeriod {
  final String month;
  final bool locked;
  final FinanceRef? lockedBy;
  final DateTime? lockedAt;
  final String? reason;
  const FinancePeriod(
      {required this.month,
      this.locked = false,
      this.lockedBy,
      this.lockedAt,
      this.reason});
  factory FinancePeriod.fromJson(Map<String, dynamic> j) => FinancePeriod(
      month: _str(j['month']),
      locked: j['status'] == 'locked',
      lockedBy: FinanceRef.fromJson(j['locked_by']),
      lockedAt: _time(j['locked_at']),
      reason: _opt(j['reason']));
}

class JournalLine {
  final FinanceRef? account, station, vendor;
  final num debit, credit;
  const JournalLine(
      {this.account,
      this.debit = 0,
      this.credit = 0,
      this.station,
      this.vendor});
  factory JournalLine.fromJson(Map<String, dynamic> j) => JournalLine(
      account: FinanceRef.fromJson(j['account']),
      debit: _amount(j['debit']),
      credit: _amount(j['credit']),
      station: FinanceRef.fromJson(j['station']),
      vendor: FinanceRef.fromJson(j['vendor']));
}

class JournalEntry {
  final String id, event, sourceType, sourceId;
  final DateTime? entryDate, originalDate, postedAt;
  final String? memo, reversesEntryId;
  final FinanceRef? postedBy;
  final List<JournalLine> lines;
  const JournalEntry(
      {required this.id,
      this.event = '',
      this.sourceType = '',
      this.sourceId = '',
      this.entryDate,
      this.originalDate,
      this.postedAt,
      this.memo,
      this.reversesEntryId,
      this.postedBy,
      this.lines = const []});
  num get total => lines.fold<num>(0, (a, l) => a + l.debit);
  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
      id: _str(j['id']),
      event: _str(j['event']),
      sourceType: _str(j['source_type']),
      sourceId: _str(j['source_id']),
      entryDate: _day(j['entry_date']),
      originalDate: _day(j['original_date']),
      postedAt: _time(j['posted_at']),
      memo: _opt(j['memo']),
      reversesEntryId: _opt(j['reverses_entry_id']),
      postedBy: FinanceRef.fromJson(j['posted_by']),
      lines: [for (final l in _rows(j['lines'])) JournalLine.fromJson(l)]);
}

class TrialBalanceRow {
  final FinanceRef? account;
  final String kind;
  final num debit, credit, balance;
  const TrialBalanceRow(
      {this.account,
      this.kind = '',
      this.debit = 0,
      this.credit = 0,
      this.balance = 0});
  factory TrialBalanceRow.fromJson(Map<String, dynamic> j) => TrialBalanceRow(
      account: FinanceRef.fromJson(j['account']),
      kind: _str(_map(j['account'])?['kind']),
      debit: _amount(j['debit']),
      credit: _amount(j['credit']),
      balance: _amount(j['balance']));
}

class TrialBalance {
  final DateTime? asOf;
  final List<TrialBalanceRow> rows;
  final num totalDebit, totalCredit;
  const TrialBalance(
      {this.asOf,
      this.rows = const [],
      this.totalDebit = 0,
      this.totalCredit = 0});
  factory TrialBalance.fromJson(Map<String, dynamic> j) => TrialBalance(
      asOf: _day(j['as_of']),
      rows: [for (final r in _rows(j['rows'])) TrialBalanceRow.fromJson(r)],
      totalDebit: _amount(j['total_debit']),
      totalCredit: _amount(j['total_credit']));
}

class AccountAmount {
  final FinanceRef? account;
  final num amount;
  const AccountAmount({this.account, this.amount = 0});
  factory AccountAmount.fromJson(Map<String, dynamic> j) => AccountAmount(
      account: FinanceRef.fromJson(j['account']),
      amount: _amount(j['amount'] ?? j['balance']));
}

class OperatingResult {
  final DateTime? from, to;
  final List<AccountAmount> income, expenses;
  final num totalIncome, totalExpenses, result;
  final bool provisional;
  final int unposted;
  const OperatingResult(
      {this.from,
      this.to,
      this.income = const [],
      this.expenses = const [],
      this.totalIncome = 0,
      this.totalExpenses = 0,
      this.result = 0,
      this.provisional = false,
      this.unposted = 0});
  factory OperatingResult.fromJson(Map<String, dynamic> j) => OperatingResult(
      from: _day(j['from']),
      to: _day(j['to']),
      income: [for (final r in _rows(j['income'])) AccountAmount.fromJson(r)],
      expenses: [
        for (final r in _rows(j['expenses'])) AccountAmount.fromJson(r)
      ],
      totalIncome: _amount(j['total_income']),
      totalExpenses: _amount(j['total_expenses']),
      result: _amount(j['result']),
      provisional: j['provisional'] == true,
      unposted: _int(j['unposted']));
}

class CashPosition {
  final DateTime? asOf;
  final List<AccountAmount> rows;
  const CashPosition({this.asOf, this.rows = const []});
  factory CashPosition.fromJson(Map<String, dynamic> j) => CashPosition(
      asOf: _day(j['as_of']),
      rows: [for (final r in _rows(j['rows'])) AccountAmount.fromJson(r)]);
}

abstract interface class OfficeFinanceRepository {
  Future<List<FinanceAccount>> financeAccounts();
  Future<FinanceAccount> createFinanceAccount(
      {required String code,
      required String name,
      required String kind,
      required String reason});
  Future<FinanceAccount> updateFinanceAccount(String id,
      {String? name, bool? active, required String reason});
  Future<List<PostingRule>> postingMap();

  /// Owner only.
  Future<PostingRule> setPostingRule(String event,
      {required String debitAccountId,
      required String creditAccountId,
      required String reason});
  Future<FinanceStatus> financeStatus();
  Future<PostResult> postToBooks({required String until});
  Future<List<FinancePeriod>> financePeriods();

  /// Owner only; months lock in order.
  Future<FinancePeriod> lockFinancePeriod(String month,
      {required String reason});
  Future<List<JournalEntry>> journal(
      {String? from, String? to, String? accountId});
  Future<TrialBalance> trialBalance({String? asOf});
  Future<OperatingResult> operatingResult({String? from, String? to});
  Future<CashPosition> cashPosition({String? asOf});
}
