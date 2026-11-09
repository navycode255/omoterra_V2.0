import '../office/owner_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import '../office/owner_reference.dart';
import '../office/people_screens.dart'
    show officeErrorText, officeStationsProvider;
import '../office/product_screens.dart' show officeProductsProvider;

/// The owner's bonus, cost and score settings (design §6, §9, §10). Each
/// save sends one setting with a reason the app writes; the server validates
/// it and its refusal is shown in its own words. Nothing is pre-filled: an
/// unset setting shows "Haijawekwa" and pays or scores nothing.

final ownerPerformanceSettingsProvider =
    FutureProvider.autoDispose<OwnerPerformanceSettings>(
        (ref) => ref.read(officeSessionProvider.notifier).guard((repo) {
              if (repo is! OwnerBonusesRepository) {
                throw const OfficeError(OfficeErrorKind.invalid);
              }
              return (repo as OwnerBonusesRepository).performanceSettings();
            }));

typedef _Settings = OwnerPerformanceSettings;

String _errorText(Strings s, Object e) => switch (e) {
      OfficeError(:final detail?) when detail.isNotEmpty =>
        s.serverRefused(detail),
      _ => officeErrorText(s, e),
    };

TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

Widget _divided(List<Widget> rows) => Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: OwnerStyle.line)),
        rows[i],
      ]
    ]);

Widget _section(BuildContext context, String title) => Padding(
    padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 4),
        OwnerStyle.px(context, 22), 0, OwnerStyle.px(context, 8)),
    child: Semantics(
        header: true,
        child: Text(title, style: OwnerStyle.text(context, 17, weight: 600))));

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Saves one setting; refreshes the settings after.
Future<void> _save(WidgetRef ref, String key, Object value, String what) async {
  final s = ref.read(stringsProvider);
  await ref.read(officeSessionProvider.notifier).guard(
      (r) => r.saveSetting(key, value: value, reason: s.perfReason(what)));
  ref.invalidate(ownerPerformanceSettingsProvider);
}

final _wholeNumber = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(9)
];

int? _int(TextEditingController c) => int.tryParse(c.text.trim());

class OwnerPerformanceSettingsScreen extends ConsumerWidget {
  const OwnerPerformanceSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final owner = auth is OfficeSignedIn && auth.profile.isOwner;
    final pad = EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));
    if (!owner) {
      return OwnerPage(
          title: s.perfSettings,
          strings: s,
          child: Padding(padding: pad, child: MNNote(s.notAllowed)));
    }
    final value = ref.watch(ownerPerformanceSettingsProvider);
    return OwnerPage(
        title: s.perfSettings,
        strings: s,
        onRefresh: () => ref.refresh(ownerPerformanceSettingsProvider.future),
        child: Padding(
            padding: pad,
            child: OwnerAsyncView(
                value: value,
                onRetry: () => ref.invalidate(ownerPerformanceSettingsProvider),
                loadingRows: 4,
                data: (settings) => _SettingsList(settings: settings))));
  }
}

class _SettingsList extends ConsumerWidget {
  final _Settings settings;
  const _SettingsList({required this.settings});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget sheet) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context, builder: (_) => sheet);
    if (done == true && context.mounted) _toast(context, s.perfSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chicken = settings.chicken;
    final profit = settings.profit;
    Widget row(String label, String? value,
            {String? subtitle, VoidCallback? onTap}) =>
        OwnerMenuRow(
            label: label,
            subtitle: subtitle,
            value: value ?? s.perfNotSet,
            valueColor: value == null ? OwnerStyle.muted : null,
            valueSize: 15,
            onTap: onTap);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(context, s.perfSectionBonus),
      OwnerCard(
          child: _divided([
        row(
            s.perfChicken,
            chicken == null
                ? null
                : s.perfChickenSummary(chicken.target, chicken.steps.length),
            onTap: () => _open(context, ref, _ChickenSheet(current: chicken))),
        row(
            s.perfEquivalents,
            settings.equivalents == null
                ? null
                : s.perfEquivalentCount(settings.equivalents!.length),
            subtitle: s.perfEquivalentsCaption,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const _ProductValuesPage(
                    settingKey: _Settings.equivalentsKey)))),
        row(
            s.perfProfit,
            profit == null
                ? null
                : s.perfProfitSummary(
                    formatTsh(profit.defaultTarget), profit.sharePercent),
            onTap: () => _open(context, ref, _ProfitSheet(current: profit))),
      ])),
      _gap(context),
      _PayPeriodField(current: settings.payPeriod),
      _section(context, s.perfSectionCost),
      OwnerCard(
          child: row(
              s.perfStandardCost,
              settings.standardCost == null
                  ? null
                  : s.perfCostCount(settings.standardCost!.length),
              subtitle: s.perfStandardCostCaption,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const _ProductValuesPage(
                      settingKey: _Settings.standardCostKey))))),
      _section(context, s.perfWeights),
      OwnerCard(
          child: _divided([
        for (final key in _Settings.weightAreas.keys)
          row(
              s.perfWeightsFor(key),
              settings.weights[key] == null
                  ? null
                  : s.perfWeightsTotal(
                      settings.weights[key]!.values.fold(0, (a, b) => a + b)),
              onTap: () => _open(
                  context,
                  ref,
                  _WeightsSheet(
                      settingKey: key, current: settings.weights[key]))),
      ])),
      _gap(context, 24),
    ]);
  }
}

