import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client_id.dart';
import '../../core/api/providers.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/filter_sheet.dart' show MNFilterSwitch;
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;

/// Runs a supply call with the office (or lead office) session. A repository
/// without supply requests refuses instead of pretending.
Future<T> _office<T>(OfficeSessionController session,
        Future<T> Function(OfficeSupplyRepository repository) call) =>
    session.guard((repository) {
      if (repository is! OfficeSupplyRepository) {
        return Future.error(const OfficeError(OfficeErrorKind.invalid));
      }
      return call(repository as OfficeSupplyRepository);
    });

/// Reads that need no repository support show nothing when there is none.
Future<List<T>> _list<T>(
    Ref ref, Future<List<T>> Function(OfficeSupplyRepository repository) call) {
  if (ref.read(officeRepositoryProvider) is! OfficeSupplyRepository) {
    return Future.value(<T>[]);
  }
  return _office(ref.read(officeSessionProvider.notifier), call);
}

/// Pending requests whose current step the signed-in person may decide.
final supplyWaitingProvider = FutureProvider.autoDispose<List<SupplyRequest>>(
    (ref) => _list(ref, (r) => r.waitingSupplyRequests()));

/// Money given and not closed: everything for Owner and Finance, otherwise
/// only what this person holds.
final supplyOutstandingProvider =
    FutureProvider.autoDispose<List<OutstandingAdvance>>(
        (ref) => _list(ref, (r) => r.officeSupplyOutstanding()));

/// A request as this person can act on it.
class SupplyView {
  final SupplyRequest request;

  /// It is in his waiting list: the server says he may decide its step now.
  final bool decidable;

  /// It is one of his own requests.
  final bool own;
  const SupplyView(this.request, {this.decidable = false, this.own = false});
}

Future<List<T>> _soft<T>(Future<List<T>> list) async {
  try {
    return await list;
  } on SupplyError {
    return <T>[];
  } on OfficeError {
    return <T>[];
  }
}

/// Approved requests, waiting for Owner or Finance to give money.
final supplyApprovedProvider = FutureProvider.autoDispose<List<SupplyRequest>>(
    (ref) => _list(ref, (r) => r.supplyRequestsByStatus('approved')));

/// A station's requests that money was given for (or later): the ones a
/// purchase delivery there may be linked to.
final supplyLinkableProvider = FutureProvider.autoDispose
    .family<List<SupplyRequest>, String>((ref, stationId) async {
  final found = <SupplyRequest>[];
  for (final status in const ['funded', 'purchased', 'closed']) {
    found.addAll(await _list(
        ref, (r) => r.supplyRequestsByStatus(status, stationId: stationId)));
  }
  return found;
});

/// A request read by its id, so it is there after leaving the page, a
/// refresh or a restart. Null when the server says it is not his to see.
final supplyViewProvider =
    FutureProvider.autoDispose.family<SupplyView?, String>((ref, id) async {
  if (ref.read(officeRepositoryProvider) is! OfficeSupplyRepository) {
    return null;
  }
  final session = ref.read(officeSessionProvider.notifier);
  final SupplyRequest request;
  try {
    request = await _office(session, (r) => r.supplyRequestById(id));
  } on SupplyError catch (e) {
    if (e.status == 404 || e.status == 403) return null;
    rethrow;
  }
  final waiting =
      await _soft(_office(session, (r) => r.waitingSupplyRequests()));
  final own = await _soft(_office(session, (r) => r.ownSupplyRequests()));
  return SupplyView(request,
      decidable: waiting.any((r) => r.id == id),
      own: own.any((r) => r.id == id));
});

bool _canFund(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn && auth.profile.canSettleMoney;
}

String? _myId(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn ? auth.profile.id : null;
}

Color _statusColor(String status) => switch (status) {
      'pending' => MNColors.warning,
      'rejected' => MNColors.error,
      'approved' || 'closed' => MNColors.success,
      _ => OwnerStyle.ink,
    };

String _summary(SupplyRequest r) =>
    r.lines.map((l) => '${l.name} ${l.quantity}').join(', ');

