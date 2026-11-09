import 'owner_widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client_id.dart';
import '../../core/api/office_approvals.dart' show OfficeApprovalsRepository;
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/expense_fields.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/select_field.dart' show MNFieldButton;
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../owner/auto_verify_settings_screen.dart';
import 'balance_screens.dart'
    show BalancesSection, MoneyExportEntry, vendorBalancesProvider;
import 'offline_settings_card.dart';
import 'office_money_providers.dart';
import 'money_formatting.dart';
import 'owner_reference.dart';
import 'office_errors.dart';
import 'supply_request_screens.dart' show SupplyOutstandingSection;
import 'stock_screens.dart' show OfficeLateEntryCard;
import 'verification_screens.dart' show verificationQueueProvider;

export 'office_money_providers.dart';

/// Station money for supervisors, finance and the owner: the cash each
/// vendor owes for a business day and hands over, and the station's
/// expenses. The server fixes every amount and decides every action; the
/// screens only offer what the role plausibly may do and show what the
/// server answered. Corrections add records; nothing is edited or deleted.

// Data ---------------------------------------------------------------------------------

/// Rows shown before "Zaidi" (project convention).
const moneyPageSize = 10;

/// What the signed-in account may plausibly do. The server decides.
({bool handle, bool settle, bool owner, String? id}) _me(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final profile = auth is OfficeSignedIn ? auth.profile : null;
  return (
    handle: profile?.canHandleMoney ?? false,
    settle: profile?.canSettleMoney ?? false,
    owner: profile?.isOwner ?? false,
    id: profile?.id,
  );
}

/// After any money change the server's lists are the truth.
void _afterChange(WidgetRef ref) {
  ref.invalidate(moneyDaysProvider);
  ref.invalidate(moneyExpensesProvider);
  ref.invalidate(vendorHandoversProvider);
}

// Formatting ---------------------------------------------------------------------------

String _moneyError(Strings s, Object error) => switch (error) {
      OfficeError(kind: OfficeErrorKind.invalid) => s.moneyInvalid,
      OfficeError(kind: OfficeErrorKind.notFound) => s.moneyRecordGone,
      OfficeError(kind: OfficeErrorKind.duplicate, :final detail?) =>
        s.serverRefused(detail),
      _ => officeErrorText(s, error),
    };

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

DateTime? _parseDay(String key) {
  final d = DateTime.tryParse(key);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

/// Server order, with each correcting row placed right after the row it
/// reverses (reversals keep the original's business date).
List<T> _linked<T>(
    List<T> rows, String Function(T) id, String? Function(T) reverses) {
  final ids = {for (final r in rows) id(r)};
  bool linked(T r) => reverses(r) != null && ids.contains(reverses(r));
  final corrections = <String, List<T>>{};
  for (final r in rows) {
    if (linked(r)) corrections.putIfAbsent(reverses(r)!, () => []).add(r);
  }
  return [
    for (final r in rows)
      if (!linked(r)) ...[r, ...?corrections[id(r)]]
  ];
}

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c, {Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, 14, color: color);
TextStyle _strong(BuildContext c) => OwnerStyle.text(c, 15, weight: 600);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

/// Shows [count] items ten at a time, with "Zaidi" for the next ten.
class _Paged extends ConsumerStatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  const _Paged({required this.count, required this.itemBuilder});
  @override
  ConsumerState<_Paged> createState() => _PagedState();
}

class _PagedState extends ConsumerState<_Paged> {
  int _limit = moneyPageSize;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < math.min(_limit, widget.count); i++) ...[
        if (i > 0) _gap(context),
        widget.itemBuilder(context, i),
      ],
      if (widget.count > _limit) ...[
        _gap(context),
        MNButton.secondary(s.moreRows,
            onPressed: () => setState(() => _limit += moneyPageSize)),
      ],
    ]);
  }
}

/// A white card with the office padding.
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

// Station chooser ----------------------------------------------------------------------

class OfficeMoneyScreen extends ConsumerWidget {
  final bool openExpenses;
  const OfficeMoneyScreen({super.key, this.openExpenses = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final stations = ref.watch(verificationQueueProvider);
    return OwnerPage(
        title: openExpenses ? s.moneyExpenses : s.money,
        strings: s,
        onRefresh: me.handle
            ? () => ref.refresh(verificationQueueProvider.future)
            : null,
        child: Padding(
            padding: _pad(context),
            child: !me.handle
                ? MNNote(s.notAllowed)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        if (me.owner) ...[
                          OwnerCard(
                              child: OwnerMenuRow(
                                  label: s.moneySettings,
                                  onTap: () => context
                                      .push(MNRoutes.officeMoneySettings))),
                          _gap(context),
                        ],
                        if (me.settle && !openExpenses)
                          const SupplyOutstandingSection(),
                        if (!openExpenses) ...[
                          const MoneyExportEntry(),
                          _gap(context),
                        ],
                        OwnerAsyncView(
                            value: stations,
                            onRetry: () =>
                                ref.invalidate(verificationQueueProvider),
                            isEmpty: (rows) => rows.isEmpty,
                            empty: (_) =>
                                MNNote(s.noStations, tone: MNNoteTone.info),
                            data: (rows) => _Paged(
                                count: rows.length,
                                itemBuilder: (_, i) => OwnerCard(
                                    child: OwnerMenuRow(
                                        label: rows[i].name,
                                        subtitle: rows[i].code.isEmpty
                                            ? null
                                            : rows[i].code,
                                        onTap: () => context.push(
                                            '${MNRoutes.officeMoneyStation(rows[i].id)}${openExpenses ? '?section=expenses' : ''}'))))),
                      ])));
  }
}

// One station on one day ---------------------------------------------------------------

