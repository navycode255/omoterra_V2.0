// What each vendor owes across days (Phase 6, VR3), the money status of each
// vendor-day, balance adjustments (MN019) and the finance exports. The
// server computes every figure and status; the app only shows them.

import 'dart:convert';
import 'dart:typed_data';

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

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

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

/// The money status of a vendor-day (financial architecture §4).
enum MoneyStatus {
  nothingDue('nothing_due'),
  outstanding('outstanding'),
  partReceived('part_received'),
  settled('settled'),
  unresolved('unresolved');

  final String wire;
  const MoneyStatus(this.wire);

  static MoneyStatus? parse(Object? v) =>
      values.where((s) => s.wire == v).firstOrNull;
}

/// One vendor's balance (`GET /staff/money/balances`, and the head of
/// `GET /staff/money/vendors/{id}`).
class OfficeVendorBalance {
  final MoneyParty vendor;
  final MoneyParty? station;
  final int owed, credit;
  final DateTime? oldestOutstanding;
  final int? ageDays;
  final int unconfirmedHandovers, unverifiedCashSales;
  final int pendingVendorExpenses, pendingAdjustments, unresolvedDays;
  final int collected, confirmed, debits, credits;
  const OfficeVendorBalance(
      {required this.vendor,
      this.station,
      this.owed = 0,
      this.credit = 0,
      this.oldestOutstanding,
      this.ageDays,
      this.unconfirmedHandovers = 0,
      this.unverifiedCashSales = 0,
      this.pendingVendorExpenses = 0,
      this.pendingAdjustments = 0,
      this.unresolvedDays = 0,
      this.collected = 0,
      this.confirmed = 0,
      this.debits = 0,
      this.credits = 0});

  factory OfficeVendorBalance.fromJson(Map<String, dynamic> j) =>
      OfficeVendorBalance(
          vendor: MoneyParty.fromJson(j['vendor']) ??
              const MoneyParty(id: '', name: ''),
          station: MoneyParty.fromJson(j['station']),
          owed: _int(j['owed']),
          credit: _int(j['credit']),
          oldestOutstanding: _day(j['oldest_outstanding']),
          ageDays: _intOrNull(j['age_days']),
          unconfirmedHandovers: _int(j['unconfirmed_handovers']),
          unverifiedCashSales: _int(j['unverified_cash_sales']),
          pendingVendorExpenses: _int(j['pending_vendor_expenses']),
          pendingAdjustments: _int(j['pending_adjustments']),
          unresolvedDays: _int(j['unresolved_days']),
          collected: _int(j['collected']),
          confirmed: _int(j['confirmed']),
          debits: _int(j['debits']),
          credits: _int(j['credits']));
}

/// One vendor-day in a vendor's money.
class OfficeBalanceDay {
  final DateTime? businessDate;
  final MoneyParty? station;
  final int verifiedCashSales, unverifiedCashSales, verifiedMpesaSales;
  final int creditRepaymentsCash, approvedVendorExpenses;
  final int collected, debits, credits, due;
  final int handedOver, confirmed, unconfirmed, applied, remaining;
  final MoneyStatus? status;
  const OfficeBalanceDay(
      {this.businessDate,
      this.station,
      this.verifiedCashSales = 0,
      this.unverifiedCashSales = 0,
      this.verifiedMpesaSales = 0,
      this.creditRepaymentsCash = 0,
      this.approvedVendorExpenses = 0,
      this.collected = 0,
      this.debits = 0,
      this.credits = 0,
      this.due = 0,
      this.handedOver = 0,
      this.confirmed = 0,
      this.unconfirmed = 0,
      this.applied = 0,
      this.remaining = 0,
      this.status});

  factory OfficeBalanceDay.fromJson(Map<String, dynamic> j) => OfficeBalanceDay(
      businessDate: _day(j['business_date']),
      station: MoneyParty.fromJson(j['station']),
      verifiedCashSales: _int(j['verified_cash_sales']),
      unverifiedCashSales: _int(j['unverified_cash_sales']),
      verifiedMpesaSales: _int(j['verified_mpesa_sales']),
      creditRepaymentsCash: _int(j['credit_repayments_cash']),
      approvedVendorExpenses: _int(j['approved_vendor_expenses']),
      collected: _int(j['collected']),
      debits: _int(j['debits']),
      credits: _int(j['credits']),
      due: _int(j['due']),
      handedOver: _int(j['handed_over']),
      confirmed: _int(j['confirmed']),
      unconfirmed: _int(j['unconfirmed']),
      applied: _int(j['applied']),
      remaining: _int(j['remaining']),
      status: MoneyStatus.parse(j['money_status']));
}

