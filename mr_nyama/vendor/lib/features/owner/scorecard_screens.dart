import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pin.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/sheet.dart';
import '../office/owner_reference.dart';
import '../office/owner_widgets.dart';
import '../office/people_screens.dart' show officeErrorText;
import 'performance_screens.dart';

/// A person's scorecard to the owner-approved reference (31 October 2026): the
/// period's score and how many areas it rests on, the areas, their bonuses,
/// then one day's detail with its rating history. The server calculates every
/// area; the office may correct one area of one day here (MN030). Weeks and
/// months stay the average of their days.

typedef _Person = ({String? vendorId, String? staffId});

Future<T> _call<T>(
        Ref ref, Future<T> Function(OwnerPerformanceRepository) work) =>
    ref.read(officeSessionProvider.notifier).guard((repo) {
      if (repo is! OwnerPerformanceRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OwnerPerformanceRepository);
    });

typedef _HistoryKey = ({String? vendorId, String? staffId, String date});

final _areaRatingsProvider = FutureProvider.autoDispose
    .family<List<AreaRating>, _HistoryKey>((ref, k) => _call(
        ref,
        (r) => r.areaRatings(
            vendorId: k.vendorId, staffId: k.staffId, date: k.date)));

bool _isOwner(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn && auth.profile.isOwner;
}

double _u(BuildContext c, double n) => OwnerStyle.px(c, n);
TextStyle _t(BuildContext c, double size,
        {double weight = 400, Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, size, weight: weight, color: color, spacing: -.25);

String _tzs(Strings s, int amount) => '${s.tzs} ${groupDigits(amount)}';

// The screens ------------------------------------------------------------------------------

class OwnerVendorScorecardScreen extends ConsumerWidget {
  final String vendorId;
  const OwnerVendorScorecardScreen({super.key, required this.vendorId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = _windowKey(ref, vendorId);
    final card = ref.watch(vendorScorecardProvider(key));
    return _ScorecardPage(
        person: (vendorId: vendorId, staffId: null),
        card: card,
        onRetry: () => ref.invalidate(vendorScorecardProvider(key)),
        onRefresh: () => ref.refresh(vendorScorecardProvider(key).future));
  }
}

class OwnerStaffScorecardScreen extends ConsumerWidget {
  final String staffId;
  const OwnerStaffScorecardScreen({super.key, required this.staffId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = _windowKey(ref, staffId);
    final card = ref.watch(staffScorecardProvider(key));
    return _ScorecardPage(
        person: (vendorId: null, staffId: staffId),
        card: card,
        onRetry: () => ref.invalidate(staffScorecardProvider(key)),
        onRefresh: () => ref.refresh(staffScorecardProvider(key).future));
  }
}

({String id, PerformancePeriod period, String? date}) _windowKey(
    WidgetRef ref, String id) {
  final w = ref.watch(performanceWindowProvider);
  return (
    id: id,
    period: w.period,
    date: w.day == null ? null : moneyDateKey(w.day!)
  );
}

class _ScorecardPage extends ConsumerWidget {
  final _Person person;
  final AsyncValue<Scorecard> card;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  const _ScorecardPage(
      {required this.person,
      required this.card,
      required this.onRetry,
      required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final c = card.valueOrNull;
    final title = c?.person?.name ?? s.opTitle;
    if (!_isOwner(ref)) {
      return OwnerPage(
          title: title,
          strings: s,
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _u(context, 19)),
              child: MNNote(s.notAllowed)));
    }
    return OwnerPage(
        title: title,
        strings: s,
        contentGap: 6,
        header: Padding(
            padding: EdgeInsets.only(left: _u(context, 25)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                  header: true,
                  child: Text(title,
                      style: OwnerStyle.text(context, 27.5,
                          weight: 700, spacing: -.6, height: 1.2))),
              if (c != null && !c.isVendor && c.card != null)
                Text(s.opCardName(c.card!),
                    style: _t(context, 13, color: OwnerStyle.muted)),
            ])),
        onRefresh: onRefresh,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _u(context, 19)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PeriodTabs(),
                  SizedBox(height: _u(context, 8)),
                  _RangeRow(card: c),
                  SizedBox(height: _u(context, 8)),
                  OwnerAsyncView(
                      value: card,
                      onRetry: onRetry,
                      loadingRows: 4,
                      data: (c) => _ScorecardBody(card: c, person: person)),
                ])));
  }
}