class OfficeMoneyStationScreen extends ConsumerStatefulWidget {
  final String stationId;
  final bool openExpenses;
  const OfficeMoneyStationScreen(
      {super.key, required this.stationId, this.openExpenses = false});
  @override
  ConsumerState<OfficeMoneyStationScreen> createState() => _MoneyStationState();
}

class _MoneyStationState extends ConsumerState<OfficeMoneyStationScreen> {
  late final DateTime _today = businessDate(ref.read(clockProvider)());
  late DateTime _day = _today;
  late int _section = widget.openExpenses ? 1 : 0;

  MoneyDayKey get _key => (station: widget.stationId, date: moneyDateKey(_day));

  Future<void> _pickDay() async {
    final picked = await showMNDateSheet(context,
        initial: _day, first: DateTime.utc(_today.year - 2), last: _today);
    if (picked == null || !mounted) return;
    setState(() => _day = DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _refresh() {
    ref.invalidate(moneySettingsProvider);
    if (_section == 1) return ref.refresh(moneyExpensesProvider(_key).future);
    if (_section == 2) {
      return ref.refresh(vendorBalancesProvider(widget.stationId).future);
    }
    return ref.refresh(moneyDaysProvider(_key).future);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final station = ref
        .watch(verificationQueueProvider)
        .valueOrNull
        ?.where((r) => r.id == widget.stationId)
        .firstOrNull;
    if (!me.handle) {
      return OwnerPage(
          title: s.money,
          strings: s,
          child: Padding(padding: _pad(context), child: MNNote(s.notAllowed)));
    }
    final yesterday = _today.subtract(const Duration(days: 1));
    final dayIndex = _day == _today
        ? 0
        : _day == yesterday
            ? 1
            : 2;
    return OwnerPage(
        title: station?.name ?? s.money,
        strings: s,
        onRefresh: _refresh,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MNChipBar(
              labels: [
                s.ownerToday,
                s.yesterday,
                dayIndex == 2 ? s.date(_day) : s.moneyChooseDate
              ],
              selected: dayIndex,
              onSelect: (i) {
                if (i == 2) {
                  _pickDay();
                } else {
                  setState(() => _day = i == 0 ? _today : yesterday);
                }
              }),
          Padding(
              padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 19),
                  OwnerStyle.px(context, 4), OwnerStyle.px(context, 19), 0),
              child: Text(s.moneyDayText(s.date(_day)), style: _meta(context))),
          _gap(context, 8),
          MNChipBar(
              labels: [s.moneyHandovers, s.moneyExpenses, s.balancesTab],
              selected: _section,
              onSelect: (i) => setState(() => _section = i)),
          _gap(context, 8),
          Padding(
              padding: _pad(context),
              child: switch (_section) {
                1 => _ExpensesSection(dayKey: _key, day: _day),
                // Balances run across every day, whatever day is chosen.
                2 => BalancesSection(stationId: widget.stationId),
                _ => _HandoversSection(dayKey: _key),
              }),
        ]));
  }
}

// Handovers ----------------------------------------------------------------------------

class _HandoversSection extends ConsumerWidget {
  final MoneyDayKey dayKey;
  const _HandoversSection({required this.dayKey});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerHelp(message: s.moneyCashDueHelp),
      _gap(context),
      OwnerAsyncView(
          value: ref.watch(moneyDaysProvider(dayKey)),
          onRetry: () => ref.invalidate(moneyDaysProvider(dayKey)),
          isEmpty: (rows) => rows.isEmpty,
          empty: (_) => MNNote(s.moneyNoDays, tone: MNNoteTone.info),
          data: (rows) => _Paged(
              count: rows.length,
              itemBuilder: (_, i) => _DayRow(day: rows[i], dayKey: dayKey))),
    ]);
  }
}

class _DayRow extends ConsumerWidget {
  final OfficeMoneyDay day;
  final MoneyDayKey dayKey;
  const _DayRow({required this.day, required this.dayKey});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final word = moneyStateWord(s, day);
    final vendor = day.vendor.code == null
        ? day.vendor.name
        : '${day.vendor.name} · ${day.vendor.code}';
    return OwnerCard(
        child: InkWell(
            onTap: () => context.push(MNRoutes.officeMoneyVendorDay(
                dayKey.station, dayKey.date, day.vendor.id)),
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: u(64)),
                child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: u(16), vertical: u(14)),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(vendor, style: _title(context)),
                            SizedBox(height: u(4)),
                            Text(s.moneyCashDue(formatTsh(day.cashDue)),
                                style: _body(context)),
                            Text(s.moneyHandedOver(formatTsh(day.handedOver)),
                                style: _body(context)),
                            Text(s.moneyRemaining(formatTsh(day.remaining)),
                                style: _body(context)),
                            if (day.unverifiedCashSales > 0)
                              Text(
                                  s.moneyUnverified(
                                      formatTsh(day.unverifiedCashSales)),
                                  style: _meta(context)),
                            if (word != null) ...[
                              SizedBox(height: u(4)),
                              Text(word.$1, style: _status(context, word.$2)),
                            ],
                            if (day.late == true)
                              Text(s.moneyLate,
                                  style: _status(context, MNColors.error)),
                          ])),
                      SizedBox(width: u(12)),
                      const OwnerGlyph('vendor-chevron', size: 14),
                    ])))));
  }
}

// One vendor-day -----------------------------------------------------------------------

class OfficeMoneyVendorDayScreen extends ConsumerWidget {
  final String stationId, date, vendorId;
  const OfficeMoneyVendorDayScreen(
      {super.key,
      required this.stationId,
      required this.date,
      required this.vendorId});

  MoneyDayKey get _dayKey => (station: stationId, date: date);
  VendorDayKey get _vendorKey =>
      (station: stationId, date: date, vendor: vendorId);

