import '../office/owner_widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/note.dart';
import '../office/owner_home_tab.dart';
import '../office/owner_reference.dart';
import '../office/money_formatting.dart' show moneyStateWord;
import '../office/office_errors.dart' show officeErrorText;
import '../office/office_money_providers.dart' as money;

export 'scorecard_screens.dart'
    show OwnerVendorScorecardScreen, OwnerStaffScorecardScreen;

/// The owner's performance view (owner plan Task 9, design §10): the
/// business overview with what needs attention and the ranking, a person's
/// scorecard, one station's figures, and ratings. The server computes every
/// figure, score and star; these screens only show them. Owner only.

// Data ---------------------------------------------------------------------------------

/// The period every performance page shows; kept while the owner drills down.
typedef PerformanceWindow = ({PerformancePeriod period, DateTime? day});

final performanceWindowProvider = StateProvider<PerformanceWindow>(
    (ref) => (period: PerformancePeriod.week, day: null));

String? _dayKey(DateTime? d) => d == null ? null : moneyDateKey(d);

Future<T> _call<T>(
        Ref ref, Future<T> Function(OwnerPerformanceRepository) work) =>
    ref.read(officeSessionProvider.notifier).guard((repo) {
      if (repo is! OwnerPerformanceRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OwnerPerformanceRepository);
    });

typedef _Key = ({PerformancePeriod period, String? date});
typedef _IdKey = ({String id, PerformancePeriod period, String? date});

final performanceOverviewProvider = FutureProvider.autoDispose
    .family<PerformanceOverview, _Key>((ref, k) =>
        _call(ref, (r) => r.performanceOverview(k.period, date: k.date)));

final vendorScorecardProvider = FutureProvider.autoDispose
    .family<Scorecard, _IdKey>((ref, k) =>
        _call(ref, (r) => r.vendorScorecard(k.id, k.period, date: k.date)));

final staffScorecardProvider = FutureProvider.autoDispose
    .family<Scorecard, _IdKey>((ref, k) =>
        _call(ref, (r) => r.staffScorecard(k.id, k.period, date: k.date)));

final stationPerformanceProvider = FutureProvider.autoDispose
    .family<StationPerformanceDetail, _IdKey>((ref, k) =>
        _call(ref, (r) => r.stationPerformance(k.id, k.period, date: k.date)));

_Key _key(WidgetRef ref) {
  final w = ref.watch(performanceWindowProvider);
  return (period: w.period, date: _dayKey(w.day));
}

_IdKey _idKey(WidgetRef ref, String id) {
  final k = _key(ref);
  return (id: id, period: k.period, date: k.date);
}

bool _isOwner(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn && auth.profile.isOwner;
}

// Shared pieces --------------------------------------------------------------------------

TextStyle _body(BuildContext c, {Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, 14, color: color);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

const _pageSize = 10;

Widget _section(BuildContext context, String title, {Widget? trailing}) =>
    Padding(
        padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 4),
            OwnerStyle.px(context, 20), 0, OwnerStyle.px(context, 8)),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title,
                      style: OwnerStyle.text(context, 17, weight: 600)))),
          if (trailing != null) trailing,
        ]));

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

/// Shows [count] items ten at a time, with "Zaidi" for the next ten.
class PerformancePaged extends ConsumerStatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final bool divided;
  const PerformancePaged(
      {super.key,
      required this.count,
      required this.itemBuilder,
      this.divided = false});
  @override
  ConsumerState<PerformancePaged> createState() => _PerformancePagedState();
}

class _PerformancePagedState extends ConsumerState<PerformancePaged> {
  int _limit = _pageSize;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < math.min(_limit, widget.count); i++) ...[
        if (i > 0)
          widget.divided
              ? const Divider(height: 1, thickness: .7, color: OwnerStyle.line)
              : _gap(context),
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

/// A label on the left and its figure on the right.
class _Line extends StatelessWidget {
  final String label, value;
  const _Line(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(vertical: OwnerStyle.px(context, 3)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: _body(context))),
        SizedBox(width: OwnerStyle.px(context, 12)),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: OwnerStyle.text(context, 14,
                    weight: 600, color: OwnerStyle.ink))),
      ]));
}

String _starsText(Strings s, int? stars) =>
    stars == null ? s.opNoScore : s.opStars(stars);

({DateTime from, DateTime to}) _periodBounds(
    PerformancePeriod period, DateTime day) {
  final date = DateTime.utc(day.year, day.month, day.day);
  return switch (period) {
    PerformancePeriod.day => (from: date, to: date),
    PerformancePeriod.week => (
        from: date.subtract(Duration(days: date.weekday - DateTime.monday)),
        to: date
            .subtract(Duration(days: date.weekday - DateTime.monday))
            .add(const Duration(days: 6)),
      ),
    PerformancePeriod.month => (
        from: DateTime.utc(date.year, date.month),
        to: DateTime.utc(date.year, date.month + 1)
            .subtract(const Duration(days: 1)),
      ),
  };
}