class _PayPeriodField extends ConsumerStatefulWidget {
  final String? current;
  const _PayPeriodField({required this.current});
  @override
  ConsumerState<_PayPeriodField> createState() => _PayPeriodState();
}

class _PayPeriodState extends ConsumerState<_PayPeriodField> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MNSelectField<String>(
          label: s.perfPayPeriod,
          value: widget.current,
          emptyText: s.perfNotSet,
          options: [
            MNSelectOption(value: 'weekly', label: s.perfWeekly),
            MNSelectOption(value: 'monthly', label: s.perfMonthly),
          ],
          onChanged: (v) async {
            if (v == widget.current) return;
            try {
              await _save(ref, _Settings.payPeriodKey, v, s.perfPayPeriod);
              if (mounted) setState(() => _error = null);
              if (context.mounted) _toast(context, s.perfSaved);
            } catch (e) {
              if (mounted) setState(() => _error = _errorText(s, e));
            }
          }),
      if (_error != null) ...[_gap(context, 8), MNNote(_error!, error: true)],
    ]);
  }
}

/// Shared shape of a settings sheet: fields, an error, Save.
abstract class _SheetState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  String? error;
  bool busy = false;

  /// The setting to send, or a message why not.
  ({Object? value, String? problem}) build0(Strings s);
  String get settingKey;
  String what(Strings s);

  Future<void> submit() async {
    if (busy) return;
    final s = ref.read(stringsProvider);
    final (:value, :problem) = build0(s);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await _save(ref, settingKey, value!, what(s));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = _errorText(s, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

// Chicken bonus ------------------------------------------------------------------------

class _ChickenSheet extends ConsumerStatefulWidget {
  final ChickenRulesSetting? current;
  const _ChickenSheet({required this.current});
  @override
  ConsumerState<_ChickenSheet> createState() => _ChickenSheetState();
}

class _ChickenSheetState extends _SheetState<_ChickenSheet> {
  late final _target =
      TextEditingController(text: widget.current?.target.toString() ?? '');
  late final _extra =
      TextEditingController(text: widget.current?.perExtra.toString() ?? '');
  late final List<(TextEditingController, TextEditingController)> _steps = [
    for (final step in widget.current?.steps ?? const <ChickenStep>[])
      (
        TextEditingController(text: '${step.at}'),
        TextEditingController(text: '${step.amount}')
      )
  ];

  @override
  String get settingKey => _Settings.chickenKey;
  @override
  String what(Strings s) => s.perfChicken;

  @override
  void dispose() {
    _target.dispose();
    _extra.dispose();
    for (final (a, b) in _steps) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  @override
  ({Object? value, String? problem}) build0(Strings s) {
    final target = _int(_target), extra = _int(_extra);
    final steps = [for (final (a, b) in _steps) (at: _int(a), amount: _int(b))];
    if (target == null ||
        target <= 0 ||
        extra == null ||
        steps.any((st) => st.at == null || st.amount == null)) {
      return (value: null, problem: s.perfNumberInvalid);
    }
    var previous = target;
    for (final st in steps) {
      if (st.at! <= previous) return (value: null, problem: s.perfStepsInvalid);
      previous = st.at!;
    }
    return (
      value: ChickenRulesSetting(
              target: target,
              perExtra: extra,
              steps: [for (final st in steps) ChickenStep(st.at!, st.amount!)])
          .toJson(),
      problem: null
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.perfChicken, children: [
      OwnerHelp(message: s.perfChickenHelp),
      MNTextField(
          label: s.perfTarget,
          controller: _target,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: _wholeNumber),
      Text(s.perfSteps, style: OwnerStyle.text(context, 15, weight: 600)),
      for (final (i, (at, amount)) in _steps.indexed) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: MNTextField(
                  label: s.perfStepAt,
                  controller: at,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: _wholeNumber)),
          const SizedBox(width: 12),
          Expanded(
              child: MNTextField(
                  label: s.perfStepAmount,
                  controller: amount,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: _wholeNumber)),
        ]),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: busy
                    ? null
                    : () => setState(() {
                          final (a, b) = _steps.removeAt(i);
                          a.dispose();
                          b.dispose();
                        }),
                child: Text(s.perfRemoveStep,
                    style:
                        OwnerStyle.text(context, 14, color: MNColors.error)))),
      ],
      MNButton.secondary(s.perfAddStep,
          onPressed: busy
              ? null
              : () => setState(() => _steps
                  .add((TextEditingController(), TextEditingController())))),
      MNTextField(
          label: s.perfPerExtra,
          controller: _extra,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: _wholeNumber),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.saveChanges, busy: busy, onPressed: busy ? null : submit),
    ]);
  }
}

