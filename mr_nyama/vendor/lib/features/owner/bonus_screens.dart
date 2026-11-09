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
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import '../office/owner_reference.dart';
import '../office/people_screens.dart' show officeErrorText;

/// The owner's view of vendor bonuses (design §6): earned on days whose
/// station count is confirmed, estimated on the others (never paid), and the
/// adjustments later corrections booked. Payments go only through vendor pay
/// ("Malipo ya wauzaji"). Also the owner's correction of a verified sale
/// (§11). The server computes every figure.

// Data ---------------------------------------------------------------------------------

/// Runs [work] with the owner's bonus side of the office API.
Future<T> ownerBonusesCall<T>(
        WidgetRef ref, Future<T> Function(OwnerBonusesRepository) work) =>
    _guard(ref.read(officeSessionProvider.notifier), work);

Future<T> _guard<T>(OfficeSessionController session,
        Future<T> Function(OwnerBonusesRepository) work) =>
    session.guard((repo) {
      if (repo is! OwnerBonusesRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OwnerBonusesRepository);
    });

typedef BonusKey = ({String period, String date});
typedef VendorBonusKey = ({String vendor, String period, String date});
typedef VerifiedSalesKey = ({String station, String date});

final ownerBonusesProvider = FutureProvider.autoDispose
    .family<OwnerBonusPeriod, BonusKey>((ref, k) => _guard(
        ref.read(officeSessionProvider.notifier),
        (r) => r.bonuses(period: k.period, date: k.date)));

final ownerVendorBonusProvider = FutureProvider.autoDispose
    .family<OwnerVendorBonus, VendorBonusKey>((ref, k) => _guard(
        ref.read(officeSessionProvider.notifier),
        (r) => r.vendorBonus(k.vendor, period: k.period, date: k.date)));

final ownerVerifiedSalesProvider = FutureProvider.autoDispose
    .family<List<OfficeSale>, VerifiedSalesKey>((ref, k) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.stationSales(k.station,
            businessDate: k.date, status: 'verified')));

bool _isOwner(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn && auth.profile.isOwner;
}

// Formatting ---------------------------------------------------------------------------

const _pageSize = 10;
const _periods = ['day', 'week', 'month'];

String _plain(num n) => n == n.roundToDouble()
    ? '${n.round()}'
    : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

String _signedTsh(int n) => n < 0 ? '−${formatTsh(-n)}' : formatTsh(n);

DateTime? _parseDay(String? key) {
  final d = key == null ? null : DateTime.tryParse(key);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c) => OwnerStyle.text(c, 14);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

DateTime _periodStart(String period, DateTime day) => switch (period) {
      'week' => DateTime.utc(
          day.year, day.month, day.day - (day.weekday - DateTime.monday)),
      'month' => DateTime.utc(day.year, day.month),
      _ => DateTime.utc(day.year, day.month, day.day),
    };

DateTime _periodEnd(String period, DateTime day) => switch (period) {
      'week' => _periodStart(period, day).add(const Duration(days: 6)),
      'month' => DateTime.utc(day.year, day.month + 1, 0),
      _ => DateTime.utc(day.year, day.month, day.day),
    };

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

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

Widget _notAllowed(BuildContext context, Strings s, String title) => OwnerPage(
    title: title,
    strings: s,
    child: Padding(padding: _pad(context), child: MNNote(s.notAllowed)));

/// Day / week / month chips and the date the period holds.
class _PeriodBar extends ConsumerWidget {
  final String period;
  final DateTime day;
  final ValueChanged<String> onPeriod;
  final ValueChanged<DateTime> onDay;
  const _PeriodBar(
      {required this.period,
      required this.day,
      required this.onPeriod,
      required this.onDay});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final today = businessDate(ref.read(clockProvider)());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MNChipBar(
          labels: [s.bonusPeriodDay, s.bonusPeriodWeek, s.bonusPeriodMonth],
          selected: math.max(0, _periods.indexOf(period)),
          onSelect: (i) => onPeriod(_periods[i])),
      _gap(context, 8),
      Padding(
          padding: _pad(context),
          child: MNFieldButton(
              label: s.bonusDate,
              text: s.bonusRange(s.date(_periodStart(period, day)),
                  s.date(_periodEnd(period, day))),
              placeholder: s.bonusRange(s.date(_periodStart(period, day)),
                  s.date(_periodEnd(period, day))),
              icon: MNIconData.calendar,
              onTap: () async {
                final picked = await showMNDateSheet(context,
                    title: s.bonusDate,
                    initial: day,
                    first: DateTime.utc(today.year - 2),
                    last: today);
                if (picked != null) {
                  onDay(DateTime.utc(picked.year, picked.month, picked.day));
                }
              })),
    ]);
  }
}

