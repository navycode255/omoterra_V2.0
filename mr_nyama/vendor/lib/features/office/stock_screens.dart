import 'owner_widgets.dart';
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
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/number_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'closing_case_screens.dart' show ClosingCasesRow;
import 'owner_reference.dart';
import 'station_screen.dart' show StationStockLinks, stationStockProvider;
import 'people_screens.dart' show officeErrorText, officeStationsProvider;
import 'product_screens.dart' show officeProductsProvider, ownerProductImage;

/// Station stock for supervisors, finance, operations and the owner: the
/// daily stock equation per vendor-day (computed by the server), returns
/// from a station to a kitchen or receiving store, re-confirming a day a
/// later entry reopened, resolving units left in transit after a short receipt, and the
/// owner's late-entry window. Nothing is shown as done until the server
/// answers; every refusal shows the server's words.

// Data ---------------------------------------------------------------------------------

/// Runs [work] with the stock side of the office API.
Future<T> officeStockCall<T>(OfficeSessionController session,
        Future<T> Function(OfficeStockRepository) work) =>
    session.guard((repo) {
      if (repo is! OfficeStockRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OfficeStockRepository);
    });

typedef StockRangeKey = ({String station, String from, String to});

final stockDaysProvider = FutureProvider.autoDispose
    .family<OfficeStockDays, StockRangeKey>((ref, k) => officeStockCall(
        ref.read(officeSessionProvider.notifier),
        (r) => r.stockDays(stationId: k.station, from: k.from, to: k.to)));

/// One meaning for every stock figure at a station. A repository without the
/// measures call (a test double) shows none, never invented figures.
final stockMeasuresProvider = FutureProvider.autoDispose
    .family<List<OfficeStockMeasure>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((repo) => repo is OfficeStockMeasuresRepository
            ? (repo as OfficeStockMeasuresRepository).stockMeasures(stationId)
            : Future.value(const <OfficeStockMeasure>[])));

final stockReturnsProvider = FutureProvider.autoDispose
    .family<List<OfficeStockReturn>, StockRangeKey>((ref, k) => officeStockCall(
        ref.read(officeSessionProvider.notifier),
        (r) => r.stockReturns(stationId: k.station, from: k.from, to: k.to)));

final stockLocationsProvider =
    FutureProvider.autoDispose<List<OfficeStockLocation>>((ref) =>
        officeStockCall(ref.read(officeSessionProvider.notifier),
            (r) => r.stockLocations()));

/// What the signed-in account may plausibly do. The server decides.
({bool view, bool returns, bool review, bool transitLoss, bool owner})
    stockAccess(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  bool any(Set<String> set) => roles.any(set.contains);
  return (
    // inventory.view
    view: any({
      StaffRole.supervisor,
      StaffRole.finance,
      StaffRole.operationsAdmin,
      StaffRole.owner
    }),
    // returns.record
    returns: any({StaffRole.supervisor, StaffRole.finance, StaffRole.owner}),
    // counts.review and receiving.manage
    review: any(StaffRole.stockReviewers),
    // adjustments.approve: a transit loss (interim until the value tiers).
    transitLoss: any({StaffRole.finance, StaffRole.owner}),
    owner: roles.contains(StaffRole.owner),
  );
}

// Formatting ---------------------------------------------------------------------------

