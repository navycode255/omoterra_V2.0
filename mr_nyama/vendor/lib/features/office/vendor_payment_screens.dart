import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/format.dart';
import '../../core/theme/theme.dart' show MNColors;
import 'vendor_pay_forms.dart';
import 'owner_reference.dart';

/// Presentation models only. Monetary totals must be supplied by the service;
/// attendance is explicit evidence and is never inferred from sales.
/// Routed through vendor_pay_pages, which fetches durable server records.
enum VendorPayFrequency { daily, weekly, monthly }

class VendorPaySummary {
  final String id, name;
  final String? station;
  final VendorPayFrequency? frequency;
  final int? earned, paid, balance;
  final int? due, overpaid;
  final DateTime? nextDue;
  const VendorPaySummary(
      {required this.id,
      required this.name,
      this.station,
      this.frequency,
      this.earned,
      this.paid,
      this.balance,
      this.due,
      this.overpaid,
      this.nextDue});
}

class VendorPayDay {
  final DateTime date;
  final String station;
  final String? salesStations;
  final bool? present;
  final int reportedSales, verifiedSales;
  final int? earned;
  const VendorPayDay(
      {required this.date,
      required this.station,
      required this.present,
      this.salesStations,
      required this.reportedSales,
      required this.verifiedSales,
      required this.earned});
}

class VendorPayContract {
  final String reference;
  final DateTime effectiveFrom;
  final VendorPayFrequency frequency;
  final String agreedTerms;
  final int? dailyRate, commissionBps, payWeekday, payMonthday;
  const VendorPayContract(
      {required this.reference,
      required this.effectiveFrom,
      required this.frequency,
      required this.agreedTerms,
      this.dailyRate,
      this.commissionBps,
      this.payWeekday,
      this.payMonthday});
}

class VendorPayRecord {
  final DateTime paidAt, periodFrom, periodTo;
  final int amount;
  final String method, reference;
  final bool reversed, isReversal, legacy;
  final String? id;
  const VendorPayRecord(
      {required this.paidAt,
      required this.periodFrom,
      required this.periodTo,
      required this.amount,
      required this.method,
      required this.reference,
      this.reversed = false,
      this.isReversal = false,
      this.legacy = false,
      this.id});
}

String _frequency(Strings s, VendorPayFrequency? f) => switch (f) {
      VendorPayFrequency.daily => s.payDaily,
      VendorPayFrequency.weekly => s.payWeekly,
      VendorPayFrequency.monthly => s.payMonthly,
      null => s.payContractMissing,
    };
String _amount(Strings s, int? value) =>
    value == null ? s.payNotCalculated : formatTsh(value);

bool _canView(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn &&
      (auth.profile.isOwner || auth.profile.roles.contains(StaffRole.finance));
}

class VendorPayOverviewScreen extends ConsumerStatefulWidget {
  final List<VendorPaySummary> vendors;
  final int? earned, paid, balance;
  final int? due, overpaid;
  final DateTime asOf;
  final int missingContracts;
  final ValueChanged<String> onOpenVendor;
  final Future<void> Function()? onRefresh;
  final bool showBack;
  final bool financeWorkspace;
  const VendorPayOverviewScreen(
      {super.key,
      required this.vendors,
      required this.earned,
      required this.paid,
      required this.balance,
      this.due,
      this.overpaid,
      required this.asOf,
      this.missingContracts = 0,
      required this.onOpenVendor,
      this.onRefresh,
      this.showBack = true,
      this.financeWorkspace = false});
  @override
  ConsumerState<VendorPayOverviewScreen> createState() =>
      _VendorPayOverviewState();
}