/// Day / week / month and the date the period holds.
class _PeriodBar extends ConsumerWidget {
  final bool showRange;
  final bool showOverviewRange;
  const _PeriodBar({this.showRange = false, this.showOverviewRange = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final w = ref.watch(performanceWindowProvider);
    final today = businessDate(ref.read(clockProvider)());
    final day = w.day ?? today;
    final bounds = _periodBounds(w.period, day);
    final overview = showOverviewRange
        ? ref.watch(performanceOverviewProvider(_key(ref))).valueOrNull
        : null;
    final from = overview?.from ?? bounds.from;
    final to = overview?.to ?? bounds.to;
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

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          margin: EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
          padding: EdgeInsets.all(OwnerStyle.px(context, 4)),
          decoration: BoxDecoration(
              color: OwnerStyle.scoreTabs,
              borderRadius: BorderRadius.circular(OwnerStyle.px(context, 14))),
          child: Row(children: [
            for (final (i, label)
                in [s.opPeriodDay, s.opPeriodWeek, s.opPeriodMonth].indexed)
              Expanded(
                  child: Semantics(
                      button: true,
                      selected: PerformancePeriod.values[i] == w.period,
                      child: InkWell(
                          borderRadius:
                              BorderRadius.circular(OwnerStyle.px(context, 11)),
                          onTap: () => ref
                                  .read(performanceWindowProvider.notifier)
                                  .state =
                              (period: PerformancePeriod.values[i], day: w.day),
                          child: Container(
                              constraints: BoxConstraints(
                                  minHeight: OwnerStyle.px(context, 44)),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: PerformancePeriod.values[i] == w.period
                                      ? OwnerStyle.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(OwnerStyle.px(context, 11))),
                              child: Text(label, style: OwnerStyle.text(context, 15, weight: PerformancePeriod.values[i] == w.period ? 600 : 400, color: PerformancePeriod.values[i] == w.period ? OwnerStyle.ink : OwnerStyle.muted)))))),
          ])),
      Padding(
          padding: _pad(context),
          child: OwnerCard(
              child: OwnerMenuRow(
                  label: s.opRange(s.date(from), s.date(to)),
                  icon: 'calendar',
                  height: 68,
                  onTap: pick))),
    ]);
  }
}

/// The frame every performance page shares: owner only, period bar on top.
class _PerformancePage extends ConsumerWidget {
  final String title;
  final Future<void> Function()? onRefresh;
  final Widget Function(BuildContext context) body;
  final List<String> help;
  final bool showPeriodRange, showOverviewRange;
  final bool showOverviewNavigation, compactTitle;
  const _PerformancePage(
      {required this.title,
      required this.body,
      this.onRefresh,
      this.help = const [],
      this.showPeriodRange = false,
      this.showOverviewRange = false,
      this.showOverviewNavigation = false,
      this.compactTitle = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (!_isOwner(ref)) {
      return OwnerPage(
          title: title,
          strings: s,
          child: Padding(padding: _pad(context), child: MNNote(s.notAllowed)));
    }
    return OwnerPage(
        title: title,
        strings: s,
        collapsedTitle: showOverviewNavigation || compactTitle ? title : null,
        onRefresh: onRefresh,
        bottom: showOverviewNavigation
            ? _PerformanceBottomNavigation(strings: s)
            : null,
        trailing:
            help.isEmpty ? null : MNWorkflowHelp(title: title, messages: help),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PeriodBar(
              showRange: showPeriodRange, showOverviewRange: showOverviewRange),
          _gap(context, 8),
          Padding(padding: _pad(context), child: body(context)),
        ]));
  }
}

class _PerformanceBottomNavigation extends ConsumerWidget {
  final Strings strings;
  const _PerformanceBottomNavigation({required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double u(double n) => OwnerStyle.px(context, n);
    final destinations = [
      (icon: 'home', label: strings.ownerSummary),
      (
        icon: 'nav-store',
        label: strings.stations,
      ),
      (
        icon: 'account',
        label: strings.ownerAccount,
      ),
    ];
    return DecoratedBox(
        decoration: const BoxDecoration(
            color: OwnerStyle.background,
            border: Border(top: BorderSide(color: OwnerStyle.line, width: .7))),
        child: SafeArea(
            top: false,
            child: SizedBox(
                height: u(MediaQuery.textScalerOf(context).scale(12.5) > 18
                    ? 74
                    : 64),
                child: Row(children: [
                  for (final (i, destination) in destinations.indexed)
                    Expanded(
                        child: Semantics(
                            selected: i == 0,
                            button: true,
                            child: InkWell(
                                onTap: () {
                                  ref
                                      .read(ownerHomeTabProvider.notifier)
                                      .state = i;
                                  context.go(MNRoutes.office);
                                },
                                child: Padding(
                                    padding: EdgeInsets.only(top: u(8)),
                                    child: Column(children: [
                                      OwnerGlyph(destination.icon,
                                          size: 27,
                                          color: i == 0
                                              ? OwnerStyle.red
                                              : OwnerStyle.navMuted),
                                      SizedBox(height: u(5)),
                                      Text(destination.label,
                                          style: OwnerStyle.text(context, 12.5,
                                              weight: 500,
                                              color: i == 0
                                                  ? OwnerStyle.red
                                                  : OwnerStyle.muted,
                                              spacing: -.2)),
                                    ]))))),
                ]))));
  }
}

// The overview ---------------------------------------------------------------------------

/// The Muhtasari row that opens the performance overview.
class PerformanceEntry extends ConsumerWidget {
  const PerformanceEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerMenuRow(
        label: s.opTitle,
        subtitle: s.opEntryCaption,
        icon: 'reports',
        height: 68,
        onTap: () => context.push(MNRoutes.officePerformance));
  }
}

class OwnerPerformanceScreen extends ConsumerWidget {
  const OwnerPerformanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = _key(ref);
    return _PerformancePage(
        title: s.opTitle,
        showPeriodRange: true,
        showOverviewRange: true,
        showOverviewNavigation: true,
        onRefresh: () => ref.refresh(performanceOverviewProvider(key).future),
        body: (context) => OwnerAsyncView(
            value: ref.watch(performanceOverviewProvider(key)),
            onRetry: () => ref.invalidate(performanceOverviewProvider(key)),
            loadingRows: 4,
            data: (o) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Totals(overview: o),
                      _Attention(overview: o),
                      _gap(context),
                      OwnerDetails(
                          title: s.opRanking,
                          leading: Icon(Icons.emoji_events_outlined,
                              color: OwnerStyle.muted,
                              size: OwnerStyle.px(context, 24)),
                          children: [_Ranking(entries: o.ranking)]),
                      _section(context, s.opStations),
                      if (o.stations.isEmpty)
                        MNNote(s.opRankingNone, tone: MNNoteTone.info)
                      else
                        OwnerCard(
                            child: PerformancePaged(
                                count: o.stations.length,
                                divided: true,
                                itemBuilder: (_, i) =>
                                    _StationRow(station: o.stations[i]))),
                      if (o.profitUnknownDays > 0) ...[
                        _gap(context, 12),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: OwnerStyle.px(context, 4)),
                            child: Text(s.opProfitIncompleteHelp,
                                style:
                                    _body(context, color: OwnerStyle.muted))),
                      ],
                    ])));
  }
}

