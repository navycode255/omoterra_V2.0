import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pressable.dart';
import '../office/owner_overview.dart'
    show ownerDayProvider, ownerMoneyKey, ownerMoneyOverviewProvider;
import '../office/owner_reference.dart';

/// Mapato na matumizi: income and expenses for all stations and for each
/// station, and the expense categories that cost the most. Owner only.
class OwnerMoneyReportScreen extends ConsumerStatefulWidget {
  const OwnerMoneyReportScreen({super.key});
  @override
  ConsumerState<OwnerMoneyReportScreen> createState() =>
      _OwnerMoneyReportScreenState();
}

class _OwnerMoneyReportScreenState
    extends ConsumerState<OwnerMoneyReportScreen> {
  OwnerPeriod _period = OwnerPeriod.day;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final owner = auth is OfficeSignedIn && auth.profile.isOwner;
    double u(double n) => OwnerStyle.px(context, n);
    return OwnerPage(
        title: s.reportMoneyTitle,
        strings: s,
        onRefresh: owner
            ? () => ref.refresh(
                ownerMoneyOverviewProvider(ownerMoneyKey(ref, _period)).future)
            : null,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: u(13)),
            child: !owner
                ? MNNote(s.notAllowed)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        _PeriodSwitch(
                            strings: s,
                            today: ref.watch(ownerDayProvider) == null,
                            selected: _period,
                            onSelect: (p) => setState(() => _period = p)),
                        SizedBox(height: u(14)),
                        OwnerAsyncView<OwnerMoneyOverview>(
                            value: ref.watch(ownerMoneyOverviewProvider(
                                ownerMoneyKey(ref, _period))),
                            onRetry: () => ref.invalidate(
                                ownerMoneyOverviewProvider(
                                    ownerMoneyKey(ref, _period))),
                            loadingRows: 4,
                            data: (data) => _Report(data: data, strings: s)),
                      ])));
  }
}

class _PeriodSwitch extends StatelessWidget {
  final Strings strings;
  final OwnerPeriod selected;
  final ValueChanged<OwnerPeriod> onSelect;

  /// False when Muhtasari chose another day: the day tab is not "Leo".
  final bool today;
  const _PeriodSwitch(
      {required this.strings,
      required this.selected,
      required this.onSelect,
      this.today = true});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    String label(OwnerPeriod p) => switch (p) {
          OwnerPeriod.day =>
            today ? strings.reportPeriodDay : strings.reportPeriodChosenDay,
          OwnerPeriod.week =>
            today ? strings.reportPeriodWeek : strings.reportPeriodChosenWeek,
          OwnerPeriod.month =>
            today ? strings.reportPeriodMonth : strings.reportPeriodChosenMonth,
        };
    return OwnerCard(
        radius: 10,
        child: Padding(
            padding: EdgeInsets.all(u(4)),
            child: Row(children: [
              for (final p in OwnerPeriod.values)
                Expanded(
                    child: MNPressable(
                        onTap: () => onSelect(p),
                        pressedScale: 1,
                        color:
                            p == selected ? OwnerStyle.ink : OwnerStyle.white,
                        borderRadius: BorderRadius.circular(u(8)),
                        semanticLabel: label(p),
                        selected: p == selected,
                        child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            child: ExcludeSemantics(
                                child: Text(label(p),
                                    style: OwnerStyle.text(context, 15,
                                        weight: 500,
                                        color: p == selected
                                            ? OwnerStyle.white
                                            : OwnerStyle.ink)))))),
            ])));
  }
}

String _range(OwnerMoneyOverview data) {
  String day(DateTime d) => '${d.day}/${d.month}/${d.year}';
  final from = data.from, to = data.to;
  if (from == null || to == null) return '';
  return from == to ? day(from) : '${day(from)} – ${day(to)}';
}

String _signed(int value) =>
    value < 0 ? '−${groupDigits(-value)}' : groupDigits(value);