String _qty(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

String _signed(num n) => n > 0
    ? '+${_qty(n)}'
    : n < 0
        ? '−${_qty(-n)}'
        : '0';

String _quantity(Strings s, num n, String unit) =>
    unit.isEmpty ? _qty(n) : '${_qty(n)} ${s.unitName(unit)}';

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

String _cost(Strings s, int? amount) =>
    amount == null ? s.costUnknown : s.costText(formatTsh(amount));

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c, {Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, 14, color: color);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

/// The plain status word for a stock day, in its status colour.
(String, Color) stockStatusWord(Strings s, OfficeStockDay d) => (
      s.stockStatusName(d.statusWire),
      switch (d.status) {
        StockDayStatus.reconciled => MNColors.success,
        StockDayStatus.discrepancy => MNColors.error,
        StockDayStatus.needsReconciliation => MNColors.warning,
        _ => OwnerStyle.muted,
      }
    );

/// Why a day cannot be confirmed yet, in words.
List<String> stockBlockerWords(Strings s, OfficeStockDay d) {
  final b = d.blockers;
  if (b == null) return const [];
  final previous = d.previousBusinessDate;
  return [
    if (b.unverifiedSales > 0) s.closingBlockedSales(b.unverifiedSales),
    if (b.pendingDamage > 0) s.closingBlockedDamage(b.pendingDamage),
    if (b.previousDayUnreconciled > 0)
      previous == null
          ? s.closingBlockedPreviousDay
          : s.stockBlockedPreviousDay(s.date(previous)),
  ];
}

// The station's stock screen -----------------------------------------------------------

class OfficeStockScreen extends ConsumerStatefulWidget {
  final String stationId;
  /// Opens scrolled to the deliveries links (`?section=deliveries`).
  final bool openDeliveries;
  const OfficeStockScreen(
      {super.key, required this.stationId, this.openDeliveries = false});
  @override
  ConsumerState<OfficeStockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<OfficeStockScreen> {
  final _linksKey = GlobalKey();
  bool _scrolled = false;
  late final DateTime _today = businessDate(ref.read(clockProvider)());

  late DateTime _from = _today.subtract(const Duration(days: 27));
  late DateTime _to = _today;

  StockRangeKey get _key => (
        station: widget.stationId,
        from: moneyDateKey(_from),
        to: moneyDateKey(_to),
      );

  Future<void> _refresh() async {
    ref.invalidate(stockReturnsProvider(_key));
    ref.invalidate(stockDaysProvider(_key));
    ref.invalidate(stationStockProvider);
    await ref.read(stockDaysProvider(_key).future);
  }

  Future<void> _period() async {
    final s = ref.read(stringsProvider);
    final picked = await showMNDateRangeSheet(context,
        start: _from,
        end: _to,
        first: DateTime.utc(2020),
        last: _today,
        title: s.stockChoosePeriod,
        titleStyle: OwnerStyle.text(context, 20, weight: 700));
    if (picked == null || !mounted) return;
    if (picked.$2.difference(picked.$1).inDays >= maxStockDaysRange) {
      _toast(context, s.stockPeriodLimit);
      return;
    }
    setState(() {
      _from = picked.$1;
      _to = picked.$2;
    });
  }

  void _details(String title, Widget child) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (detailContext) => OwnerPage(
            onBack: () => Navigator.of(detailContext).pop(),
            title: title,
            strings: ref.read(stringsProvider),
            child: Padding(padding: _pad(context), child: child))));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = stockAccess(ref);
    final station = ref
        .watch(officeStationsProvider)
        .valueOrNull
        ?.where((x) => x.id == widget.stationId)
        .firstOrNull;
    final key = _key;
    if (widget.openDeliveries && !_scrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _linksKey.currentContext;
        if (!mounted || _scrolled || target == null) return;
        _scrolled = true;
        Scrollable.ensureVisible(target,
            duration: Duration.zero, alignment: 0);
      });
    }
    final days = access.view ? ref.watch(stockDaysProvider(key)) : null;
    final returns = access.view ? ref.watch(stockReturnsProvider(key)) : null;
    final stock = access.view && station?.stockLocationId != null
        ? ref.watch(stationStockProvider(station!.stockLocationId!))
        : null;
    final available = stock?.valueOrNull;
    final positive = available
        ?.where((r) => (num.tryParse('${r['quantity']}') ?? 0) > 0)
        .toList();
    final canReturn = positive != null && positive.isNotEmpty;
    String summaryQuantity(num n, String unit) =>
        '${_qty(n)} ${unit == 'kg' ? 'kg' : s.unitName(unit).toLowerCase()}';
    final empty = days?.hasValue == true &&
        returns?.hasValue == true &&
        days!.value!.days.isEmpty &&
        returns!.value!.isEmpty;
    double u(double n) => OwnerStyle.px(context, n);
    Widget heading(String text) => Padding(
        padding: EdgeInsets.fromLTRB(u(3), u(24), 0, u(15)),
        child: Text(text, style: OwnerStyle.text(context, 17, weight: 600)));
    String short(DateTime d) => s.date(d).replaceFirst(' ${d.year}', '');
    final period = _from.year == _to.year
        ? '${short(_from)} – ${s.date(_to)}'
        : '${s.date(_from)} – ${s.date(_to)}';
    return OwnerPage(
      title: s.stockTitle,
      strings: s,
      headingSize: 36,
      contentGap: 25,
      subtitle: station == null
          ? null
          : Text(station.name,
              style: OwnerStyle.text(context, 18, color: OwnerStyle.muted)),
      onRefresh: access.view ? _refresh : null,
      bottom: !access.view || !access.returns
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(u(20), u(12), u(20), u(24)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MNButton(s.returnGoods,
                        onPressed: canReturn
                            ? () async {
                                await context.push(MNRoutes.officeStockReturn(
                                    widget.stationId));
                                ref.invalidate(stockDaysProvider);
                                ref.invalidate(stockReturnsProvider);
                                ref.invalidate(stationStockProvider);
                              }
                            : null),
                    if (!canReturn) ...[
                      _gap(context, 5),
                      Text(
                          stock?.hasError == true
                              ? s.payLoadFailed
                              : available == null
                                  ? s.unknownQuantity
                                  : s.stockNothingAvailable,
                          textAlign: TextAlign.center,
                          style: _meta(context)),
                    ],
                  ])),
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: u(20)),
          child: !access.view
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      MNNote(s.notAllowed),
                      if (station != null) ...[
                        SizedBox(height: u(24)),
                        StationStockLinks(station: station),
                      ],
                    ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      OwnerCard(
                          radius: 17,
                          child: MNPressable(
                              onTap: _period,
                              semanticLabel: s.stockChoosePeriod,
                              child: Padding(
                                  padding: EdgeInsets.all(u(16)),
                                  child: Row(children: [
                                    MNIcon(MNIconData.calendar,
                                        size: u(23), color: OwnerStyle.muted),
                                    SizedBox(width: u(12)),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(period, style: _title(context)),
                                          _gap(context, 3),
                                          Text(s.stockChoosePeriod,
                                              style: _meta(context)),
                                        ])),
                                    const OwnerGlyph('chevron',
                                        size: 10, color: OwnerStyle.muted),
                                  ])))),
                      // Days nobody counted (MN031); only while there are some.
                      if (station != null)
                        ClosingCasesRow(stationId: station.id, card: true),
                      if (station != null) ...[
                        heading(s.measuresHeading),
                        OwnerAsyncView(
                            value: ref.watch(stockMeasuresProvider(station.id)),
                            onRetry: () => ref
                                .invalidate(stockMeasuresProvider(station.id)),
                            data: (rows) => rows.isEmpty
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final r in rows) ...[
                                        _MeasureCard(measure: r, strings: s),
                                        _gap(context, 12),
                                      ],
                                      OwnerHelp(
                                          title: s.measuresHelpTitle,
                                          message: s.measuresHelp),
                                    ])),
                      ],
                      if (empty)
                        SizedBox(
                            height: MediaQuery.sizeOf(context).height * .43,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MNIcon(MNIconData.box,
                                      size: u(44), color: OwnerStyle.secondary),
                                  _gap(context, 27),
                                  Text(s.stockNoRecords,
                                      style: OwnerStyle.text(context, 19,
                                          weight: 600),
                                      textAlign: TextAlign.center),
                                  _gap(context, 18),
                                  Text(s.stockRecordsHint,
                                      style: _body(context,
                                          color: OwnerStyle.muted),
                                      textAlign: TextAlign.center),
                                ]))
                      else ...[
                        if (days?.valueOrNull?.days.isNotEmpty != false ||
                            days?.hasError == true) ...[
                          heading(s.stockDailyCounts),
                          OwnerAsyncView(
                              value: days!,
                              onRetry: () =>
                                  ref.invalidate(stockDaysProvider(key)),
                              data: (v) => _summaryGroup([
                                    for (final d in v.days.reversed)
                                      _summaryRow(context,
                                          title: d.businessDate == null
                                              ? '—'
                                              : '${s.weekdayName(d.businessDate!.weekday)}, ${short(d.businessDate!)}',
                                          subtitle: d.closingId == null
                                              ? s.stockStillOpen
                                              : stockStatusWord(s, d).$1,
                                          value: d.closingId == null
                                              ? '${d.products.where((p) => p.counted != null).length}/${d.products.length}'
                                              : s.stockKinds(d.products.length),
                                          onTap: () => _details(
                                              s.stockDailyCounts,
                                              StockDayCard(
                                                  day: d,
                                                  review: access.review,
                                                  onChanged: () =>
                                                      ref.invalidate(
                                                          stockDaysProvider)))),
                                  ])),
                        ],
                        if (returns?.valueOrNull?.isNotEmpty != false ||
                            returns?.hasError == true) ...[
                          heading(s.stockOfficeReturns),
                          OwnerAsyncView(
                              value: returns!,
                              onRetry: () =>
                                  ref.invalidate(stockReturnsProvider(key)),
                              data: (rows) => _summaryGroup([
                                    for (final r in rows)
                                      for (final l in r.lines)
                                        _summaryRow(context,
                                            title:
                                                '${r.businessDate == null ? '—' : short(r.businessDate!)} · ${l.name}',
                                            subtitle: s.stockReceivedOffice,
                                            value: summaryQuantity(
                                                l.quantity, l.unit),
                                            onTap: () => _details(s.returnGoods,
                                                StockReturnCard(row: r))),
                                  ])),
                        ],
                      ],
                      if (station != null) ...[
                        SizedBox(height: u(24)),
                        KeyedSubtree(
                            key: _linksKey,
                            child: StationStockLinks(station: station)),
                      ],
                    ])),
    );
  }

  Widget _summaryGroup(List<Widget> rows) => OwnerCard(
      radius: 17,
      child: Column(children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0)
            Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: OwnerStyle.px(context, 16)),
                child: const Divider(height: 1, color: OwnerStyle.line)),
          row,
        ]
      ]));

  Widget _summaryRow(BuildContext context,
          {required String title,
          required String subtitle,
          required String value,
          required VoidCallback onTap}) =>
      MNPressable(
          onTap: onTap,
          child: Padding(
              padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: OwnerStyle.text(context, 16, weight: 500)),
                      _gap(context, 8),
                      Text(subtitle, style: _meta(context)),
                    ])),
                SizedBox(width: OwnerStyle.px(context, 12)),
                Text(value, style: OwnerStyle.text(context, 14, weight: 600)),
                SizedBox(width: OwnerStyle.px(context, 16)),
                const OwnerGlyph('chevron',
                    size: 9, color: OwnerStyle.secondary),
              ])));
}

