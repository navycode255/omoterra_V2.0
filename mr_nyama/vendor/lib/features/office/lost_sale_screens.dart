import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_lost_sales.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'credit_screens.dart' show officeCreditCustomersProvider;
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;

/// Lost sale entries (MN036). One person asks, a different finance person or the
/// owner decides; the server checks both. Nothing here makes a sale: the server
/// records it only on approval, and it then waits for normal verification.

Future<T> _lost<T>(WidgetRef ref, Future<T> Function(OfficeLostSalesRepository) call) =>
    ref.read(officeSessionProvider.notifier).guard((r) => call(r as OfficeLostSalesRepository));

/// A vendor's requests, newest first (the vendor page).
final vendorLostSalesProvider = FutureProvider.autoDispose
    .family<List<LostSaleEntry>, String>((ref, vendorId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => (r as OfficeLostSalesRepository).lostSaleEntries(vendorId: vendorId)));

/// A station's open requests (the Uthibitisho section).
final stationLostSalesProvider = FutureProvider.autoDispose
    .family<List<LostSaleEntry>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) async => r is OfficeLostSalesRepository
            ? await (r as OfficeLostSalesRepository)
                .lostSaleEntries(stationId: stationId, status: 'open')
            : const <LostSaleEntry>[]));

final _lostSaleDayProvider = FutureProvider.autoDispose
    .family<LostSaleDay, (String, String)>((ref, key) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => (r as OfficeLostSalesRepository).lostSaleDay(key.$1, key.$2)));

/// Finance and the owner decide (`sales.backdate_decide`); the server checks.
bool canDecideLostSales(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  return roles.any({StaffRole.finance, StaffRole.owner}.contains);
}

String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _showDay(Strings s, String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : s.date(d);
}

// The vendor page's list ----------------------------------------------------------------

class LostSalesScreen extends ConsumerWidget {
  final String vendorId;
  const LostSalesScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(vendorLostSalesProvider(vendorId));
    double u(double n) => OwnerStyle.px(context, n);
    void changed() => ref.invalidate(vendorLostSalesProvider(vendorId));
    return OwnerPage(
        title: s.lostSalesTitle,
        strings: s,
        onRefresh: () => ref.refresh(vendorLostSalesProvider(vendorId).future),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MNNote(s.lostSaleHelp, tone: MNNoteTone.info),
          SizedBox(height: u(12)),
          MNButton(s.lostSaleNew, onPressed: () async {
            final sent = await context.push<bool>(MNRoutes.officeLostSaleNew(vendorId));
            if (sent != true) return;
            changed();
            if (context.mounted) _toast(context, s.lostSaleSent);
          }),
          SizedBox(height: u(12)),
          OwnerAsyncView<List<LostSaleEntry>>(
              value: value,
              onRetry: changed,
              isEmpty: (rows) => rows.isEmpty,
              empty: (_) => MNNote(s.lostSalesNone, tone: MNNoteTone.info),
              data: (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in rows) ...[
                      LostSaleCard(row: row, onChanged: changed),
                      SizedBox(height: u(8)),
                    ],
                  ])),
        ]));
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// The Uthibitisho section ---------------------------------------------------------------

/// "Mauzo yaliyopotea": open requests at the station, for those who decide them,
/// only while there are some.
class LostSaleRequestsSection extends ConsumerWidget {
  final String stationId;
  final VoidCallback onChanged;
  const LostSaleRequestsSection(
      {super.key, required this.stationId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canDecideLostSales(ref)) return const SizedBox.shrink();
    final value = ref.watch(stationLostSalesProvider(stationId));
    double u(double n) => OwnerStyle.px(context, n);
    // A failed load says so; hiding it would look like there is no request.
    if (value.hasError && !value.hasValue) {
      return Padding(
          padding: EdgeInsets.fromLTRB(u(12), u(8), u(12), u(8)),
          child: OwnerAsyncView<List<LostSaleEntry>>(
              value: value,
              onRetry: () => ref.invalidate(stationLostSalesProvider(stationId)),
              data: (_) => const SizedBox.shrink()));
    }
    final rows = value.valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    return Padding(
        padding: EdgeInsets.fromLTRB(u(12), u(8), u(12), u(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.lostSalesTitle, style: OwnerStyle.text(context, 17, weight: 600)),
          SizedBox(height: u(8)),
          for (final row in rows) ...[
            LostSaleCard(
                row: row,
                onChanged: () {
                  ref.invalidate(stationLostSalesProvider(stationId));
                  onChanged();
                }),
            SizedBox(height: u(8)),
          ],
        ]));
  }
}