// Every vendor's bonuses -----------------------------------------------------------------

class OwnerBonusesScreen extends ConsumerStatefulWidget {
  const OwnerBonusesScreen({super.key});
  @override
  ConsumerState<OwnerBonusesScreen> createState() => _BonusesState();
}

class _BonusesState extends ConsumerState<OwnerBonusesScreen> {
  String _period = 'week';
  late DateTime _day = businessDate(ref.read(clockProvider)());

  BonusKey get _key => (period: _period, date: moneyDateKey(_day));

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (!_isOwner(ref)) return _notAllowed(context, s, s.bonusTitle);
    final value = ref.watch(ownerBonusesProvider(_key));
    return OwnerPage(
        title: s.bonusTitle,
        strings: s,
        onRefresh: () => ref.refresh(ownerBonusesProvider(_key).future),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PeriodBar(
              period: _period,
              day: _day,
              onPeriod: (p) => setState(() => _period = p),
              onDay: (d) => setState(() => _day = d)),
          _gap(context),
          Padding(
              padding: _pad(context),
              child: OwnerAsyncView(
                  value: value,
                  onRetry: () => ref.invalidate(ownerBonusesProvider(_key)),
                  loadingRows: 3,
                  data: (p) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Totals(
                                from: p.from,
                                to: p.to,
                                earned: p.earned,
                                estimated: p.estimated,
                                adjustments: p.adjustments),
                            _gap(context),
                            if (p.vendors.isEmpty)
                              MNNote(s.bonusNone, tone: MNNoteTone.info)
                            else
                              _Paged(
                                  count: p.vendors.length,
                                  itemBuilder: (_, i) => _VendorRow(
                                      bonus: p.vendors[i],
                                      period: _period,
                                      date: moneyDateKey(_day))),
                          ]))),
        ]));
  }
}

class _Totals extends ConsumerWidget {
  final DateTime? from, to;
  final int earned, estimated, adjustments;
  const _Totals(
      {this.from,
      this.to,
      required this.earned,
      required this.estimated,
      required this.adjustments});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (from != null && to != null)
        Text(s.bonusRange(s.date(from!), s.date(to!)), style: _meta(context)),
      _gap(context, 4),
      Text(s.bonusEarned(formatTsh(earned)),
          style: OwnerStyle.text(context, 20, weight: 600)),
      if (adjustments != 0)
        Text(s.bonusAdjustments(_signedTsh(adjustments)),
            style: _body(context)),
      if (estimated > 0) ...[
        _gap(context, 6),
        Text(s.bonusEstimated(formatTsh(estimated)), style: _meta(context)),
        Text(s.bonusEstimatedNote, style: _meta(context)),
      ],
    ]));
  }
}

class _VendorRow extends ConsumerWidget {
  final OwnerVendorBonus bonus;
  final String period, date;
  const _VendorRow(
      {required this.bonus, required this.period, required this.date});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final b = bonus;
    final name = b.vendor.code == null
        ? b.vendor.name
        : '${b.vendor.name} · ${b.vendor.code}';
    return OwnerCard(
        child: InkWell(
            onTap: () => context.push(MNRoutes.officeVendorBonus(b.vendor.id,
                period: period, date: date)),
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
                            Text(s.bonusEarned(formatTsh(b.earned)),
                                style: _body(context)),
                            if (b.adjustments != 0)
                              Text(
                                  s.bonusAdjustments(_signedTsh(b.adjustments)),
                                  style: _meta(context)),
                            if (b.estimated > 0)
                              Text(s.bonusEstimated(formatTsh(b.estimated)),
                                  style: _meta(context)),
                            Text(s.bonusChickens(_plain(b.chickens)),
                                style: _meta(context)),
                          ])),
                      SizedBox(width: u(12)),
                      const OwnerGlyph('vendor-chevron', size: 14),
                    ])))));
  }
}

// One vendor's bonus days ----------------------------------------------------------------

class OwnerVendorBonusScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String? period, date, selectedDay;
  const OwnerVendorBonusScreen(
      {super.key,
      required this.vendorId,
      this.period,
      this.date,
      this.selectedDay});
  @override
  ConsumerState<OwnerVendorBonusScreen> createState() => _VendorBonusState();
}

class _VendorBonusState extends ConsumerState<OwnerVendorBonusScreen> {
  late String _period =
      _periods.contains(widget.period) ? widget.period! : 'week';
  late DateTime _day =
      _parseDay(widget.date) ?? businessDate(ref.read(clockProvider)());

  VendorBonusKey get _key =>
      (vendor: widget.vendorId, period: _period, date: moneyDateKey(_day));

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (!_isOwner(ref)) return _notAllowed(context, s, s.bonusTitle);
    final value = ref.watch(ownerVendorBonusProvider(_key));
    final name = value.valueOrNull?.vendor.name ?? '';
    final selectedDate = _parseDay(widget.selectedDay);
    final selectedBonusDay = value.valueOrNull?.days
        .where((d) => d.businessDate == selectedDate)
        .firstOrNull;
    final stationName = selectedBonusDay?.station?.name;
    final subtitle = selectedDate == null
        ? s.bonusEarnings
        : [
            if (stationName != null) stationName,
            if (name.isNotEmpty) name,
          ].join(' · ');
    return OwnerPage(
        title: selectedDate == null
            ? (name.isEmpty ? s.bonusTitle : name)
            : s.date(selectedDate),
        subtitle: Text(subtitle,
            style: OwnerStyle.text(context, 16, color: OwnerStyle.muted)),
        headingSize: 26,
        contentGap: 8,
        strings: s,
        onRefresh: () => ref.refresh(ownerVendorBonusProvider(_key).future),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (selectedDate == null)
            _PeriodBar(
                period: _period,
                day: _day,
                onPeriod: (p) => setState(() => _period = p),
                onDay: (d) => setState(() => _day = d)),
          _gap(context),
          Padding(
              padding: _pad(context),
              child: OwnerAsyncView(
                  value: value,
                  onRetry: () => ref.invalidate(ownerVendorBonusProvider(_key)),
                  loadingRows: 3,
                  data: (v) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: selectedDate == null
                          ? [
                              _VendorEarningsSummary(bonus: v),
                              _gap(context),
                              if (v.days.any((d) => !d.profitKnown)) ...[
                                OwnerCard(
                                    child: OwnerMenuRow(
                                        label: s.bonusProfitMissingDays(v.days
                                            .where((d) => !d.profitKnown)
                                            .length),
                                        leading: const MNIcon(MNIconData.info,
                                            size: 20, color: OwnerStyle.muted),
                                        onTap: () => context.push(MNRoutes
                                            .officePerformanceSettings))),
                                _gap(context),
                              ],
                              OwnerCard(
                                  child: OwnerMenuRow(
                                      label: s.bonusPay,
                                      subtitle: s.bonusPayCaption,
                                      leading: const MNIcon(
                                          MNIconData.accountWallet,
                                          size: 24,
                                          color: OwnerStyle.muted),
                                      onTap: () => context.push(
                                          MNRoutes.officeVendorPay(
                                              widget.vendorId)))),
                              _gap(context, 20),
                              Text(s.bonusDays, style: _title(context)),
                              _gap(context, 8),
                              if (v.days.isEmpty)
                                MNNote(s.bonusNone, tone: MNNoteTone.info)
                              else
                                _VendorBonusDays(
                                    vendorId: widget.vendorId,
                                    period: _period,
                                    date: moneyDateKey(_day),
                                    days: v.days),
                            ]
                          : selectedBonusDay == null
                              ? [MNNote(s.bonusNone, tone: MNNoteTone.info)]
                              : [_BonusDayDetail(day: selectedBonusDay)]))),
        ]));
  }
}