/// One vendor-day: status, why it is blocked, what reopened it, and its
/// products (expandable rows).
class StockDayCard extends ConsumerStatefulWidget {
  final OfficeStockDay day;
  final bool review;
  final VoidCallback onChanged;
  const StockDayCard(
      {super.key,
      required this.day,
      required this.review,
      required this.onChanged});
  @override
  ConsumerState<StockDayCard> createState() => _StockDayCardState();
}

class _StockDayCardState extends ConsumerState<StockDayCard> {
  bool _open = false;
  bool _busy = false;
  String? _error;
  final _openRows = <String>{};

  Future<void> _confirmAgain() async {
    final id = widget.day.closingId;
    if (_busy || id == null) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => r.confirmClosing(id));
      if (mounted) _toast(context, s.stockConfirmedAgain);
      widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final d = widget.day;
    final word = stockStatusWord(s, d);
    final blockers = stockBlockerWords(s, d);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(d.businessDate == null ? '—' : s.date(d.businessDate!),
          style: _title(context)),
      if (d.vendorName.isNotEmpty) Text(d.vendorName, style: _body(context)),
      _gap(context, 4),
      Text(word.$1, style: _status(context, word.$2)),
      if (blockers.isNotEmpty)
        Text('${s.closingBlocked} ${blockers.join(', ')}',
            style: _body(context, color: MNColors.warning)),
      for (final r in d.reopenedBy)
        Text(
            s.stockReopenedBy(
                s.movementName(r.movementType),
                r.businessDate == null ? '—' : s.date(r.businessDate!),
                _when(s, r.at ?? r.occurredAt)),
            style: _body(context, color: MNColors.warning)),
      if (d.canConfirmAgain && widget.review) ...[
        _gap(context),
        MNNote(s.stockConfirmAgainHelp, tone: MNNoteTone.info),
        if (_error != null) ...[
          _gap(context, 8),
          MNNote(_error!, error: true),
        ],
        _gap(context, 8),
        MNButton(s.stockConfirmAgain,
            busy: _busy,
            onPressed:
                _busy || (d.blockers?.any ?? false) ? null : _confirmAgain),
      ],
      if (d.products.isNotEmpty)
        Align(
            alignment: Alignment.centerLeft,
            child: MNTextButton(
                _open ? s.stockHideProducts : s.stockShowProducts,
                onPressed: () => setState(() => _open = !_open))),
      if (_open)
        for (final p in d.products) ...[
          const Divider(height: 1, thickness: .6, color: OwnerStyle.line),
          _ProductRow(
              product: p,
              open: _openRows.contains(p.productId + p.productCode),
              onToggle: () => setState(() {
                    final k = p.productId + p.productCode;
                    _openRows.contains(k)
                        ? _openRows.remove(k)
                        : _openRows.add(k);
                  })),
        ],
    ]));
  }
}