class LostSaleCard extends ConsumerWidget {
  final LostSaleEntry row;
  final VoidCallback onChanged;
  const LostSaleCard({super.key, required this.row, required this.onChanged});

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecideSheet(row: row, approve: approve));
    if (done != true) return;
    onChanged();
    if (context.mounted) _toast(context, s.lostSaleDecided);
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final yes = await showMNConfirmDialog(context,
        title: s.lostSaleWithdraw,
        message: s.lostSaleWithdrawBody,
        confirmLabel: s.lostSaleWithdrawYes,
        cancelLabel: s.cancel,
        sheet: true);
    if (!yes || !context.mounted) return;
    String message = s.lostSaleWithdrawn;
    try {
      await _lost(ref, (r) => r.withdrawLostSale(row.id));
      onChanged();
    } catch (error) {
      message = officeErrorText(s, error);
    }
    if (context.mounted) _toast(context, message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final body = OwnerStyle.text(context, 14);
    final meta = OwnerStyle.text(context, 13, color: OwnerStyle.muted);
    final today = businessDate(ref.watch(clockProvider)());
    final asked = row.requestedAt;
    final color = switch (row.status) {
      'approved' when row.saleCancelled => MNColors.error,
      'approved' => MNColors.success,
      'rejected' => MNColors.error,
      'withdrawn' => OwnerStyle.muted,
      _ => MNColors.warning,
    };
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(u(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${row.vendorName} · ${_showDay(s, row.businessDate)}',
                  style: OwnerStyle.text(context, 16, weight: 600)),
              Text(row.stationName, style: meta),
              for (final l in row.lines)
                Text('${l.quantity} × ${l.name} · ${formatTsh(l.amount)}', style: body),
              Text(formatTsh(row.total), style: OwnerStyle.text(context, 15, weight: 600)),
              Text(s.paymentMethodName(row.paymentMethod, customer: row.customer), style: meta),
              Text(row.saleCancelled ? s.lostSaleCancelled : s.lostSaleStatus(row.status),
                  style: OwnerStyle.text(context, 13, weight: 600, color: color)),
              if (row.isOpen && asked != null)
                Text(s.lostSaleAge(today.difference(businessDate(asked)).inDays), style: meta),
              if (row.requestedBy != null) Text(s.lostSaleAskedBy(row.requestedBy!), style: meta),
              Text(row.reason, style: body),
              if (row.decidedBy != null) Text(s.lostSaleDecidedBy(row.decidedBy!), style: meta),
              if (row.decisionReason != null && row.decidedBy != null)
                Text(row.decisionReason!, style: body),
              if (row.isOpen) ...[
                SizedBox(height: u(8)),
                if (row.requestedByMe) ...[
                  MNNote(s.lostSaleOtherDecides, tone: MNNoteTone.info),
                  SizedBox(height: u(8)),
                  MNButton.secondary(s.lostSaleWithdraw,
                      onPressed: () => _withdraw(context, ref)),
                ] else if (canDecideLostSales(ref)) ...[
                  MNButton(s.lostSaleApprove, onPressed: () => _decide(context, ref, true)),
                  SizedBox(height: u(8)),
                  MNButton.secondary(s.lostSaleReject, onPressed: () => _decide(context, ref, false)),
                ],
              ],
            ])));
  }
}

class _DecideSheet extends ConsumerStatefulWidget {
  final LostSaleEntry row;
  final bool approve;
  const _DecideSheet({required this.row, required this.approve});
  @override
  ConsumerState<_DecideSheet> createState() => _DecideState();
}

