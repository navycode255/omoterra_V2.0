import 'owner_widgets.dart';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;
import 'verification_screens.dart' show verificationQueueProvider;

/// What each vendor owes across days (Phase 6, VR3), each day's money
/// status, balance adjustments and the finance exports. The server computes
/// every figure and decides every action; the screens show what it answered.
/// Adjustments are asked for by finance or the owner and approved by someone
/// else; a wrong one is corrected by a new one, never edited.

// Data ---------------------------------------------------------------------------------

/// Runs [work] with the balances side of the office API.
Future<T> officeBalancesCall<T>(
        WidgetRef ref, Future<T> Function(OfficeBalancesRepository) work) =>
    ref.read(officeSessionProvider.notifier).guard((repo) {
      if (repo is! OfficeBalancesRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OfficeBalancesRepository);
    });

final vendorBalancesProvider = FutureProvider.autoDispose
    .family<List<OfficeVendorBalance>, String>((ref, stationId) =>
        ref.read(officeSessionProvider.notifier).guard((repo) {
          if (repo is! OfficeBalancesRepository) {
            throw const OfficeError(OfficeErrorKind.invalid);
          }
          return (repo as OfficeBalancesRepository)
              .vendorBalances(stationId: stationId);
        }));

final vendorMoneyProvider = FutureProvider.autoDispose
    .family<OfficeVendorMoney, String>((ref, vendorId) =>
        ref.read(officeSessionProvider.notifier).guard((repo) {
          if (repo is! OfficeBalancesRepository) {
            throw const OfficeError(OfficeErrorKind.invalid);
          }
          return (repo as OfficeBalancesRepository).vendorMoney(vendorId);
        }));

/// Saves a downloaded report where the person chooses (overridden in tests).
final saveMoneyExportProvider =
    Provider<Future<void> Function(String name, Uint8List bytes)>(
        (ref) => (name, bytes) async {
              await FilePicker.platform.saveFile(
                  fileName: name,
                  type: FileType.custom,
                  allowedExtensions: ['csv'],
                  bytes: bytes);
            });

/// What the signed-in account may plausibly do. The server decides.
({bool handle, bool settle, String? id}) _me(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final profile = auth is OfficeSignedIn ? auth.profile : null;
  return (
    handle: profile?.canHandleMoney ?? false,
    // Finance or the owner: adjustments.approve.
    settle: profile?.canSettleMoney ?? false,
    id: profile?.id,
  );
}

void _afterChange(WidgetRef ref) {
  ref.invalidate(vendorBalancesProvider);
  ref.invalidate(vendorMoneyProvider);
}

// Formatting ---------------------------------------------------------------------------

/// A money status in its status colour.
(String, Color) moneyStatusWord(Strings s, MoneyStatus? status) =>
    switch (status) {
      MoneyStatus.settled => (s.moneyStatusName('settled'), MNColors.success),
      MoneyStatus.partReceived => (
          s.moneyStatusName('part_received'),
          MNColors.warning
        ),
      MoneyStatus.outstanding => (
          s.moneyStatusName('outstanding'),
          MNColors.error
        ),
      MoneyStatus.unresolved => (
          s.moneyStatusName('unresolved'),
          MNColors.warning
        ),
      MoneyStatus.nothingDue || null => (
          s.moneyStatusName('nothing_due'),
          OwnerStyle.muted
        ),
    };

/// The balance headline in its status colour.
(String, Color) balanceWord(Strings s, OfficeVendorBalance b) => b.owed > 0
    ? (s.balanceOwed(formatTsh(b.owed)), MNColors.warning)
    : b.credit > 0
        ? (s.balanceCredit(formatTsh(b.credit)), OwnerStyle.muted)
        : (s.balanceClear, MNColors.success);

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

String _errorText(Strings s, Object error) => switch (error) {
      OfficeError(kind: OfficeErrorKind.invalid) => s.moneyInvalid,
      OfficeError(kind: OfficeErrorKind.notFound) => s.moneyRecordGone,
      _ => officeErrorText(s, error),
    };

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c) => OwnerStyle.text(c, 14);
TextStyle _strong(BuildContext c) => OwnerStyle.text(c, 15, weight: 600);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

const _pageSize = 10;

/// Shows [count] items ten at a time, with "Zaidi" for the next ten.
class _Paged extends ConsumerStatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  const _Paged({required this.count, required this.itemBuilder});
  @override
  ConsumerState<_Paged> createState() => _PagedState();
}