  Future<void> _receive(BuildContext context, WidgetRef ref,
      {required String vendorName}) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _HandoverSheet(
            vendorId: vendorId, vendorName: vendorName, date: date));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.moneyHandoverSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    if (!me.handle) {
      return OwnerPage(
          title: s.money,
          strings: s,
          child: Padding(padding: _pad(context), child: MNNote(s.notAllowed)));
    }
    final days = ref.watch(moneyDaysProvider(_dayKey));
    final day =
        days.valueOrNull?.where((d) => d.vendor.id == vendorId).firstOrNull;
    final handovers = ref.watch(vendorHandoversProvider(_vendorKey));
    final vendorName = day?.vendor.name ??
        handovers.valueOrNull?.firstOrNull?.vendor.name ??
        '';
    final businessDay = _parseDay(date);
    return OwnerPage(
        title: vendorName.isEmpty ? s.money : vendorName,
        strings: s,
        onRefresh: () {
          ref.invalidate(moneyDaysProvider(_dayKey));
          return ref.refresh(vendorHandoversProvider(_vendorKey).future);
        },
        child: Padding(
            padding: _pad(context),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (businessDay != null)
                    Text(s.moneyDayText(s.date(businessDay)),
                        style: _meta(context)),
                  _gap(context, 8),
                  OwnerAsyncView(
                      value: days,
                      onRetry: () => ref.invalidate(moneyDaysProvider(_dayKey)),
                      loadingRows: 2,
                      data: (_) => day == null
                          ? MNNote(s.moneyNoDayForVendor, tone: MNNoteTone.info)
                          : _DaySummary(day: day)),
                  _gap(context),
                  MNButton(s.moneyReceiveCash,
                      onPressed: () =>
                          _receive(context, ref, vendorName: vendorName)),
                  _gap(context, 20),
                  Text(s.moneyHandovers, style: _title(context)),
                  _gap(context, 8),
                  OwnerAsyncView(
                      value: handovers,
                      onRetry: () =>
                          ref.invalidate(vendorHandoversProvider(_vendorKey)),
                      isEmpty: (rows) => rows.isEmpty,
                      empty: (_) =>
                          MNNote(s.moneyNoHandovers, tone: MNNoteTone.info),
                      data: (rows) {
                        final ordered =
                            _linked(rows, (h) => h.id, (h) => h.reversesId);
                        return _Paged(
                            count: ordered.length,
                            itemBuilder: (_, i) => _HandoverCard(
                                handover: ordered[i],
                                original: rows
                                    .where((h) => h.id == ordered[i].reversesId)
                                    .firstOrNull));
                      }),
                ])));
  }
}

class _DaySummary extends ConsumerWidget {
  final OfficeMoneyDay day;
  const _DaySummary({required this.day});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final word = moneyStateWord(s, day);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.moneyCashDue(formatTsh(day.cashDue)), style: _strong(context)),
      OwnerDetails(title: s.recordDetails, children: [
        Text(s.moneyVerifiedCash(formatTsh(day.verifiedCashSales)),
            style: _body(context)),
        if (day.creditRepaymentsCash > 0)
          Text(s.creditCashRepaid(formatTsh(day.creditRepaymentsCash)),
              style: _body(context)),
        Text(
            s.moneyApprovedVendorExpenses(
                formatTsh(day.approvedVendorExpenses)),
            style: _body(context)),
      ]),
      if (day.creditSales > 0)
        Text(s.creditSalesNotCash(formatTsh(day.creditSales)),
            style: _meta(context)),
      _gap(context, 6),
      Text(s.moneyHandedOver(formatTsh(day.handedOver)), style: _body(context)),
      Text(s.moneyConfirmedCash(formatTsh(day.confirmed)),
          style: _body(context)),
      Text(s.moneyRemaining(formatTsh(day.remaining)), style: _strong(context)),
      if (day.unverifiedCashSales > 0 || day.pendingVendorExpenses > 0)
        _gap(context, 6),
      if (day.unverifiedCashSales > 0)
        Text(s.moneyUnverified(formatTsh(day.unverifiedCashSales)),
            style: _meta(context)),
      if (day.pendingVendorExpenses > 0)
        Text(s.moneyPendingVendorExpenses(formatTsh(day.pendingVendorExpenses)),
            style: _meta(context)),
      if (day.lastReceivedAt != null)
        Text(s.moneyLastReceived(_when(s, day.lastReceivedAt)),
            style: _meta(context)),
      if (day.cashOnHandEstimate != null) ...[
        _gap(context, 6),
        Text(s.cashOnHandEstimate, style: _meta(context)),
        Text(formatTsh(day.cashOnHandEstimate!), style: _body(context)),
        Text(s.cashOnHandEstimateHelp, style: _meta(context)),
      ],
      if (word != null) ...[
        _gap(context, 6),
        Text(word.$1, style: _status(context, word.$2)),
      ],
      if (day.late == true)
        Text(s.moneyLate, style: _status(context, MNColors.error)),
    ]));
  }
}

class _HandoverCard extends ConsumerStatefulWidget {
  final OfficeHandover handover;

  /// The row a correcting record reverses, when it is in the list.
  final OfficeHandover? original;
  const _HandoverCard({required this.handover, this.original});
  @override
  ConsumerState<_HandoverCard> createState() => _HandoverCardState();
}