/// Day | Week | Month.
class _PeriodTabs extends ConsumerWidget {
  const _PeriodTabs();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final w = ref.watch(performanceWindowProvider);
    final labels = [s.opPeriodDay, s.opPeriodWeek, s.opPeriodMonth];
    return Container(
        constraints: BoxConstraints(minHeight: _u(context, 33)),
        padding: EdgeInsets.all(_u(context, 2.5)),
        decoration: BoxDecoration(
            color: OwnerStyle.scoreTabs,
            borderRadius: BorderRadius.circular(_u(context, 8))),
        child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
                child: Semantics(
                    button: true,
                    selected: PerformancePeriod.values[i] == w.period,
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                                .read(performanceWindowProvider.notifier)
                                .state =
                            (period: PerformancePeriod.values[i], day: w.day),
                        child: Container(
                            alignment: Alignment.center,
                            decoration: PerformancePeriod.values[i] == w.period
                                ? BoxDecoration(
                                    color: OwnerStyle.white,
                                    borderRadius:
                                        BorderRadius.circular(_u(context, 6.5)))
                                : null,
                            child: Text(labels[i],
                                style: _t(context, 12.5,
                                    weight: PerformancePeriod.values[i] == w.period
                                        ? 600
                                        : 400,
                                    color: PerformancePeriod.values[i] == w.period ? OwnerStyle.ink : OwnerStyle.muted)))))),
        ])));
  }
}

class _RangeRow extends ConsumerWidget {
  final Scorecard? card;
  const _RangeRow({this.card});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final w = ref.watch(performanceWindowProvider);
    final today = businessDate(ref.read(clockProvider)());
    final day = w.day ?? today;
    final from = card?.from, to = card?.to;
    final range = from == null || to == null || from == to
        ? s.date(day)
        : '${s.date(from)} – ${s.date(to)}';
    Future<void> pick() async {
      final picked = await showMNDateSheet(context,
          title: s.opDate,
          initial: day,
          first: DateTime.utc(today.year - 2),
          last: today);
      if (picked == null) return;
      final chosen = DateTime.utc(picked.year, picked.month, picked.day);
      ref.read(performanceWindowProvider.notifier).state =
          (period: w.period, day: chosen == today ? null : chosen);
    }

    return OwnerCard(
        radius: 7,
        child: MNPressable(
            onTap: pick,
            pressedScale: 1,
            semanticLabel: '${s.opDate}: $range',
            child: Container(
                constraints: BoxConstraints(minHeight: _u(context, 34)),
                padding: EdgeInsets.symmetric(horizontal: _u(context, 12)),
                child: Row(children: [
                  MNIcon(MNIconData.calendar,
                      size: _u(context, 15), color: OwnerStyle.ink),
                  SizedBox(width: _u(context, 11)),
                  Expanded(child: Text(range, style: _t(context, 12.5))),
                  _chevron(context),
                ]))));
  }
}

Widget _chevron(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: _u(context, 8)),
    child: const OwnerGlyph('vendor-chevron',
        size: 13, color: OwnerStyle.stationChevron));

class _ScorecardBody extends ConsumerWidget {
  final Scorecard card;
  final _Person person;
  const _ScorecardBody({required this.card, required this.person});

  /// The day a rating here applies to: the chosen date when they worked it,
  /// else their latest day of the period.
  ScoreDay? _ratingDay(WidgetRef ref) {
    final w = ref.read(performanceWindowProvider);
    final day = w.day ?? businessDate(ref.read(clockProvider)());
    return card.days.where((d) => d.businessDate == day).firstOrNull ??
        card.days.firstOrNull;
  }