class _PagedState extends ConsumerState<_Paged> {
  int _limit = _pageSize;
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
            onPressed: () => setState(() => _limit += _pageSize)),
      ],
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

// A station's vendors and what each owes -------------------------------------------------

class BalancesSection extends ConsumerWidget {
  final String stationId;
  const BalancesSection({super.key, required this.stationId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerHelp(message: s.balancesHelp),
      _gap(context),
      OwnerAsyncView(
          value: ref.watch(vendorBalancesProvider(stationId)),
          onRetry: () => ref.invalidate(vendorBalancesProvider(stationId)),
          isEmpty: (rows) => rows.isEmpty,
          empty: (_) => MNNote(s.balancesNone, tone: MNNoteTone.info),
          data: (rows) => _Paged(
              count: rows.length,
              itemBuilder: (_, i) => _BalanceRow(balance: rows[i]))),
    ]);
  }
}

class _BalanceRow extends ConsumerWidget {
  final OfficeVendorBalance balance;
  const _BalanceRow({required this.balance});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final b = balance;
    final (word, color) = balanceWord(s, b);
    final name = b.vendor.code == null
        ? b.vendor.name
        : '${b.vendor.name} · ${b.vendor.code}';
    return OwnerCard(
        child: InkWell(
            onTap: () => context.push(MNRoutes.officeVendorMoney(b.vendor.id)),
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
                            Text(name, style: _title(context)),
                            SizedBox(height: u(4)),
                            Text(word, style: _status(context, color)),
                            if (b.oldestOutstanding != null)
                              Text(
                                  s.balanceSince(s.date(b.oldestOutstanding!),
                                      b.ageDays ?? 0),
                                  style: _meta(context)),
                            if (b.unconfirmedHandovers > 0)
                              Text(
                                  s.balanceUnconfirmed(
                                      formatTsh(b.unconfirmedHandovers)),
                                  style: _meta(context)),
                            if (b.pendingAdjustments > 0)
                              Text(
                                  s.balancePendingAdjustments(
                                      b.pendingAdjustments),
                                  style: _meta(context)),
                          ])),
                      SizedBox(width: u(12)),
                      const OwnerGlyph('vendor-chevron', size: 14),
                    ])))));
  }
}

// One vendor's money ---------------------------------------------------------------------

class OfficeVendorMoneyScreen extends ConsumerWidget {
  final String vendorId;
  const OfficeVendorMoneyScreen({super.key, required this.vendorId});

  Future<void> _request(BuildContext context, WidgetRef ref,
      {OfficeAdjustment? correcting}) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) =>
            _AdjustmentSheet(vendorId: vendorId, correcting: correcting));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.adjustmentSaved);
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
    final money = ref.watch(vendorMoneyProvider(vendorId));
    final name = money.valueOrNull?.balance.vendor.name ?? '';
    return OwnerPage(
        title: name.isEmpty ? s.money : name,
        strings: s,
        onRefresh: () => ref.refresh(vendorMoneyProvider(vendorId).future),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView(
                value: money,
                onRetry: () => ref.invalidate(vendorMoneyProvider(vendorId)),
                loadingRows: 3,
                data: (v) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BalanceSummary(balance: v.balance),
                          _gap(context, 20),
                          Text(s.adjustments, style: _title(context)),
                          _gap(context, 8),
                          if (me.settle) ...[
                            MNButton.secondary(s.adjustmentNew,
                                onPressed: () => _request(context, ref)),
                            _gap(context),
                          ],
                          if (v.adjustments.isEmpty)
                            MNNote(s.adjustmentNone, tone: MNNoteTone.info)
                          else
                            _Paged(
                                count: v.adjustments.length,
                                itemBuilder: (_, i) => _AdjustmentCard(
                                    adjustment: v.adjustments[i],
                                    corrected: v.adjustments
                                        .where((a) =>
                                            a.id == v.adjustments[i].correctsId)
                                        .firstOrNull,
                                    onCorrect: () => _request(context, ref,
                                        correcting: v.adjustments[i]))),
                          _gap(context, 20),
                          Text(s.balanceDays, style: _title(context)),
                          _gap(context, 8),
                          if (v.days.isEmpty)
                            MNNote(s.moneyNoDays, tone: MNNoteTone.info)
                          else
                            _Paged(
                                count: v.days.length,
                                itemBuilder: (_, i) =>
                                    _BalanceDayCard(day: v.days[i])),
                        ]))));
  }
}