class _DecideState extends ConsumerState<_DecideSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _lost(ref, (r) => r.decideLostSale(widget.row.id,
          approve: widget.approve, reason: _reason.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final label = widget.approve ? s.lostSaleApprove : s.lostSaleReject;
    return MNSheet(title: label, children: [
      if (widget.approve) ...[
        MNNote(s.lostSaleApproveNote, tone: MNNoteTone.info),
        if (widget.row.isCash)
          MNNote(s.lostSaleCashWarning(formatTsh(widget.row.total)), tone: MNNoteTone.warning),
        if (!widget.row.dayCounted)
          MNNote(s.lostSaleMissedDayWarning, tone: MNNoteTone.warning),
      ],
      MNTextField(
          label: s.lostSaleDecisionReason,
          controller: _reason,
          enabled: !_busy,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(label,
          busy: _busy,
          onPressed: _reason.text.trim().length >= 3 && !_busy ? _save : null),
    ]);
  }
}

// The form ------------------------------------------------------------------------------

class LostSaleFormScreen extends ConsumerStatefulWidget {
  final String vendorId;
  const LostSaleFormScreen({super.key, required this.vendorId});
  @override
  ConsumerState<LostSaleFormScreen> createState() => _LostSaleFormState();
}

class _LostSaleFormState extends ConsumerState<LostSaleFormScreen> {
  // One id per request; kept while the details are unchanged so a retry is safe.
  String _clientId = const Uuid().v4();
  String? _sentAs;
  DateTime? _date;
  final _quantities = <String, int>{};
  String _payment = 'cash';
  String? _customerId;
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final s = ref.read(stringsProvider);
    final today = businessDate(ref.read(clockProvider)());
    final yesterday = today.subtract(const Duration(days: 1));
    final picked = await showMNDateSheet(context,
        initial: _date ?? yesterday,
        first: today.subtract(const Duration(days: 31)),
        last: yesterday,
        title: s.lostSaleDate);
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      // A different day has its own station and prices.
      _quantities.clear();
      _customerId = null;
      _error = null;
    });
  }

  Future<void> _send(LostSaleDay day) async {
    final s = ref.read(stringsProvider);
    final quantities = {
      for (final e in _quantities.entries)
        if (e.value > 0) e.key: e.value
    };
    final reason = _reason.text.trim();
    String? problem;
    if (quantities.isEmpty) {
      problem = s.lostSaleNeedsProduct;
    } else if (reason.length < 10) {
      problem = s.lostSaleReasonShort;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final codes = quantities.keys.toList()..sort();
    final details = [
      day.businessDate,
      day.stationId,
      _payment,
      _customerId ?? '',
      for (final code in codes) '$code:${quantities[code]}',
      reason
    ].join('|');
    if (_sentAs != null && _sentAs != details) _clientId = const Uuid().v4();
    _sentAs = details;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _lost(ref, (r) => r.askLostSale(
          clientId: _clientId,
          vendorId: widget.vendorId,
          stationId: day.stationId,
          businessDate: day.businessDate,
          paymentMethod: _payment,
          customerId: _payment == 'credit' ? _customerId : null,
          quantities: quantities,
          reason: reason));
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dayForm(BuildContext context, Strings s, LostSaleDay day) {
    double u(double n) => OwnerStyle.px(context, n);
    final meta = OwnerStyle.text(context, 13, color: OwnerStyle.muted);
    final prices = {for (final p in day.products) p.code: p};
    final chosen = [
      for (final p in day.products)
        if ((_quantities[p.code] ?? 0) > 0) p
    ];
    final total = chosen.fold<int>(0, (sum, p) => sum + p.unitPrice * _quantities[p.code]!);
    final customers = _payment == 'credit'
        ? ref.watch(officeCreditCustomersProvider(day.stationId)).valueOrNull ?? const []
        : const [];
    final ready = chosen.isNotEmpty && (_payment == 'cash' || _customerId != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(day.stationName, style: OwnerStyle.text(context, 15, weight: 600)),
      if (!day.otherDecider) ...[
        SizedBox(height: u(8)),
        MNNote(s.lostSaleNoDecider, tone: MNNoteTone.warning),
      ],
      SizedBox(height: u(12)),
      Text(s.lostSaleProducts, style: OwnerStyle.text(context, 17, weight: 600)),
      Text(s.lostSaleOnlyPriced, style: meta),
      SizedBox(height: u(8)),
      if (day.products.isEmpty)
        MNNote(s.lostSaleNoProducts, tone: MNNoteTone.warning)
      else
        OwnerCard(
            child: Column(children: [
          for (final p in day.products)
            Padding(
                padding: EdgeInsets.symmetric(horizontal: u(12), vertical: u(4)),
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: OwnerStyle.text(context, 15, weight: 600)),
                    Text(formatTsh(p.unitPrice), style: meta),
                  ])),
                  MNQuantitySelector(
                      compact: true,
                      itemLabel: p.name,
                      value: _quantities[p.code] ?? 0,
                      onChanged: _busy
                          ? (_) {}
                          : (v) => setState(() => _quantities[p.code] = v)),
                ])),
        ])),
      SizedBox(height: u(12)),
      MNSelectField<String>(
          label: s.lostSalePayment,
          value: _payment,
          options: [
            MNSelectOption(value: 'cash', label: s.cash),
            MNSelectOption(value: 'credit', label: s.credit),
          ],
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    _payment = v;
                    _customerId = null;
                  })),
      if (_payment == 'credit') ...[
        SizedBox(height: u(8)),
        MNSelectField<String>(
            label: s.lostSaleCustomer,
            value: _customerId,
            emptyText: s.lostSaleNoCustomers,
            options: [
              for (final c in customers) MNSelectOption(value: c.id as String, label: c.name as String)
            ],
            onChanged: _busy ? null : (v) => setState(() => _customerId = v)),
      ],
      SizedBox(height: u(12)),
      MNTextField(
          label: s.lostSaleReason,
          controller: _reason,
          enabled: !_busy,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (chosen.isNotEmpty) ...[
        SizedBox(height: u(12)),
        Text(s.lostSaleSummary, style: OwnerStyle.text(context, 17, weight: 600)),
        for (final p in chosen)
          Text('${_quantities[p.code]} × ${prices[p.code]!.name} · '
              '${formatTsh(p.unitPrice * _quantities[p.code]!)}',
              style: OwnerStyle.text(context, 14)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s.lostSaleTotal, style: OwnerStyle.text(context, 15, weight: 600)),
          Text(formatTsh(total), style: OwnerStyle.text(context, 15, weight: 600)),
        ]),
      ],
      if (_error != null) ...[
        SizedBox(height: u(8)),
        MNNote(_error!, error: true),
      ],
      SizedBox(height: u(12)),
      MNButton(s.lostSaleSend,
          busy: _busy, onPressed: ready && !_busy ? () => _send(day) : null),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final key = _date == null ? null : (widget.vendorId, _dateKey(_date!));
    final value = key == null ? null : ref.watch(_lostSaleDayProvider(key));
    final error = value?.error;
    return OwnerPage(
        title: s.lostSaleNew,
        strings: s,
        onRefresh: key == null ? null : () => ref.refresh(_lostSaleDayProvider(key).future),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MNNote(s.lostSaleHelp, tone: MNNoteTone.info),
          SizedBox(height: u(12)),
          OwnerCard(
              child: OwnerMenuRow(
                  label: s.lostSaleDate,
                  value: _date == null ? s.lostSaleChooseDate : s.date(_date!),
                  onTap: _busy ? null : _pickDate)),
          SizedBox(height: u(12)),
          if (value != null)
            // A refused day is an answer, not a failed load.
            if (error is OfficeError && error.kind == OfficeErrorKind.refused)
              MNNote(officeErrorText(s, error), tone: MNNoteTone.warning)
            else
              OwnerAsyncView<LostSaleDay>(
                  value: value,
                  onRetry: () => ref.invalidate(_lostSaleDayProvider(key!)),
                  data: (day) => _dayForm(context, s, day)),
        ]));
  }
}