class _Totals extends ConsumerWidget {
  final PerformanceOverview overview;
  const _Totals({required this.overview});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final o = overview;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(MNRoutes.officeMoneyReport),
          child: Padding(
              padding: EdgeInsets.fromLTRB(
                  OwnerStyle.px(context, 4),
                  OwnerStyle.px(context, 4),
                  OwnerStyle.px(context, 4),
                  OwnerStyle.px(context, 12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.opSales,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                    SizedBox(height: OwnerStyle.px(context, 4)),
                    Row(children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(formatTsh(o.sales),
                                  style: OwnerStyle.text(context, 30,
                                      weight: 700, spacing: -.8)))),
                      OwnerGlyph('chevron',
                          size: 12, color: OwnerStyle.secondary),
                    ]),
                  ]))),
      const Divider(height: 1, color: OwnerStyle.line),
      _MetricsGrid(overview: o),
      if (o.bonusAdjustments != 0) ...[
        const Divider(height: 1, color: OwnerStyle.line),
        Padding(
            padding: EdgeInsets.symmetric(
                horizontal: OwnerStyle.px(context, 4),
                vertical: OwnerStyle.px(context, 10)),
            child: _Line(s.opBonusAdjustments, formatTsh(o.bonusAdjustments))),
      ],
      if (o.profitUnknownDays > 0) ...[
        SizedBox(height: OwnerStyle.px(context, 14)),
        Container(
            padding: EdgeInsets.symmetric(
                horizontal: OwnerStyle.px(context, 14),
                vertical: OwnerStyle.px(context, 12)),
            decoration: BoxDecoration(
                color: OwnerStyle.scoreNote,
                borderRadius:
                    BorderRadius.circular(OwnerStyle.px(context, 12))),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size: OwnerStyle.px(context, 19), color: OwnerStyle.muted),
              SizedBox(width: OwnerStyle.px(context, 10)),
              Expanded(
                  child: Text(s.opProfitUnknown(o.profitUnknownDays),
                      style: OwnerStyle.text(context, 13,
                          color: OwnerStyle.navMuted))),
              OwnerGlyph('chevron', size: 12, color: OwnerStyle.navMuted),
            ])),
      ],
    ]));
  }
}

class _MetricsGrid extends ConsumerWidget {
  final PerformanceOverview overview;
  const _MetricsGrid({required this.overview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final o = overview;
    final profit =
        o.profitUnknownDays > 0 ? s.opProfitIncomplete : formatTsh(o.profit);
    return Column(children: [
      IntrinsicHeight(
          child: Row(children: [
        Expanded(
            child: _MetricCell(
                label: s.opProfit, value: profit, top: true, left: true)),
        Container(width: 1, color: OwnerStyle.line),
        Expanded(
            child: _MetricCell(
                label: s.opBonusEarned,
                value: formatTsh(o.bonusEarned),
                top: true)),
      ])),
      const Divider(height: 1, color: OwnerStyle.line),
      IntrinsicHeight(
          child: Row(children: [
        Expanded(
            child: _MetricCell(
                label: s.opVerifiedChickens,
                value: s.opPieces(chickensText(o.chickens)),
                left: true)),
        Container(width: 1, color: OwnerStyle.line),
        Expanded(
            child: _MetricCell(
                label: s.opEstimatedShort,
                value: formatTsh(o.bonusEstimated),
                estimatedHelp: s.opEstimatedHelp)),
      ])),
    ]);
  }
}

class _MetricCell extends StatelessWidget {
  final String label, value;
  final bool top, left;
  final String? estimatedHelp;
  const _MetricCell(
      {required this.label,
      required this.value,
      this.top = false,
      this.left = false,
      this.estimatedHelp});

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          left ? OwnerStyle.px(context, 4) : OwnerStyle.px(context, 14),
          OwnerStyle.px(context, top ? 12 : 14),
          OwnerStyle.px(context, 8),
          OwnerStyle.px(context, 12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Expanded(
                  child: Text(label,
                      style: OwnerStyle.text(context, 13.5,
                          color: OwnerStyle.muted))),
              if (estimatedHelp != null)
                Tooltip(
                    message: estimatedHelp!,
                    child: Icon(Icons.info_outline,
                        size: OwnerStyle.px(context, 16),
                        color: OwnerStyle.muted)),
            ]),
            SizedBox(height: OwnerStyle.px(context, 4)),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: OwnerStyle.text(context, 18, weight: 600))),
          ]));
}

class _Attention extends ConsumerStatefulWidget {
  final PerformanceOverview overview;
  const _Attention({required this.overview});

  @override
  ConsumerState<_Attention> createState() => _AttentionState();
}

class _AttentionState extends ConsumerState<_Attention> {
  bool _showAll = false;