/// The kinds of balance adjustment (MN019). A correction goes the other way
/// from the adjustment it names.
enum AdjustmentKind {
  stockCharge('stock_charge', 'debit'),
  priceShortfall('price_shortfall', 'debit'),
  writeOff('write_off', 'credit'),
  correction('correction', null);

  final String wire;

  /// The direction this kind always has; null for a correction.
  final String? direction;
  const AdjustmentKind(this.wire, this.direction);

  static AdjustmentKind? parse(Object? v) =>
      values.where((k) => k.wire == v).firstOrNull;
}

class OfficeAdjustment {
  final String id;
  final MoneyParty? vendor, station, requestedBy, decidedBy;
  final DateTime? businessDate, decidedAt, createdAt;
  final String direction;
  final AdjustmentKind? kind;
  final int amount;
  final String reason;
  final String? basisRef, correctsId, decisionReason;
  final String status;
  const OfficeAdjustment(
      {required this.id,
      this.vendor,
      this.station,
      this.requestedBy,
      this.decidedBy,
      this.businessDate,
      this.decidedAt,
      this.createdAt,
      this.direction = 'debit',
      this.kind,
      this.amount = 0,
      this.reason = '',
      this.basisRef,
      this.correctsId,
      this.decisionReason,
      this.status = 'pending'});

  bool get pending => status == 'pending';
  bool get approved => status == 'approved';
  bool get debit => direction == 'debit';

  factory OfficeAdjustment.fromJson(Map<String, dynamic> j) => OfficeAdjustment(
      id: _str(j['id']),
      vendor: MoneyParty.fromJson(j['vendor']),
      station: MoneyParty.fromJson(j['station']),
      requestedBy: MoneyParty.fromJson(j['requested_by']),
      decidedBy: MoneyParty.fromJson(j['decided_by']),
      businessDate: _day(j['business_date']),
      decidedAt: _time(j['decided_at']),
      createdAt: _time(j['created_at']),
      direction: _str(j['direction']),
      kind: AdjustmentKind.parse(j['kind']),
      amount: _int(j['amount']),
      reason: _str(j['reason']),
      basisRef: _opt(j['basis_ref']),
      correctsId: _opt(j['corrects_id']),
      decisionReason: _opt(j['decision_reason']),
      status: _opt(j['status']) ?? 'pending');
}

/// A vendor's money: the balance, recent days (newest first) and adjustments.
class OfficeVendorMoney {
  final OfficeVendorBalance balance;
  final List<OfficeBalanceDay> days;
  final List<OfficeAdjustment> adjustments;
  const OfficeVendorMoney(
      {required this.balance,
      this.days = const [],
      this.adjustments = const []});

  factory OfficeVendorMoney.fromJson(Map<String, dynamic> j) =>
      OfficeVendorMoney(balance: OfficeVendorBalance.fromJson(j), days: [
        for (final d in _rows(j['days'])) OfficeBalanceDay.fromJson(d)
      ], adjustments: [
        for (final a in _rows(j['adjustments'])) OfficeAdjustment.fromJson(a)
      ]);
}

/// What finance can download as CSV.
enum MoneyExportKind {
  days('days'),
  balances('balances'),
  handovers('handovers'),
  adjustments('adjustments');

  final String wire;
  const MoneyExportKind(this.wire);
}

class MoneyExport {
  final String filename;
  final Uint8List bytes;
  final int rows;
  const MoneyExport(
      {required this.filename, required this.bytes, required this.rows});

  factory MoneyExport.fromJson(Map<String, dynamic> j) => MoneyExport(
      filename: _opt(j['filename']) ?? 'mr_nyama.csv',
      bytes: base64Decode(_str(j['content_base64'])),
      rows: _int(j['rows']));
}

abstract interface class OfficeBalancesRepository {
  Future<List<OfficeVendorBalance>> vendorBalances({String? stationId});
  Future<OfficeVendorMoney> vendorMoney(String vendorId);
  Future<List<OfficeAdjustment>> adjustments(
      {String? status, String? vendorId});

  /// Finance or the owner; decided by someone else. [clientId] makes a
  /// retry after no answer record one adjustment.
  Future<OfficeAdjustment> requestAdjustment(
      {required String clientId,
      required String vendorId,
      required String businessDate,
      required AdjustmentKind kind,
      required String direction,
      required int amount,
      required String reason,
      required String basisRef,
      String? correctsId});
  Future<OfficeAdjustment> decideAdjustment(String id,
      {required bool approve, required String reason});
  Future<MoneyExport> moneyExport(MoneyExportKind kind,
      {required String from, required String to, String? stationId});
}