class _BalanceSummary extends ConsumerWidget {
  final OfficeVendorBalance balance;
  const _BalanceSummary({required this.balance});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final b = balance;
    final (word, color) = balanceWord(s, b);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(word,
          style: OwnerStyle.text(context, 20, weight: 600, color: color)),
      if (b.oldestOutstanding != null)
        Text(s.balanceSince(s.date(b.oldestOutstanding!), b.ageDays ?? 0),
            style: _meta(context)),
      _gap(context, 8),
      OwnerHelp(message: s.balancesHelp),
      if (b.unconfirmedHandovers > 0 ||
          b.unverifiedCashSales > 0 ||
          b.pendingAdjustments > 0 ||
          b.unresolvedDays > 0)
        _gap(context, 8),
      if (b.unconfirmedHandovers > 0)
        Text(s.balanceUnconfirmed(formatTsh(b.unconfirmedHandovers)),
            style: _body(context)),
      if (b.unverifiedCashSales > 0)
        Text(s.balanceUnverified(formatTsh(b.unverifiedCashSales)),
            style: _body(context)),
      if (b.pendingAdjustments > 0)
        Text(s.balancePendingAdjustments(b.pendingAdjustments),
            style: _body(context)),
      if (b.unresolvedDays > 0)
        Text(s.balanceUnresolvedDays(b.unresolvedDays),
            style: _status(context, MNColors.warning)),
    ]));
  }
}

class _BalanceDayCard extends ConsumerWidget {
  final OfficeBalanceDay day;
  const _BalanceDayCard({required this.day});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final d = day;
    final (word, color) = moneyStatusWord(s, d.status);
    final date = d.businessDate == null ? '—' : s.date(d.businessDate!);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(d.station == null ? date : '$date · ${d.station!.name}',
          style: _strong(context)),
      Text(word, style: _status(context, color)),
      _gap(context, 6),
      Text(s.balanceDayDue(formatTsh(d.due)), style: _body(context)),
      if (d.remaining > 0)
        Text(s.balanceDayRemaining(formatTsh(d.remaining)),
            style: _body(context)),
      if (d.debits > 0 || d.credits > 0)
        Text(s.balanceDayAdjusted(formatTsh(d.debits), formatTsh(d.credits)),
            style: _meta(context)),
      OwnerDetails(title: s.recordDetails, children: [
        Text(s.balanceDayApplied(formatTsh(d.applied)), style: _body(context)),
      ]),
      if (d.unconfirmed > 0)
        Text(s.balanceUnconfirmed(formatTsh(d.unconfirmed)),
            style: _meta(context)),
      if (d.unverifiedCashSales > 0)
        Text(s.balanceUnverified(formatTsh(d.unverifiedCashSales)),
            style: _meta(context)),
    ]));
  }
}

// Adjustments -----------------------------------------------------------------------------

class _AdjustmentCard extends ConsumerWidget {
  final OfficeAdjustment adjustment;