  void _open(BuildContext context, AttentionItem a) {
    final station = a.station;
    final vendor = a.vendor;
    if (station != null && vendor != null) {
      final date =
          a.businessDate == null ? null : moneyDateKey(a.businessDate!);
      final detail = a.detail;
      final kind = a.kind;
      final recordId = detail['expense_id']?.toString();
      final lastSyncedAt = detail['last_synced_at']?.toString();
      final supported = switch (kind) {
        AttentionKind.moneyShort || AttentionKind.notSynced => true,
        AttentionKind.expensePending =>
          date != null && recordId != null && recordId.isNotEmpty,
        _ => false,
      };
      if (supported && (kind == AttentionKind.notSynced || date != null)) {
        context.push(
            MNRoutes.officePerformanceAttention(
                kind: kind!.wire,
                stationId: station.id,
                vendorId: vendor.id,
                recordId: recordId,
                date: date,
                lastSyncedAt: lastSyncedAt),
            extra: {'station': station.name, 'vendor': vendor.name});
        return;
      }
    }
    if (a.vendor != null && a.kind != AttentionKind.stockDifference) {
      context.push(MNRoutes.officePerformanceVendor(a.vendor!.id));
    } else if (a.station != null) {
      context.push(MNRoutes.officePerformanceStation(a.station!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final kinds = [
      for (final k in AttentionKind.values)
        if (widget.overview.countOf(k) > 0) k
    ];
    if (kinds.isEmpty) {
      return Column(children: [
        _section(context, s.opAttention),
        MNNote(s.opAttentionNone, tone: MNNoteTone.info)
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(context, s.opAttention,
          trailing: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              style: TextButton.styleFrom(
                  foregroundColor: OwnerStyle.muted,
                  minimumSize: Size(48, OwnerStyle.px(context, 48)),
                  padding: EdgeInsets.symmetric(
                      horizontal: OwnerStyle.px(context, 4))),
              child: Text(_showAll ? s.opShowLess : s.opViewAll,
                  style:
                      OwnerStyle.text(context, 14, color: OwnerStyle.muted)))),
      OwnerCard(
          child: Column(children: [
        for (final (i, kind) in kinds.indexed) ...[
          if (i > 0) const Divider(height: 1, color: OwnerStyle.line),
          Builder(builder: (context) {
            final items =
                widget.overview.attention.where((a) => a.kind == kind).toList();
            final count = widget.overview.countOf(kind);
            final first = items.firstOrNull;
            return Column(children: [
              OwnerMenuRow(
                  leading: _attentionIcon(kind),
                  label: s.attentionKindName(kind.wire),
                  subtitle: _attentionCaption(s, kind),
                  value: '$count',
                  valueSize: 16,
                  valueColor: OwnerStyle.muted,
                  height: 76,
                  onTap: first == null ? null : () => _open(context, first),
                  showChevron: first != null),
              if (_showAll) ...[
                for (final item in items)
                  OwnerMenuRow(
                      label: item.vendor?.name ?? item.station?.name ?? '—',
                      subtitle: [
                        if (item.vendor != null && item.station != null)
                          item.station!.name,
                        if (item.businessDate != null)
                          s.date(item.businessDate!),
                      ].join(' · '),
                      height: 58,
                      onTap: item.vendor == null && item.station == null
                          ? null
                          : () => _open(context, item),
                      showChevron: item.vendor != null || item.station != null),
                if (count > items.length)
                  Padding(
                      padding: EdgeInsets.fromLTRB(
                          OwnerStyle.px(context, 16),
                          OwnerStyle.px(context, 4),
                          OwnerStyle.px(context, 16),
                          OwnerStyle.px(context, 12)),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(s.attentionMore(count - items.length),
                              style: _meta(context)))),
              ],
            ]);
          }),
        ],
      ])),
    ]);
  }
}

String _attentionCaption(Strings s, AttentionKind kind) => switch (kind) {
      AttentionKind.moneyShort => s.opAttentionReview,
      AttentionKind.expensePending => s.opAttentionPendingReview,
      AttentionKind.notSynced => s.opAttentionSync,
      AttentionKind.stockDifference => s.opAttentionStock,
      AttentionKind.targetMissed => s.opAttentionTarget,
    };

Widget _attentionIcon(AttentionKind kind) => switch (kind) {
      AttentionKind.moneyShort =>
        const OwnerGlyph('warning', size: 26, color: OwnerStyle.red),
      AttentionKind.notSynced => const Icon(Icons.cloud_sync_outlined,
          size: 28, color: OwnerStyle.muted),
      AttentionKind.expensePending =>
        const OwnerGlyph('reports', size: 25, color: OwnerStyle.muted),
      AttentionKind.stockDifference =>
        const OwnerGlyph('stock-box', size: 25, color: OwnerStyle.muted),
      AttentionKind.targetMissed =>
        const OwnerGlyph('warning', size: 25, color: OwnerStyle.muted),
    };

class OwnerPerformanceAttentionScreen extends ConsumerWidget {
  final String kind, stationId, vendorId;
  final String? stationName, vendorName, recordId, date, lastSyncedAt;

  const OwnerPerformanceAttentionScreen(
      {super.key,
      required this.kind,
      required this.stationId,
      required this.vendorId,
      this.stationName,
      this.vendorName,
      this.recordId,
      this.date,
      this.lastSyncedAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final parsedKind = AttentionKind.parse(kind);
    if (!_isOwner(ref) ||
        stationId.isEmpty ||
        vendorId.isEmpty ||
        parsedKind == null) {
      return OwnerPage(
          title: s.opTitle,
          strings: s,
          child: Padding(
              padding: _pad(context),
              child: MNNote(s.notAllowed, tone: MNNoteTone.warning)));
    }

    return switch (parsedKind) {
      AttentionKind.moneyShort when date != null => _CashShortAttention(
          stationId: stationId,
          stationName: stationName ?? stationId,
          vendorId: vendorId,
          vendorName: vendorName ?? vendorId,
          date: date!),
      AttentionKind.notSynced => _PhoneSyncAttention(
          stationId: stationId,
          stationName: stationName ?? stationId,
          vendorId: vendorId,
          vendorName: vendorName ?? vendorId,
          lastSyncedAt: lastSyncedAt),
      AttentionKind.expensePending when date != null && recordId != null =>
        _ExpenseAttention(
            stationId: stationId,
            vendorId: vendorId,
            expenseId: recordId!,
            date: date!),
      _ => OwnerPage(
          title: s.opTitle,
          strings: s,
          child: Padding(
              padding: _pad(context),
              child: MNNote(s.errorBody, tone: MNNoteTone.info))),
    };
  }
}

class _CashShortAttention extends ConsumerWidget {
  final String stationId, stationName, vendorId, vendorName, date;
  const _CashShortAttention(
      {required this.stationId,
      required this.stationName,
      required this.vendorId,
      required this.vendorName,
      required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final dayKey = (station: stationId, date: date);
    final vendorKey = (station: stationId, date: date, vendor: vendorId);
    final days = ref.watch(money.moneyDaysProvider(dayKey));
    final handovers = ref.watch(money.vendorHandoversProvider(vendorKey));
    final businessDate = _attentionDate(date);
    return OwnerPage(
        title: s.opCashShortTitle,
        strings: s,
        subtitle: Text(
            businessDate == null
                ? stationName
                : '$stationName · ${s.date(businessDate)}',
            style: _meta(context)),
        onRefresh: () => ref
            .refresh(money.moneyDaysProvider(dayKey).future)
            .then((_) =>
                ref.refresh(money.vendorHandoversProvider(vendorKey).future))
            .then<void>((_) {}),
        child: Padding(
            padding: _pad(context),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OwnerAsyncView(
                      value: days,
                      onRetry: () =>
                          ref.invalidate(money.moneyDaysProvider(dayKey)),
                      isEmpty: (rows) => rows.isEmpty,
                      empty: (_) =>
                          MNNote(s.moneyNoDayForVendor, tone: MNNoteTone.info),
                      data: (rows) {
                        final day = rows
                            .where((row) => row.vendor.id == vendorId)
                            .firstOrNull;
                        if (day == null) {
                          return MNNote(s.moneyNoDayForVendor,
                              tone: MNNoteTone.info);
                        }
                        final state = moneyStateWord(s, day);
                        final resolved = switch (day.state) {
                          MoneyDayState.full ||
                          MoneyDayState.over ||
                          MoneyDayState.nothingDue =>
                            true,
                          _ => false,
                        };
                        final open = day.state == MoneyDayState.short ||
                            day.state == MoneyDayState.notHanded;
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AttentionStateCard(
                                  icon: resolved
                                      ? Icons.check_circle_outline
                                      : open
                                          ? Icons.warning_amber_outlined
                                          : Icons.help_outline,
                                  color: resolved
                                      ? MNColors.success
                                      : open
                                          ? MNColors.error
                                          : OwnerStyle.muted,
                                  title: resolved
                                      ? s.opDifferenceResolved
                                      : open
                                          ? s.opCashNeedsReview
                                          : s.opCashStateUnknown,
                                  detail: state?.$1 ?? s.opCashStateUnknown),
                              _gap(context),
                              _AttentionSection(
                                  title: s.opCashDetails,
                                  children: [
                                    _AttentionRow(
                                        label: s.opVendor, value: vendorName),
                                    _AttentionRow(
                                        label: s.opExpected,
                                        value: formatTsh(day.cashDue)),
                                    _AttentionRow(
                                        label: s.opHandedOver,
                                        value: formatTsh(day.handedOver)),
                                    _AttentionRow(
                                        label: s.opConfirmed,
                                        value: formatTsh(day.confirmed)),
                                    _AttentionRow(
                                        label: s.opRemainingCash,
                                        value: formatTsh(day.remaining)),
                                  ]),
                              _gap(context),
                              _AttentionSection(
                                  title: s.moneyHandovers,
                                  children: [
                                    OwnerAsyncView(
                                        value: handovers,
                                        onRetry: () => ref.invalidate(
                                            money.vendorHandoversProvider(
                                                vendorKey)),
                                        isEmpty: (rows) => rows.isEmpty,
                                        empty: (_) => MNNote(s.moneyNoHandovers,
                                            tone: MNNoteTone.info),
                                        data: (rows) {
                                          final dayHandovers = rows
                                              .where((h) =>
                                                  h.businessDate != null &&
                                                  moneyDateKey(
                                                          h.businessDate!) ==
                                                      date)
                                              .toList();
                                          if (dayHandovers.isEmpty) {
                                            return MNNote(s.moneyNoHandovers,
                                                tone: MNNoteTone.info);
                                          }
                                          return Column(
                                              children: dayHandovers
                                                  .map((handover) =>
                                                      _HandoverAttentionRow(
                                                          handover: handover))
                                                  .toList());
                                        }),
                                  ]),
                              _gap(context),
                              MNButton(s.opReviewDifference,
                                  onPressed: businessDate == null
                                      ? null
                                      : () => context.push(
                                          MNRoutes.officeMoneyVendorDay(
                                              stationId, date, vendorId))),
                            ]);
                      }),
                ])));
  }
}