// Profit bonus -------------------------------------------------------------------------

class _ProfitSheet extends ConsumerStatefulWidget {
  final ProfitRulesSetting? current;
  const _ProfitSheet({required this.current});
  @override
  ConsumerState<_ProfitSheet> createState() => _ProfitSheetState();
}

class _ProfitSheetState extends _SheetState<_ProfitSheet> {
  late final _target = TextEditingController(
      text: widget.current?.defaultTarget.toString() ?? '');
  late final _share =
      TextEditingController(text: widget.current?.sharePercent ?? '');
  final _stations = <String, TextEditingController>{};

  @override
  String get settingKey => _Settings.profitKey;
  @override
  String what(Strings s) => s.perfProfit;

  TextEditingController _station(String id) => _stations.putIfAbsent(
      id,
      () => TextEditingController(
          text: widget.current?.stationTargets[id]?.toString() ?? ''));

  @override
  void dispose() {
    _target.dispose();
    _share.dispose();
    for (final c in _stations.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  ({Object? value, String? problem}) build0(Strings s) {
    final target = _int(_target);
    final share = num.tryParse(_share.text.trim().replaceAll(',', '.'));
    if (target == null) return (value: null, problem: s.perfNumberInvalid);
    if (share == null || share < 0 || share > 100) {
      return (value: null, problem: s.perfShareInvalid);
    }
    final targets = <String, int>{};
    for (final e in _stations.entries) {
      final text = e.value.text.trim();
      if (text.isEmpty) continue;
      final n = int.tryParse(text);
      if (n == null) return (value: null, problem: s.perfNumberInvalid);
      targets[e.key] = n;
    }
    // Stations not opened in this sheet keep their targets.
    for (final e
        in (widget.current?.stationTargets ?? const <String, int>{}).entries) {
      if (!_stations.containsKey(e.key)) targets[e.key] = e.value;
    }
    return (
      value: ProfitRulesSetting(
              defaultTarget: target,
              sharePercent: _share.text.trim().replaceAll(',', '.'),
              stationTargets: targets)
          .toJson(),
      problem: null
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final stations = ref.watch(officeStationsProvider).valueOrNull ?? const [];
    return MNSheet(title: s.perfProfit, children: [
      OwnerHelp(message: s.perfProfitHelp),
      MNTextField(
          label: s.perfDefaultTarget,
          controller: _target,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: _wholeNumber),
      MNTextField(
          label: s.perfShare,
          controller: _share,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            LengthLimitingTextInputFormatter(6)
          ]),
      if (stations.isNotEmpty)
        Text(s.perfStationTargets,
            style: OwnerStyle.text(context, 15, weight: 600)),
      for (final st in stations)
        MNTextField(
            label: st.name,
            controller: _station(st.id),
            enabled: !busy,
            keyboardType: TextInputType.number,
            inputFormatters: _wholeNumber),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.saveChanges, busy: busy, onPressed: busy ? null : submit),
    ]);
  }
}

// Score weights ------------------------------------------------------------------------

class _WeightsSheet extends ConsumerStatefulWidget {
  final String settingKey;
  final Map<String, int>? current;
  const _WeightsSheet({required this.settingKey, required this.current});
  @override
  ConsumerState<_WeightsSheet> createState() => _WeightsSheetState();
}

class _WeightsSheetState extends _SheetState<_WeightsSheet> {
  late final _fields = {
    for (final area in _Settings.weightAreas[widget.settingKey]!)
      area: TextEditingController(text: widget.current?[area]?.toString() ?? '')
  };

  @override
  String get settingKey => widget.settingKey;
  @override
  String what(Strings s) =>
      '${s.perfWeights}: ${s.perfWeightsFor(widget.settingKey)}';