class _VendorEarningsSummary extends ConsumerWidget {
  final OwnerVendorBonus bonus;
  const _VendorEarningsSummary({required this.bonus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lockedDays = bonus.days.where((day) => day.locked).toList();
    final chickens =
        lockedDays.fold<num>(0, (total, day) => total + day.chickens);
    final chickenBonus =
        lockedDays.fold<int>(0, (total, day) => total + day.chickenBonus);
    final profitBonus =
        lockedDays.fold<int>(0, (total, day) => total + day.profitBonus);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.bonusEarnedStatus, style: _meta(context)),
      _gap(context, 2),
      Text(formatTsh(bonus.earned),
          style: OwnerStyle.text(context, 32, weight: 700)),
      Text(s.bonusPayableEarned, style: _meta(context)),
      if (bonus.adjustments != 0) ...[
        _gap(context, 4),
        Text(s.bonusAdjustments(_signedTsh(bonus.adjustments)),
            style: _meta(context)),
      ],
      _gap(context, 12),
      const Divider(height: 1, color: OwnerStyle.line),
      _MetricGrid(rows: [
        [
          (
            s.bonusVerifiedChickens,
            s.bonusChickenCount(_plain(chickens)),
            null
          ),
          (s.bonusChickenPartShort, formatTsh(chickenBonus), null),
        ],
        [
          (s.bonusProfitPartShort, formatTsh(profitBonus), null),
          (
            s.bonusEstimatedStatus,
            formatTsh(bonus.estimated),
            OwnerStyle.muted
          ),
        ],
      ]),
    ]));
  }
}

class _MetricGrid extends StatelessWidget {
  final List<List<(String, String, Color?)>> rows;
  const _MetricGrid({required this.rows});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: OwnerStyle.line),
          Row(children: [
            Expanded(
                child: _Metric(
                    label: rows[i][0].$1,
                    value: rows[i][0].$2,
                    valueColor: rows[i][0].$3)),
            Container(width: 1, height: 66, color: OwnerStyle.line),
            Expanded(
                child: _Metric(
                    label: rows[i][1].$1,
                    value: rows[i][1].$2,
                    valueColor: rows[i][1].$3)),
          ]),
        ],
      ]);
}

class _Metric extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _Metric({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: OwnerStyle.px(context, 10),
          vertical: OwnerStyle.px(context, 12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _meta(context)),
        _gap(context, 3),
        Text(value,
            style: OwnerStyle.text(context, 17,
                weight: 600, color: valueColor ?? OwnerStyle.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]));
}

class _VendorBonusDays extends ConsumerStatefulWidget {
  final String vendorId, period, date;
  final List<OwnerBonusDay> days;
  const _VendorBonusDays(
      {required this.vendorId,
      required this.period,
      required this.date,
      required this.days});

  @override
  ConsumerState<_VendorBonusDays> createState() => _VendorBonusDaysState();
}

class _VendorBonusDaysState extends ConsumerState<_VendorBonusDays> {
  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final count = math.min(_limit, widget.days.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerCard(
          child: Column(children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const Divider(height: 1, color: OwnerStyle.line),
          _VendorBonusDayRow(
              vendorId: widget.vendorId,
              period: widget.period,
              date: widget.date,
              day: widget.days[i]),
        ],
      ])),
      if (widget.days.length > _limit) ...[
        _gap(context),
        MNButton.secondary(s.moreRows,
            onPressed: () => setState(() => _limit += _pageSize)),
      ],
    ]);
  }
}

class _VendorBonusDayRow extends ConsumerWidget {
  final String vendorId, period, date;
  final OwnerBonusDay day;
  const _VendorBonusDayRow(
      {required this.vendorId,
      required this.period,
      required this.date,
      required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final d = day;
    final date = d.businessDate == null ? '—' : s.date(d.businessDate!);
    final station = d.station;
    final dayKey =
        d.businessDate == null ? null : moneyDateKey(d.businessDate!);
    return InkWell(
        key: dayKey == null ? null : ValueKey('bonus-day-$dayKey'),
        onTap: dayKey == null
            ? null
            : () => context.push(MNRoutes.officeVendorBonus(vendorId,
                period: period, date: this.date, day: dayKey)),
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: OwnerStyle.px(context, 78)),
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
                        Text(station == null ? date : '$date · ${station.name}',
                            style: _title(context)),
                        _gap(context, 4),
                        Text(
                            '${d.locked ? s.bonusEarnedStatus : s.bonusEstimatedStatus} · ${s.bonusChickenCount(_plain(d.chickens))}',
                            style: _meta(context)),
                      ])),
                  SizedBox(width: OwnerStyle.px(context, 8)),
                  Text(formatTsh(d.total),
                      style: OwnerStyle.text(context, 15,
                          weight: 600,
                          color: d.locked ? OwnerStyle.ink : OwnerStyle.muted)),
                  SizedBox(width: OwnerStyle.px(context, 10)),
                  const OwnerGlyph('vendor-chevron', size: 14),
                ]))));
  }
}

