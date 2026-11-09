// Station money in the office: what each vendor owes for a business day,
// the cash they hand over, and the station's expenses. Amounts are whole
// shillings fixed by the server; the app never computes what is owed.
// Parsing is null-safe so a field the server leaves out never breaks the
// screen.

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

int _int(Object? v) => switch (v) {
      int() => v,
      num() => v.round(),
      String() => num.tryParse(v)?.round() ?? 0,
      _ => 0,
    };

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `YYYY-MM-DD` (a business date) as a date-only value.
DateTime? _day(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

Map<String, dynamic>? _mapOrNull(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// A business date as the server writes it (`YYYY-MM-DD`).
String moneyDateKey(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// A person, vendor or station the server names: `{"id","name","code"}`.
class MoneyParty {
  final String id, name;
  final String? code;
  const MoneyParty({required this.id, required this.name, this.code});

  static MoneyParty? fromJson(Object? v) {
    final m = _mapOrNull(v);
    if (m == null) return null;
    return MoneyParty(
        id: _str(m['id']), name: _str(m['name']), code: _opt(m['code']));
  }
}

const _nobody = MoneyParty(id: '', name: '');

/// The server's word for a vendor-day's cash.
enum MoneyDayState {
  nothingDue('nothing_due'),
  notHanded('not_handed'),
  short('short'),
  full('full'),
  over('over');

  final String wire;
  const MoneyDayState(this.wire);

  static MoneyDayState? parse(Object? v) =>
      values.where((s) => s.wire == v).firstOrNull;
}

/// One vendor's cash for one business day (`GET /staff/money/days`).
/// [cashDue] = verified cash sales − approved vendor expenses (server).
class OfficeMoneyDay {
  final String vendorDayId;
  final MoneyParty vendor;
  final DateTime? businessDate;
  final int verifiedCashSales, unverifiedCashSales;
  final int approvedVendorExpenses, pendingVendorExpenses;
  final int cashDue, handedOver, confirmed, remaining;

  /// Cash the vendor took from credit customers (part of [cashDue]) and the
  /// day's credit sales (not cash), MN018.
  final int creditRepaymentsCash, creditSales;
  final DateTime? lastReceivedAt;

  /// Null when the server sent a state this app does not know.
  final MoneyDayState? state;

  /// Null when no handover deadline is set: nothing is said about lateness.
  final bool? late;

  /// An ESTIMATE of the cash the vendor holds now, from sales (verified or
  /// not), expenses and handovers. Not proof of cash, never a balance. Null
  /// when the server does not send it.
  final int? cashOnHandEstimate;
  const OfficeMoneyDay(
      {this.vendorDayId = '',
      required this.vendor,
      this.businessDate,
      this.verifiedCashSales = 0,
      this.unverifiedCashSales = 0,
      this.approvedVendorExpenses = 0,
      this.pendingVendorExpenses = 0,
      this.cashDue = 0,
      this.handedOver = 0,
      this.confirmed = 0,
      this.remaining = 0,
      this.creditRepaymentsCash = 0,
      this.creditSales = 0,
      this.lastReceivedAt,
      this.state,
      this.late,
      this.cashOnHandEstimate});

  factory OfficeMoneyDay.fromJson(Map<String, dynamic> j) => OfficeMoneyDay(
      vendorDayId: _str(j['vendor_day_id']),
      vendor: MoneyParty.fromJson(j['vendor']) ?? _nobody,
      businessDate: _day(j['business_date']),
      verifiedCashSales: _int(j['verified_cash_sales']),
      unverifiedCashSales: _int(j['unverified_cash_sales']),
      approvedVendorExpenses: _int(j['approved_vendor_expenses']),
      pendingVendorExpenses: _int(j['pending_vendor_expenses']),
      cashDue: _int(j['cash_due']),
      creditRepaymentsCash: _int(j['credit_repayments_cash']),
      creditSales: _int(j['credit_sales']),
      handedOver: _int(j['handed_over']),
      confirmed: _int(j['confirmed']),
      remaining: _int(j['remaining']),
      lastReceivedAt: _time(j['last_received_at']),
      state: MoneyDayState.parse(j['state']),
      late: j['late'] is bool ? j['late'] as bool : null,
      cashOnHandEstimate: j['cash_on_hand_estimate'] is num
          ? _int(j['cash_on_hand_estimate'])
          : null);
}

/// Cash a vendor handed to the office (`/staff/handovers`). A correction is
/// a new row naming the one it reverses; nothing is edited or deleted.
class OfficeHandover {
  final String id;
  final MoneyParty vendor, station, recordedBy;
  final DateTime? businessDate, receivedAt, confirmedAt, createdAt;
  final int amount;
  final String status;
  final MoneyParty? confirmedBy;
  final String? reversesId, reversedById, reason, note;
  const OfficeHandover(
      {required this.id,
      required this.vendor,
      this.station = _nobody,
      this.businessDate,
      required this.amount,
      this.receivedAt,
      this.recordedBy = _nobody,
      this.status = 'recorded',
      this.confirmedBy,
      this.confirmedAt,
      this.reversesId,
      this.reversedById,
      this.reason,
      this.note,
      this.createdAt});

  bool get confirmed => status == 'confirmed';

  /// This row corrects (reverses) another handover.
  bool get isReversal => reversesId != null;

  /// A later row reversed this one.
  bool get reversed => reversedById != null;

  factory OfficeHandover.fromJson(Map<String, dynamic> j) => OfficeHandover(
      id: _str(j['id']),
      vendor: MoneyParty.fromJson(j['vendor']) ?? _nobody,
      station: MoneyParty.fromJson(j['station']) ?? _nobody,
      businessDate: _day(j['business_date']),
      amount: _int(j['amount']),
      receivedAt: _time(j['received_at']),
      recordedBy: MoneyParty.fromJson(j['recorded_by']) ?? _nobody,
      status: _opt(j['status']) ?? 'recorded',
      confirmedBy: MoneyParty.fromJson(j['confirmed_by']),
      confirmedAt: _time(j['confirmed_at']),
      reversesId: _opt(j['reverses_id']),
      reversedById: _opt(j['reversed_by_id']),
      reason: _opt(j['reason']),
      note: _opt(j['note']),
      createdAt: _time(j['created_at']));
}

/// A station expense (`/staff/expenses`): paid by the office (approved when
/// recorded) or claimed by a vendor (pending until decided).
class OfficeExpense {
  final String id;
  final MoneyParty station;
  final DateTime? businessDate, decidedAt, createdAt;
  final String category;

  /// What was bought (MN017); null on expenses recorded before items.
  final String? item;
  final int amount;
  final String? note;
  final String paidBy;
  final MoneyParty? vendor, recordedBy, decidedBy;
  final String status;
  final String? decisionReason, reversesId, reversedById;
  const OfficeExpense(
      {required this.id,
      this.station = _nobody,
      this.businessDate,
      required this.category,
      this.item,
      required this.amount,
      this.note,
      this.paidBy = 'office',
      this.vendor,
      this.recordedBy,
      this.status = 'approved',
      this.decidedBy,
      this.decidedAt,
      this.decisionReason,
      this.reversesId,
      this.reversedById,
      this.createdAt});

  bool get pending => status == 'pending';
  bool get approved => status == 'approved';
  bool get rejected => status == 'rejected';
  bool get byVendor => paidBy == 'vendor';
  bool get isReversal => reversesId != null;
  bool get reversed => reversedById != null;

  factory OfficeExpense.fromJson(Map<String, dynamic> j) => OfficeExpense(
      id: _str(j['id']),
      station: MoneyParty.fromJson(j['station']) ?? _nobody,
      businessDate: _day(j['business_date']),
      category: _str(j['category']),
      item: _opt(j['item']),
      amount: _int(j['amount']),
      note: _opt(j['note']),
      paidBy: _opt(j['paid_by']) ?? 'office',
      vendor: MoneyParty.fromJson(j['vendor']),
      recordedBy: MoneyParty.fromJson(j['recorded_by']),
      status: _opt(j['status']) ?? 'approved',
      decidedBy: MoneyParty.fromJson(j['decided_by']),
      decidedAt: _time(j['decided_at']),
      decisionReason: _opt(j['decision_reason']),
      reversesId: _opt(j['reverses_id']),
      reversedById: _opt(j['reversed_by_id']),
      createdAt: _time(j['created_at']));
}

/// The owner's money settings (`GET /admin/settings`). Null means not set.
/// `sales.auto_verify`, as the owner set it; every value has no default. A
/// value left out is null here and the settings screen shows it as not set.
class OfficeAutoVerifySetting {
  final String mode;
  final List<String> stationIds;
  final String? runTime;
  final int? lateHours, duplicateWindowMinutes, maxSaleAmount, samplePercent;
  final bool? acceptStalePrice;
  const OfficeAutoVerifySetting(
      {this.mode = 'off',
      this.stationIds = const [],
      this.runTime,
      this.lateHours,
      this.duplicateWindowMinutes,
      this.maxSaleAmount,
      this.samplePercent,
      this.acceptStalePrice});

  static OfficeAutoVerifySetting? fromJson(Object? v) {
    if (v is! Map) return null;
    int? whole(Object? n) => n is int ? n : null;
    final stations = v['station_ids'];
    return OfficeAutoVerifySetting(
        mode: v['mode'] is String ? v['mode'] as String : 'off',
        stationIds: [
          if (stations is List)
            for (final id in stations) '$id'
        ],
        runTime: v['run_time'] is String ? v['run_time'] as String : null,
        lateHours: whole(v['late_hours']),
        duplicateWindowMinutes: whole(v['duplicate_window_minutes']),
        maxSaleAmount: whole(v['max_sale_amount']),
        samplePercent: whole(v['sample_percent']),
        acceptStalePrice: v['accept_stale_price'] is bool
            ? v['accept_stale_price'] as bool
            : null);
  }
}

class OfficeMoneySettings {
  static const categoriesKey = 'expense.categories';
  static const deadlineKey = 'money.handover_deadline';
  static const lateEntryKey = 'stock.late_entry_hours';
  static const cutsKey = 'stock.cuts';
  static const itemsKey = 'expense.items';
  static const cashLimitKey = 'money.cash_on_hand_limit';
  static const autoVerifyKey = 'sales.auto_verify';

  /// Offline unlock limits (Phase 11, policies §10); all unset → offline
  /// unlock off. (setting key, lowest, highest)
  static const offlineLimits = [
    ('offline.validity_hours', 1, 720),
    ('offline.relock_minutes', 1, 1440),
    ('offline.pin_attempts', 1, 20),
  ];

  final List<String>? expenseCategories;

  /// What can be bought under each category (`expense.items`).
  final Map<String, List<String>> expenseItems;

  /// Pieces cut at the station (`stock.cuts`): piece code -> the product
  /// it is cut from and how many one gives. Empty when none are set.
  final Map<String, OfficeCut> cuts;

  /// `HH:MM`, East Africa Time.
  final String? handoverDeadline;

  /// Hours after a day is reconciled during which a back-dated entry needs
  /// no approval. Null: not set (every such entry needs approval).
  final int? lateEntryHours;

  /// The offline limits that are set, by key.
  final Map<String, int> offline;

  /// Whole TZS above which a vendor's estimated cash on hand tells the
  /// supervisor. Null: not set, the alert is off.
  final int? cashOnHandLimit;

  /// Null: never set, so it is off.
  final OfficeAutoVerifySetting? autoVerify;
  const OfficeMoneySettings(
      {this.expenseCategories,
      this.autoVerify,
      this.cashOnHandLimit,
      this.handoverDeadline,
      this.lateEntryHours,
      this.offline = const {},
      this.cuts = const {},
      this.expenseItems = const {}});

  bool get hasCategories => expenseCategories?.isNotEmpty ?? false;

  factory OfficeMoneySettings.fromJson(Map<String, dynamic> j) {
    final categories = j[categoriesKey];
    final deadline = j[deadlineKey];
    final lateEntry = j[lateEntryKey];
    final cuts = j[cutsKey];
    final items = j[itemsKey];
    final cashLimit = j[cashLimitKey];
    return OfficeMoneySettings(
        autoVerify: OfficeAutoVerifySetting.fromJson(j[autoVerifyKey]),
        cashOnHandLimit: cashLimit is int && cashLimit > 0 ? cashLimit : null,
        expenseItems: {
          if (items is Map)
            for (final MapEntry(:key, :value) in items.entries)
              if (value is List) '$key': [for (final i in value) '$i']
        },
        cuts: {
          if (cuts is Map)
            for (final MapEntry(key: parent, value: pieces) in cuts.entries)
              if (pieces is Map)
                for (final MapEntry(key: piece, value: count) in pieces.entries)
                  if (count is int && count > 0)
                    '$piece': OfficeCut('$parent', count)
        },
        expenseCategories: categories is List
            ? [
                for (final c in categories)
                  if (c != null && '$c'.trim().isNotEmpty) '$c'
              ]
            : null,
        handoverDeadline: deadline is String && validHandoverDeadline(deadline)
            ? deadline
            : null,
        offline: {
          for (final (key, _, _) in offlineLimits)
            if (j[key] is int) key: j[key] as int
        },
        lateEntryHours: lateEntry is int && lateEntry >= 0 ? lateEntry : null);
  }
}

/// A piece cut at the station: one [from] gives [count] of it.
class OfficeCut {
  final String from;
  final int count;
  const OfficeCut(this.from, this.count);
}

/// The `stock.cuts` value from piece rules: parent -> {piece: count}.
Map<String, Map<String, int>> cutsSetting(Map<String, OfficeCut> cuts) {
  final out = <String, Map<String, int>>{};
  cuts.forEach((piece, cut) => (out[cut.from] ??= {})[piece] = cut.count);
  return out;
}

/// What is wrong with an expense category list, as the server checks it.
enum CategoryListProblem { empty, tooMany, blank, tooLong, duplicate }

const maxExpenseCategories = 30;
const maxExpenseCategoryLength = 40;

/// Checks [names] (already trimmed) before they are sent: 1–30 names of
/// 1–40 characters, no two alike (ignoring case).
CategoryListProblem? checkExpenseCategories(List<String> names) {
  if (names.isEmpty) return CategoryListProblem.empty;
  if (names.length > maxExpenseCategories) return CategoryListProblem.tooMany;
  if (names.any((n) => n.isEmpty)) return CategoryListProblem.blank;
  if (names.any((n) => n.length > maxExpenseCategoryLength)) {
    return CategoryListProblem.tooLong;
  }
  final seen = <String>{};
  for (final n in names) {
    if (!seen.add(n.toLowerCase())) return CategoryListProblem.duplicate;
  }
  return null;
}

/// `HH:MM` from 00:00 to 23:59.
bool validHandoverDeadline(String value) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