class _PhoneSyncAttention extends ConsumerWidget {
  final String stationId, stationName, vendorId, vendorName;
  final String? lastSyncedAt;
  const _PhoneSyncAttention(
      {required this.stationId,
      required this.stationName,
      required this.vendorId,
      required this.vendorName,
      this.lastSyncedAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final overviewKey = _key(ref);
    final overview = ref.watch(performanceOverviewProvider(overviewKey));
    final syncTime =
        lastSyncedAt == null ? null : DateTime.tryParse(lastSyncedAt!);
    return OwnerPage(
        title: s.opPhoneSyncTitle,
        strings: s,
        onRefresh: () => ref
            .refresh(performanceOverviewProvider(overviewKey).future)
            .then<void>((_) {}),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView(
                value: overview,
                onRetry: () =>
                    ref.invalidate(performanceOverviewProvider(overviewKey)),
                data: (data) {
                  final syncItem = data.attention
                      .where((item) =>
                          item.kind == AttentionKind.notSynced &&
                          item.station?.id == stationId &&
                          item.vendor?.id == vendorId)
                      .firstOrNull;
                  final waiting = syncItem != null;
                  final noAlerts = data.countOf(AttentionKind.notSynced) == 0;
                  final recovered = !waiting && noAlerts;
                  final title = waiting
                      ? s.opWaitingForDevice
                      : recovered
                          ? s.opSyncNoAlertTitle
                          : s.opSyncStatusUnknown;
                  final detail = waiting
                      ? s.opSyncPendingPhone
                      : recovered
                          ? s.opNoCurrentSyncAlert
                          : s.opSyncStatusUnknown;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AttentionStateCard(
                            icon: waiting
                                ? Icons.cloud_sync_outlined
                                : recovered
                                    ? Icons.check_circle_outline
                                    : Icons.help_outline,
                            color: waiting
                                ? MNColors.warning
                                : recovered
                                    ? MNColors.success
                                    : OwnerStyle.muted,
                            title: title,
                            detail: detail),
                        _gap(context),
                        _AttentionSection(title: s.opAffectedPhone, children: [
                          _AttentionRow(
                              label: s.opAssignedTo,
                              value: '$vendorName · $stationName'),
                          _AttentionRow(
                              label: s.opLastSync,
                              value: syncTime == null
                                  ? s.opNotProvidedByServer
                                  : _attentionWhen(s, syncTime)),
                        ]),
                        _gap(context),
                        MNNote(s.opSyncHistoryUnavailable,
                            tone: MNNoteTone.info),
                        _gap(context),
                        MNButton.secondary(s.opViewSyncReviews,
                            onPressed: () =>
                                context.push(MNRoutes.officeSyncConflicts)),
                      ]);
                })));
  }
}

