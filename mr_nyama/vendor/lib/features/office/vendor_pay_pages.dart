import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/states.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../shared/widgets/date_sheet.dart';
import 'owner_reference.dart';
import 'vendor_pay_data.dart';
import 'vendor_pay_forms.dart';
import 'vendor_payment_screens.dart';

bool _allowed(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn &&
      (auth.profile.isOwner || auth.profile.roles.contains(StaffRole.finance));
}

Widget _loadPage(
        BuildContext context, Strings s, Object? error, VoidCallback retry,
        {bool showBack = true}) =>
    OwnerPage(
        title: s.vendorPayTitle,
        strings: s,
        showBack: showBack,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    MNErrorState(
                        error: error,
                        message: error is OfficeError &&
                                error.kind == OfficeErrorKind.notFound
                            ? s.payServerUpdate
                            : s.payLoadFailed,
                        onRetry: retry),
                ])));

class VendorPaymentsScreen extends ConsumerWidget {
  final bool showBack;
  final bool financeWorkspace;
  const VendorPaymentsScreen(
      {super.key, this.showBack = true, this.financeWorkspace = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (!_allowed(ref)) {
      return OwnerPage(
          title: s.vendorPayTitle,
          strings: s,
          showBack: showBack,
          child: Text(s.notAllowed));
    }
    final data = ref.watch(vendorPayOverviewProvider);
    return data.when(
        loading: () => _loadPage(
            context, s, null, () => ref.invalidate(vendorPayOverviewProvider),
            showBack: showBack),
        error: (e, _) => _loadPage(
            context, s, e, () => ref.invalidate(vendorPayOverviewProvider),
            showBack: showBack),
        data: (snapshot) {
          try {
            return VendorPayOverviewScreen(
                vendors: payRows(snapshot['vendors']).map(paySummary).toList(),
                earned: payInt(snapshot['earned']),
                paid: payInt(snapshot['paid']),
                balance: payInt(snapshot['balance']),
                due: payInt(snapshot['due']),
                overpaid: payInt(snapshot['overpaid']),
                asOf: DateTime.parse(snapshot['as_of'] as String),
                missingContracts: payInt(snapshot['missing_contracts']) ?? 0,
                onRefresh: () async {
                  ref.invalidate(vendorPayOverviewProvider);
                  await ref.read(vendorPayOverviewProvider.future);
                },
                showBack: showBack,
                financeWorkspace: financeWorkspace,
                onOpenVendor: (id) =>
                    context.push(MNRoutes.officeVendorPay(id)));
          } catch (e) {
            return _loadPage(
                context, s, e, () => ref.invalidate(vendorPayOverviewProvider),
                showBack: showBack);
          }
        });
  }
}

class VendorPaymentStatementScreen extends ConsumerStatefulWidget {
  final String vendor;
  const VendorPaymentStatementScreen({super.key, required this.vendor});
  @override
  ConsumerState<VendorPaymentStatementScreen> createState() =>
      _VendorStatementState();
}

class _VendorStatementState
    extends ConsumerState<VendorPaymentStatementScreen> {
  late DateTime _to = businessDate(ref.read(clockProvider)());
  late DateTime _from = DateTime.utc(_to.year, _to.month, 1);
  PayStatementKey get key =>
      (vendor: widget.vendor, from: moneyDateKey(_from), to: moneyDateKey(_to));
  Future<void> form(VendorPayFormKind kind,
      {Map<String, dynamic>? attendance, String? paymentId}) async {
    final ok = await showVendorPayForm(context,
        vendor: widget.vendor,
        kind: kind,
        from: _from,
        to: _to,
        attendance: attendance,
        paymentId: paymentId);
    if (ok == true) {
      ref.invalidate(vendorPayStatementProvider(key));
      ref.invalidate(vendorPayOverviewProvider);
    }
  }

  Future<void> choosePeriod() async {
    final range = await showMNDateRangeSheet(context,
        titleStyle: OwnerStyle.text(context, 22, weight: 700),
        start: _from,
        end: _to,
        first: DateTime.utc(2020),
        last: businessDate(ref.read(clockProvider)()));
    if (range != null && mounted) {
      final (start, end) = range;
      if (end.difference(start).inDays > 366) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(stringsProvider).payMaxPeriod)));
        return;
      }
      setState(() {
        _from = start;
        _to = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (!_allowed(ref)) {
      return OwnerPage(
          title: s.vendorPayTitle, strings: s, child: Text(s.notAllowed));
    }
    final data = ref.watch(vendorPayStatementProvider(key));
    return data.when(
        loading: () => _loadPage(context, s, null,
            () => ref.invalidate(vendorPayStatementProvider(key))),
        error: (e, _) => _loadPage(context, s, e,
            () => ref.invalidate(vendorPayStatementProvider(key))),
        data: (snapshot) {
          try {
            final rawDays = payRows(snapshot['days']);
            final rawPayments = payRows(snapshot['payments']);
            return VendorPayStatementScreen(
                vendor: paySummary(payMap(snapshot['vendor'])),
                from: _from,
                to: _to,
                days: [
                  for (final d in rawDays)
                    VendorPayDay(
                        date: DateTime.parse(d['date'] as String),
                        station: d['station'] as String? ?? s.payStationUnknown,
                        present: d['present'] as bool?,
                        salesStations: d['sales_stations'] as String?,
                        reportedSales: payInt(d['reported_sales'])!,
                        verifiedSales: payInt(d['verified_sales'])!,
                        earned: payInt(d['earned']))
                ],
                contracts: [
                  for (final c in payRows(snapshot['contracts']))
                    VendorPayContract(
                        reference: c['reference'] as String,
                        effectiveFrom:
                            DateTime.parse(c['effective_from'] as String),
                        frequency: payFrequency(c['frequency'])!,
                        agreedTerms: c['terms'] as String,
                        dailyRate: payInt(c['daily_rate']),
                        commissionBps: payInt(c['commission_bps']),
                        payWeekday: payInt(c['pay_weekday']),
                        payMonthday: payInt(c['pay_monthday']))
                ],
                payments: [
                  for (final p in rawPayments)
                    VendorPayRecord(
                        id: p['id'] as String,
                        paidAt: businessDate(
                            DateTime.parse(p['paid_at'] as String)),
                        periodFrom: DateTime.parse(p['period_from'] as String),
                        periodTo: DateTime.parse(p['period_to'] as String),
                        amount: payInt(p['amount'])!,
                        method: switch (p['method']) {
                          'cash' => s.cash,
                          'mpesa' => s.mpesaShort,
                          _ => s.payOtherMethod
                        },
                        reference: p['reference'] as String,
                        reversed: p['reversed'] as bool,
                        isReversal: p['is_reversal'] as bool,
                        legacy: p['legacy_bonus'] == true)
                ],
                onAttendance: () => form(VendorPayFormKind.attendance),
                onContract: () => form(VendorPayFormKind.contract),
                onRecordPayment: () => form(VendorPayFormKind.payment),
                onChangePeriod: choosePeriod,
                onRefresh: () async {
                  ref.invalidate(vendorPayStatementProvider(key));
                  await ref.read(vendorPayStatementProvider(key).future);
                },
                onCorrectAttendance: (day) {
                  final d = rawDays
                      .firstWhere((d) => d['date'] == moneyDateKey(day.date));
                  if (d['attendance'] != null) {
                    form(VendorPayFormKind.attendance,
                        attendance: payMap(d['attendance']));
                  } else {
                    form(VendorPayFormKind.attendance);
                  }
                },
                onReversePayment: (p) =>
                    form(VendorPayFormKind.reversal, paymentId: p.id));
          } catch (e) {
            return _loadPage(context, s, e,
                () => ref.invalidate(vendorPayStatementProvider(key)));
          }
        });
  }
}