  /// The adjustment a correction names, when it is in the list.
  final OfficeAdjustment? corrected;
  final VoidCallback onCorrect;
  const _AdjustmentCard(
      {required this.adjustment, required this.onCorrect, this.corrected});

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final a = adjustment;
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title: approve ? s.adjustmentApprove : s.adjustmentReject,
            note: approve ? s.adjustmentApproveNote : s.adjustmentRejectNote,
            actionLabel: approve ? s.adjustmentApprove : s.adjustmentReject,
            send: (reason) => officeBalancesCall(
                ref,
                (r) => r.decideAdjustment(a.id,
                    approve: approve, reason: reason))));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.adjustmentDecided);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final a = adjustment;
    final kind = s.adjustmentKindName(a.kind?.wire ?? '');
    final (word, color) = a.pending
        ? (s.adjustmentPending, MNColors.warning)
        : a.approved
            ? (
                s.adjustmentApprovedBy(a.decidedBy?.name ?? '—'),
                MNColors.success
              )
            : (
                s.adjustmentRejectedBy(a.decidedBy?.name ?? '—'),
                OwnerStyle.muted
              );
    final own = me.id != null && a.requestedBy?.id == me.id;
    final corrects = corrected;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$kind · ${s.adjustmentEffect(a.debit, formatTsh(a.amount))}',
          style: _title(context)),
      if (a.businessDate != null)
        Text(s.moneyDayText(s.date(a.businessDate!)), style: _meta(context)),
      if (corrects != null)
        Text(
            s.adjustmentCorrects(
                s.adjustmentKindName(corrects.kind?.wire ?? ''),
                formatTsh(corrects.amount)),
            style: _meta(context)),
      Text(s.reasonText(a.reason), style: _body(context)),
      if (a.basisRef != null)
        Text(s.basisText(a.basisRef!), style: _meta(context)),
      Text(
          s.adjustmentRequestedBy(
              a.requestedBy?.name ?? '—', _when(s, a.createdAt)),
          style: _meta(context)),
      _gap(context, 4),
      Text(word, style: _status(context, color)),
      if (a.decisionReason != null)
        Text(s.reasonText(a.decisionReason!), style: _meta(context)),
      if (me.settle && a.pending) ...[
        _gap(context),
        if (own)
          Text(s.adjustmentOwn, style: _meta(context))
        else ...[
          MNButton(s.adjustmentApprove,
              onPressed: () => _decide(context, ref, true)),
          _gap(context, 8),
          MNButton.secondary(s.adjustmentReject,
              onPressed: () => _decide(context, ref, false)),
        ],
      ],
      if (me.settle && a.approved && a.kind != AdjustmentKind.correction) ...[
        _gap(context, 8),
        MNButton.secondary(s.adjustmentCorrect, onPressed: onCorrect),
      ],
    ]));
  }
}

/// Asks for a new adjustment, or for a correction of [correcting] (the other
/// direction, at most its amount; the server checks what is left).
class _AdjustmentSheet extends ConsumerStatefulWidget {
  final String vendorId;
  final OfficeAdjustment? correcting;
  const _AdjustmentSheet({required this.vendorId, this.correcting});
  @override
  ConsumerState<_AdjustmentSheet> createState() => _AdjustmentSheetState();
}

class _AdjustmentSheetState extends ConsumerState<_AdjustmentSheet> {
  /// One id per request: a retry after no answer records one adjustment.
  final _clientId = const Uuid().v4();
  late final DateTime _today = businessDate(ref.read(clockProvider)());
  late DateTime _day = widget.correcting?.businessDate ?? _today;
  AdjustmentKind? _kind;
  late final _amount = TextEditingController(
      text: widget.correcting == null ? '' : '${widget.correcting!.amount}');
  final _reason = TextEditingController();
  final _basis = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _basis.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showMNDateSheet(context,
        title: ref.read(stringsProvider).adjustmentDay,
        initial: _day,
        first: DateTime.utc(_today.year - 2),
        last: _today);
    if (picked != null && mounted) {
      setState(
          () => _day = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final correcting = widget.correcting;
    final kind = correcting == null ? _kind : AdjustmentKind.correction;
    final amount = int.tryParse(_amount.text.trim());
    final reason = _reason.text.trim();
    final basis = _basis.text.trim();
    String? error;
    if (kind == null) {
      error = s.moneyInvalid;
    } else if (amount == null || amount <= 0) {
      error = s.moneyAmountInvalid;
    } else if (reason.length < 3 || reason.length > 500) {
      error = s.decisionReasonInvalid;
    } else if (basis.length < 3 || basis.length > 120) {
      error = s.adjustmentBasisInvalid;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final direction = correcting == null
        ? kind!.direction!
        : (correcting.debit ? 'credit' : 'debit');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeBalancesCall(
          ref,
          (r) => r.requestAdjustment(
              clientId: _clientId,
              vendorId: widget.vendorId,
              businessDate: moneyDateKey(_day),
              kind: kind!,
              direction: direction,
              amount: amount!,
              reason: reason,
              basisRef: basis,
              correctsId: correcting?.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final correcting = widget.correcting;
    return MNSheet(
        title: correcting == null ? s.adjustmentNew : s.adjustmentCorrect,
        children: [
          MNNote(
              correcting == null ? s.adjustmentHelp : s.adjustmentCorrectNote,
              tone: MNNoteTone.info),
          if (correcting == null) ...[
            MNSelectField<AdjustmentKind>(
                label: s.adjustmentKind,
                value: _kind,
                options: [
                  for (final k in const [
                    AdjustmentKind.stockCharge,
                    AdjustmentKind.priceShortfall,
                    AdjustmentKind.writeOff
                  ])
                    MNSelectOption(
                        value: k,
                        label: s.adjustmentKindName(k.wire),
                        caption: s.adjustmentKindCaption(k.wire)),
                ],
                onChanged: _busy ? null : (k) => setState(() => _kind = k)),
            MNFieldButton(
                label: s.adjustmentDay,
                text: s.date(_day),
                placeholder: s.date(_day),
                icon: MNIconData.calendar,
                onTap: _busy ? null : _pickDay),
          ] else
            Text(
                s.adjustmentCorrects(
                    s.adjustmentKindName(correcting.kind?.wire ?? ''),
                    formatTsh(correcting.amount)),
                style: _body(context)),
          MNTextField(
              label: s.moneyAmount,
              controller: _amount,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9)
              ]),
          MNTextField(
              label: s.moneyReason,
              controller: _reason,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(500)]),
          MNTextField(
              label: s.adjustmentBasis,
              controller: _basis,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(120)]),
          if (_error != null) MNNote(_error!, error: true),
          MNButton(s.adjustmentSend,
              busy: _busy, onPressed: _busy ? null : _save),
        ]);
  }
}