/// Requests waiting for this person's decision, as rows. On the approvals
/// page ([quiet]) it shows nothing when there are none or it cannot load.
class SupplyWaitingSection extends ConsumerWidget {
  final bool quiet;
  const SupplyWaitingSection({super.key, this.quiet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final waiting = ref.watch(supplyWaitingProvider);
    if (quiet) {
      final rows = waiting.valueOrNull;
      if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 8),
              OwnerStyle.px(context, 8), 0, OwnerStyle.px(context, 8)),
          child: Semantics(
              header: true,
              child: Text(s.supplyOfficeTitle,
                  style: OwnerStyle.text(context, 17, weight: 700)))),
      OwnerAsyncView<List<SupplyRequest>>(
          value: waiting,
          onRetry: () => ref.invalidate(supplyWaitingProvider),
          isEmpty: (rows) => rows.isEmpty,
          empty: (_) => MNNote(s.supplyWaitingEmpty, tone: MNNoteTone.info),
          data: (rows) => Column(children: [
                for (final r in rows)
                  Padding(
                      padding:
                          EdgeInsets.only(bottom: OwnerStyle.px(context, 10)),
                      child: OwnerCard(
                          child: OwnerMenuRow(
                              label: '${r.requesterName} · ${r.stationName}',
                              subtitle: _summary(r),
                              value: formatTsh(r.estimatedTotal),
                              valueSize: 14,
                              onTap: () => context
                                  .push(MNRoutes.officeSupplyRequest(r.id))))),
              ])),
      SizedBox(height: OwnerStyle.px(context, 8)),
    ]);
  }
}

/// Approved requests waiting for money, for Owner and Finance. Shows nothing
/// when there are none or it cannot load.
class SupplyApprovedSection extends ConsumerWidget {
  const SupplyApprovedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(supplyApprovedProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 8),
              OwnerStyle.px(context, 8), 0, OwnerStyle.px(context, 8)),
          child: Semantics(
              header: true,
              child: Text(s.supplyApprovedTitle,
                  style: OwnerStyle.text(context, 17, weight: 700)))),
      for (final r in rows)
        Padding(
            padding: EdgeInsets.only(bottom: OwnerStyle.px(context, 10)),
            child: OwnerCard(
                child: OwnerMenuRow(
                    label: '${r.requesterName} · ${r.stationName}',
                    subtitle: _summary(r),
                    value: formatTsh(r.estimatedTotal),
                    valueSize: 14,
                    onTap: () =>
                        context.push(MNRoutes.officeSupplyRequest(r.id))))),
      SizedBox(height: OwnerStyle.px(context, 8)),
    ]);
  }
}

/// Money given and not closed, oldest first, with its age in business days.
/// Each row opens the request. Shows nothing when there is none.
class SupplyOutstandingSection extends ConsumerWidget {
  /// Only the advances of this station (the delivery form).
  final String? stationId;
  const SupplyOutstandingSection({super.key, this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = [
      for (final o in ref.watch(supplyOutstandingProvider).valueOrNull ??
          const <OutstandingAdvance>[])
        if (stationId == null || o.stationId == stationId) o
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 8),
              OwnerStyle.px(context, 8), 0, OwnerStyle.px(context, 8)),
          child: Semantics(
              header: true,
              child: Text(s.supplyOutstandingTitle,
                  style: OwnerStyle.text(context, 17, weight: 700)))),
      for (final o in rows)
        Padding(
            padding: EdgeInsets.only(bottom: OwnerStyle.px(context, 10)),
            child: OwnerCard(
                child: OwnerMenuRow(
                    label: '${o.holderName} · ${formatTsh(o.amount)}',
                    subtitle:
                        '${o.stationName} · ${s.supplyAge(o.ageDays)} · ${o.explained ? s.supplyOutstandingExplained : s.supplyOutstandingOpen}',
                    valueSize: 14,
                    onTap: () => context
                        .push(MNRoutes.officeSupplyRequest(o.requestId))))),
      SizedBox(height: OwnerStyle.px(context, 8)),
    ]);
  }
}

/// Maombi ya mzigo (office): what waits for this person's decision and, for
/// Owner and Finance, the money still open. This is also the page a lead
/// opens from his Kituo section.
class OfficeSupplyRequestsScreen extends ConsumerWidget {
  const OfficeSupplyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerPage(
        title: s.supplyOfficeTitle,
        strings: s,
        onRefresh: () async {
          ref.invalidate(supplyOutstandingProvider);
          ref.invalidate(supplyApprovedProvider);
          await ref
              .refresh(supplyWaitingProvider.future)
              .then((_) {}, onError: (_) {});
        },
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SupplyWaitingSection(),
                  if (_canFund(ref)) const SupplyApprovedSection(),
                  if (_canFund(ref)) const SupplyOutstandingSection(),
                ])));
  }
}