class _Report extends StatelessWidget {
  final OwnerMoneyOverview data;
  final Strings strings;
  const _Report({required this.data, required this.strings});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    double u(double n) => OwnerStyle.px(context, n);
    Widget heading(String text) => Padding(
        padding: EdgeInsets.fromLTRB(u(6), u(22), u(6), u(8)),
        child: Semantics(
            header: true,
            child: Text(text,
                style:
                    OwnerStyle.text(context, 20, weight: 700, spacing: -.6))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.only(left: u(6), bottom: u(8)),
          child: Text(_range(data),
              style: OwnerStyle.text(context, 14, color: OwnerStyle.muted))),
      _TotalsCard(title: s.reportAllStations, figures: data.totals, strings: s),
      Padding(
          padding: EdgeInsets.fromLTRB(u(6), u(8), u(6), 0),
          child: Text(s.reportBalanceNote,
              style: OwnerStyle.text(context, 12.5, color: OwnerStyle.muted))),
      heading(s.reportTopExpenses),
      OwnerCard(
          radius: 10,
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: u(6)),
              child: _CategoryList(categories: data.categories, strings: s))),
      heading(s.reportByStation),
      if (data.stations.isEmpty)
        MNNote(s.reportNoStations)
      else
        for (final station in data.stations) ...[
          _StationCard(station: station, strings: s),
          SizedBox(height: u(10)),
        ],
    ]);
  }
}

class _TotalsCard extends StatelessWidget {
  final String title;
  final OwnerMoneyFigures figures;
  final Strings strings;
  const _TotalsCard(
      {required this.title, required this.figures, required this.strings});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    double u(double n) => OwnerStyle.px(context, n);
    return OwnerCard(
        radius: 10,
        child: Padding(
            padding: EdgeInsets.all(u(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$title · ${s.reportIncome}',
                  style: OwnerStyle.text(context, 16, color: OwnerStyle.muted)),
              SizedBox(height: u(6)),
              Row(children: [
                Text(s.ownerCurrency,
                    style: OwnerStyle.text(context, 19,
                        weight: 700, spacing: -.7)),
                SizedBox(width: u(10)),
                Expanded(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(groupDigits(figures.sales),
                            style: OwnerStyle.text(context, 41,
                                weight: 500, spacing: -1.5)))),
              ]),
              Text(s.reportVerified(groupDigits(figures.verifiedSales)),
                  style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
              SizedBox(height: u(16)),
              const Divider(height: 1, thickness: .7, color: OwnerStyle.line),
              SizedBox(height: u(15)),
              IntrinsicHeight(
                  child: Row(children: [
                Expanded(
                    child: _Figure(
                        label: s.reportExpenses,
                        value: groupDigits(figures.expenses))),
                Container(width: .7, color: OwnerStyle.line),
                Expanded(
                    child: Padding(
                        padding: EdgeInsets.only(left: u(22)),
                        child: _Figure(
                            label: s.reportBalance,
                            value: _signed(figures.balance),
                            negative: figures.balance < 0))),
              ])),
              if (figures.pendingExpenses > 0) ...[
                SizedBox(height: u(10)),
                Text(s.reportPending(groupDigits(figures.pendingExpenses)),
                    style:
                        OwnerStyle.text(context, 14, color: MNColors.warning)),
              ],
            ])));
  }
}

class _Figure extends StatelessWidget {
  final String label, value;
  final bool negative;
  final double size;
  const _Figure(
      {required this.label,
      required this.value,
      this.negative = false,
      this.size = 28});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: OwnerStyle.text(context, 15, color: OwnerStyle.muted)),
        SizedBox(height: OwnerStyle.px(context, 3.5)),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: OwnerStyle.text(context, size,
                    weight: 500,
                    spacing: -.8,
                    color: negative ? OwnerStyle.red : OwnerStyle.ink))),
      ]);
}