class _VendorPayOverviewState extends ConsumerState<VendorPayOverviewScreen> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (!_canView(ref)) {
      return OwnerPage(
          title: s.vendorPayTitle,
          strings: s,
          showBack: widget.showBack,
          child: Text(s.notAllowed));
    }
    final rows = widget.vendors.where((v) => widget.financeWorkspace
        ? switch (_filter) {
            1 => v.due == 0 && v.earned != null && (v.paid ?? 0) > 0,
            _ => v.due != null && v.due! > 0,
          }
        : switch (_filter) {
            1 => v.balance != null && v.balance! > 0,
            2 => v.balance == 0 && v.earned != null && (v.paid ?? 0) > 0,
            3 => v.frequency == null,
            _ => true,
          });
    return OwnerPage(
        title: s.vendorPayTitle,
        strings: s,
        showBack: widget.showBack,
        onRefresh: widget.onRefresh,
        subtitle: Text(s.payAsOf(s.date(widget.asOf)),
            style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PayTotals(
                      earned: widget.earned,
                      paid: widget.paid,
                      balance: widget.balance,
                      due: widget.due,
                      overpaid: widget.overpaid),
                  if (widget.missingContracts > 0)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            s.payMissingContracts(widget.missingContracts),
                            style: OwnerStyle.text(context, 13,
                                color: OwnerStyle.muted))),
                  const SizedBox(height: 20),
                  if (widget.financeWorkspace)
                    _FinancePaymentSegments(
                        selected: _filter,
                        labels: [s.payUnpaid, s.paySettled],
                        onChanged: (value) => setState(() => _filter = value))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (i, label) in [
                        s.all,
                        s.payUnpaid,
                        s.paySettled,
                        s.payContractMissing
                      ].indexed)
                        ChoiceChip(
                            label: Text(label,
                                style: OwnerStyle.text(context, 13,
                                    color: _filter == i
                                        ? OwnerStyle.white
                                        : OwnerStyle.ink)),
                            selected: _filter == i,
                            selectedColor: OwnerStyle.ink,
                            backgroundColor: OwnerStyle.white,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = i)),
                    ]),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    OwnerCard(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(s.payNoMatches,
                                style: OwnerStyle.text(context, 14,
                                    color: OwnerStyle.muted)))),
                  for (final vendor in rows) ...[
                    OwnerCard(
                        child: Column(children: [
                      OwnerMenuRow(
                          label: vendor.name,
                          subtitle: [
                            if (vendor.station != null) vendor.station!,
                            _frequency(s, vendor.frequency)
                          ].join(' · '),
                          value: _amount(
                              s,
                              widget.financeWorkspace
                                  ? vendor.due
                                  : vendor.balance),
                          valueSize: 15,
                          onTap: () => widget.onOpenVendor(vendor.id)),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _PayLine(
                                    s.payEarned, _amount(s, vendor.earned)),
                                _PayLine(s.payPaid, _amount(s, vendor.paid)),
                                Text(
                                    vendor.frequency == null
                                        ? s.payContractMissing
                                        : (vendor.balance ?? 0) > 0
                                            ? (vendor.paid ?? 0) > 0
                                                ? s.payPartial
                                                : s.payUnpaid
                                            : s.payNothingOwed,
                                    style: OwnerStyle.text(context, 13,
                                        color: OwnerStyle.muted)),
                                if (vendor.nextDue != null)
                                  _PayLine(
                                      s.payNextDue, s.date(vendor.nextDue!)),
                              ])),
                    ])),
                    const SizedBox(height: 12),
                  ],
                ])));
  }
}