/// One request: lines (requested against received), steps, deliveries, the
/// money, and the actions this person has right now.
class OfficeSupplyRequestScreen extends ConsumerStatefulWidget {
  final String id;
  const OfficeSupplyRequestScreen({super.key, required this.id});
  @override
  ConsumerState<OfficeSupplyRequestScreen> createState() => _RequestState();
}

class _RequestState extends ConsumerState<OfficeSupplyRequestScreen> {
  /// The server's answer after an action here; shown in place of the list.
  SupplyRequest? _answer;

  void _changed(SupplyRequest next) {
    setState(() => _answer = next);
    ref.invalidate(supplyWaitingProvider);
    ref.invalidate(supplyOutstandingProvider);
    ref.invalidate(supplyApprovedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final view = ref.watch(supplyViewProvider(widget.id));
    return OwnerPage(
        title: s.supplyOfficeTitle,
        strings: s,
        onRefresh: () async {
          setState(() => _answer = null);
          ref.invalidate(supplyOutstandingProvider);
          await ref
              .refresh(supplyViewProvider(widget.id).future)
              .then((_) {}, onError: (_) {});
        },
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: OwnerAsyncView<SupplyView?>(
                value: view,
                onRetry: () => ref.invalidate(supplyViewProvider(widget.id)),
                isEmpty: (v) => v == null && _answer == null,
                empty: (_) => MNNote(s.supplyNotFound, tone: MNNoteTone.info),
                data: (v) => _Detail(
                    request: _answer ?? v!.request,
                    // A decision or money already acted on here is final:
                    // what the server answered decides what is offered next.
                    decidable: _answer == null && (v?.decidable ?? false),
                    own: v?.own ?? false,
                    onChanged: _changed))));
  }
}

class _Detail extends ConsumerWidget {
  final SupplyRequest request;
  final bool decidable, own;
  final ValueChanged<SupplyRequest> onChanged;
  const _Detail(
      {required this.request,
      required this.decidable,
      required this.own,
      required this.onChanged});

  Future<void> _decide(BuildContext context, bool approve) async {
    final next = await showMNSheet<SupplyRequest>(context,
        builder: (_) => _DecisionSheet(request: request, approve: approve));
    if (next != null) onChanged(next);
  }

  Future<void> _give(BuildContext context) async {
    final next = await showMNSheet<SupplyRequest>(context,
        builder: (_) => _GiveSheet(request: request));
    if (next != null) onChanged(next);
  }

  Future<void> _confirm(BuildContext context) async {
    final next = await showMNSheet<SupplyRequest>(context,
        builder: (_) => _ConfirmSheet(request: request));
    if (next != null) onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = request;
    final body = MNText.resolve(context, MNText.body);
    final meta = MNText.resolve(context, MNText.meta);
    final me = _myId(ref);
    final fund = _canFund(ref);
    final mine = own || (me != null && r.requesterId == me);
    final holder = r.advance != null && r.advance!.holderId == me;
    final gap = SizedBox(height: OwnerStyle.px(context, 12));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerCard(
          child: Padding(
              padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.supplyStatusLine(r.status, r.waitingKind, r.chain),
                        style: MNText.withWeight(body, FontWeight.w700)
                            .copyWith(color: _statusColor(r.status))),
                    if (r.stationName.isNotEmpty)
                      Text('${s.supplyStation}: ${r.stationName}', style: body),
                    if (r.requesterName.isNotEmpty)
                      Text('${s.supplyRequester}: ${r.requesterName}',
                          style: body),
                    if (r.neededBy.isNotEmpty)
                      Text('${s.supplyNeededBy}: ${r.neededBy}', style: meta),
                    if (r.note != null && r.note!.isNotEmpty)
                      Text(r.note!, style: meta),
                    if (r.lines.isNotEmpty)
                      Text(
                          '${s.supplyEstimatedTotal}: ${formatTsh(r.estimatedTotal)}',
                          style: meta),
                  ]))),
      if (r.lines.isNotEmpty) ...[gap, _Lines(request: r)],
      if (r.steps.isNotEmpty) ...[gap, _Steps(request: r)],
      if (r.advance != null) ...[gap, _Money(request: r)],
      if (r.deliveries.isNotEmpty || r.status == SupplyStatus.closed) ...[
        gap,
        _Deliveries(request: r)
      ],
      gap,
      if (decidable && r.isPending) ...[
        MNButton(s.approvalApprove, onPressed: () => _decide(context, true)),
        SizedBox(height: OwnerStyle.px(context, 8)),
        MNButton.secondary(s.approvalReject,
            onPressed: () => _decide(context, false)),
      ] else if (r.isPending && mine)
        MNNote(s.supplyNotDecidable, tone: MNNoteTone.info),
      if (r.status == SupplyStatus.approved && fund && !mine)
        MNButton(s.supplyGiveMoney, onPressed: () => _give(context)),
      if (r.status == SupplyStatus.purchased && fund && !holder && !mine)
        MNButton(s.supplyConfirm, onPressed: () => _confirm(context)),
    ]);
  }
}