class _ProductRow extends ConsumerWidget {
  final StockDayProduct product;
  final bool open;
  final VoidCallback onToggle;
  const _ProductRow(
      {required this.product, required this.open, required this.onToggle});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final p = product;
    final d = p.difference;
    final color = d == null || d == 0
        ? OwnerStyle.muted
        : d < 0
            ? MNColors.error
            : MNColors.warning;
    Widget fact(String label, String value, {Color? valueColor}) => Padding(
        padding: EdgeInsets.only(top: OwnerStyle.px(context, 4)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: _meta(context))),
          SizedBox(width: OwnerStyle.px(context, 8)),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: valueColor == null
                      ? _body(context)
                      : _status(context, valueColor))),
        ]));
    return InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
                padding:
                    EdgeInsets.symmetric(vertical: OwnerStyle.px(context, 10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(p.name, style: _body(context)),
                      Text(
                          d == null
                              ? '${s.stockExpected} ${_quantity(s, p.expected, p.unit)} · ${s.stockNotCounted}'
                              : '${s.stockExpected} ${_qty(p.expected)} · ${s.stockDifference} ${_signed(d)}',
                          style: d == null
                              ? _meta(context)
                              : _status(context, color)),
                      if (open) ...[
                        fact(s.stockOpening, _qty(p.opening)),
                        fact(s.stockReceived, _qty(p.received)),
                        fact(s.stockSold, _qty(p.sold)),
                        fact(s.stockReturned, _qty(p.returned)),
                        fact(s.stockLost, _qty(p.lost)),
                        fact(s.stockMovedOut, _qty(p.movedOut)),
                        fact(s.stockExpected, _quantity(s, p.expected, p.unit)),
                        fact(
                            s.stockCounted,
                            p.counted == null
                                ? s.stockNotCounted
                                : _quantity(s, p.counted!, p.unit)),
                        if (p.cutPieces > 0)
                          fact(s.stockCutPieces, _qty(p.cutPieces)),
                        if (d != null)
                          fact(s.stockDifference, _signed(d),
                              valueColor: color),
                      ],
                    ]))));
  }
}