class _FinancePaymentSegments extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _FinancePaymentSegments(
      {required this.selected, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: MNColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          for (final (index, label) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == index,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(index),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == index
                          ? MNColors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: OwnerStyle.text(
                        context,
                        14,
                        weight: selected == index ? 600 : 400,
                        color: selected == index
                            ? OwnerStyle.ink
                            : OwnerStyle.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class VendorPayStatementScreen extends ConsumerWidget {
  final VendorPaySummary vendor;
  final DateTime from, to;
  final List<VendorPayDay> days;
  final List<VendorPayContract> contracts;
  final List<VendorPayRecord> payments;
  final VoidCallback onAttendance, onContract, onRecordPayment;
  final VoidCallback? onChangePeriod;
  final Future<void> Function()? onRefresh;
  final ValueChanged<VendorPayDay>? onCorrectAttendance;
  final ValueChanged<VendorPayRecord>? onReversePayment;
  const VendorPayStatementScreen(
      {super.key,
      required this.vendor,
      required this.from,
      required this.to,
      required this.days,
      required this.contracts,
      required this.payments,
      required this.onAttendance,
      required this.onContract,
      required this.onRecordPayment,
      this.onChangePeriod,
      this.onRefresh,
      this.onCorrectAttendance,
      this.onReversePayment});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (!_canView(ref)) {
      return OwnerPage(
          title: s.vendorPayTitle, strings: s, child: Text(s.notAllowed));
    }
    final auth = ref.watch(officeSessionProvider).valueOrNull as OfficeSignedIn;
    Widget heading(String label) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(label, style: OwnerStyle.text(context, 18, weight: 700)));
    return OwnerPage(
        title: vendor.name,
        strings: s,
        onRefresh: onRefresh,
        subtitle: Text('${s.date(from)} – ${s.date(to)}',
            style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.payAllTimeTotals,
                      style: OwnerStyle.text(context, 13,
                          color: OwnerStyle.muted)),
                  const SizedBox(height: 8),
                  _PayTotals(
                      earned: vendor.earned,
                      paid: vendor.paid,
                      balance: vendor.balance,
                      due: vendor.due,
                      overpaid: vendor.overpaid),
                  const SizedBox(height: 16),
                  PayAction(
                      label: s.payRecordPayment,
                      onTap: vendor.balance != null && vendor.balance! > 0
                          ? onRecordPayment
                          : null),
                  if (onChangePeriod != null)
                    PayAction(
                        secondary: true,
                        label: s.payChoosePeriod,
                        onTap: onChangePeriod),
                  heading(s.payAttendanceAndSales),
                  PayAction(
                      secondary: true,
                      label: s.payRecordAttendance,
                      onTap: vendor.frequency == null ? null : onAttendance),
                  if (vendor.frequency == null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(s.paySetContractFirst,
                            style: OwnerStyle.text(context, 13,
                                color: OwnerStyle.muted))),
                  const SizedBox(height: 12),
                  if (days.isEmpty)
                    Text(s.payNoAttendance,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                  for (final day in days) ...[
                    OwnerCard(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('${s.date(day.date)} · ${day.station}',
                                      style: OwnerStyle.text(context, 15,
                                          weight: 600)),
                                  const SizedBox(height: 8),
                                  _PayLine(
                                      s.payAttendance,
                                      day.present == null
                                          ? s.payAttendanceUnknown
                                          : day.present!
                                              ? s.payPresent
                                              : s.payAbsent),
                                  if (day.salesStations != null &&
                                      day.salesStations != day.station)
                                    _PayLine(
                                        s.paySalesStations, day.salesStations!),
                                  _PayLine(s.payReportedSales,
                                      formatTsh(day.reportedSales)),
                                  _PayLine(s.payVerifiedSales,
                                      formatTsh(day.verifiedSales)),
                                  _PayLine(s.payEarned, _amount(s, day.earned)),
                                  if (onCorrectAttendance != null &&
                                      day.present != null)
                                    TextButton(
                                        onPressed: () =>
                                            onCorrectAttendance!(day),
                                        child: Text(s.payCorrectAttendance,
                                            style: OwnerStyle.text(context, 13,
                                                color: OwnerStyle.red))),
                                ]))),
                    const SizedBox(height: 10),
                  ],
                  heading(s.payContracts),
                  if (auth.profile.isOwner)
                    PayAction(
                        secondary: true,
                        label: s.paySetContract,
                        onTap: onContract),
                  const SizedBox(height: 12),
                  if (contracts.isEmpty)
                    Text(s.payContractMissing,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                  for (final contract in contracts) ...[
                    OwnerCard(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(contract.reference,
                                      style: OwnerStyle.text(context, 15,
                                          weight: 600)),
                                  _PayLine(s.payFrequency,
                                      _frequency(s, contract.frequency)),
                                  if (contract.dailyRate != null)
                                    _PayLine(s.payDailyRate,
                                        formatTsh(contract.dailyRate!)),
                                  if (contract.commissionBps != null)
                                    _PayLine(
                                        s.payCommissionPercent,
                                        s.payPercent(
                                            '${contract.commissionBps! ~/ 100}.${(contract.commissionBps! % 100).toString().padLeft(2, '0')}')),
                                  if (contract.payWeekday != null)
                                    _PayLine(s.payWeekday,
                                        s.payWeekdayName(contract.payWeekday!)),
                                  if (contract.payMonthday != null)
                                    _PayLine(s.payMonthday,
                                        '${contract.payMonthday}'),
                                  _PayLine(s.payEffectiveFrom,
                                      s.date(contract.effectiveFrom)),
                                  Text(contract.agreedTerms,
                                      style: OwnerStyle.text(context, 14,
                                          color: OwnerStyle.muted)),
                                ]))),
                    const SizedBox(height: 10),
                  ],
                  heading(s.payHistory),
                  if (payments.isEmpty)
                    Text(s.payNoPayments,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                  for (final payment in payments) ...[
                    OwnerCard(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PayLine(s.date(payment.paidAt),
                                      formatTsh(payment.amount)),
                                  Text(
                                      '${payment.method} · ${payment.reference}',
                                      style: OwnerStyle.text(context, 13,
                                          color: OwnerStyle.muted)),
                                  Text(
                                      '${s.date(payment.periodFrom)} – ${s.date(payment.periodTo)}',
                                      style: OwnerStyle.text(context, 13,
                                          color: OwnerStyle.muted)),
                                  if (onReversePayment != null &&
                                      payment.id != null &&
                                      !payment.reversed &&
                                      !payment.isReversal &&
                                      !payment.legacy)
                                    TextButton(
                                        onPressed: () =>
                                            onReversePayment!(payment),
                                        child: Text(s.payReverse,
                                            style: OwnerStyle.text(context, 13,
                                                color: OwnerStyle.red))),
                                  if (payment.isReversal || payment.reversed)
                                    Text(s.payReversed,
                                        style: OwnerStyle.text(context, 13,
                                            color: OwnerStyle.muted)),
                                ]))),
                    const SizedBox(height: 10),
                  ],
                ])));
  }
}

class _PayLine extends StatelessWidget {
  final String label, value;
  const _PayLine(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(label,
                style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
            Text(value, style: OwnerStyle.text(context, 14, weight: 600)),
          ]));
}

class _PayTotals extends ConsumerWidget {
  final int? earned, paid, balance;
  final int? due, overpaid;
  const _PayTotals(
      {required this.earned,
      required this.paid,
      required this.balance,
      this.due,
      this.overpaid});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerCard(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.payBalance,
                      style: OwnerStyle.text(context, 14,
                          color: OwnerStyle.muted)),
                  const SizedBox(height: 8),
                  Text(_amount(s, balance),
                      style: OwnerStyle.text(context, 28, weight: 700)),
                  const SizedBox(height: 16),
                  const Divider(color: OwnerStyle.line),
                  const SizedBox(height: 12),
                  _PayLine(s.payEarned, _amount(s, earned)),
                  _PayLine(s.payPaid, _amount(s, paid)),
                  if (due != null) _PayLine(s.payDueNow, _amount(s, due)),
                  if (overpaid != null && overpaid! > 0)
                    _PayLine(s.payOverpaid, _amount(s, overpaid)),
                ])));
  }
}
