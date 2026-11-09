import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_approvals.dart';
import '../../core/api/office_verification.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/filter_sheet.dart' show MNFilterSwitch;
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/number_sheet.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'supply_request_screens.dart';
import 'people_screens.dart' show officeErrorText, officeStaffProvider;

/// Requests this person may decide, and their own that are waiting.
final approvalsProvider = FutureProvider.autoDispose<List<ApprovalItem>>(
    (ref) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => (r as OfficeApprovalsRepository).approvals()));

final alertSettingsProvider = FutureProvider.autoDispose<AlertSettings>((ref) =>
    ref
        .read(officeSessionProvider.notifier)
        .guard((r) => (r as OfficeApprovalsRepository).alertSettings()));

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// "Tatua": how the problem was resolved and why. Returns true when it was
/// settled, false when it went for approval, null when dismissed.
class ResolveProblemSheet extends ConsumerStatefulWidget {
  final OfficeException problem;
  const ResolveProblemSheet({super.key, required this.problem});
  @override
  ConsumerState<ResolveProblemSheet> createState() => _ResolveState();
}

class _ResolveState extends ConsumerState<ResolveProblemSheet> {
  final _reason = TextEditingController();
  String? _resolution, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final options = widget.problem.resolutions;
    if (options.length == 1) _resolution = options.single;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready => _resolution != null && _reason.text.trim().length >= 3;

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeApprovalsRepository).resolveException(widget.problem.id,
              resolution: _resolution!, reason: _reason.text.trim()));
      if (mounted) Navigator.of(context).pop(result.resolved);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.problemKind(widget.problem.kind), children: [
      MNNote(s.problemResolveHelp, tone: MNNoteTone.info),
      MNSelectField<String>(
          label: s.problemHowResolved,
          value: _resolution,
          options: [
            for (final code in widget.problem.resolutions)
              MNSelectOption(value: code, label: s.resolutionName(code)),
          ],
          onChanged: _busy ? null : (v) => setState(() => _resolution = v)),
      MNTextField(
          label: s.approvalReason,
          controller: _reason,
          enabled: !_busy,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.problemResolve,
          busy: _busy, onPressed: _ready && !_busy ? _save : null),
    ]);
  }
}

/// "Idhini": requests waiting for a decision.
class OfficeApprovalsScreen extends ConsumerWidget {
  const OfficeApprovalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerPage(
        title: s.approvalsTitle,
        strings: s,
        onRefresh: () {
          ref.invalidate(supplyWaitingProvider);
          return ref.refresh(approvalsProvider.future);
        },
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SupplyWaitingSection(quiet: true),
              OwnerAsyncView<List<ApprovalItem>>(
                value: ref.watch(approvalsProvider),
                onRetry: () => ref.invalidate(approvalsProvider),
                isEmpty: (rows) => rows.isEmpty,
                empty: (_) => MNNote(s.approvalsEmpty, tone: MNNoteTone.info),
                data: (rows) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in rows) _ApprovalCard(item: item),
                        ])),
            ])));
  }
}

class _ApprovalCard extends ConsumerWidget {
  final ApprovalItem item;
  const _ApprovalCard({required this.item});

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecisionSheet(item: item, approve: approve));
    if (done != true || !context.mounted) return;
    ref.invalidate(approvalsProvider);
    _toast(context, s.approvalDecisionSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final body = MNText.resolve(context, MNText.body);
    final meta = MNText.resolve(context, MNText.meta);
    final value = item.countedValue ?? item.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: MNSpace.x3),
      child: OwnerCard(
          child: Padding(
              padding: const EdgeInsets.all(MNSpace.x4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.problemKind(item.kind),
                        style: MNText.withWeight(body, FontWeight.w700)),
                    if (item.station != null)
                      Text(
                          [item.station!, if (item.vendor != null) item.vendor!]
                              .join(' · '),
                          style: meta),
                    const SizedBox(height: MNSpace.x2),
                    Text(
                        value == null
                            ? s.approvalValueUnknown
                            : formatTsh(value),
                        style: body),
                    Text(s.resolutionName(item.resolution), style: body),
                    Text(s.reasonText(item.reason), style: body),
                    Text(s.approvalAskedBy(item.requestedBy), style: meta),
                    const SizedBox(height: MNSpace.x3),
                    if (!item.canDecide)
                      MNNote(s.approvalWaiting, tone: MNNoteTone.info)
                    else ...[
                      MNButton(s.approvalApprove,
                          onPressed: () => _decide(context, ref, true)),
                      const SizedBox(height: MNSpace.x2),
                      MNButton.secondary(s.approvalReject,
                          onPressed: () => _decide(context, ref, false)),
                    ],
                  ]))),
    );
  }
}