  int get _total =>
      _fields.values.fold(0, (sum, c) => sum + (int.tryParse(c.text) ?? 0));

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  ({Object? value, String? problem}) build0(Strings s) {
    final values = {for (final e in _fields.entries) e.key: _int(e.value)};
    if (values.values.any((v) => v == null || v > 100)) {
      return (value: null, problem: s.perfNumberInvalid);
    }
    if (_total != 100) return (value: null, problem: s.perfWeightsInvalid);
    return (value: values, problem: null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final total = _total;
    return MNSheet(
        title: '${s.perfWeights}: ${s.perfWeightsFor(widget.settingKey)}',
        children: [
          for (final e in _fields.entries)
            MNTextField(
                label: s.perfArea(e.key),
                controller: e.value,
                enabled: !busy,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3)
                ]),
          Text(s.perfWeightsTotal(total),
              style: OwnerStyle.text(context, 15,
                  weight: 600,
                  color: total == 100 ? MNColors.success : MNColors.warning)),
          if (error != null) MNNote(error!, error: true),
          MNButton(s.saveChanges,
              busy: busy, onPressed: busy || total != 100 ? null : submit),
        ]);
  }
}

// Per-product values (chicken-equivalents, standard costs) -------------------------------

class _ProductValuesPage extends ConsumerWidget {
  final String settingKey;
  const _ProductValuesPage({required this.settingKey});

  bool get _decimal => settingKey == _Settings.equivalentsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(ownerPerformanceSettingsProvider).valueOrNull;
    final current = <String, String>{
      if (_decimal)
        ...?settings?.equivalents
      else
        for (final e
            in (settings?.standardCost ?? const <String, int>{}).entries)
          e.key: '${e.value}'
    };
    final products = ref.watch(officeProductsProvider);
    final title = _decimal ? s.perfEquivalents : s.perfStandardCost;
    return OwnerPage(
        title: title,
        strings: s,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      _decimal
                          ? s.perfEquivalentsCaption
                          : s.perfStandardCostCaption,
                      style: _meta(context)),
                  _gap(context),
                  OwnerAsyncView(
                      value: products,
                      onRetry: () => ref.invalidate(officeProductsProvider),
                      data: (rows) => OwnerCard(
                              child: _divided([
                            for (final p in rows)
                              OwnerMenuRow(
                                  label: p.name,
                                  subtitle: p.code,
                                  value: current[p.code] == null
                                      ? s.perfNotSet
                                      : _decimal
                                          ? current[p.code]
                                          : formatTsh(
                                              int.parse(current[p.code]!)),
                                  valueColor: current[p.code] == null
                                      ? OwnerStyle.muted
                                      : null,
                                  valueSize: 15,
                                  onTap: () async {
                                    final done = await showMNSheet<bool>(
                                        context,
                                        builder: (_) => _ProductValueSheet(
                                            settingKey: settingKey,
                                            code: p.code,
                                            name: p.name,
                                            all: current));
                                    if (done == true && context.mounted) {
                                      _toast(context, s.perfSaved);
                                    }
                                  }),
                          ]))),
                ])));
  }
}

class _ProductValueSheet extends ConsumerStatefulWidget {
  final String settingKey, code, name;
  final Map<String, String> all;
  const _ProductValueSheet(
      {required this.settingKey,
      required this.code,
      required this.name,
      required this.all});
  @override
  ConsumerState<_ProductValueSheet> createState() => _ProductValueState();
}

class _ProductValueState extends _SheetState<_ProductValueSheet> {
  late final _value =
      TextEditingController(text: widget.all[widget.code] ?? '');
  bool _remove = false;

  bool get _decimal => widget.settingKey == _Settings.equivalentsKey;

  @override
  String get settingKey => widget.settingKey;
  @override
  String what(Strings s) =>
      '${_decimal ? s.perfEquivalents : s.perfStandardCost}: ${widget.name}';

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  ({Object? value, String? problem}) build0(Strings s) {
    Object convert(String v) => _decimal ? v : int.parse(v);
    final next = <String, Object>{
      for (final e in widget.all.entries)
        if (e.key != widget.code) e.key: convert(e.value)
    };
    if (!_remove) {
      final text = _value.text.trim().replaceAll(',', '.');
      if (_decimal) {
        final n = num.tryParse(text);
        if (n == null ||
            n < 0 ||
            n > 10 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
          return (value: null, problem: s.perfEquivalentInvalid);
        }
        next[widget.code] = text;
      } else {
        final n = int.tryParse(text);
        if (n == null || n <= 0) {
          return (value: null, problem: s.perfNumberInvalid);
        }
        next[widget.code] = n;
      }
    }
    return (value: next, problem: null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.name, children: [
      MNTextField(
          label: _decimal ? s.perfEquivalentLabel : s.perfCostLabel,
          controller: _value,
          enabled: !busy,
          keyboardType: TextInputType.numberWithOptions(decimal: _decimal),
          inputFormatters: _decimal
              ? [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(5)
                ]
              : _wholeNumber),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.saveChanges,
          busy: busy,
          onPressed: busy
              ? null
              : () {
                  _remove = false;
                  submit();
                }),
      if (widget.all.containsKey(widget.code))
        MNButton.secondary(s.perfRemove,
            onPressed: busy
                ? null
                : () {
                    _remove = true;
                    submit();
                  }),
    ]);
  }
}