class _Lines extends ConsumerWidget {
  final SupplyRequest request;
  const _Lines({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final body = MNText.resolve(context, MNText.body);
    final meta = MNText.resolve(context, MNText.meta);
    final counted = request.deliveries.isNotEmpty;
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final line in request.lines) ...[
                Text(line.name,
                    style: MNText.withWeight(body, FontWeight.w600)),
                Text(
                    '${s.supplyRequested}: ${line.quantity} ${line.unit} · ${formatTsh(line.estimatedUnitPrice.round())}',
                    style: meta),
                if (counted)
                  Text(
                      line.received == null
                          ? '${s.supplyReceived}: ${s.supplyReceivedUnknown}'
                          : '${s.supplyReceived}: ${line.received} ${line.unit} · ${s.supplyDifference}: ${line.difference}',
                      style: meta),
                SizedBox(height: OwnerStyle.px(context, 8)),
              ],
            ])));
  }
}

class _Steps extends ConsumerWidget {
  final SupplyRequest request;
  const _Steps({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final body = MNText.resolve(context, MNText.body);
    final meta = MNText.resolve(context, MNText.meta);
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.supplySteps,
                  style: MNText.withWeight(body, FontWeight.w700)),
              for (final step in request.steps)
                Text(
                    [
                      s.supplyStepName(step.kind),
                      if (step.skipped)
                        s.supplyStepSkipped
                      else if (step.approve != null)
                        '${step.decidedBy ?? ''} ${step.approve! ? s.supplyStepApproved : s.supplyStepRejected}',
                      if (step.reason != null && step.reason!.isNotEmpty)
                        step.reason!,
                    ].join(' · '),
                    style: meta),
            ])));
  }
}

class _Money extends ConsumerWidget {
  final SupplyRequest request;
  const _Money({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final body = MNText.resolve(context, MNText.body);
    final meta = MNText.resolve(context, MNText.meta);
    final advance = request.advance!;
    final settled = request.settlement;
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.supplyGiven2}: ${formatTsh(advance.amount)}',
                  style: MNText.withWeight(body, FontWeight.w700)),
              if (advance.holderName.isNotEmpty)
                Text('${s.supplyHolder}: ${advance.holderName}', style: meta),
              if (settled != null) ...[
                Text(
                    '${s.supplySpent.replaceAll(' (TSh)', '')}: ${formatTsh(settled.spent)}',
                    style: body),
                Text(
                    '${s.supplyChangeRow}: ${formatTsh(settled.changeReturned)}',
                    style: body),
                if (settled.supplier.isNotEmpty)
                  Text('${s.supplySupplier}: ${settled.supplier}', style: meta),
                if (settled.overspend > 0)
                  Text(s.supplyOverspendNote(groupDigits(settled.overspend)),
                      style: body.copyWith(color: MNColors.warning)),
              ],
            ])));
  }
}