class _ReasonSheet extends ConsumerStatefulWidget {
  final String title, note, actionLabel;
  final Future<void> Function(String reason) send;
  const _ReasonSheet(
      {required this.title,
      required this.note,
      required this.actionLabel,
      required this.send});
  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _message;
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
      setState(() => _message = s.decisionReasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.send(reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _message = _errorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      MNNote(widget.note, tone: MNNoteTone.warning),
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_message != null) MNNote(_message!, error: true),
      MNButton(widget.actionLabel,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// Exports ----------------------------------------------------------------------------------

/// "Pakua ripoti (CSV)" on the money home.
class MoneyExportEntry extends ConsumerWidget {
  const MoneyExportEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerCard(
        child: OwnerMenuRow(
            label: s.moneyExport,
            subtitle: s.moneyExportCaption,
            onTap: () async {
              final rows = await showMNSheet<int>(context,
                  builder: (_) => const _ExportSheet());
              if (rows != null && context.mounted) {
                _toast(context, s.moneyExportSaved(rows));
              }
            }));
  }
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();
  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  late final DateTime _today = businessDate(ref.read(clockProvider)());
  late DateTime _from = _today.subtract(const Duration(days: 29));
  late DateTime _to = _today;
  MoneyExportKind _kind = MoneyExportKind.days;
  String? _station, _error;
  bool _busy = false;

  Future<void> _pickRange() async {
    final picked = await showMNDateRangeSheet(context,
        title: ref.read(stringsProvider).moneyExportRange,
        start: _from,
        end: _to,
        first: DateTime.utc(_today.year - 2),
        last: _today);
    if (picked != null && mounted) {
      setState(() {
        _from = picked.$1;
        _to = picked.$2;
      });
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await officeBalancesCall(
          ref,
          (r) => r.moneyExport(_kind,
              from: moneyDateKey(_from),
              to: moneyDateKey(_to),
              stationId: _station));
      await ref.read(saveMoneyExportProvider)(file.filename, file.bytes);
      if (mounted) Navigator.of(context).pop(file.rows);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final stations =
        ref.watch(verificationQueueProvider).valueOrNull ?? const [];
    return MNSheet(title: s.moneyExport, children: [
      MNSelectField<MoneyExportKind>(
          label: s.moneyExportKind,
          value: _kind,
          options: [
            for (final k in MoneyExportKind.values)
              MNSelectOption(value: k, label: s.moneyExportKindName(k.wire)),
          ],
          onChanged: _busy ? null : (k) => setState(() => _kind = k)),
      MNSelectField<String?>(
          label: s.moneyExportStation,
          value: _station,
          options: [
            MNSelectOption(value: null, label: s.allStations),
            for (final st in stations)
              MNSelectOption(value: st.id, label: st.name),
          ],
          onChanged: _busy ? null : (v) => setState(() => _station = v)),
      if (_kind != MoneyExportKind.balances)
        MNFieldButton(
            label: s.moneyExportRange,
            text: '${s.date(_from)} – ${s.date(_to)}',
            placeholder: s.moneyExportRange,
            icon: MNIconData.calendar,
            onTap: _busy ? null : _pickRange),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.moneyExportSave,
          busy: _busy, onPressed: _busy ? null : _download),
    ]);
  }
}