class _ExpenseAttention extends ConsumerWidget {
  final String stationId, vendorId, expenseId, date;
  const _ExpenseAttention(
      {required this.stationId,
      required this.vendorId,
      required this.expenseId,
      required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = (station: stationId, date: date);
    final expenses = ref.watch(money.moneyExpensesProvider(key));
    final businessDate = _attentionDate(date);
    final expense = expenses.valueOrNull
        ?.where((row) => row.id == expenseId && row.vendor?.id == vendorId)
        .firstOrNull;
    return OwnerPage(
        title: s.opExpenseDetails,
        strings: s,
        subtitle: Text(
            '${expense?.station.name ?? stationId} · ${businessDate == null ? date : s.date(businessDate)}',
            style: _meta(context)),
        onRefresh: () => ref
            .refresh(money.moneyExpensesProvider(key).future)
            .then<void>((_) {}),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView(
                value: expenses,
                onRetry: () => ref.invalidate(money.moneyExpensesProvider(key)),
                data: (rows) {
                  final item = rows
                      .where((row) =>
                          row.id == expenseId && row.vendor?.id == vendorId)
                      .firstOrNull;
                  if (item == null) {
                    return MNNote(s.moneyRecordGone, tone: MNNoteTone.info);
                  }
                  final pending = item.pending;
                  final approved = item.approved;
                  final stateLabel = pending
                      ? s.opAwaitingApproval
                      : approved
                          ? s.moneyExpenseApproved
                          : s.moneyExpenseRejected;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AttentionStateCard(
                            icon: pending
                                ? Icons.hourglass_top_outlined
                                : approved
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                            color: pending
                                ? MNColors.warning
                                : approved
                                    ? MNColors.success
                                    : MNColors.error,
                            title: stateLabel,
                            detail: formatTsh(item.amount)),
                        _gap(context),
                        _AttentionSection(title: s.opExpenseDetails, children: [
                          _AttentionRow(
                              label: s.opRequestedAmount,
                              value: formatTsh(item.amount)),
                          _AttentionRow(
                              label: s.opSubmittedBy,
                              value: item.recordedBy?.name ??
                                  item.vendor?.name ??
                                  '—'),
                          _AttentionRow(
                              label: s.moneyExpenses, value: item.category),
                          if (item.item?.isNotEmpty == true)
                            _AttentionRow(
                                label: s.expenseItem, value: item.item!),
                          if (item.note?.isNotEmpty == true)
                            _AttentionRow(
                                label: s.noteOptional, value: item.note!),
                          if (item.decisionReason?.isNotEmpty == true)
                            _AttentionRow(
                                label: s.decisionReason,
                                value: item.decisionReason!),
                        ]),
                        _gap(context),
                        _AttentionSection(
                            title: s.opExpenseAuditHistory,
                            children: [
                              _AttentionRow(
                                  label: s.opExpenseSubmitted,
                                  value: _attentionWhen(s, item.createdAt)),
                              if (item.decidedAt != null)
                                _AttentionRow(
                                    label: approved
                                        ? s.opExpenseApproved
                                        : s.opExpenseRejected,
                                    value:
                                        '${_attentionWhen(s, item.decidedAt)} · ${item.decidedBy?.name ?? s.opOffice}'),
                            ]),
                        if (pending) ...[
                          _gap(context),
                          MNButton(s.moneyApproveExpense,
                              onPressed: () =>
                                  _decideExpense(context, ref, item, true)),
                          _gap(context, 8),
                          MNButton.secondary(s.moneyRejectExpense,
                              onPressed: () =>
                                  _decideExpense(context, ref, item, false)),
                        ],
                      ]);
                })));
  }

  Future<void> _decideExpense(BuildContext context, WidgetRef ref,
      OfficeExpense expense, bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _AttentionExpenseDecisionSheet(
            title: approve
                ? s.moneyApproveExpenseTitle
                : s.moneyRejectExpenseTitle,
            body: approve
                ? s.moneyApproveExpenseBody(
                    formatTsh(expense.amount), expense.vendor?.name ?? '—')
                : s.moneyRejectExpenseBody,
            action: approve ? s.moneyApproveExpense : s.moneyRejectExpense,
            approve: approve,
            send: (reason) => ref.read(officeSessionProvider.notifier).guard(
                (repo) => repo.decideExpense(expense.id,
                    approve: approve, reason: reason))));
    if (done == true) {
      ref.invalidate(
          money.moneyExpensesProvider((station: stationId, date: date)));
      ref.invalidate(performanceOverviewProvider(_key(ref)));
    }
  }
}

class _AttentionExpenseDecisionSheet extends ConsumerStatefulWidget {
  final String title, body, action;
  final bool approve;
  final Future<void> Function(String) send;
  const _AttentionExpenseDecisionSheet(
      {required this.title,
      required this.body,
      required this.action,
      required this.approve,
      required this.send});