class _HandoverCardState extends ConsumerState<_HandoverCard> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final h = widget.handover;
    final yes = await showMNConfirmDialog(context,
        title: s.moneyConfirmHandoverTitle(formatTsh(h.amount), h.vendor.name),
        message: s.moneyConfirmHandoverBody,
        confirmLabel: s.yesConfirm,
        cancelLabel: s.cancel);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => r.confirmHandover(h.id));
      if (mounted) _toast(context, s.moneyHandoverConfirmed);
      _afterChange(ref);
    } catch (error) {
      if (mounted) setState(() => _error = _moneyError(s, error));
      ref.invalidate(vendorHandoversProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reverse() async {
    final s = ref.read(stringsProvider);
    final h = widget.handover;
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title: s.moneyReverseHandoverTitle,
            note: s.moneyReverseWarning,
            actionLabel: s.moneyReverse,
            send: (reason) => ref
                .read(officeSessionProvider.notifier)
                .guard((r) => r.reverseHandover(h.id, reason: reason))));
    if (done != true) return;
    _afterChange(ref);
    if (mounted) _toast(context, s.moneyReversalSaved);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final h = widget.handover;
    final (word, color) = h.isReversal
        ? (s.moneyCorrection, OwnerStyle.muted)
        : h.confirmed
            ? (s.moneyConfirmedBy(h.confirmedBy?.name ?? '—'), MNColors.success)
            : (s.moneyHandoverWaiting, MNColors.warning);
    final open = !h.isReversal && !h.reversed;
    final ownRecord = me.id != null && h.recordedBy.id == me.id;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (h.isReversal) ...[
        Text(s.moneyCorrection, style: _title(context)),
        Text(
            s.moneyCorrectsHandover(
                formatTsh((widget.original?.amount ?? h.amount).abs())),
            style: _body(context)),
      ] else
        Text(formatTsh(h.amount), style: _title(context)),
      Text(
          s.moneyRecordedBy(
              h.recordedBy.name,
              _when(
                  s,
                  h.isReversal
                      ? h.createdAt ?? h.receivedAt
                      : h.receivedAt ?? h.createdAt)),
          style: _meta(context)),
      if (h.reason != null)
        Text(s.reasonText(h.reason!), style: _body(context)),
      if (h.note != null) Text(h.note!, style: _body(context)),
      if (!h.isReversal) ...[
        _gap(context, 4),
        Text(word, style: _status(context, color)),
      ],
      if (h.reversed)
        Text(s.moneyReversed, style: _status(context, OwnerStyle.muted)),
      if (_error != null) ...[
        _gap(context),
        MNNote(_error!, error: true),
      ],
      if (open && me.settle) ...[
        if (!h.confirmed) ...[
          _gap(context),
          if (ownRecord)
            Text(s.moneyOwnRecord, style: _meta(context))
          else
            MNButton(s.moneyConfirmHandover,
                busy: _busy, onPressed: _busy ? null : _confirm),
        ],
        _gap(context, 8),
        MNButton.secondary(s.moneyReverse, onPressed: _busy ? null : _reverse),
      ],
    ]));
  }
}

class _HandoverSheet extends ConsumerStatefulWidget {
  final String vendorId, vendorName, date;
  const _HandoverSheet(
      {required this.vendorId, required this.vendorName, required this.date});
  @override
  ConsumerState<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends ConsumerState<_HandoverSheet> {
  final _retry = RetryId();
  // Never prefilled from sales: the supervisor types what was received.
  final _amount = TextEditingController(), _note = TextEditingController();
  DateTime? _receivedAt; // null means now
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final s = ref.read(stringsProvider);
    final now = ref.read(clockProvider)();
    final current = eatClock(_receivedAt ?? now);
    final picked = await showMNTimeSheet(context,
        hour: current.hour, minute: current.minute);
    if (picked == null || !mounted) return;
    final day = _parseDay(widget.date);
    if (day == null) return;
    final chosen = businessDayRange(day)
        .$1
        .add(Duration(hours: picked.hour, minutes: picked.minute));
    // A time that has not come yet is refused here; the server refuses it too.
    if (chosen.isAfter(now)) {
      setState(() => _error = s.handoverTimeFuture);
      return;
    }
    setState(() {
      _receivedAt = chosen;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = s.moneyAmountInvalid);
      return;
    }
    final day = _parseDay(widget.date);
    final yes = await showMNConfirmDialog(context,
        title:
            s.moneyHandoverConfirmTitle(formatTsh(amount), widget.vendorName),
        message:
            s.moneyHandoverConfirmBody(day == null ? widget.date : s.date(day)),
        confirmLabel: s.yesConfirm,
        cancelLabel: s.cancel);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          r.recordHandover(
              vendorId: widget.vendorId,
              businessDate: widget.date,
              amount: amount,
              receivedAt: _receivedAt,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              clientId: _retry.forDetails(
                  '${widget.vendorId}|${widget.date}|$amount|'
                  '${_receivedAt?.toIso8601String() ?? ''}|${_note.text.trim()}')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _moneyError(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.moneyReceiveCash, children: [
      if (widget.vendorName.isNotEmpty)
        Text(widget.vendorName, style: _body(context)),
      MNTextField(
          label: s.moneyAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ]),
      MNFieldButton(
          label: s.handoverReceivedAt,
          text: _receivedAt == null ? null : s.hhmm(eatClock(_receivedAt!)),
          placeholder: s.handoverReceivedNow,
          icon: MNIconData.clock,
          onTap: _busy ? null : _pickTime),
      MNTextField(
          label: s.handoverNoteLabel,
          controller: _note,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(200)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.moneyReceiveCash,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// Expenses -----------------------------------------------------------------------------

class _ExpensesSection extends ConsumerWidget {
  final MoneyDayKey dayKey;
  final DateTime day;
  const _ExpensesSection({required this.dayKey, required this.day});

  Future<void> _add(BuildContext context, WidgetRef ref,
      List<String> categories, Map<String, List<String>> items) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ExpenseSheet(
            stationId: dayKey.station,
            day: day,
            categories: categories,
            items: items));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.moneyExpenseSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(moneySettingsProvider);
    final categories = settings.valueOrNull?.expenseCategories ?? const [];
    final items = settings.valueOrNull?.expenseItems ?? const {};
    // "Mengineyo" is always there, so an expense can be recorded as soon as
    // the settings have loaded.
    final ready = settings.hasValue;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (settings.hasError && !settings.hasValue) ...[
        MNNote(_moneyError(s, settings.error!), error: true),
        MNTextButton(s.retry,
            onPressed: () => ref.invalidate(moneySettingsProvider)),
        _gap(context),
      ],
      MNButton(s.moneyAddExpense,
          onPressed:
              ready ? () => _add(context, ref, categories, items) : null),
      _gap(context, 16),
      OwnerAsyncView(
          value: ref.watch(moneyExpensesProvider(dayKey)),
          onRetry: () => ref.invalidate(moneyExpensesProvider(dayKey)),
          isEmpty: (rows) => rows.isEmpty,
          empty: (_) => MNNote(s.moneyNoExpenses, tone: MNNoteTone.info),
          data: (rows) {
            final claims = [
              for (final e in rows)
                if (e.pending && e.byVendor) e
            ];
            final rest = _linked([
              for (final e in rows)
                if (!(e.pending && e.byVendor)) e
            ], (e) => e.id, (e) => e.reversesId);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (claims.isNotEmpty) ...[
                    Text(s.moneyVendorClaims, style: _title(context)),
                    _gap(context, 8),
                    _Paged(
                        count: claims.length,
                        itemBuilder: (_, i) =>
                            _ExpenseCard(expense: claims[i])),
                    if (rest.isNotEmpty) ...[
                      _gap(context, 20),
                      Text(s.moneyDayExpenses, style: _title(context)),
                      _gap(context, 8),
                    ],
                  ],
                  _Paged(
                      count: rest.length,
                      itemBuilder: (_, i) => _ExpenseCard(
                          expense: rest[i],
                          original: rows
                              .where((e) => e.id == rest[i].reversesId)
                              .firstOrNull)),
                ]);
          }),
    ]);
  }
}

