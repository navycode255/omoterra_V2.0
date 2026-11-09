import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_catalogue.dart';
import '../../core/api/office_closing_cases.dart';
import '../../core/api/office_repository.dart' show OfficeError, StaffRole;
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;
import 'product_screens.dart' show officeProductsProvider;

/// Missed-closing cases (MN031): the days nobody counted at a station, and the
/// estimate or "not counted" case that explains one. A case is information
/// only: it never says a day was counted, and nothing here changes stock. A
/// supervisor or the owner opens a case; finance or the owner decides it,
/// never the person who opened it. The server decides every outcome.

/// The missed days of one station (null: every station this person sees).
final closingCasesProvider = FutureProvider.autoDispose
    .family<List<MissedDay>, String?>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => (r as OfficeClosingCasesRepository)
            .missedDays(stationId: stationId)));

/// What the signed-in account may plausibly do. The server decides.
({bool open, bool decide}) closingCaseAccess(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  return (
    // closing_cases.open
    open: roles.any({StaffRole.supervisor, StaffRole.owner}.contains),
    // closing_cases.decide
    decide: roles.any({StaffRole.finance, StaffRole.owner}.contains),
  );
}

DateTime _day(String iso) => DateTime.tryParse(iso) ?? DateTime.utc(2000);

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 20));

Color _stateColor(String status) => switch (status) {
      'approved' => MNColors.success,
      'rejected' => MNColors.error,
      'open' => MNColors.warning,
      _ => OwnerStyle.muted,
    };

String _vendors(MissedDay day) => day.vendors.map((v) => v.name).join(', ');

/// "Siku zisizofungwa" as one row, only while the station has such a day and
/// the person may act on it. Placed on the station's verification screen and
/// on Stoo.
class ClosingCasesRow extends ConsumerWidget {
  final String stationId;