/// A recorded return as the server answered it.
class StockReturnCard extends ConsumerWidget {
  final OfficeStockReturn row;
  const StockReturnCard({super.key, required this.row});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(row.businessDate == null ? '—' : s.date(row.businessDate!),
          style: _title(context)),
      Text(s.returnedTo(row.destinationName), style: _body(context)),
      for (final l in row.lines)
        Text('${_quantity(s, l.quantity, l.unit)} × ${l.name}',
            style: _body(context)),
      if (row.reason.isNotEmpty)
        Text(s.reasonText(row.reason), style: _meta(context)),
      Text(_cost(s, row.cost), style: _meta(context)),
    ]));
  }
}

// Return form --------------------------------------------------------------------------

class _ReturnLine {
  final String product;
  int quantity = 1;
  _ReturnLine(this.product);
}

class OfficeStockReturnScreen extends ConsumerStatefulWidget {
  final String stationId;
  const OfficeStockReturnScreen({super.key, required this.stationId});
  @override
  ConsumerState<OfficeStockReturnScreen> createState() => _ReturnFormState();
}

class _ReturnFormState extends ConsumerState<OfficeStockReturnScreen> {
  static const _max = 1000000;

  /// One id per return: a retry after no answer sends the same id and body.
  String _clientId = const Uuid().v4();
  late final DateTime _today = businessDate(ref.read(clockProvider)());
  late DateTime _day = _today;
  String? _destination;
  final _lines = <_ReturnLine>[];
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  /// The body sent and not answered: retried unchanged.
  ({
    String destination,
    String date,
    String reason,
    List<ReturnLineDraft> lines
  })? _pending;
  OfficeStockReturn? _saved;

  bool get _locked => _busy || _pending != null;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _addProduct(Strings s, List<OfficeProduct> products) async {
    final picked = await showMNSelectSheet<String>(context,
        title: s.officeChooseProduct,
        emptyText: s.noOfficeProducts,
        options: [
          for (final p in products.where((p) => p.status == 'active'))
            MNSelectOption(
                value: p.code,
                label: p.name,
                image: ownerProductImage(p),
                enabled: !_lines.any((l) => l.product == p.code),
                caption: _lines.any((l) => l.product == p.code)
                    ? s.officeAlreadyAdded
                    : s.unitName(p.unit)),
        ]);
    if (picked != null && mounted) {
      setState(() {
        _lines.add(_ReturnLine(picked.value));
        _error = null;
      });
    }
  }

  Future<void> _review(Strings s, String destinationName,
      Map<String, OfficeProduct> byCode) async {
    if (_pending == null) {
      final reason = _reason.text.trim();
      if (_destination == null ||
          _lines.isEmpty ||
          _lines.length > 200 ||
          reason.length < 3 ||
          reason.length > 500 ||
          _lines.any((l) => l.quantity <= 0 || l.quantity > _max)) {
        setState(() => _error = s.detailsInvalid);
        return;
      }
      final yes = await showMNSheet<bool>(context,
          builder: (sheet) => MNSheet(title: s.reviewBeforeSending, children: [
                Text(s.returnSummary(destinationName, s.date(_day)),
                    style: MNText.resolve(context, MNText.body)),
                for (final l in _lines)
                  Text(
                      '${_quantity(s, l.quantity, byCode[l.product]?.unit ?? '')} × ${byCode[l.product]?.name ?? l.product}',
                      style: MNText.resolve(context, MNText.body)),
                Text(s.reasonText(reason),
                    style: MNText.resolve(context, MNText.meta)),
                MNButton(s.returnSend,
                    onPressed: () => Navigator.pop(sheet, true)),
                MNButton.secondary(s.cancel,
                    onPressed: () => Navigator.pop(sheet, false)),
              ]));
      if (yes != true || !mounted) return;
      _pending = (
        destination: _destination!,
        date: moneyDateKey(_day),
        reason: reason,
        lines: [for (final l in _lines) ReturnLineDraft(l.product, l.quantity)],
      );
    }
    await _send(s);
  }