class _ExpenseCard extends ConsumerWidget {
  final OfficeExpense expense;

  /// The row a correcting record reverses, when it is in the list.
  final OfficeExpense? original;
  const _ExpenseCard({required this.expense, this.original});

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final e = expense;
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title: approve
                ? s.moneyApproveExpenseTitle
                : s.moneyRejectExpenseTitle,
            note: approve
                ? s.moneyApproveExpenseBody(
                    formatTsh(e.amount), e.vendor?.name ?? '—')
                : s.moneyRejectExpenseBody,
            tone: approve ? MNNoteTone.warning : MNNoteTone.info,
            reasonLabel: s.decisionReason,
            actionLabel: approve ? s.moneyApproveExpense : s.moneyRejectExpense,
            send: (reason) => ref.read(officeSessionProvider.notifier).guard(
                (r) =>
                    r.decideExpense(e.id, approve: approve, reason: reason))));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.decisionSaved);
  }

  Future<void> _reverse(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title: s.moneyReverseExpenseTitle,
            note: s.moneyReverseWarning,
            actionLabel: s.moneyReverse,
            send: (reason) => ref
                .read(officeSessionProvider.notifier)
                .guard((r) => r.reverseExpense(expense.id, reason: reason))));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.moneyReversalSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final e = expense;
    final (word, color) = e.isReversal
        ? (s.moneyCorrection, OwnerStyle.muted)
        : e.pending
            ? (s.moneyExpenseWaiting, MNColors.warning)
            : e.rejected
                ? (s.moneyExpenseRejected, MNColors.error)
                : (s.moneyExpenseApproved, MNColors.success);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (e.isReversal) ...[
        // A correction, not new spending.
        Text(s.moneyCorrection, style: _title(context)),
        Text(
            s.moneyCorrectsExpense(original?.category ?? e.category,
                formatTsh((original?.amount ?? e.amount).abs())),
            style: _body(context)),
        if (e.decisionReason != null)
          Text(s.reasonText(e.decisionReason!), style: _body(context)),
        if (e.decidedBy != null)
          Text(s.moneyCorrectedBy(e.decidedBy!.name), style: _meta(context)),
      ] else ...[
        Text(s.expenseLabel(e.category, e.item), style: _title(context)),
        Text(formatTsh(e.amount), style: _strong(context)),
        Text(
            e.byVendor
                ? s.moneyPaidByVendor(e.vendor?.name ?? '—')
                : s.moneyPaidByOffice,
            style: _body(context)),
        if (e.note != null) Text(s.noteText(e.note!), style: _body(context)),
        // Office expenses are decided by whoever recorded them; only a
        // vendor's claim has a decision worth showing.
        if (e.byVendor && e.decisionReason != null)
          Text(s.reasonText(e.decisionReason!), style: _body(context)),
        if (e.byVendor && e.decidedBy != null)
          Text(s.moneyDecidedBy(e.decidedBy!.name), style: _meta(context)),
        _gap(context, 4),
        Text(word, style: _status(context, color)),
      ],
      if (e.reversed)
        Text(s.moneyReversed, style: _status(context, OwnerStyle.muted)),
      if (e.pending && e.byVendor && me.handle) ...[
        _gap(context),
        MNButton(s.moneyApproveExpense,
            onPressed: () => _decide(context, ref, true)),
        _gap(context, 8),
        MNButton.secondary(s.moneyRejectExpense,
            onPressed: () => _decide(context, ref, false)),
      ],
      if (e.approved && !e.isReversal && !e.reversed && me.settle) ...[
        _gap(context),
        MNButton.secondary(s.moneyReverse,
            onPressed: () => _reverse(context, ref)),
      ],
    ]));
  }
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  final String stationId;
  final DateTime day;
  final List<String> categories;
  final Map<String, List<String>> items;
  const _ExpenseSheet(
      {required this.stationId,
      required this.day,
      required this.categories,
      required this.items});
  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _retry = RetryId();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _written = TextEditingController();
  String? _category, _item, _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _written.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final category = _category;
    final amount = int.tryParse(_amount.text.trim());
    if (category == null) {
      setState(() => _error = s.moneyCategoryRequired);
      return;
    }
    final item = expenseItemFor(
        category: category,
        items: widget.items,
        chosen: _item,
        written: _written.text);
    if (item.missing) {
      setState(() => _error = s.expenseItemRequired);
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = s.moneyAmountInvalid);
      return;
    }
    final note = _note.text.trim();
    final yes = await showMNConfirmDialog(context,
        title: s.moneyExpenseConfirmTitle(
            s.expenseLabel(category, item.item), formatTsh(amount)),
        message: s.moneyExpenseConfirmBody(s.date(widget.day)),
        confirmLabel: s.yesConfirm,
        cancelLabel: s.cancel);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) => r.recordExpense(
          stationId: widget.stationId,
          businessDate: moneyDateKey(widget.day),
          category: category,
          item: item.item,
          amount: amount,
          note: note.isEmpty ? null : note,
          clientId: _retry.forDetails(
              '${widget.stationId}|${moneyDateKey(widget.day)}|$category|${item.item}|$amount|$note')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _moneyError(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.moneyAddExpense, children: [
      Text(s.moneyDayText(s.date(widget.day)), style: _body(context)),
      ExpenseItemFields(
          categories: widget.categories,
          items: widget.items,
          category: _category,
          item: _item,
          written: _written,
          enabled: !_busy,
          onCategory: (v) => setState(() {
                _category = v;
                _item = null;
              }),
          onItem: (v) => setState(() => _item = v)),
      MNTextField(
          label: s.moneyAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ]),
      MNTextField(
          label: s.noteOptional,
          controller: _note,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.moneyAddExpense, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// A reason, then one server call ------------------------------------------------------

class _ReasonSheet extends ConsumerStatefulWidget {
  final String title, note, actionLabel;
  final String? reasonLabel;
  final MNNoteTone tone;
  final Future<void> Function(String reason) send;
  const _ReasonSheet(
      {required this.title,
      required this.note,
      required this.actionLabel,
      required this.send,
      this.reasonLabel,
      this.tone = MNNoteTone.warning});
  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (reason.length < 3 || reason.length > 500) {
      setState(() => _error = s.decisionReasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _moneyError(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      MNNote(widget.note, tone: widget.tone),
      MNTextField(
          label: widget.reasonLabel ?? s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(widget.actionLabel,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// Owner settings -----------------------------------------------------------------------

/// Saves one owner setting with a plain reason written by the app (owner
/// decision 25 October 2026: adding an item is one field and Save). Returns
/// whether the server took it; a refusal is shown in the server's words.
Future<bool> _saveSetting(BuildContext context, WidgetRef ref, String key,
    Object value, String reason) async {
  final s = ref.read(stringsProvider);
  try {
    await ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.saveSetting(key, value: value, reason: reason));
    ref.invalidate(moneySettingsProvider);
    return true;
  } catch (error) {
    if (context.mounted) _toast(context, _moneyError(s, error));
    return false;
  }
}

Widget _divided(List<Widget> rows) => Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: OwnerStyle.line)),
        rows[i],
      ]
    ]);

/// A section title, with "+ Ongeza" on the right when [onAdd] is given.
Widget _section(BuildContext context, Strings s, String title,
        {VoidCallback? onAdd}) =>
    Padding(
        padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 4),
            OwnerStyle.px(context, 22), 0, OwnerStyle.px(context, 8)),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title,
                      style: OwnerStyle.text(context, 17, weight: 600)))),
          if (onAdd != null)
            TextButton(
                onPressed: onAdd,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const OwnerGlyph('plus', size: 20, color: OwnerStyle.muted),
                  const SizedBox(width: 6),
                  Text(s.stationAdd,
                      style: OwnerStyle.text(context, 16,
                          color: OwnerStyle.muted)),
                ])),
        ]));