  /// Stand alone in its own card (Stoo) instead of inside a list of rows.
  final bool card;
  const ClosingCasesRow({super.key, required this.stationId, this.card = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = closingCaseAccess(ref);
    if (!access.open && !access.decide) return const SizedBox.shrink();
    final days = ref.watch(closingCasesProvider(stationId)).valueOrNull;
    if (days == null || days.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final row = OwnerMenuRow(
        label: s.closingCasesTitle,
        subtitle: s.closingCasesRowCount(days.length),
        onTap: () => context.push(MNRoutes.officeClosingCases(stationId)));
    return card
        ? Padding(
            padding: EdgeInsets.only(top: OwnerStyle.px(context, 12)),
            child: OwnerCard(radius: 17, child: row))
        : row;
  }
}

// The list ---------------------------------------------------------------------------

class ClosingCasesScreen extends ConsumerWidget {
  final String stationId;
  const ClosingCasesScreen({super.key, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = closingCaseAccess(ref);
    return OwnerPage(
        title: s.closingCasesTitle,
        strings: s,
        onRefresh: () => ref.refresh(closingCasesProvider(stationId).future),
        child: Padding(
            padding: _pad(context),
            child: !access.open && !access.decide
                ? MNNote(s.notAllowed)
                : OwnerAsyncView<List<MissedDay>>(
                    value: ref.watch(closingCasesProvider(stationId)),
                    onRetry: () =>
                        ref.invalidate(closingCasesProvider(stationId)),
                    isEmpty: (rows) => rows.isEmpty,
                    empty: (_) =>
                        MNNote(s.closingCasesEmpty, tone: MNNoteTone.info),
                    data: (rows) => OwnerCard(
                            child: Column(children: [
                          for (final day in rows)
                            _DayRow(day: day, stationId: stationId),
                        ])))));
  }
}

class _DayRow extends ConsumerWidget {
  final MissedDay day;
  final String stationId;
  const _DayRow({required this.day, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = closingCaseAccess(ref);
    final current = day.current;
    final state = current == null
        ? s.closingCaseNone
        : '${s.closingCaseOutcome(current.outcome)} · ${s.closingCaseState(current.status)}';
    return OwnerMenuRow(
        label: s.date(_day(day.businessDate)),
        subtitle: '${_vendors(day)}\n$state',
        height: 76,
        onTap: current != null
            ? () async {
                await context.push(
                    MNRoutes.officeClosingCase(current.id, stationId: stationId));
                ref.invalidate(closingCasesProvider);
              }
            : access.open
                ? () async {
                    await context.push(
                        MNRoutes.officeClosingCase('nje', stationId: stationId),
                        extra: day.businessDate);
                    ref.invalidate(closingCasesProvider);
                  }
                : null);
  }
}

// One case ---------------------------------------------------------------------------

class ClosingCaseScreen extends ConsumerWidget {
  /// A case id, or `nje` for a day with no case yet (then [openDate] names it
  /// through the route's `extra`).
  final String caseId;
  final String? stationId;
  const ClosingCaseScreen({super.key, required this.caseId, this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final days = ref.watch(closingCasesProvider(stationId));
    final openDate = GoRouterState.of(context).extra as String?;
    return OwnerPage(
        title: s.closingCasesTitle,
        strings: s,
        onRefresh: () => ref.refresh(closingCasesProvider(stationId).future),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView<List<MissedDay>>(
                value: days,
                onRetry: () => ref.invalidate(closingCasesProvider(stationId)),
                data: (rows) {
                  final day = rows
                      .where((d) => caseId == 'nje'
                          ? d.businessDate == openDate
                          : d.current?.id == caseId ||
                              d.history.any((c) => c.id == caseId))
                      .firstOrNull;
                  if (day == null) {
                    return MNNote(s.closingCasesEmpty, tone: MNNoteTone.info);
                  }
                  return _CaseView(day: day, stationId: stationId);
                })));
  }
}

class _CaseView extends ConsumerWidget {
  final MissedDay day;
  final String? stationId;
  const _CaseView({required this.day, required this.stationId});

  Future<void> _decide(BuildContext context, WidgetRef ref, ClosingCase c,
      bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecisionSheet(closingCase: c, approve: approve));
    if (done != true || !context.mounted) return;
    ref.invalidate(closingCasesProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.approvalDecisionSaved)));
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => OpenClosingCaseScreen(day: day)));
    if (sent == true) ref.invalidate(closingCasesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = closingCaseAccess(ref);
    final current = day.current;
    final body = OwnerStyle.text(context, 16);
    final meta = OwnerStyle.text(context, 14, color: OwnerStyle.muted);
    Widget gap([double h = 8]) => SizedBox(height: OwnerStyle.px(context, h));
    Widget caseCard(ClosingCase c) => OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(s.closingCaseOutcome(c.outcome),
                            style: OwnerStyle.text(context, 17, weight: 700))),
                    Text(s.closingCaseState(c.status),
                        style: OwnerStyle.text(context, 14,
                            weight: 600, color: _stateColor(c.status))),
                  ]),
                  if (c.isEstimate) ...[
                    gap(4),
                    Text(s.closingCaseEstimateLabel, style: meta),
                  ],
                  gap(),
                  Text(c.basis, style: body),
                  for (final l in c.lines)
                    Text('${l.name}: ${l.estimated}', style: body),
                  gap(),
                  if (c.openedBy != null)
                    Text(s.closingCaseOpenedBy(c.openedBy!.name), style: meta),
                  if (c.decidedBy != null)
                    Text(s.closingCaseDecidedBy(c.decidedBy!.name),
                        style: meta),
                  if ((c.decisionReason ?? '').isNotEmpty &&
                      c.status != 'withdrawn')
                    Text(s.reasonText(c.decisionReason!), style: meta),
                ])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.date(_day(day.businessDate)),
          style: OwnerStyle.text(context, 20, weight: 700)),
      Text('${day.stationName} · ${_vendors(day)}', style: meta),
      gap(12),
      if (current != null) caseCard(current) else MNNote(s.closingCaseNone, tone: MNNoteTone.info),
      gap(12),
      if (current != null && current.isOpen) ...[
        if (current.openedByMe)
          MNNote(s.closingCaseOwnWaiting, tone: MNNoteTone.info)
        else if (access.decide) ...[
          MNButton(s.approvalApprove,
              onPressed: () => _decide(context, ref, current, true)),
          gap(),
          MNButton.secondary(s.approvalReject,
              onPressed: () => _decide(context, ref, current, false)),
        ],
      ] else if (day.canOpen && access.open)
        MNButton(s.closingCaseOpen, onPressed: () => _open(context, ref)),
      if (day.history.isNotEmpty) ...[
        gap(20),
        Text(s.closingCaseHistory,
            style: OwnerStyle.text(context, 17, weight: 600)),
        gap(),
        for (final c in day.history) ...[caseCard(c), gap(12)],
      ],
    ]);
  }
}