  Future<void> _rate(BuildContext context, WidgetRef ref, String area) async {
    final s = ref.read(stringsProvider);
    final day = _ratingDay(ref);
    if (day?.businessDate == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.opNoWorkDay)));
      return;
    }
    await _showAreaRating(context,
        person: person,
        area: area,
        day: day!.businessDate!,
        namedDay: ref.read(performanceWindowProvider).period !=
            PerformancePeriod.day);
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final area = await showMNSheet<String>(context,
        builder: (sheet) => MNSheet(title: s.opRateChoose, children: [
              OwnerCard(
                  child: Column(children: [
                for (final e in card.areas.entries)
                  _AreaRow(
                      label: s.opAreaName(e.key),
                      value: e.value,
                      onTap: () => Navigator.pop(sheet, e.key)),
              ])),
            ]));
    if (area != null && context.mounted) await _rate(context, ref, area);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final c = card;
    if (!c.isVendor && c.card == null) return MNNote(s.opNoCard);
    final measured = c.areas.values.where((v) => v != null).length;
    final full = c.areas.isNotEmpty && measured == c.areas.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ScoreHero(
          score: c.score,
          measured: measured,
          total: c.areas.length,
          weights: c.weights,
          period: true),
      _heading(context, s.opAreas),
      _AreaCard(areas: c.areas, onTap: (area) => _rate(context, ref, area)),
      SizedBox(height: _u(context, 13)),
      full
          ? _UpdateRow(
              label: s.opUpdateRating, onTap: () => _choose(context, ref))
          : _RedButton(
              label: s.opRatePerformance,
              height: 43,
              onTap: () => _choose(context, ref)),
      if (c.bonus case final b?) ...[
        _heading(context, s.opBonusTitle),
        _BonusCard(bonus: b),
      ],
      if (person.vendorId != null) ...[
        SizedBox(height: _u(context, 12)),
        OwnerCard(
            child: OwnerMenuRow(
                label: s.opPayments,
                subtitle: s.opPaymentsCaption,
                onTap: () =>
                    context.push(MNRoutes.officeVendorPay(person.vendorId!)))),
      ],
      _heading(context, s.opDays),
      if (c.days.isEmpty)
        MNNote(s.opNoDays, tone: MNNoteTone.info)
      else
        PerformancePaged(
            count: c.days.length,
            itemBuilder: (_, i) => _DayRow(day: c.days[i], person: person)),
    ]);
  }
}

Widget _heading(BuildContext context, String text) => Padding(
    padding:
        EdgeInsets.fromLTRB(_u(context, 1), _u(context, 13), 0, _u(context, 6)),
    child: Semantics(
        header: true,
        child: Text(text, style: _t(context, 14.5, weight: 700))));

/// The big circle and what the score rests on, in each of the reference's
/// states. It opens the owner's score settings.
class _ScoreHero extends ConsumerWidget {
  final int? score;
  final int measured, total;
  final Map<String, int> weights;

  /// A period's hero says more about a partial score than a day's does.
  final bool period;
  const _ScoreHero(
      {required this.score,
      required this.measured,
      required this.total,
      required this.weights,
      this.period = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final count = s.opMeasured(measured, total);
    final equal = weights.values.toSet().length <= 1;
    final String? title;
    final String subtitle;
    var chip = false;
    if (weights.isEmpty) {
      title = s.opNoScore;
      subtitle = s.opWeightsNotSet;
    } else if (measured == 0) {
      title = s.opNotRatedYet;
      subtitle = count;
    } else if (score == null) {
      title = period ? s.opScorePending : s.opNoScore;
      subtitle = count;
    } else if (measured < total) {
      title = null;
      chip = period;
      subtitle = count;
    } else {
      title = s.opAllMeasured;
      subtitle = equal ? s.opEqualWeights : s.opYourWeights;
    }
    return OwnerCard(
        radius: 9,
        child: MNPressable(
            onTap: () => context.push(MNRoutes.officePerformanceSettings),
            pressedScale: 1,
            child: Padding(
                padding: EdgeInsets.fromLTRB(_u(context, 13), _u(context, 13),
                    _u(context, 12), _u(context, 13)),
                child: Row(children: [
                  Container(
                      width: _u(context, 69),
                      height: _u(context, 69),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: OwnerStyle.scoreCircle,
                          shape: BoxShape.circle),
                      child: score == null
                          ? _BarsGlyph(size: _u(context, 27))
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$score',
                                        style: OwnerStyle.text(context, 31,
                                            weight: 700, height: 1.05)),
                                    Text('/100',
                                        style: _t(context, 11.5,
                                            color: OwnerStyle.muted)),
                                  ]))),
                  SizedBox(width: _u(context, 16)),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        if (chip)
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: _u(context, 13),
                                  vertical: _u(context, 4)),
                              decoration: BoxDecoration(
                                  color: OwnerStyle.scoreChip,
                                  borderRadius:
                                      BorderRadius.circular(_u(context, 5))),
                              child: Text(s.opPartial,
                                  style:
                                      _t(context, 12, color: OwnerStyle.muted)))
                        else if (title != null)
                          Text(title,
                              style: _t(
                                  context, title == s.opAllMeasured ? 15 : 17.5,
                                  weight: 700)),
                        SizedBox(height: _u(context, 4)),
                        Text(subtitle,
                            style: _t(context, 13, color: OwnerStyle.muted)),
                      ])),
                  if (weights.isEmpty)
                    Text(s.opSetWeights,
                        style: _t(context, 13, color: OwnerStyle.muted)),
                  _chevron(context),
                ]))));
  }
}