  Future<void> _send(Strings s) async {
    final body = _pending;
    if (body == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await officeStockCall(
          ref.read(officeSessionProvider.notifier),
          (r) => r.recordReturn(
              clientId: _clientId,
              stationId: widget.stationId,
              businessDate: body.date,
              destinationLocationId: body.destination,
              reason: body.reason,
              lines: body.lines));
      if (mounted) setState(() => _saved = row);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is OfficeError) {
          // A definite refusal recorded nothing: the form opens again.
          _pending = null;
          _clientId = const Uuid().v4();
          _error = error.kind == OfficeErrorKind.invalid
              ? s.detailsInvalid
              : officeErrorText(s, error);
        } else {
          _error = '${officeErrorText(s, error)}\n${s.sendRetryNote}';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _lineRow(Strings s, int index, _ReturnLine line, OfficeProduct? p) {
    final name = p?.name ?? line.product;
    void set(int v) => setState(() {
          if (v == 0) {
            _lines.remove(line);
          } else {
            line.quantity = v;
          }
        });
    return Container(
        key: ValueKey(line),
        padding: const EdgeInsets.symmetric(
            horizontal: MNSpace.x3, vertical: MNSpace.x3 - 2),
        decoration: BoxDecoration(
            border: index == 0
                ? null
                : const Border(top: BorderSide(color: MNColors.cardBorder))),
        child: Row(children: [
          MNProductImage.thumb(image: p == null ? null : ownerProductImage(p)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                MNPressable(
                    semanticLabel: s.quantityFor(name),
                    onTap: _locked
                        ? null
                        : () async {
                            final v = await showNumberSheet(context,
                                title: s.quantityFor(name),
                                initial: line.quantity,
                                max: _max);
                            if (v != null && mounted) set(v);
                          },
                    child: Text(name,
                        style: MNText.resolve(context, MNText.body))),
                if (p != null)
                  Text(s.unitName(p.unit),
                      style: MNText.resolve(context, MNText.meta)),
                const SizedBox(height: 4),
                MNQuantitySelector(
                    value: line.quantity,
                    min: 0,
                    max: _max,
                    compact: true,
                    itemLabel: name,
                    onChanged: _locked ? (_) {} : set),
              ])),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = stockAccess(ref);
    final products = ref.watch(officeProductsProvider);
    final locations = ref.watch(stockLocationsProvider);
    final byCode = {
      for (final p in products.valueOrNull ?? const <OfficeProduct>[]) p.code: p
    };
    final destinations = [
      for (final l in locations.valueOrNull ?? const <OfficeStockLocation>[])
        if (l.takesReturns) l
    ];
    final destinationName =
        destinations.where((l) => l.id == _destination).firstOrNull?.name ?? '';
    final saved = _saved;
    return OwnerPage(
        title: s.returnGoods,
        strings: s,
        child: Padding(
            padding: _pad(context),
            child: !access.returns
                ? MNNote(s.notAllowed)
                : saved != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Text(s.returnSaved,
                                style: OwnerStyle.text(context, 16,
                                    weight: 600, color: MNColors.success)),
                            _gap(context),
                            StockReturnCard(row: saved),
                            _gap(context),
                            MNButton(s.finish,
                                onPressed: () => context.pop(saved)),
                          ])
                    : _Card(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            OwnerHelp(message: s.returnHelp),
                            _gap(context),
                            if (locations.hasError)
                              MNNote(officeErrorText(s, locations.error!),
                                  error: true),
                            if (locations.hasValue && destinations.isEmpty)
                              MNNote(s.returnNoDestinations)
                            else
                              MNSelectField<String>(
                                  label: s.returnDestination,
                                  value: _destination,
                                  emptyText:
                                      locations.isLoading ? s.loading : null,
                                  options: [
                                    for (final l in destinations)
                                      MNSelectOption(
                                          value: l.id,
                                          label: l.name,
                                          caption:
                                              l.code.isEmpty ? null : l.code)
                                  ],
                                  onChanged: _locked
                                      ? null
                                      : (v) =>
                                          setState(() => _destination = v)),
                            _gap(context),
                            MNFieldButton(
                                label: s.returnDate,
                                text: s.date(_day),
                                placeholder: s.date(_day),
                                icon: MNIconData.calendar,
                                onTap: _locked
                                    ? null
                                    : () async {
                                        final d = await showMNDateSheet(context,
                                            title: s.returnDate,
                                            initial: _day,
                                            first: _today.subtract(
                                                const Duration(days: 13)),
                                            last: _today);
                                        if (d != null && mounted) {
                                          setState(() => _day = d);
                                        }
                                      }),
                            _gap(context),
                            Semantics(
                                header: true,
                                child: Text(s.returnProducts,
                                    style:
                                        MNText.resolve(context, MNText.title))),
                            _gap(context, 8),
                            if (products.hasError)
                              MNNote(officeErrorText(s, products.error!),
                                  error: true),
                            if (_lines.isEmpty)
                              Text(s.returnNoProducts,
                                  style: MNText.resolve(context, MNText.meta))
                            else
                              Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                      color: MNColors.white,
                                      borderRadius: BorderRadius.circular(
                                          MNRadius.medium),
                                      border: Border.all(
                                          color: MNColors.cardBorder)),
                                  child: Column(children: [
                                    for (final (i, l) in _lines.indexed)
                                      _lineRow(s, i, l, byCode[l.product]),
                                  ])),
                            _gap(context, 8),
                            MNButton.secondary(s.addMore,
                                onPressed: _locked || _lines.length >= 200
                                    ? null
                                    : () => _addProduct(
                                        s,
                                        products.valueOrNull ??
                                            const <OfficeProduct>[])),
                            _gap(context),
                            MNTextField(
                                label: s.returnReason,
                                controller: _reason,
                                enabled: !_locked,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(500)
                                ]),
                            if (_error != null) ...[
                              _gap(context),
                              MNNote(_error!, error: true),
                            ],
                            _gap(context),
                            MNButton(_pending == null ? s.returnSend : s.retry,
                                busy: _busy,
                                onPressed: _busy || _lines.isEmpty
                                    ? null
                                    : () =>
                                        _review(s, destinationName, byCode)),
                          ]))));
  }
}