class _DecisionSheet extends ConsumerStatefulWidget {
  final ClosingCase closingCase;
  final bool approve;
  const _DecisionSheet({required this.closingCase, required this.approve});
  @override
  ConsumerState<_DecisionSheet> createState() => _DecisionState();
}

class _DecisionState extends ConsumerState<_DecisionSheet> {
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
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeClosingCasesRepository).decideClosingCase(
              widget.closingCase.id,
              approve: widget.approve,
              reason: _reason.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } on ClosingCaseBlocked catch (blocked) {
      if (mounted) {
        setState(() => _error = s.closingCaseBlockedTitle(
            blocked.unverifiedSales > 0
                ? s.closingCaseBlockedSales(blocked.unverifiedSales)
                : '',
            blocked.pendingDamage > 0
                ? s.closingCaseBlockedDamage(blocked.pendingDamage)
                : ''));
      }
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final label = widget.approve ? s.approvalApprove : s.approvalReject;
    return MNSheet(title: label, children: [
      MNTextField(
          label: s.approvalReason,
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

// Opening a case ---------------------------------------------------------------------

class _Line {
  final String product;
  int quantity;
  _Line(this.product, this.quantity);
}

class OpenClosingCaseScreen extends ConsumerStatefulWidget {
  final MissedDay day;
  const OpenClosingCaseScreen({super.key, required this.day});
  @override
  ConsumerState<OpenClosingCaseScreen> createState() => _OpenState();
}

class _OpenState extends ConsumerState<OpenClosingCaseScreen> {
  static const _max = 1000000;

  /// One id per case: a retry after no answer sends the same id and body.
  String _clientId = const Uuid().v4();

  /// What the last unanswered send carried: the id is kept only while the
  /// form still says the same, so an edit is never swallowed by a retry.
  String? _sentAs;
  String? _outcome, _error;
  final _basis = TextEditingController();
  final _lines = <_Line>[];
  bool _busy = false;

  @override
  void dispose() {
    _basis.dispose();
    super.dispose();
  }

  bool get _estimate => _outcome == 'estimate';
  bool get _ready =>
      _outcome != null &&
      _basis.text.trim().length >= 10 &&
      (!_estimate || _lines.isNotEmpty);

  Future<void> _addProduct(Strings s, List<OfficeProduct> products) async {
    final picked = await showMNSelectSheet<String>(context,
        title: s.officeChooseProduct,
        emptyText: s.noOfficeProducts,
        options: [
          for (final p in products.where((p) => p.status == 'active'))
            MNSelectOption(
                value: p.code,
                label: p.name,
                enabled: !_lines.any((l) => l.product == p.code),
                caption: _lines.any((l) => l.product == p.code)
                    ? s.officeAlreadyAdded
                    : s.unitName(p.unit))
        ]);
    if (picked != null && mounted) {
      setState(() => _lines.add(_Line(picked.value, 1)));
    }
  }

  Future<void> _review(Strings s) async {
    if (!_ready) {
      setState(() => _error = s.closingCaseFormInvalid);
      return;
    }
    final yes = await showMNSheet<bool>(context,
        builder: (sheet) => MNSheet(title: s.closingCaseConfirmTitle, children: [
              Text(
                  '${s.closingCaseOutcome(_outcome!)} · ${s.date(_day(widget.day.businessDate))}',
                  style: MNText.resolve(context, MNText.body)),
              Text(
                  _estimate
                      ? s.closingCaseConfirmEstimate
                      : s.closingCaseConfirmNotCounted,
                  style: MNText.resolve(context, MNText.meta)),
              MNButton(s.closingCaseSend,
                  onPressed: () => Navigator.pop(sheet, true)),
              MNButton.secondary(s.cancel,
                  onPressed: () => Navigator.pop(sheet, false)),
            ]));
    if (yes != true || !mounted) return;
    await _send(s);
  }

  Future<void> _send(Strings s) async {
    if (_busy) return;
    final form = '$_outcome|${_basis.text.trim()}|'
        '${_estimate ? _lines.map((l) => '${l.product}:${l.quantity}').join(',') : ''}';
    if (_sentAs != null && _sentAs != form) _clientId = const Uuid().v4();
    _sentAs = form;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeClosingCasesRepository).openClosingCase(
              clientId: _clientId,
              stationId: widget.day.stationId,
              businessDate: widget.day.businessDate,
              outcome: _outcome!,
              basis: _basis.text.trim(),
              lines: _estimate
                  ? [for (final l in _lines) CaseLineDraft(l.product, l.quantity)]
                  : const []));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.closingCaseSent)));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is OfficeError) {
          // A definite refusal recorded nothing: the next send is a new one.
          _clientId = const Uuid().v4();
          _sentAs = null;
          _error = officeErrorText(s, error);
        } else {
          _error = '${officeErrorText(s, error)}\n${s.sendRetryNote}';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _lineRow(Strings s, _Line line, OfficeProduct? p) {
    final name = p?.name ?? line.product;
    void set(int v) => setState(() {
          if (v == 0) {
            _lines.remove(line);
          } else {
            line.quantity = v;
          }
        });
    return Padding(
        key: ValueKey(line),
        padding: const EdgeInsets.symmetric(vertical: MNSpace.x2),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name, style: MNText.resolve(context, MNText.body)),
                if (p != null)
                  Text(s.unitName(p.unit),
                      style: MNText.resolve(context, MNText.meta)),
              ])),
          MNQuantitySelector(
              value: line.quantity,
              min: 0,
              max: _max,
              compact: true,
              itemLabel: name,
              onChanged: _busy ? (_) {} : set),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(officeProductsProvider);
    final byCode = {
      for (final p in products.valueOrNull ?? const <OfficeProduct>[]) p.code: p
    };
    return OwnerPage(
        title: s.closingCaseOpen,
        strings: s,
        onBack: () => Navigator.of(context).pop(),
        child: Padding(
            padding: _pad(context),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.date(_day(widget.day.businessDate)),
                      style: OwnerStyle.text(context, 20, weight: 700)),
                  Text('${widget.day.stationName} · ${_vendors(widget.day)}',
                      style: OwnerStyle.text(context, 14,
                          color: OwnerStyle.muted)),
                  const SizedBox(height: MNSpace.x4),
                  MNSelectField<String>(
                      label: s.closingCaseKind,
                      value: _outcome,
                      options: [
                        for (final code in const ['estimate', 'not_counted'])
                          MNSelectOption(
                              value: code, label: s.closingCaseOutcome(code)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                _outcome = v;
                                _error = null;
                              })),
                  const SizedBox(height: MNSpace.x3),
                  MNTextField(
                      label: s.closingCaseBasis,
                      controller: _basis,
                      enabled: !_busy,
                      maxLines: 3,
                      onChanged: (_) => setState(() => _error = null),
                      inputFormatters: [LengthLimitingTextInputFormatter(500)]),
                  if (_estimate) ...[
                    const SizedBox(height: MNSpace.x4),
                    Text(s.closingCaseEstimates,
                        style: OwnerStyle.text(context, 17, weight: 600)),
                    Text(s.closingCaseEstimateLabel,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                    for (final l in _lines) _lineRow(s, l, byCode[l.product]),
                    const SizedBox(height: MNSpace.x2),
                    MNButton.secondary(s.closingCaseAddProduct,
                        onPressed: _busy
                            ? null
                            : () => _addProduct(
                                s, products.valueOrNull ?? const [])),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: MNSpace.x3),
                    MNNote(_error!, error: true),
                  ],
                  const SizedBox(height: MNSpace.x4),
                  MNButton(s.closingCaseSend,
                      busy: _busy,
                      onPressed: _ready && !_busy ? () => _review(s) : null),
                ])));
  }
}