/// The empty score's three bars.
class _BarsGlyph extends StatelessWidget {
  final double size;
  const _BarsGlyph({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final height in const [.56, 1.0, .68])
              Container(
                  width: size * .13,
                  height: size * height,
                  decoration: BoxDecoration(
                      color: OwnerStyle.scoreBars,
                      borderRadius: BorderRadius.circular(size * .07))),
          ]));
}

class _AreaCard extends StatelessWidget {
  final Map<String, int?> areas;
  final ValueChanged<String> onTap;
  const _AreaCard({required this.areas, required this.onTap});
  @override
  Widget build(BuildContext context) => Consumer(
      builder: (context, ref, _) => OwnerCard(
          radius: 7,
          child: Column(children: [
            for (final (i, e) in areas.entries.indexed) ...[
              if (i > 0)
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: _u(context, 10)),
                    child: const Divider(
                        height: 1, thickness: .6, color: OwnerStyle.line)),
              _AreaRow(
                  label: ref.watch(stringsProvider).opAreaName(e.key),
                  value: e.value,
                  onTap: () => onTap(e.key)),
            ],
          ])));
}

class _AreaRow extends ConsumerWidget {
  final String label;
  final int? value;
  final VoidCallback onTap;
  const _AreaRow(
      {required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return MNPressable(
        onTap: onTap,
        pressedScale: 1,
        semanticLabel: '$label: ${s.opAreaValue(value)}',
        child: Container(
            constraints: BoxConstraints(minHeight: _u(context, 32.5)),
            padding: EdgeInsets.symmetric(horizontal: _u(context, 13.5)),
            child: Row(children: [
              Expanded(child: Text(label, style: _t(context, 13.5))),
              Text(s.opAreaValue(value),
                  style: value == null
                      ? _t(context, 13.5, color: OwnerStyle.muted)
                      : _t(context, 13.5, weight: 600)),
              SizedBox(width: _u(context, 5)),
              _chevron(context),
            ])));
  }
}

/// The reference's red action, lower than the standard button.
class _RedButton extends StatelessWidget {
  final String label;
  final double height;
  final bool busy;
  final VoidCallback? onTap;
  const _RedButton(
      {required this.label,
      required this.onTap,
      this.height = 50,
      this.busy = false});
  @override
  Widget build(BuildContext context) => MNPressable(
      onTap: onTap,
      color: onTap == null ? OwnerStyle.scoreDisabled : OwnerStyle.scoreRed,
      pressedColor: OwnerStyle.red,
      borderRadius: BorderRadius.circular(_u(context, 8)),
      semanticLabel: label,
      child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: _u(context, height)),
          child: Center(
              child: busy
                  ? const MNSpinner(color: OwnerStyle.white)
                  : Text(label,
                      style: _t(context, height >= 50 ? 16 : 14.5,
                          weight: 600, color: OwnerStyle.white)))));
}

class _UpdateRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _UpdateRow({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => MNPressable(
      onTap: onTap,
      pressedScale: 1,
      color: OwnerStyle.scoreUpdate,
      pressedColor: OwnerStyle.line,
      borderRadius: BorderRadius.circular(_u(context, 7)),
      semanticLabel: label,
      child: Container(
          constraints: BoxConstraints(minHeight: _u(context, 43)),
          padding: EdgeInsets.symmetric(horizontal: _u(context, 13)),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: _t(context, 13.5, color: OwnerStyle.muted))),
            _chevron(context),
          ])));
}

