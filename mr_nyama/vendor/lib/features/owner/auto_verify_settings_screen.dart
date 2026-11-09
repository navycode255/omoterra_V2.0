import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/workflow_help.dart';
import '../office/money_screens.dart' show moneySettingsProvider;
import '../office/owner_reference.dart';
import '../office/people_screens.dart'
    show officeErrorText, officeStationsProvider;

/// The owner's automatic verification (Milestone E): mode, stations and values,
/// nothing prefilled, and what a trial found. Unset means off. The server
/// validates the value and its refusal is shown; a failed save keeps its button.

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// Monday to Sunday of a week, by its Monday (`YYYY-MM-DD`).
final _shadowSummaryProvider = FutureProvider.autoDispose
    .family<OfficeShadowSummary, String>((ref, monday) {
  final from = DateTime.parse('${monday}T00:00:00Z');
  return ref.read(officeSessionProvider.notifier).guard((r) {
    if (r is! OfficeAutoVerifyRepository) {
      throw const OfficeError(OfficeErrorKind.invalid);
    }
    return (r as OfficeAutoVerifyRepository).autoVerifySummary(
        from: monday, to: _isoDate(from.add(const Duration(days: 6))));
  });
});

class AutoVerifySettingsScreen extends ConsumerWidget {
  const AutoVerifySettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final owner = auth is OfficeSignedIn && auth.profile.isOwner;
    final pad = EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));
    Future<void> refresh() async {
      ref.invalidate(officeStationsProvider);
      ref.invalidate(moneySettingsProvider);
      await ref.read(moneySettingsProvider.future);
    }

    return OwnerPage(
        title: s.autoVerifyTitle,
        strings: s,
        onBack: () => Navigator.of(context).pop(),
        onRefresh: owner ? refresh : null,
        trailing: MNWorkflowHelp(
            title: s.autoVerifyTitle,
            messages: [s.autoVerifyHelp, s.autoVerifyHelpOnce]),
        child: Padding(
            padding: pad,
            child: !owner
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: ref.watch(moneySettingsProvider),
                    onRetry: () => ref.invalidate(moneySettingsProvider),
                    loadingRows: 4,
                    data: (settings) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Editor(current: settings.autoVerify),
                              const _ShadowSummary(),
                            ]))));
  }
}

class _Editor extends ConsumerStatefulWidget {
  final OfficeAutoVerifySetting? current;
  const _Editor({required this.current});
  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late String? _mode = widget.current?.mode;
  late final Set<String> _stations = {...?widget.current?.stationIds};
  late String? _runTime = widget.current?.runTime;
  late bool? _acceptStale = widget.current?.acceptStalePrice;
  late final _late = _field(widget.current?.lateHours);
  late final _duplicate = _field(widget.current?.duplicateWindowMinutes);
  late final _max = _field(widget.current?.maxSaleAmount);
  late final _sample = _field(widget.current?.samplePercent);
  bool _busy = false;
  String? _error;

  static TextEditingController _field(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');

  static final _digits = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(9)
  ];