class OfficeMoneySettingsScreen extends ConsumerWidget {
  const OfficeMoneySettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final owner = _me(ref).owner;
    return OwnerPage(
        title: s.moneySettings,
        strings: s,
        trailing: MNWorkflowHelp(title: s.moneySettings, messages: [
          s.moneySettingsCaption,
          s.expenseOtherSetting,
          s.lateEntryHelp,
          s.offlineSettingsHelp,
        ]),
        child: Padding(
            padding: _pad(context),
            child: !owner
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: ref.watch(moneySettingsProvider),
                    onRetry: () => ref.invalidate(moneySettingsProvider),
                    loadingRows: 3,
                    data: (settings) => _SettingsList(settings: settings))));
  }
}

class _SettingsList extends ConsumerWidget {
  final OfficeMoneySettings settings;
  const _SettingsList({required this.settings});

  Future<void> _deadline(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final current = settings.handoverDeadline;
    final now = eatClock(ref.read(clockProvider)());
    final picked = await showMNTimeSheet(context,
        hour: current == null ? now.hour : int.parse(current.substring(0, 2)),
        minute:
            current == null ? now.minute : int.parse(current.substring(3, 5)));
    if (picked == null || !context.mounted) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    if (value == current || !validHandoverDeadline(value)) return;
    final saved = await _saveSetting(
        context,
        ref,
        OfficeMoneySettings.deadlineKey,
        value,
        s.moneySaveDeadlineTitle(value));
    if (saved && context.mounted) _toast(context, s.moneySettingsSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final categories = settings.expenseCategories ?? const <String>[];
    final deadline = settings.handoverDeadline;
    void open(String title, Widget child, List<String> help) =>
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => OwnerPage(
                title: title,
                strings: s,
                onBack: () => Navigator.of(context).pop(),
                trailing: MNWorkflowHelp(title: title, messages: help),
                child: Padding(padding: _pad(context), child: child))));
    Widget summary(String title,
            {String? value, required VoidCallback onTap}) =>
        OwnerMenuRow(
            label: title,
            value: value,
            valueSize: 14,
            valueWeight: 400,
            valueColor: OwnerStyle.muted,
            onTap: onTap);
    Widget section(String title) => Padding(
        padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 10),
            OwnerStyle.px(context, 22), 0, OwnerStyle.px(context, 8)),
        child: Text(title.toUpperCase(),
            style: OwnerStyle.text(context, 12,
                weight: 600, color: OwnerStyle.muted)));
    final offlineOn = OfficeMoneySettings.offlineLimits
        .every((l) => settings.offline.containsKey(l.$1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section(s.moneySectionExpenses),
      OwnerCard(
          child: summary(s.moneyExpenseCategories,
              value: s.moneyCategoryCount(categories.length),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const _ExpenseSettingsPage())))),
      section(s.moneySectionCash),
      OwnerCard(
          child: _divided([
        summary(s.moneyDeadline,
            value: deadline ?? s.moneyDeadlineNotSet,
            onTap: () => _deadline(context, ref)),
        summary(s.cashLimitTitle,
            value: settings.cashOnHandLimit == null
                ? s.cashLimitNotSet
                : formatTsh(settings.cashOnHandLimit!),
            onTap: () => showMNSheet<void>(context,
                builder: (_) =>
                    _CashLimitSheet(current: settings.cashOnHandLimit))),
      ])),
      section(s.autoVerifySection),
      OwnerCard(
          child: summary(s.autoVerifyTitle,
              value: s.autoVerifyModeName(settings.autoVerify?.mode ?? 'off'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AutoVerifySettingsScreen())))),
      section(s.moneySectionStock),
      OwnerCard(
          child: summary(s.lateEntryTitle,
              value: settings.lateEntryHours == null
                  ? s.lateEntryNotSet
                  : s.moneyHoursSummary(settings.lateEntryHours!),
              onTap: () => open(s.lateEntryTitle,
                  const _LateEntrySettingsEditor(), [s.lateEntryHelp]))),
      section(s.moneySettingsSecurity),
      OwnerCard(
          child: summary(s.offlineSettingsTitle,
              value: offlineOn ? s.offlineOn : s.offlineOff,
              onTap: () => open(s.offlineSettingsTitle,
                  const _OfflineSettingsEditor(), [s.offlineSettingsHelp]))),
      section(s.managementAdministration),
      OwnerCard(
          child: summary(s.perfSettings,
              onTap: () => context.push(MNRoutes.officePerformanceSettings))),
      _gap(context, 24),
    ]);
  }
}