class _BonusCard extends ConsumerWidget {
  final ScorecardBonus bonus;
  const _BonusCard({required this.bonus});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    TextStyle label() => _t(context, 12.5, color: OwnerStyle.muted);
    TextStyle figure() => _t(context, 15.5, weight: 700);
    return OwnerCard(
        radius: 7,
        child: Padding(
            padding: EdgeInsets.fromLTRB(_u(context, 13.5), _u(context, 11),
                _u(context, 13.5), _u(context, 11)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.opVerifiedChickens, style: label()),
                  SizedBox(height: _u(context, 7)),
                  Text(s.opPieces(chickensText(bonus.chickens)),
                      style: figure()),
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: _u(context, 8)),
                      child: const Divider(
                          height: 1, thickness: .6, color: OwnerStyle.line)),
                  IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(s.opBonusEarned, style: label()),
                              SizedBox(height: _u(context, 7)),
                              Text(_tzs(s, bonus.earned), style: figure()),
                            ])),
                        const VerticalDivider(
                            width: 1, thickness: .6, color: OwnerStyle.line),
                        SizedBox(width: _u(context, 22)),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Flexible(
                                    child: Text(s.opEstimatedShort,
                                        style: label())),
                                SizedBox(width: _u(context, 8)),
                                _InfoButton(message: s.opEstimatedHelp),
                              ]),
                              SizedBox(height: _u(context, 7)),
                              Text(_tzs(s, bonus.estimated), style: figure()),
                            ])),
                      ])),
                  if (bonus.adjustments != 0) ...[
                    SizedBox(height: _u(context, 8)),
                    Row(children: [
                      Expanded(
                          child: Text(s.opBonusAdjustments, style: label())),
                      Text(_tzs(s, bonus.adjustments),
                          style: _t(context, 13, weight: 600)),
                    ]),
                  ],
                ])));
  }
}

class _InfoButton extends ConsumerWidget {
  final String message;
  const _InfoButton({required this.message});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showMNSheet<void>(context,
            builder: (_) => MNSheet(title: s.opEstimatedShort, children: [
                  Text(message,
                      style: OwnerStyle.text(context, 16, height: 1.45))
                ])),
        child: Semantics(
            button: true,
            label: s.help,
            child: MNIcon(MNIconData.info,
                size: _u(context, 15), color: OwnerStyle.muted)));
  }
}

class _DayRow extends ConsumerWidget {
  final ScoreDay day;
  final _Person person;
  const _DayRow({required this.day, required this.person});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = day.businessDate;
    return OwnerCard(
        child: OwnerMenuRow(
            label: _dayTitle(s, day),
            value: day.score == null ? s.opNoScore : s.opScore(day.score!),
            valueColor: day.score == null ? OwnerStyle.muted : OwnerStyle.ink,
            valueSize: 13.5,
            valueMaxWidth: 110,
            height: 52,
            onTap: date == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        _ScoreDayScreen(person: person, date: date)))));
  }
}

String _dayTitle(Strings s, ScoreDay d) {
  final date = d.businessDate == null ? '—' : s.date(d.businessDate!);
  return d.station == null ? date : '$date · ${d.station!.name}';
}

// One day ----------------------------------------------------------------------------------