  @override
  ConsumerState<_AttentionExpenseDecisionSheet> createState() =>
      _AttentionExpenseDecisionSheetState();
}

class _AttentionExpenseDecisionSheetState
    extends ConsumerState<_AttentionExpenseDecisionSheet> {
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
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      MNNote(widget.body,
          tone: widget.approve ? MNNoteTone.warning : MNNoteTone.info),
      MNTextField(
          label: s.decisionReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(widget.action, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

class _AttentionStateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, detail;
  const _AttentionStateCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.detail});

  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: OwnerStyle.px(context, 24), color: color),
            SizedBox(width: OwnerStyle.px(context, 12)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: OwnerStyle.text(context, 16,
                          weight: 600, color: color)),
                  SizedBox(height: OwnerStyle.px(context, 4)),
                  Text(detail, style: _meta(context)),
                ])),
          ])));
}

class _AttentionSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _AttentionSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: OwnerStyle.text(context, 16, weight: 600)),
        _gap(context, 8),
        OwnerCard(
            child: Column(children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const Divider(height: 1, color: OwnerStyle.line),
            child,
          ],
        ])),
      ]);
}

class _AttentionRow extends StatelessWidget {
  final String label, value;
  const _AttentionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: OwnerStyle.px(context, 16),
          vertical: OwnerStyle.px(context, 12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: _meta(context))),
        SizedBox(width: OwnerStyle.px(context, 12)),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: OwnerStyle.text(context, 14, weight: 600))),
      ]));
}

class _HandoverAttentionRow extends ConsumerWidget {
  final OfficeHandover handover;
  const _HandoverAttentionRow({required this.handover});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final when = handover.confirmedAt ?? handover.receivedAt;
    return Column(children: [
      _AttentionRow(
          label: _attentionWhen(s, when), value: formatTsh(handover.amount)),
      Padding(
          padding: EdgeInsets.fromLTRB(
              OwnerStyle.px(context, 16), 0, OwnerStyle.px(context, 16), 12),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  handover.confirmed
                      ? s.moneyConfirmedBy(
                          handover.confirmedBy?.name ?? s.opOffice)
                      : s.moneyHandoverWaiting,
                  style: _meta(context)))),
    ]);
  }
}

DateTime? _attentionDate(String? date) {
  if (date == null) return null;
  final parsed = DateTime.tryParse(date);
  return parsed == null
      ? null
      : DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String _attentionWhen(Strings strings, DateTime? value) {
  if (value == null) return strings.opNotConfirmed;
  final local = eatClock(value);
  return '${strings.date(local)}, ${strings.hhmm(local)}';
}

class _Ranking extends ConsumerWidget {
  final List<RankingEntry> entries;
  const _Ranking({required this.entries});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (entries.isEmpty) return MNNote(s.opRankingNone, tone: MNNoteTone.info);
    final scored = entries.any((e) => e.score != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!scored) ...[
        MNNote(s.opScoresNotSet, tone: MNNoteTone.info),
        _gap(context),
      ],
      OwnerCard(
          child: PerformancePaged(
              count: entries.length,
              divided: true,
              itemBuilder: (_, i) {
                final e = entries[i];
                final id = e.person?.id ?? '';
                return OwnerMenuRow(
                    label: e.person?.name ?? '—',
                    subtitle:
                        s.opCardName(e.card ?? (e.isVendor ? 'vendor' : '')),
                    value: e.score == null
                        ? '—'
                        : '${e.score} · ${_starsText(s, e.stars)}',
                    valueColor: OwnerStyle.muted,
                    height: 58,
                    onTap: id.isEmpty
                        ? null
                        : () => context.push(e.isVendor
                            ? MNRoutes.officePerformanceVendor(id)
                            : MNRoutes.officePerformanceStaff(id)));
              })),
    ]);
  }
}

class _StationRow extends ConsumerWidget {
  final StationPerformance station;
  const _StationRow({required this.station});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final st = station;
    return OwnerMenuRow(
        label: st.station.name,
        subtitle: s.opStationSummary(
            chickensText(st.chickens),
            st.profitUnknownDays > 0 || st.profit == null
                ? s.opProfitIncomplete
                : formatTsh(st.profit!)),
        height: 76,
        onTap: () =>
            context.push(MNRoutes.officePerformanceStation(st.station.id)));
  }
}

// A person's scorecard -------------------------------------------------------------------

// One station ------------------------------------------------------------------------------

class OwnerStationPerformanceScreen extends ConsumerWidget {
  final String stationId;
  const OwnerStationPerformanceScreen({super.key, required this.stationId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = _idKey(ref, stationId);
    final detail = ref.watch(stationPerformanceProvider(key));
    return _PerformancePage(
        title: detail.valueOrNull?.station?.name ?? s.opStationPerformance,
        showPeriodRange: true,
        compactTitle: true,
        onRefresh: () => ref.refresh(stationPerformanceProvider(key).future),
        help: [s.opStationPerformanceHelp],
        body: (context) => OwnerAsyncView(
            value: detail,
            onRetry: () => ref.invalidate(stationPerformanceProvider(key)),
            loadingRows: 4,
            data: (d) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StationTotals(detail: d),
                      _gap(context),
                      _StationIssues(detail: d, stationId: stationId),
                      if (d.vendors.isNotEmpty) ...[
                        _section(context, s.opVendors),
                        OwnerCard(
                            child: PerformancePaged(
                                count: d.vendors.length,
                                divided: true,
                                itemBuilder: (_, i) =>
                                    _StationVendorRow(vendor: d.vendors[i]))),
                      ],
                      _section(context, s.opDays),
                      if (d.days.isEmpty)
                        MNNote(s.opNoDays, tone: MNNoteTone.info)
                      else ...[
                        OwnerCard(
                            child: PerformancePaged(
                                count: d.days.length,
                                divided: true,
                                itemBuilder: (_, i) =>
                                    _StationDayRow(day: d.days[i]))),
                        _gap(context, 12),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: OwnerStyle.px(context, 4)),
                            child: Text(s.opStationDayReviewHint,
                                style:
                                    _body(context, color: OwnerStyle.muted))),
                        _gap(context, 8),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: OwnerStyle.px(context, 4)),
                            child: Text(s.opStationDayScope,
                                style: _meta(context))),
                      ],
                      _gap(context, 24),
                    ])));
  }
}