class _ExpenseSettingsPage extends ConsumerWidget {
  const _ExpenseSettingsPage();
  Future<void> _addCategory(
      BuildContext context, WidgetRef ref, OfficeMoneySettings settings) async {
    final s = ref.read(stringsProvider);
    final current = settings.expenseCategories ?? const <String>[];
    await showMNSheet<void>(context,
        builder: (_) => _NameSheet(
            title: s.expenseAddCategory,
            label: s.expenseCategoryName,
            longest: maxExpenseCategoryLength,
            taken: [...current, expenseOther, 'Others'],
            save: (name) => _saveSetting(
                context,
                ref,
                OfficeMoneySettings.categoriesKey,
                [...current, name],
                s.expenseReasonAddCategory(name))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerPage(
        title: s.moneyExpenseCategories,
        strings: s,
        onBack: () => Navigator.of(context).pop(),
        trailing: MNWorkflowHelp(
            title: s.moneyExpenseCategories,
            messages: [s.expenseItemsHelp, s.expenseOtherSetting]),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView(
              value: ref.watch(moneySettingsProvider),
              onRetry: () => ref.invalidate(moneySettingsProvider),
              data: (settings) {
                final categories =
                    settings.expenseCategories ?? const <String>[];
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(context, s, s.moneySectionExpenses,
                          onAdd: categories.length < maxExpenseCategories
                              ? () => _addCategory(context, ref, settings)
                              : null),
                      OwnerCard(
                          child: _divided([
                        for (final c in categories)
                          OwnerMenuRow(
                              label: c,
                              value: s.expenseItemCount(
                                  settings.expenseItems[c]?.length ?? 0),
                              valueColor: OwnerStyle.muted,
                              valueSize: 14,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          _ExpenseCategoryPage(category: c)))),
                        OwnerMenuRow(
                            label: s.expenseOtherLabel, showChevron: false),
                      ])),
                      _gap(context, 24),
                    ]);
              },
            )));
  }
}

class _LateEntrySettingsEditor extends ConsumerWidget {
  const _LateEntrySettingsEditor();
  @override
  Widget build(BuildContext context, WidgetRef ref) => OwnerAsyncView(
      value: ref.watch(moneySettingsProvider),
      onRetry: () => ref.invalidate(moneySettingsProvider),
      data: (settings) => OfficeLateEntryCard(
          hours: settings.lateEntryHours,
          showExplanation: false,
          onSaved: () => ref.invalidate(moneySettingsProvider)));
}

class _OfflineSettingsEditor extends ConsumerWidget {
  const _OfflineSettingsEditor();
  @override
  Widget build(BuildContext context, WidgetRef ref) => OwnerAsyncView(
      value: ref.watch(moneySettingsProvider),
      onRetry: () => ref.invalidate(moneySettingsProvider),
      data: (settings) => OfficeOfflineCard(
          values: settings.offline,
          showExplanation: false,
          onSaved: () => ref.invalidate(moneySettingsProvider)));
}