class _ScoreDayScreen extends ConsumerWidget {
  final _Person person;
  final DateTime date;
  const _ScoreDayScreen({required this.person, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = (
      id: person.vendorId ?? person.staffId!,
      period: PerformancePeriod.day,
      date: moneyDateKey(date)
    );
    final card = person.vendorId != null
        ? ref.watch(vendorScorecardProvider(key))
        : ref.watch(staffScorecardProvider(key));
    void retry() => person.vendorId != null
        ? ref.invalidate(vendorScorecardProvider(key))
        : ref.invalidate(staffScorecardProvider(key));
    final day = card.valueOrNull?.days.firstOrNull;
    return OwnerPage(
        title: day == null ? s.date(date) : _dayTitle(s, day),
        strings: s,
        onBack: () => Navigator.of(context).pop(),
        header: Padding(
            padding: EdgeInsets.fromLTRB(
                _u(context, 19), _u(context, 2), _u(context, 19), 0),
            child: Semantics(
                header: true,
                child: Text(day == null ? s.date(date) : _dayTitle(s, day),
                    style: _t(context, 20)))),
        contentGap: 14,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _u(context, 19)),
            child: OwnerAsyncView(
                value: card,
                onRetry: retry,
                loadingRows: 4,
                data: (c) {
                  final d = c.days.firstOrNull;
                  if (d == null) return MNNote(s.opNoDays);
                  final measured =
                      d.areas.values.where((v) => v != null).length;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ScoreHero(
                            score: d.score,
                            measured: measured,
                            total: d.areas.length,
                            weights: c.weights),
                        _heading(context, s.opAreas),
                        _AreaCard(
                            areas: d.areas,
                            onTap: (area) => _showAreaRating(context,
                                person: person,
                                area: area,
                                day: date,
                                namedDay: false)),
                        SizedBox(height: _u(context, 14)),
                        OwnerCard(
                            radius: 7,
                            child: MNPressable(
                                pressedScale: 1,
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => _HistoryScreen(
                                            person: person, date: date))),
                                semanticLabel: s.opRatingHistory,
                                child: Container(
                                    constraints: BoxConstraints(
                                        minHeight: _u(context, 43)),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: _u(context, 13.5)),
                                    child: Row(children: [
                                      Expanded(
                                          child: Text(s.opRatingHistory,
                                              style: _t(context, 13.5))),
                                      Text(s.opChanges(d.ratingChanges),
                                          style: _t(context, 13.5,
                                              color: OwnerStyle.muted)),
                                      SizedBox(width: _u(context, 5)),
                                      _chevron(context),
                                    ])))),
                        if (d.score == null && c.weights.isNotEmpty) ...[
                          SizedBox(height: _u(context, 14)),
                          Container(
                              padding: EdgeInsets.all(_u(context, 15)),
                              decoration: BoxDecoration(
                                  color: OwnerStyle.scoreNote,
                                  borderRadius:
                                      BorderRadius.circular(_u(context, 8))),
                              child: Row(children: [
                                Container(
                                    width: _u(context, 22),
                                    height: _u(context, 22),
                                    decoration: const BoxDecoration(
                                        color: OwnerStyle.muted,
                                        shape: BoxShape.circle),
                                    clipBehavior: Clip.antiAlias,
                                    child: OverflowBox(
                                        maxWidth: _u(context, 30),
                                        maxHeight: _u(context, 30),
                                        child: MNIcon(MNIconData.info,
                                            size: _u(context, 30),
                                            color: OwnerStyle.white))),
                                SizedBox(width: _u(context, 16)),
                                Expanded(
                                    child: Text(s.opNotAllRated,
                                        style: OwnerStyle.text(context, 14.5,
                                            spacing: -.2, height: 1.35))),
                              ])),
                        ],
                        if (d.reasons.isNotEmpty) ...[
                          SizedBox(height: _u(context, 14)),
                          OwnerDetails(title: s.opWhyScores, children: [
                            for (final e in d.reasons.entries)
                              Padding(
                                  padding:
                                      EdgeInsets.only(bottom: _u(context, 8)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.opAreaName(e.key),
                                            style:
                                                _t(context, 13.5, weight: 600)),
                                        Text(e.value,
                                            style: _t(context, 13,
                                                color: OwnerStyle.muted)),
                                      ])),
                          ]),
                        ],
                      ]);
                })));
  }
}

class _HistoryScreen extends ConsumerWidget {
  final _Person person;
  final DateTime date;
  const _HistoryScreen({required this.person, required this.date});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = (
      vendorId: person.vendorId,
      staffId: person.staffId,
      date: moneyDateKey(date)
    );
    final rows = ref.watch(_areaRatingsProvider(key));
    return OwnerPage(
        title: s.opRatingHistory,
        strings: s,
        headingSize: 26,
        onBack: () => Navigator.of(context).pop(),
        subtitle:
            Text(s.date(date), style: _t(context, 14, color: OwnerStyle.muted)),
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _u(context, 19)),
            child: OwnerAsyncView(
                value: rows,
                onRetry: () => ref.invalidate(_areaRatingsProvider(key)),
                data: (items) => items.isEmpty
                    ? MNNote(s.opNoRatingChanges, tone: MNNoteTone.info)
                    : OwnerCard(
                        child: Column(children: [
                        for (final (i, r) in items.indexed) ...[
                          if (i > 0)
                            const Divider(height: 1, color: OwnerStyle.line),
                          Padding(
                              padding: EdgeInsets.all(_u(context, 14)),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        '${s.opAreaName(r.area)}: '
                                        '${r.previousScore ?? '—'} → ${r.score}',
                                        style: _t(context, 15, weight: 600)),
                                    if (r.ratedBy != null)
                                      Text(r.ratedBy!.name,
                                          style: _t(context, 13,
                                              color: OwnerStyle.muted)),
                                  ])),
                        ],
                      ])))));
  }
}