/// Categories largest first, each with a bar for its share of the spending.
class _CategoryList extends StatelessWidget {
  final List<OwnerExpenseCategory> categories;
  final Strings strings;
  const _CategoryList({required this.categories, required this.strings});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    if (categories.isEmpty) {
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: u(16), vertical: u(12)),
          child: Text(strings.reportNoExpenses,
              style: OwnerStyle.text(context, 15, color: OwnerStyle.muted)));
    }
    return Column(children: [
      for (final c in categories)
        Padding(
            padding: EdgeInsets.symmetric(horizontal: u(16), vertical: u(9)),
            child: Semantics(
                label: '${c.category}, ${groupDigits(c.amount)}, '
                    '${c.share.toStringAsFixed(1)}%',
                excludeSemantics: true,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: Text(c.category,
                            style: OwnerStyle.text(context, 16, weight: 500))),
                    Text(groupDigits(c.amount),
                        style: OwnerStyle.text(context, 16, weight: 500)),
                    SizedBox(
                        width: u(58),
                        child: Text('${c.share.toStringAsFixed(1)}%',
                            textAlign: TextAlign.end,
                            style: OwnerStyle.text(context, 14,
                                color: OwnerStyle.muted))),
                  ]),
                  SizedBox(height: u(7)),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(u(3)),
                      child: LinearProgressIndicator(
                          value: (c.share / 100).clamp(0, 1).toDouble(),
                          minHeight: u(6),
                          backgroundColor: OwnerStyle.line,
                          color: OwnerStyle.ink)),
                ]))),
    ]);
  }
}

/// One station's income, expenses and balance; tap to see its expenses.
class _StationCard extends StatefulWidget {
  final OwnerStationMoney station;
  final Strings strings;
  const _StationCard({required this.station, required this.strings});
  @override
  State<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<_StationCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final st = widget.station;
    final f = st.figures;
    double u(double n) => OwnerStyle.px(context, n);
    return OwnerCard(
        radius: 10,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MNPressable(
              onTap: () => setState(() => _open = !_open),
              pressedScale: 1,
              semanticLabel: st.name,
              selected: _open,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(u(16), u(14), u(16), u(14)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const OwnerGlyph('store', size: 22),
                          SizedBox(width: u(12)),
                          Expanded(
                              child: Text(
                                  st.code == null
                                      ? st.name
                                      : '${st.name} · ${st.code}',
                                  style: OwnerStyle.text(context, 17,
                                      weight: 500, spacing: -.55))),
                          AnimatedRotation(
                              turns: _open ? .25 : 0,
                              duration: MNMotion.small,
                              child: const OwnerGlyph('chevron', size: 12)),
                        ]),
                        SizedBox(height: u(12)),
                        Row(children: [
                          Expanded(
                              child: _Figure(
                                  label: s.reportIncome,
                                  value: groupDigits(f.sales),
                                  size: 19)),
                          Expanded(
                              child: _Figure(
                                  label: s.reportExpenses,
                                  value: groupDigits(f.expenses),
                                  size: 19)),
                          Expanded(
                              child: _Figure(
                                  label: s.reportBalance,
                                  value: _signed(f.balance),
                                  negative: f.balance < 0,
                                  size: 19)),
                        ]),
                        if (f.pendingExpenses > 0) ...[
                          SizedBox(height: u(8)),
                          Text(s.reportPending(groupDigits(f.pendingExpenses)),
                              style: OwnerStyle.text(context, 13.5,
                                  color: MNColors.warning)),
                        ],
                      ]))),
          AnimatedSize(
              duration: MNMotion.sheet,
              curve: MNMotion.easeOut,
              alignment: Alignment.topCenter,
              child: _open
                  ? Column(children: [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: u(16)),
                          child: const Divider(
                              height: 1,
                              thickness: .7,
                              color: OwnerStyle.line)),
                      Padding(
                          padding: EdgeInsets.fromLTRB(u(16), u(10), u(16), 0),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  s.reportVerified(
                                      groupDigits(f.verifiedSales)),
                                  style: OwnerStyle.text(context, 13.5,
                                      color: OwnerStyle.muted)))),
                      _CategoryList(categories: st.categories, strings: s),
                      SizedBox(height: u(6)),
                    ])
                  : const SizedBox(width: double.infinity)),
        ]));
  }
}