class _StationTotals extends ConsumerWidget {
  final StationPerformanceDetail detail;
  const _StationTotals({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final d = detail;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(
              OwnerStyle.px(context, 4),
              OwnerStyle.px(context, 4),
              OwnerStyle.px(context, 4),
              OwnerStyle.px(context, 12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.opSalesLabel,
                style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
            SizedBox(height: OwnerStyle.px(context, 4)),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatTsh(d.sales),
                    style: OwnerStyle.text(context, 30,
                        weight: 700, spacing: -.8))),
          ])),
      const Divider(height: 1, color: OwnerStyle.line),
      IntrinsicHeight(
          child: Row(children: [
        Expanded(
            child: _MetricCell(
                label: s.opExpenses,
                value: formatTsh(d.expenses),
                top: true,
                left: true)),
        Container(width: 1, color: OwnerStyle.line),
        Expanded(
            child: _MetricCell(
                label: s.opProfit,
                value: d.profitUnknownDays > 0 || d.profit == null
                    ? s.opProfitIncomplete
                    : formatTsh(d.profit!),
                top: true)),
      ])),
      const Divider(height: 1, color: OwnerStyle.line),
      IntrinsicHeight(
          child: Row(children: [
        Expanded(
            child: _MetricCell(
                label: s.opVerifiedChickens,
                value: s.opPieces(chickensText(d.chickens)),
                left: true)),
        Container(width: 1, color: OwnerStyle.line),
        Expanded(
            child: _MetricCell(
                label: s.opPendingExpensesLabel,
                value: formatTsh(d.pendingExpenses))),
      ])),
    ]));
  }
}

class _StationIssues extends ConsumerWidget {
  final StationPerformanceDetail detail;
  final String stationId;
  const _StationIssues({required this.detail, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = <Widget>[];
    if (detail.profitUnknownDays > 0) {
      rows.add(OwnerMenuRow(
          leading: Icon(Icons.info_outline,
              size: OwnerStyle.px(context, 22), color: OwnerStyle.muted),
          label: s.opProfitMissingDays(detail.profitUnknownDays),
          height: 60,
          showChevron: false));
    }
    if (detail.openExceptions > 0) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, color: OwnerStyle.line));
      }
      rows.add(OwnerMenuRow(
          leading: const OwnerGlyph('warning', size: 25, color: OwnerStyle.red),
          label: s.opOpenProblemsShort,
          value: '${detail.openExceptions}',
          valueSize: 16,
          valueColor: OwnerStyle.muted,
          onTap: () =>
              context.push(MNRoutes.officeVerificationStation(stationId))));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return OwnerCard(child: Column(children: rows));
  }
}

class _StationVendorRow extends ConsumerWidget {
  final StationVendorFigures vendor;
  const _StationVendorRow({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final id = vendor.vendor?.id;
    return InkWell(
        onTap: id == null
            ? null
            : () => context.push(MNRoutes.officePerformanceVendor(id)),
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: OwnerStyle.px(context, 76)),
            child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: OwnerStyle.px(context, 16),
                    vertical: OwnerStyle.px(context, 12)),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(vendor.vendor?.name ?? '—',
                            style: OwnerStyle.text(context, 16,
                                weight: 500, spacing: -.45)),
                        SizedBox(height: OwnerStyle.px(context, 4)),
                        Text(
                            s.opVendorVerifiedChickens(
                                chickensText(vendor.chickens)),
                            style: _meta(context)),
                      ])),
                  SizedBox(width: OwnerStyle.px(context, 8)),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.opVendorBonusEarned(formatTsh(vendor.earned)),
                            style: OwnerStyle.text(context, 13,
                                weight: 600, spacing: -.25)),
                        SizedBox(height: OwnerStyle.px(context, 4)),
                        Text(
                            s.opVendorBonusEstimated(
                                formatTsh(vendor.estimated)),
                            style: _meta(context)),
                      ]),
                  SizedBox(width: OwnerStyle.px(context, 10)),
                  OwnerGlyph('vendor-chevron', size: 17),
                ]))));
  }
}

class _StationDayRow extends ConsumerWidget {
  final StationDayFigures day;
  const _StationDayRow({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = day.businessDate;
    final profit =
        day.profit == null ? s.opProfitIncomplete : formatTsh(day.profit!);
    return InkWell(
        onTap: date == null
            ? null
            : () => ref.read(performanceWindowProvider.notifier).state =
                (period: PerformancePeriod.day, day: date),
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: OwnerStyle.px(context, 80)),
            child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: OwnerStyle.px(context, 16),
                    vertical: OwnerStyle.px(context, 12)),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(date == null ? '—' : s.date(date),
                            style: OwnerStyle.text(context, 16,
                                weight: 500, spacing: -.4)),
                        SizedBox(height: OwnerStyle.px(context, 4)),
                        Text(
                            s.opStationDaySummary(
                                s.opVendorsSharing(day.vendorsSharing), profit),
                            style: _meta(context)),
                      ])),
                  SizedBox(width: OwnerStyle.px(context, 8)),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.opSalesLabel, style: _meta(context)),
                        SizedBox(height: OwnerStyle.px(context, 2)),
                        Text(formatTsh(day.sales),
                            style: OwnerStyle.text(context, 16,
                                weight: 600, spacing: -.3)),
                      ]),
                  SizedBox(width: OwnerStyle.px(context, 10)),
                  OwnerGlyph('vendor-chevron', size: 17),
                ]))));
  }
}