// Rating one area --------------------------------------------------------------------------

/// Opens the sheet that corrects [area] of [day]. [namedDay] says which day it
/// is, when the screen behind shows a whole period.
Future<void> _showAreaRating(BuildContext context,
        {required _Person person,
        required String area,
        required DateTime day,
        required bool namedDay}) =>
    showMNSheet<void>(context,
        builder: (_) => _AreaRatingSheet(
            person: person, area: area, day: day, namedDay: namedDay));

class _AreaRatingSheet extends ConsumerStatefulWidget {
  final _Person person;
  final String area;
  final DateTime day;
  final bool namedDay;
  const _AreaRatingSheet(
      {required this.person,
      required this.area,
      required this.day,
      required this.namedDay});
  @override
  ConsumerState<_AreaRatingSheet> createState() => _AreaRatingSheetState();
}

class _AreaRatingSheetState extends ConsumerState<_AreaRatingSheet> {
  static const _maxDigits = 3;
  var _value = '';
  bool _busy = false;
  String? _serverError;
  AreaRating? _saved;

  int? get _number => int.tryParse(_value);
  bool get _outOfRange => _value.isNotEmpty && (_number ?? 101) > 100;
  bool get _canSave => _value.isNotEmpty && !_outOfRange && !_busy;

  void _digit(int d) {
    if (_busy || _value.length >= _maxDigits) return;
    setState(() {
      _serverError = null;
      _value += '$d';
    });
  }