class _BonusDayDetail extends ConsumerWidget {
  final OwnerBonusDay day;
  const _BonusDayDetail({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final station = day.station;
    final status = day.locked ? s.bonusEarnedStatus : s.bonusEstimatedStatus;
    final statusColor = day.locked ? MNColors.success : OwnerStyle.muted;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.bonusDailyEarnings, style: _title(context)),
      _gap(context, 12),
      _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(status, style: _meta(context)),
        _gap(context, 2),
        Text(formatTsh(day.total),
            style:
                OwnerStyle.text(context, 32, weight: 700, color: statusColor)),
        if (!day.locked)
          Text(s.bonusEstimatedNotPayable, style: _meta(context)),
      ])),
      _gap(context),
      _Card(
          child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 16)),
              child: Column(children: [
                _BonusValueRow(
                    label: s.bonusVerifiedChickens,
                    value: s.bonusChickenCount(_plain(day.chickens))),
                const Divider(height: 1, color: OwnerStyle.line),
                _BonusValueRow(
                    label: s.bonusChickenPartShort,
                    value: formatTsh(day.chickenBonus)),
                const Divider(height: 1, color: OwnerStyle.line),
                _BonusValueRow(
                    label: s.bonusProfitPartShort,
                    value: formatTsh(day.profitBonus)),
                const Divider(height: 1, color: OwnerStyle.line),
                _BonusValueRow(
                    label: s.bonusOverallStatus,
                    value: status,
                    valueColor: statusColor),
                if (day.adjustments != 0) ...[
                  const Divider(height: 1, color: OwnerStyle.line),
                  _BonusValueRow(
                      label: s.bonusAdjustments(_signedTsh(day.adjustments)),
                      value: _signedTsh(day.adjustments)),
                ],
              ]))),
      if (day.shared || day.usedStandardCost) ...[
        _gap(context, 8),
        if (day.shared)
          Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 6)),
              child: Text(s.bonusShared(day.vendorsSharing),
                  style: _meta(context))),
        if (day.usedStandardCost)
          Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 6)),
              child: Text(s.bonusStandardCost, style: _meta(context))),
      ],
      if (!day.profitKnown) ...[
        _gap(context),
        _Card(
            child: Padding(
                padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MNIcon(MNIconData.info,
                          size: 20, color: OwnerStyle.muted),
                      SizedBox(width: OwnerStyle.px(context, 12)),
                      Expanded(
                          child: Text(s.bonusProfitCannotConfirm,
                              style: _body(context))),
                    ]))),
      ],
      if (station != null && day.businessDate != null) ...[
        _gap(context, 18),
        Text(s.bonusRecords, style: _title(context)),
        _gap(context, 8),
        OwnerCard(
            child: OwnerMenuRow(
                label: s.bonusVerifiedSales,
                onTap: () => context.push(MNRoutes.officeVerifiedSales(
                    station.id,
                    date: moneyDateKey(day.businessDate!))))),
      ],
      if (!day.locked) ...[
        _gap(context, 12),
        Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 6)),
            child: Text(s.bonusDayReviewOnly, style: _meta(context))),
      ],
    ]);
  }
}

class _BonusValueRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _BonusValueRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: BoxConstraints(minHeight: OwnerStyle.px(context, 55)),
      child: Padding(
          padding: EdgeInsets.symmetric(vertical: OwnerStyle.px(context, 10)),
          child: Row(children: [
            Expanded(child: Text(label, style: _body(context))),
            SizedBox(width: OwnerStyle.px(context, 8)),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: OwnerStyle.text(context, 15,
                        weight: 600, color: valueColor ?? OwnerStyle.ink))),
          ])));
}
// Verified sales and the owner's correction ----------------------------------------------

class OwnerVerifiedSalesScreen extends ConsumerStatefulWidget {
  final String stationId;
  final String? date;
  const OwnerVerifiedSalesScreen(
      {super.key, required this.stationId, this.date});
  @override
  ConsumerState<OwnerVerifiedSalesScreen> createState() =>
      _VerifiedSalesState();
}