/// One category's items: the vendor chooses one of them when recording.
class _ExpenseCategoryPage extends ConsumerWidget {
  final String category;
  const _ExpenseCategoryPage({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(moneySettingsProvider).valueOrNull;
    final items = settings?.expenseItems[category] ?? const <String>[];
    final allItems = settings?.expenseItems ?? const <String, List<String>>{};

    Future<void> saveItems(List<String> next, String reason) => _saveSetting(
        context,
        ref,
        OfficeMoneySettings.itemsKey,
        {
          for (final MapEntry(:key, :value) in allItems.entries)
            if (key != category) key: value,
          if (next.isNotEmpty) category: next,
        },
        reason);

    Future<void> add() => showMNSheet<void>(context,
        builder: (_) => _NameSheet(
            title: s.expenseAddItem,
            label: s.expenseItemName,
            longest: maxExpenseItemLength,
            taken: items,
            save: (name) async {
              await saveItems(
                  [...items, name], s.expenseReasonAddItem(name, category));
              return true;
            }));

    Future<void> remove(String item) async {
      final yes = await showMNConfirmDialog(context,
          title: s.expenseRemoveItemConfirm(item),
          confirmLabel: s.remove,
          cancelLabel: s.cancel,
          destructive: true);
      if (!yes || !context.mounted) return;
      await saveItems([
        for (final i in items)
          if (i != item) i
      ], s.expenseReasonRemoveItem(item, category));
    }

    Future<void> removeCategory() async {
      final yes = await showMNConfirmDialog(context,
          title: s.expenseRemoveCategoryConfirm(category),
          confirmLabel: s.remove,
          cancelLabel: s.cancel,
          destructive: true);
      if (!yes || !context.mounted) return;
      final categories = settings?.expenseCategories ?? const <String>[];
      final reason = s.expenseReasonRemoveCategory(category);
      final saved = await _saveSetting(
          context,
          ref,
          OfficeMoneySettings.categoriesKey,
          [
            for (final c in categories)
              if (c != category) c
          ],
          reason);
      if (!saved || !context.mounted) return;
      if (items.isNotEmpty) await saveItems(const [], reason);
      if (context.mounted) Navigator.of(context).pop();
    }

    return OwnerPage(
        title: category,
        strings: s,
        onBack: () => Navigator.of(context).pop(),
        trailing:
            MNWorkflowHelp(title: category, messages: [s.expenseItemsHelp]),
        child: Padding(
            padding: _pad(context),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(context, s, s.expenseItem,
                      onAdd: items.length < 50 ? add : null),
                  if (items.isEmpty)
                    MNNote(s.expenseNoItems, tone: MNNoteTone.info)
                  else ...[
                    OwnerCard(
                        child: _divided([
                      for (final item in items)
                        OwnerMenuRow(
                            label: item,
                            value: s.remove,
                            valueColor: OwnerStyle.muted,
                            valueSize: 15,
                            showChevron: false,
                            onTap: () => remove(item)),
                    ])),
                  ],
                  _gap(context, 32),
                  MNTextButton(s.expenseRemoveCategory,
                      onPressed: removeCategory),
                ])));
  }
}

/// The owner's cash-on-hand limit (whole TZS). No default: unset means the
/// alert is off, and "turn off" puts it back to unset.
class _CashLimitSheet extends ConsumerStatefulWidget {
  final int? current;
  const _CashLimitSheet({required this.current});
  @override
  ConsumerState<_CashLimitSheet> createState() => _CashLimitSheetState();
}

class _CashLimitSheetState extends ConsumerState<_CashLimitSheet> {
  late final _amount = TextEditingController(
      text: widget.current == null ? '' : '${widget.current}');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send(Object? value, String reason) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) => value == null
          ? (r as OfficeApprovalsRepository).saveAlertSetting(
              OfficeMoneySettings.cashLimitKey,
              value: null,
              reason: reason)
          : r.saveSetting(OfficeMoneySettings.cashLimitKey,
              value: value, reason: reason));
      ref.invalidate(moneySettingsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = _moneyError(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final s = ref.read(stringsProvider);
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount < 1) {
      setState(() => _error = s.cashLimitInvalid);
      return;
    }
    _send(amount, s.cashLimitReason(formatTsh(amount)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.cashLimitTitle, children: [
      Text(s.cashLimitHelp, style: _body(context, color: OwnerStyle.muted)),
      MNTextField(
          label: s.cashLimitAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9)
          ]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.cashLimitSave, busy: _busy, onPressed: _busy ? null : _save),
      if (widget.current != null)
        MNButton.secondary(s.cashLimitClear,
            onPressed:
                _busy ? null : () => _send(null, s.cashLimitClearedReason)),
    ]);
  }
}

/// One name and Save: a new category or item.
class _NameSheet extends ConsumerStatefulWidget {
  final String title, label;
  final int longest;
  final List<String> taken;
  final Future<bool> Function(String name) save;
  const _NameSheet(
      {required this.title,
      required this.label,
      required this.longest,
      required this.taken,
      required this.save});
  @override
  ConsumerState<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends ConsumerState<_NameSheet> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final name = _name.text.trim();
    final error = name.isEmpty || name.length > widget.longest
        ? s.expenseNameLength(widget.longest)
        : const ['mengineyo', 'others'].contains(name.toLowerCase())
            ? s.expenseNameReserved
            : widget.taken.any((t) => t.toLowerCase() == name.toLowerCase())
                ? s.expenseNameTaken
                : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.save(name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      MNTextField(
          label: widget.label,
          controller: _name,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(widget.longest)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