  void _backspace() {
    if (_busy || _value.isEmpty) return;
    setState(() {
      _serverError = null;
      _value = _value.substring(0, _value.length - 1);
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      final saved =
          await ref.read(officeSessionProvider.notifier).guard((repo) {
        if (repo is! OwnerPerformanceRepository) {
          throw const OfficeError(OfficeErrorKind.invalid);
        }
        return (repo as OwnerPerformanceRepository).rateArea(
            vendorId: widget.person.vendorId,
            staffId: widget.person.staffId,
            date: moneyDateKey(widget.day),
            area: widget.area,
            score: _number!);
      });
      ref.invalidate(vendorScorecardProvider);
      ref.invalidate(staffScorecardProvider);
      ref.invalidate(performanceOverviewProvider);
      ref.invalidate(_areaRatingsProvider);
      if (mounted) setState(() => _saved = saved);
    } catch (e) {
      if (mounted) setState(() => _serverError = officeErrorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final name = s.opAreaName(widget.area);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final saved = _saved;
    if (saved != null) {
      return Padding(
          padding: EdgeInsets.fromLTRB(_u(context, 15), _u(context, 32),
              _u(context, 15), _u(context, 16) + bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        width: _u(context, 62),
                        height: _u(context, 62),
                        decoration: const BoxDecoration(
                            color: OwnerStyle.scoreSaved,
                            shape: BoxShape.circle),
                        child: Center(
                            child: MNIcon(MNIconData.check,
                                size: _u(context, 34),
                                color: OwnerStyle.white)))),
                SizedBox(height: _u(context, 18)),
                Semantics(
                    liveRegion: true,
                    child: Text(s.opRatingUpdated,
                        textAlign: TextAlign.center,
                        style: _t(context, 20, weight: 700))),
                SizedBox(height: _u(context, 7)),
                Text.rich(
                    TextSpan(text: '$name: ', children: [
                      TextSpan(
                          text:
                              '${saved.previousScore ?? '—'} → ${saved.score}',
                          style: _t(context, 16, weight: 700)),
                    ]),
                    textAlign: TextAlign.center,
                    style: _t(context, 16)),
                SizedBox(height: _u(context, 18)),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: _u(context, 50)),
                    child: Text(s.opRatingRecorded,
                        textAlign: TextAlign.center,
                        style: OwnerStyle.text(context, 15,
                            color: OwnerStyle.muted,
                            spacing: -.2,
                            height: 1.45))),
                SizedBox(height: _u(context, 28)),
                _RedButton(
                    label: s.done,
                    height: 52,
                    onTap: () => Navigator.of(context).pop()),
              ]));
    }
    final error = _outOfRange ? s.opRateOutOfRange : _serverError;
    final bad = _outOfRange;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: EdgeInsets.fromLTRB(_u(context, 27), _u(context, 26),
                  _u(context, 15), _u(context, 16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                        header: true,
                        child: Text(s.opRateArea(name),
                            style: _t(context, 19, weight: 700))),
                    SizedBox(height: _u(context, 7)),
                    Text(
                        widget.namedDay
                            ? s.opRateHelpOn(s.date(widget.day))
                            : s.opRateAreaHelp,
                        style: _t(context, 13.5, color: OwnerStyle.muted)),
                    SizedBox(height: _u(context, 16)),
                    Container(
                        height: _u(context, 48),
                        padding: EdgeInsets.only(
                            left: _u(context, 14), right: _u(context, 4)),
                        decoration: BoxDecoration(
                            color: OwnerStyle.white,
                            borderRadius: BorderRadius.circular(_u(context, 7)),
                            border: Border.all(
                                color: bad
                                    ? OwnerStyle.scoreRed
                                    : OwnerStyle.scoreFocus,
                                width: 1.3)),
                        child: Row(children: [
                          Semantics(
                              label: s.opRateArea(name),
                              value: _value,
                              liveRegion: true,
                              child: ExcludeSemantics(
                                  child: Text(_value, style: _t(context, 18)))),
                          Container(
                              width: 1.5,
                              height: _u(context, 22),
                              margin: const EdgeInsets.only(left: 1),
                              color: OwnerStyle.ink),
                          const Spacer(),
                          if (_value.isNotEmpty)
                            SizedBox.square(
                                dimension: 44,
                                child: MNPressable(
                                    onTap: _busy
                                        ? null
                                        : () => setState(() {
                                              _value = '';
                                              _serverError = null;
                                            }),
                                    pressedScale: 1,
                                    semanticLabel: s.close,
                                    child: Center(
                                        child: Container(
                                            width: _u(context, 18),
                                            height: _u(context, 18),
                                            decoration: BoxDecoration(
                                                color: bad
                                                    ? OwnerStyle.scoreRed
                                                    : OwnerStyle.stationChevron,
                                                shape: BoxShape.circle),
                                            child: Center(
                                                child: MNIcon(MNIconData.x,
                                                    size: _u(context, 11),
                                                    color:
                                                        OwnerStyle.white)))))),
                        ])),
                    SizedBox(height: _u(context, 6)),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: error == null
                                  ? const SizedBox.shrink()
                                  : Semantics(
                                      liveRegion: true,
                                      child: Text(error,
                                          style: _t(context, 12.5,
                                              color: OwnerStyle.scoreRed)))),
                          Text('${_value.length}/$_maxDigits',
                              style: _t(context, 12, color: OwnerStyle.muted)),
                        ]),
                    SizedBox(height: _u(context, 9)),
                    Row(children: [
                      Expanded(
                          flex: 10,
                          child: MNPressable(
                              onTap: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              pressedScale: 1,
                              semanticLabel: s.cancel,
                              child: SizedBox(
                                  height: _u(context, 50),
                                  child: Center(
                                      child: Text(s.cancel,
                                          style: _t(context, 15,
                                              color: OwnerStyle.muted)))))),
                      SizedBox(width: _u(context, 16)),
                      Expanded(
                          flex: 12,
                          child: _RedButton(
                              label: s.opSaveShort,
                              busy: _busy,
                              onTap: _canSave ? _save : null)),
                    ]),
                  ])),
          ColoredBox(
              color: OwnerStyle.scorePanel,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(_u(context, 11), _u(context, 7),
                      _u(context, 11), _u(context, 12) + bottom),
                  child: MNPinKeypad(
                      tiles: true,
                      tileHeight: _u(context, 44).clamp(44.0, 64.0),
                      tileGap: _u(context, 7),
                      tileColumnGap: _u(context, 7),
                      tileRadius: 6,
                      digitStyle: _t(context, 19),
                      backspaceSize: 24,
                      enabled: !_busy,
                      onDigit: _digit,
                      onBackspace: _backspace))),
        ]);
  }
}