class _VerifiedSalesState extends ConsumerState<OwnerVerifiedSalesScreen> {
  late DateTime _day =
      _parseDay(widget.date) ?? businessDate(ref.read(clockProvider)());

  VerifiedSalesKey get _key =>
      (station: widget.stationId, date: moneyDateKey(_day));

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (!_isOwner(ref)) return _notAllowed(context, s, s.bonusVerifiedSales);
    final today = businessDate(ref.read(clockProvider)());
    final value = ref.watch(ownerVerifiedSalesProvider(_key));
    return OwnerPage(
        title: s.bonusVerifiedSales,
        strings: s,
        onRefresh: () => ref.refresh(ownerVerifiedSalesProvider(_key).future),
        child: Padding(
            padding: _pad(context),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MNFieldButton(
                      label: s.bonusDate,
                      text: s.date(_day),
                      placeholder: s.date(_day),
                      icon: MNIconData.calendar,
                      onTap: () async {
                        final picked = await showMNDateSheet(context,
                            title: s.bonusDate,
                            initial: _day,
                            first: DateTime.utc(today.year - 2),
                            last: today);
                        if (picked != null && mounted) {
                          setState(() => _day = DateTime.utc(
                              picked.year, picked.month, picked.day));
                        }
                      }),
                  _gap(context),
                  OwnerAsyncView(
                      value: value,
                      onRetry: () =>
                          ref.invalidate(ownerVerifiedSalesProvider(_key)),
                      isEmpty: (rows) => rows.isEmpty,
                      empty: (_) =>
                          MNNote(s.noVerifiedSales, tone: MNNoteTone.info),
                      data: (rows) => _Paged(
                          count: rows.length,
                          itemBuilder: (_, i) => _VerifiedSaleCard(
                              sale: rows[i], salesKey: _key))),
                ])));
  }
}

class _VerifiedSaleCard extends ConsumerWidget {
  final OfficeSale sale;
  final VerifiedSalesKey salesKey;
  const _VerifiedSaleCard({required this.sale, required this.salesKey});

  Future<void> _correct(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => CorrectSaleSheet(saleId: sale.saleId));
    if (done != true) return;
    ref.invalidate(ownerVerifiedSalesProvider(salesKey));
    ref.invalidate(ownerBonusesProvider);
    ref.invalidate(ownerVendorBonusProvider);
    if (context.mounted) _toast(context, s.correctSaleDone);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final time =
        sale.recordedAt == null ? '—' : s.hhmm(eatClock(sale.recordedAt!));
    final products = sale.lines.isEmpty
        ? sale.product
        : sale.lines.map((l) => '${_plain(l.quantity)} × ${l.name}').join(', ');
    final vendor = sale.vendorCode == null
        ? sale.vendorName
        : '${sale.vendorName} · ${sale.vendorCode}';
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$time · ${formatTsh(sale.amount)}',
          style: OwnerStyle.text(context, 15,
              weight: 600,
              color: sale.voided ? OwnerStyle.muted : OwnerStyle.ink)),
      Text(vendor, style: _body(context)),
      if (products.isNotEmpty) Text(products, style: _meta(context)),
      if (sale.autoVerified && !sale.voided)
        Text(s.autoVerifiedLabel, style: _status(context, OwnerStyle.muted)),
      if (sale.voided)
        Text(s.correctedSale, style: _status(context, OwnerStyle.muted))
      else if (sale.verified && sale.saleId.isNotEmpty) ...[
        _gap(context, 8),
        MNButton.secondary(s.correctSale,
            onPressed: () => _correct(context, ref)),
      ],
    ]));
  }
}

/// The owner's reason for correcting a verified sale; pops true once the
/// server has corrected it.
class CorrectSaleSheet extends ConsumerStatefulWidget {
  final String saleId;
  const CorrectSaleSheet({super.key, required this.saleId});
  @override
  ConsumerState<CorrectSaleSheet> createState() => _CorrectSaleState();
}

class _CorrectSaleState extends ConsumerState<CorrectSaleSheet> {
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
      await ownerBonusesCall(
          ref, (r) => r.correctSale(widget.saleId, reason: reason));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = officeErrorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.correctSale, children: [
      MNNote(s.correctSaleWarning, tone: MNNoteTone.warning),
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.correctSale, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