// Receipt mismatch: units still in transit after a short receipt -----------------------

/// The ways a receipt mismatch's in-transit units can end (vendor plan,
/// "Dispatch and stock in transit").
const transitDeliveredLater = 'delivered_later',
    transitReturned = 'returned_to_central',
    transitLoss = 'transit_loss';

/// Resolves a receipt mismatch; pops with the resolution the server took.
class ReceiptMismatchSheet extends ConsumerStatefulWidget {
  final OfficeException problem;
  const ReceiptMismatchSheet({super.key, required this.problem});
  @override
  ConsumerState<ReceiptMismatchSheet> createState() => _MismatchState();
}

class _MismatchState extends ConsumerState<ReceiptMismatchSheet> {
  final _reason = TextEditingController();
  String? _resolution, _destination, _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save(String resolution) async {
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
      await officeStockCall(
          ref.read(officeSessionProvider.notifier),
          (r) => r.resolveTransit(widget.problem.id,
              resolution: resolution,
              reason: reason,
              destinationLocationId:
                  resolution == transitReturned ? _destination : null));
      if (mounted) Navigator.of(context).pop(resolution);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = stockAccess(ref);
    final choices = [
      if (access.review) transitDeliveredLater,
      if (access.review) transitReturned,
      if (access.transitLoss) transitLoss,
    ];
    final resolution =
        _resolution ?? (choices.length == 1 ? choices.single : null);
    final locations = ref.watch(stockLocationsProvider).valueOrNull;
    final stores = [
      for (final l in locations ?? const <OfficeStockLocation>[])
        if (l.active && l.kind == 'receiving') l
    ];
    return MNSheet(title: s.mismatchResolve, children: [
      MNNote(s.mismatchHelp, tone: MNNoteTone.info),
      MNSelectField<String>(
          label: s.mismatchOutcome,
          value: resolution,
          options: [
            for (final c in choices)
              MNSelectOption(
                  value: c,
                  label: s.transitResolutionName(c),
                  caption: s.transitResolutionCaption(c)),
          ],
          onChanged: _busy ? null : (v) => setState(() => _resolution = v)),
      if (resolution == transitReturned && stores.isNotEmpty)
        MNSelectField<String?>(
            label: s.mismatchDestination,
            value: _destination,
            options: [
              MNSelectOption(value: null, label: s.mismatchDefaultDestination),
              for (final l in stores)
                MNSelectOption(value: l.id, label: l.name),
            ],
            onChanged: _busy ? null : (v) => setState(() => _destination = v)),
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(
          resolution == null
              ? s.mismatchResolve
              : s.transitResolutionName(resolution),
          busy: _busy,
          onPressed:
              _busy || resolution == null ? null : () => _save(resolution)),
    ]);
  }
}