class _Deliveries extends ConsumerWidget {
  final SupplyRequest request;
  const _Deliveries({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final body = MNText.resolve(context, MNText.body);
    final meta = MNText.resolve(context, MNText.meta);
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.supplyDeliveries,
                  style: MNText.withWeight(body, FontWeight.w700)),
              if (request.deliveries.isEmpty)
                Text(s.supplyNoDeliveries, style: meta),
              for (final d in request.deliveries)
                Text(
                    [d.reference, d.sender, d.status]
                        .where((x) => x.isNotEmpty)
                        .join(' · '),
                    style: meta),
            ])));
  }
}

/// Approve or refuse the current step. A refusal needs a reason; an approval
/// may carry one.
class _DecisionSheet extends ConsumerStatefulWidget {
  final SupplyRequest request;
  final bool approve;
  const _DecisionSheet({required this.request, required this.approve});
  @override
  ConsumerState<_DecisionSheet> createState() => _DecisionState();
}

class _DecisionState extends ConsumerState<_DecisionSheet> {
  final _reason = TextEditingController();
  final _retry = RetryId();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready => widget.approve || _reason.text.trim().length >= 3;

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = widget.request;
      final id = _retry.forDetails(
          '${r.id}|${r.currentStep}|${widget.approve}|${_reason.text.trim()}');
      final next = await _office(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.decideSupplyRequest(r.id,
              clientId: id,
              step: r.currentStep,
              approve: widget.approve,
              reason: _reason.text.trim()));
      if (mounted) Navigator.of(context).pop(next);
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
          label: s.supplyDecideReason,
          controller: _reason,
          enabled: !_busy,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(label, busy: _busy, onPressed: _ready && !_busy ? _save : null),
    ]);
  }
}

/// Toa fedha: money for an approved request, never above its estimate.
class _GiveSheet extends ConsumerStatefulWidget {
  final SupplyRequest request;
  const _GiveSheet({required this.request});
  @override
  ConsumerState<_GiveSheet> createState() => _GiveState();
}

class _GiveState extends ConsumerState<_GiveSheet> {
  late final _amount =
      TextEditingController(text: '${widget.request.estimatedTotal}');
  final _retry = RetryId();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.trim());
  bool get _ready =>
      _value != null && _value! > 0 && _value! <= widget.request.estimatedTotal;

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = _retry.forDetails('${widget.request.id}|$_value');
      final next = await _office(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.giveSupplyMoney(widget.request.id,
              clientId: id, amount: _value!));
      if (mounted) Navigator.of(context).pop(next);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.supplyGiveMoney, children: [
      MNTextField(
          label: s.supplyGiveAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ]),
      Text(s.supplyGiveLimit(groupDigits(widget.request.estimatedTotal)),
          style: MNText.resolve(context, MNText.meta)),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.supplyGiveMoney,
          busy: _busy, onPressed: _ready && !_busy ? _save : null),
    ]);
  }
}

/// Thibitisha matumizi: what the holder spent. An overspend is accepted
/// explicitly, never by the confirm button alone.
class _ConfirmSheet extends ConsumerStatefulWidget {
  final SupplyRequest request;
  const _ConfirmSheet({required this.request});
  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmState();
}

class _ConfirmState extends ConsumerState<_ConfirmSheet> {
  final _retry = RetryId();
  bool _accept = false, _busy = false;
  String? _error;

  int get _over => widget.request.settlement?.overspend ?? 0;

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = _retry.forDetails('${widget.request.id}|$_accept');
      final next = await _office(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.confirmSupply(widget.request.id,
              clientId: id, acceptOverspend: _accept));
      if (mounted) Navigator.of(context).pop(next);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final x = widget.request.settlement;
    return MNSheet(title: s.supplyConfirm, children: [
      if (x != null) ...[
        Text('${s.supplySpent.replaceAll(' (TSh)', '')}: ${formatTsh(x.spent)}',
            style: MNText.resolve(context, MNText.body)),
        Text('${s.supplyChangeRow}: ${formatTsh(x.changeReturned)}',
            style: MNText.resolve(context, MNText.body)),
      ],
      if (_over > 0) ...[
        MNNote(s.supplyOverspendNote(groupDigits(_over)),
            tone: MNNoteTone.info),
        MNFilterSwitch(
            label: s.supplyAcceptOverspend,
            value: _accept,
            onChanged: _busy ? (_) {} : (v) => setState(() => _accept = v)),
      ],
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.supplyConfirm,
          busy: _busy,
          onPressed: _busy || (_over > 0 && !_accept) ? null : _save),
    ]);
  }
}