  @override
  void dispose() {
    for (final c in [_late, _duplicate, _max, _sample]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  /// The value to send; null when it is not complete. A part is never sent.
  Map<String, Object>? _value() {
    final mode = _mode;
    if (mode == null) return null;
    // Off must always save, whatever is in the fields.
    if (mode == 'off') return {'mode': 'off'};
    final late = _int(_late), duplicate = _int(_duplicate);
    final max = _int(_max), sample = _int(_sample);
    final runTime = _runTime, stale = _acceptStale;
    if (_stations.isEmpty ||
        runTime == null ||
        late == null ||
        duplicate == null ||
        max == null ||
        sample == null ||
        stale == null) {
      return null;
    }
    return {
      'mode': mode,
      'station_ids': _stations.toList()..sort(),
      'run_time': runTime,
      'late_hours': late,
      'duplicate_window_minutes': duplicate,
      'max_sale_amount': max,
      'sample_percent': sample,
      'accept_stale_price': stale,
    };
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final value = _value();
    if (value == null) {
      setState(() => _error = s.autoVerifyIncomplete);
      return;
    }
    if (_mode == 'live' && widget.current?.mode != 'live') {
      final yes = await showMNConfirmDialog(context,
          title: s.autoVerifyLiveConfirmTitle,
          message: s.autoVerifyLiveConfirmBody,
          confirmLabel: s.yesConfirm,
          cancelLabel: s.cancel);
      if (!yes || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) => r.saveSetting(
          OfficeMoneySettings.autoVerifyKey,
          value: value,
          reason: s.autoVerifyReason(_mode!)));
      ref.invalidate(moneySettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.autoVerifySaved)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = switch (e) {
              OfficeError(:final detail?) when detail.isNotEmpty =>
                s.serverRefused(detail),
              _ => officeErrorText(s, e),
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final current = _runTime;
    final now = eatClock(ref.read(clockProvider)());
    final picked = await showMNTimeSheet(context,
        hour: current == null ? now.hour : int.parse(current.substring(0, 2)),
        minute:
            current == null ? now.minute : int.parse(current.substring(3, 5)));
    if (picked == null || !mounted) return;
    setState(() => _runTime = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    Widget number(String label, TextEditingController c) => Padding(
        padding: EdgeInsets.only(top: u(12)),
        child: MNTextField(
            label: label,
            controller: c,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: _digits));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MNSelectField<String>(
          label: s.autoVerifyMode,
          value: _mode,
          options: [
            for (final mode in const ['off', 'shadow', 'live'])
              MNSelectOption(value: mode, label: s.autoVerifyModeName(mode))
          ],
          onChanged: _busy ? null : (v) => setState(() => _mode = v)),
      SizedBox(height: u(16)),
      Text(s.autoVerifyStations, style: OwnerStyle.text(context, 15, weight: 600)),
      OwnerAsyncView(
          value: ref.watch(officeStationsProvider),
          onRetry: () => ref.invalidate(officeStationsProvider),
          loadingRows: 2,
          data: (rows) => Column(children: [
                for (final station in rows)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _stations.contains(station.id),
                      title: Text(station.name,
                          style: OwnerStyle.text(context, 15)),
                      onChanged: _busy
                          ? null
                          : (yes) => setState(() => yes == true
                              ? _stations.add(station.id)
                              : _stations.remove(station.id))),
              ])),
      SizedBox(height: u(8)),
      OwnerCard(
          child: OwnerMenuRow(
              label: s.autoVerifyRunTime,
              value: _runTime ?? s.autoVerifyNotSet,
              valueSize: 14,
              valueWeight: 400,
              valueColor: OwnerStyle.muted,
              onTap: _busy ? null : _pickTime)),
      number(s.autoVerifyLateHours, _late),
      number(s.autoVerifyDuplicateMinutes, _duplicate),
      number(s.autoVerifyMaxAmount, _max),
      number(s.autoVerifySamplePercent, _sample),
      SizedBox(height: u(12)),
      MNSelectField<bool>(
          label: s.autoVerifyStalePrice,
          value: _acceptStale,
          options: [
            MNSelectOption(value: false, label: s.autoVerifyStaleHold),
            MNSelectOption(value: true, label: s.autoVerifyStaleAccept),
          ],
          onChanged: _busy ? null : (v) => setState(() => _acceptStale = v)),
      if (_error != null) ...[
        SizedBox(height: u(12)),
        MNNote(_error!, error: true),
      ],
      SizedBox(height: u(16)),
      MNButton(s.autoVerifySave, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// How many sales a trial would have passed and held, for a chosen week.
class _ShadowSummary extends ConsumerStatefulWidget {
  const _ShadowSummary();
  @override
  ConsumerState<_ShadowSummary> createState() => _ShadowSummaryState();
}

class _ShadowSummaryState extends ConsumerState<_ShadowSummary> {
  int _weeksBack = 0;

  DateTime _monday() {
    final today = businessDate(ref.read(clockProvider)());
    return today.subtract(Duration(days: today.weekday - 1 + 7 * _weeksBack));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final monday = _monday();
    final key = _isoDate(monday);
    final value = ref.watch(_shadowSummaryProvider(key));
    Widget line(String text, {bool strong = false}) => Padding(
        padding: EdgeInsets.only(top: u(4)),
        child: Text(text,
            style: OwnerStyle.text(context, 15, weight: strong ? 600 : 400)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: u(24)),
      Text(s.autoSummaryTitle, style: OwnerStyle.text(context, 17, weight: 600)),
      Text(
          s.autoSummaryWeek(
              s.date(monday), s.date(monday.add(const Duration(days: 6)))),
          style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
      SizedBox(height: u(8)),
      OwnerAsyncView(
          value: value,
          onRetry: () => ref.invalidate(_shadowSummaryProvider(key)),
          loadingRows: 2,
          isEmpty: (summary) => summary.checked == 0 && summary.unchecked == 0,
          empty: (_) => MNNote(s.autoSummaryEmpty, tone: MNNoteTone.info),
          data: (summary) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    line(s.autoSummaryWouldPass(summary.wouldPass), strong: true),
                    line(s.autoSummaryWouldHold(summary.wouldHold), strong: true),
                    for (final MapEntry(:key, :value)
                        in summary.heldByReason.entries)
                      line(s.autoSummaryReason(s.autoHoldReason(key), value)),
                    line(s.autoSummaryStaffWouldHold(
                        summary.staffVerifiedWouldHold)),
                    if (summary.unchecked > 0)
                      line(s.autoSummaryUnchecked(summary.unchecked),
                          strong: true),
                  ])),
      SizedBox(height: u(8)),
      MNTextButton(s.autoSummaryEarlierWeek,
          onPressed: () => setState(() => _weeksBack++)),
      if (_weeksBack > 0)
        MNTextButton(s.autoSummaryLaterWeek,
            onPressed: () => setState(() => _weeksBack--)),
      SizedBox(height: u(24)),
    ]);
  }
}