// The owner's late-entry window (money settings, "stock" section) -----------------------

class OfficeLateEntryCard extends ConsumerStatefulWidget {
  final int? hours;
  final VoidCallback onSaved;
  final bool showExplanation;
  const OfficeLateEntryCard(
      {super.key,
      required this.hours,
      required this.onSaved,
      this.showExplanation = true});
  @override
  ConsumerState<OfficeLateEntryCard> createState() => _LateEntryState();
}

class _LateEntryState extends ConsumerState<OfficeLateEntryCard> {
  late final _hours = TextEditingController(
      text: widget.hours == null ? '' : '${widget.hours}');
  String? _error;

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _change(int? hours) async {
    final s = ref.read(stringsProvider);
    if (hours == widget.hours) {
      setState(() => _error = s.nothingChanged);
      return;
    }
    setState(() => _error = null);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title:
                hours == null ? s.lateEntryClear : s.lateEntrySaveTitle(hours),
            note: hours == null ? s.lateEntryClearBody : s.lateEntryHelp,
            actionLabel: s.saveChanges,
            send: (reason) => officeStockCall(
                ref.read(officeSessionProvider.notifier),
                (r) => r.saveLateEntryHours(hours, reason: reason))));
    if (done != true) return;
    widget.onSaved();
    if (mounted) _toast(context, s.moneySettingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final current = widget.hours;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.showExplanation) ...[
        Text(s.lateEntryTitle, style: _title(context)),
        _gap(context, 4),
      ],
      Text(current == null ? s.lateEntryNotSet : s.lateEntryValue(current),
          style: OwnerStyle.text(context, 15, weight: 600)),
      if (widget.showExplanation) Text(s.lateEntryHelp, style: _meta(context)),
      _gap(context),
      MNTextField(
          label: s.lateEntryHours,
          controller: _hours,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4)
          ]),
      if (_error != null) ...[
        _gap(context, 8),
        MNNote(_error!, error: true),
      ],
      _gap(context),
      MNButton(s.lateEntrySave, onPressed: () {
        final hours = parseLateEntryHours(_hours.text);
        if (hours == null) {
          setState(() => _error = s.lateEntryInvalid);
          return;
        }
        _change(hours);
      }),
      if (current != null) ...[
        _gap(context, 8),
        MNButton.secondary(s.lateEntryClear, onPressed: () => _change(null)),
      ],
    ]));
  }
}

/// A reason, then one server call.
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
      MNNote(widget.note, tone: MNNoteTone.info),
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(widget.actionLabel,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// One product's stock figures: the estimate is the main number, the others
/// are smaller lines beneath. Pending and held figures show only when there
/// is something; a held sale and a difference not posted are warnings.
class _MeasureCard extends StatelessWidget {
  final OfficeStockMeasure measure;
  final Strings strings;
  const _MeasureCard({required this.measure, required this.strings});

  static String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final m = measure;
    double u(double n) => OwnerStyle.px(context, n);
    Widget line(String label, String value, {Color? color}) => Padding(
        padding: EdgeInsets.only(top: u(8)),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: OwnerStyle.text(context, 13,
                      color: color ?? OwnerStyle.muted))),
          Text(value,
              style: OwnerStyle.text(context, 13,
                  weight: 600, color: color ?? OwnerStyle.ink)),
        ]));
    final count = m.lastCount;
    return OwnerCard(
        radius: 17,
        child: Padding(
            padding: EdgeInsets.all(u(16)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(m.productName, style: _title(context)),
                          SizedBox(height: u(4)),
                          Text(s.measureEstimate, style: _meta(context)),
                        ])),
                    Text(_n(m.estimatedAvailable),
                        style: OwnerStyle.text(context, 26, weight: 600)),
                  ]),
                  line(s.measureBook, _n(m.book)),
                  if (m.pendingSales != 0)
                    line(s.measurePendingSales, _n(m.pendingSales)),
                  if (m.pendingDamage != 0)
                    line(s.measurePendingDamage, _n(m.pendingDamage)),
                  if (m.heldPhoneSales != 0)
                    line(s.measureHeldSales, _n(m.heldPhoneSales),
                        color: MNColors.warning),
                  if (count != null) line(s.measureCounted, _n(count.counted)),
                  if (m.lastVariance != null)
                    line(s.measureVariance, _n(m.lastVariance!)),
                  if (m.countGap != 0)
                    line(s.measureGap, _n(m.countGap), color: MNColors.warning),
                ])));
  }
}