class _DecisionSheet extends ConsumerStatefulWidget {
  final ApprovalItem item;
  final bool approve;
  const _DecisionSheet({required this.item, required this.approve});
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
          (r as OfficeApprovalsRepository).decideApproval(widget.item.id,
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

/// The owner's limits, alert times and texts. Nothing here has a default.
class OwnerAlertSettingsScreen extends ConsumerWidget {
  const OwnerAlertSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final owner = auth is OfficeSignedIn && auth.profile.isOwner;
    return OwnerPage(
        title: s.alertSettingsTitle,
        strings: s,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MNSpace.x3),
            child: !owner
                ? MNNote(s.notAllowed)
                : OwnerAsyncView<AlertSettings>(
                    value: ref.watch(alertSettingsProvider),
                    onRetry: () => ref.invalidate(alertSettingsProvider),
                    data: (settings) => _AlertList(settings: settings))));
  }
}

class _AlertList extends ConsumerWidget {
  final AlertSettings settings;
  const _AlertList({required this.settings});

  Future<void> _save(BuildContext context, WidgetRef ref, String key,
      String name, Object? value) async {
    final s = ref.read(stringsProvider);
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) => (r
              as OfficeApprovalsRepository)
          .saveAlertSetting(key, value: value, reason: s.settingReason(name)));
      ref.invalidate(alertSettingsProvider);
      if (context.mounted) _toast(context, s.settingSaved);
    } catch (error) {
      if (context.mounted) _toast(context, officeErrorText(s, error));
    }
  }

  /// A number; 0 clears it, as the help line says.
  Future<void> _number(BuildContext context, WidgetRef ref, String name,
      int? current, int max, Future<void> Function(int? value) store) async {
    final picked = await showNumberSheet(context,
        title: name, initial: current ?? 0, max: max);
    if (picked == null || picked == current) return;
    await store(picked == 0 ? null : picked);
  }

  Future<void> _time(BuildContext context, WidgetRef ref, String name,
      String? current, Future<void> Function(String value) store) async {
    final now = DateTime.now();
    final picked = await showMNTimeSheet(context,
        title: name,
        hour: current == null ? now.hour : int.parse(current.substring(0, 2)),
        minute:
            current == null ? now.minute : int.parse(current.substring(3, 5)));
    if (picked == null) return;
    await store('${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}');
  }

  /// A time already set can be changed or cleared, which turns that alert off.
  Future<void> _timeOrClear(
      BuildContext context, WidgetRef ref, String name, String key) async {
    final s = ref.read(stringsProvider);
    final current = settings.clock(key);
    if (current != null) {
      final change = await showMNSelectSheet<bool>(context,
          title: name,
          emptyText: name,
          options: [
            MNSelectOption(value: true, label: s.settingChange),
            MNSelectOption(value: false, label: s.settingClear),
          ]);
      if (change == null || !context.mounted) return;
      if (!change.value) return _save(context, ref, key, name, null);
    }
    await _time(
        context, ref, name, current, (v) => _save(context, ref, key, name, v));
  }

  /// Both or neither: a share of 0 turns it off; otherwise the time follows.
  Future<void> _lowSales(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final share = await showNumberSheet(context,
        title: s.alertLowSalesShare,
        initial: settings.lowSalesShare ?? 0,
        max: 100);
    if (share == null || !context.mounted) return;
    if (share == 0) {
      await _save(context, ref, AlertSettings.lowSales, s.alertLowSales, null);
      return;
    }
    await _time(
        context,
        ref,
        s.alertLowSalesTime,
        settings.lowSalesTime,
        (time) => _save(context, ref, AlertSettings.lowSales, s.alertLowSales,
            {'check_time': time, 'share_percent': share}));
  }

  Future<void> _approvers(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final staff = await ref.read(officeStaffProvider.future);
    if (!context.mounted) return;
    final picked = await showMNSheet<Set<String>>(context,
        builder: (_) => _ApproverSheet(people: [
              for (final p in staff.where((p) => !p.suspended))
                (id: p.id, name: p.name)
            ], selected: settings.approverIds.toSet()));
    if (picked == null || !context.mounted) return;
    await _save(context, ref, AlertSettings.approvers, s.independentApprovers,
        picked.isEmpty ? null : picked.toList());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    String money(int? v) => v == null ? s.notSet : formatTsh(v);
    String text(Object? v) => v == null ? s.notSet : '$v';
    Widget section(String title) => Padding(
        padding:
            const EdgeInsets.fromLTRB(MNSpace.x2, MNSpace.x5, 0, MNSpace.x2),
        child: Text(title.toUpperCase(),
            style: OwnerStyle.text(context, 12,
                weight: 600, color: OwnerStyle.muted)));
    Widget card(List<Widget> rows) => OwnerCard(
            child: Column(children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0)
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: MNSpace.x4),
                  child: Divider(height: 1, color: OwnerStyle.line)),
            row,
          ]
        ]));
    Widget row(String label, String value, VoidCallback onTap) => OwnerMenuRow(
        label: label,
        value: value,
        valueSize: 14,
        valueWeight: 400,
        valueColor: OwnerStyle.muted,
        onTap: onTap);
    Widget limit(String label, String key) => row(
        label,
        money(settings.number(key)),
        () => _number(context, ref, label, settings.number(key), 1000000000,
            (v) => _save(context, ref, key, label, v)));
    Widget hours(String label, String severity) => row(
        label,
        text(settings.escalationHours(severity)),
        () => _number(
                context, ref, label, settings.escalationHours(severity), 720,
                (v) {
              final next = <String, int>{
                for (final k in const ['warning', 'critical'])
                  if (settings.escalationHours(k) != null)
                    k: settings.escalationHours(k)!,
              };
              v == null ? next.remove(severity) : next[severity] = v;
              return _save(context, ref, AlertSettings.escalation, label,
                  next.isEmpty ? null : next);
            }));
    Widget time(String label, String key) => row(
        label,
        settings.clock(key) ?? s.notSet,
        () => _timeOrClear(context, ref, label, key));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MNNote(s.alertSettingsHelp, tone: MNNoteTone.info),
      section(s.sectionLimits),
      card([
        limit(s.limitSupervisor, AlertSettings.supervisorLimit),
        limit(s.limitFinance, AlertSettings.financeLimit),
        limit(s.limitOwner, AlertSettings.managerLimit),
        row(
            s.independentApprovers,
            settings.approverIds.isEmpty
                ? s.notSet
                : s.approversCount(settings.approverIds.length),
            () => _approvers(context, ref)),
      ]),
      section(s.sectionAlerts),
      card([
        time(s.alertClosingDue, AlertSettings.closingDue),
        row(
            s.alertSilentMinutes,
            text(settings.number(AlertSettings.silentMinutes)),
            () => _number(
                context,
                ref,
                s.alertSilentMinutes,
                settings.number(AlertSettings.silentMinutes),
                1440,
                (v) => _save(context, ref, AlertSettings.silentMinutes,
                    s.alertSilentMinutes, v))),
        row(
            s.alertLowSales,
            settings.lowSalesShare == null
                ? s.notSet
                : '${settings.lowSalesShare}% · ${settings.lowSalesTime}',
            () => _lowSales(context, ref)),
        time(s.alertSummaryTime, AlertSettings.summaryTime),
      ]),
      section(s.sectionEscalation),
      card([
        hours(s.escalateWarning, 'warning'),
        hours(s.escalateCritical, 'critical'),
      ]),
      const SizedBox(height: MNSpace.x4),
      MNFilterSwitch(
          label: s.supervisorSms,
          value: settings.smsOn,
          onChanged: (v) => _save(
              context, ref, AlertSettings.supervisorSms, s.supervisorSms, v)),
      const SizedBox(height: MNSpace.x6),
    ]);
  }
}

class _ApproverSheet extends ConsumerStatefulWidget {
  final List<({String id, String name})> people;
  final Set<String> selected;
  const _ApproverSheet({required this.people, required this.selected});
  @override
  ConsumerState<_ApproverSheet> createState() => _ApproverState();
}

class _ApproverState extends ConsumerState<_ApproverSheet> {
  late final _picked = {...widget.selected};
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.independentApprovers, children: [
      for (final person in widget.people)
        MNFilterSwitch(
            label: person.name,
            value: _picked.contains(person.id),
            onChanged: (on) => setState(
                () => on ? _picked.add(person.id) : _picked.remove(person.id))),
      MNButton(s.languageDone,
          onPressed: () => Navigator.of(context).pop(_picked)),
    ]);
  }
}
