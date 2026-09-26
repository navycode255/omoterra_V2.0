import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/supply_art.dart';

String stockUnits(Object? value, String unit, Strings s) =>
    '${amount(value)} ${s.unit(unit, num.tryParse('$value'))}';
String stockDate(Object? date, Strings s) {
  final parsed = DateTime.tryParse('$date')?.toLocal();
  return parsed == null
      ? '$date'
      : '${s.date(parsed)} · ${DateFormat('HH:mm').format(parsed)}';
}

void refreshStock(WidgetRef ref, String id) {
  for (final path in [
    '/supplier/stock',
    '/supplier/stock/$id',
    '/supplier/stock/$id/history',
    '/supplier/sales'
  ]) {
    ref.invalidate(resourceProvider(path));
  }
  ref.invalidate(listingsProvider);
}

/// One representative category per unit type, used only to pick a small icon
/// for that row — a unit type can span several categories (e.g. 'bird'
/// covers both broilers and local chicken), so this is a visual stand-in,
/// not a categorisation.
const _unitIcon = {
  'bird': 'broilers',
  'animal': 'cattle',
  'kg': 'goat_meat',
  'tray': 'eggs',
};

class StockBalances extends StatelessWidget {
  final List<dynamic> rows;
  const StockBalances(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final units = rows.map((r) => r['unit_type'] as String).toSet();
    final columns = [
      (Icons.inventory_2_outlined, s.availableStat, 'quantity_available'),
      (Icons.schedule, s.reservedStat, 'quantity_reserved'),
      (Icons.bar_chart, s.soldStat, 'quantity_sold'),
    ];
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Space for the leading category icon each data row carries,
            // so the header labels line up over their numbers below.
            const SizedBox(width: 48),
            for (final entry in columns)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: [
                        Icon(entry.$1, size: 13, color: OColors.secondary),
                        const SizedBox(width: 3),
                        Flexible(
                            child: Text(entry.$2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5, color: OColors.secondary))),
                      ])))
          ]),
          if (units.isEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 12, left: 10),
                child: Text(s.balancesAppearHere)),
          for (final unit in units)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      SizedBox(
                          width: 48,
                          child: Center(
                              child: SupplyArt(_unitIcon[unit] ?? 'crate',
                                  size: 34))),
                      for (var i = 0; i < columns.length; i++) ...[
                        // A divider between columns — not before the
                        // first or after the last — so the three figures
                        // read as separate cells rather than crowding
                        // together.
                        if (i > 0)
                          const VerticalDivider(
                              width: 1, color: OColors.border),
                        Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          amount(rows
                                              .where(
                                                  (r) => r['unit_type'] == unit)
                                              .fold<num>(
                                                  0,
                                                  (sum, r) =>
                                                      sum +
                                                      num.parse(
                                                          '${r[columns[i].$3]}'))),
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: OColors.forest)),
                                    ]))),
                      ],
                    ]))),
        ]));
  }
}

class StockChangeScreen extends ConsumerWidget {
  final String id, action;
  const StockChangeScreen(this.id, this.action, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correction = action == 'correct';
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(correction ? s.correctStockCount : s.addToThisStock)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView('/supplier/stock/$id',
              builder: (row) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SupplyArt(row['category'], size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Text(s.label(row['category']),
                                  style:
                                      Theme.of(context).textTheme.titleLarge))
                        ]),
                        const SizedBox(height: 24),
                        StockBalances([row]),
                        const SizedBox(height: 24),
                        Text(
                            correction
                                ? s.fixRecordingMistake
                                : s.receivedMoreQ,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(correction ? s.correctionBody : s.additionBody),
                        const SizedBox(height: 24),
                        DataForm(
                            path:
                                '/supplier/stock/$id/${correction ? 'corrections' : 'additions'}',
                            fields: [
                              FormFieldSpec(
                                  correction ? 'counted_on_hand' : 'quantity',
                                  correction
                                      ? s.actualOnHand(
                                          s.unit('${row['unit_type']}', 1))
                                      : s.quantityReceived(
                                          s.unit('${row['unit_type']}', 1)),
                                  numeric: true,
                                  initial: correction
                                      ? '${num.parse('${row['quantity_available']}') + num.parse('${row['quantity_reserved']}')}'
                                      : ''),
                              FormFieldSpec(
                                  'reason',
                                  correction
                                      ? s.whyCountWrong
                                      : s.stockReceivedNote,
                                  multiline: true)
                            ],
                            button: correction
                                ? s.saveCorrection
                                : s.addStockSaveHistory,
                            onSuccess: (_) {
                              refreshStock(ref, id);
                              context.pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(correction
                                          ? s.countCorrected
                                          : s.stockAddedRecorded)));
                            }),
                      ]))
        ]));
  }
}

class RecordSaleScreen extends ConsumerWidget {
  final String id;
  const RecordSaleScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.recordASale)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView('/supplier/stock/$id',
              builder: (row) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SupplyArt(row['category'], size: 72),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(s.label(row['category']),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(s.nAvailable(stockUnits(
                                    row['quantity_available'],
                                    row['unit_type'],
                                    s)))
                              ]))
                        ]),
                        const SizedBox(height: 24),
                        Surface(
                            color: OColors.soft,
                            child: Text(s.soldOutsideNote)),
                        const SizedBox(height: 24),
                        DataForm(
                            path: '/supplier/stock/$id/sales',
                            fields: [
                              FormFieldSpec(
                                  'quantity',
                                  s.quantitySold(
                                      s.unit('${row['unit_type']}', 1)),
                                  numeric: true),
                              FormFieldSpec('sold_on', s.dateSold,
                                  date: true,
                                  initial: DateTime.now()
                                      .toIso8601String()
                                      .split('T')
                                      .first),
                              FormFieldSpec(
                                  'unit_price',
                                  s.salePricePer(
                                      s.unit('${row['unit_type']}', 1)),
                                  numeric: true,
                                  optional: true),
                              FormFieldSpec('note', s.saleNoteOptional,
                                  optional: true, multiline: true),
                            ],
                            transform: (data) => {
                                  ...data,
                                  'unit_price': data['unit_price'] == ''
                                      ? null
                                      : data['unit_price']
                                },
                            button: s.recordSaleDeduct,
                            reviewTitle: s.confirmThisSale,
                            reviewCopy: s.confirmSaleCopy,
                            onSuccess: (sale) {
                              refreshStock(ref, id);
                              context.pushReplacement('/sales/${sale['id']}');
                            }),
                      ]))
        ]));
  }
}

class StockHistoryScreen extends StatefulWidget {
  final String id;
  const StockHistoryScreen(this.id, {super.key});
  @override
  State<StockHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<StockHistoryScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.stockHistory)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(s.movementRecordTitle,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(s.movementRecordBody),
          const SizedBox(height: 20),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: ['all', 'sales', 'corrections', 'reservations']
                      .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              label: Text(s.historyFilter(f)),
                              selected: f == filter,
                              onSelected: (_) => setState(() => filter = f))))
                      .toList())),
          const SizedBox(height: 20),
          ResourceView('/supplier/stock/${widget.id}/history', builder: (data) {
            final rows = (data as List)
                .where((r) =>
                    filter == 'all' ||
                    (filter == 'sales' &&
                        r['kind'].toString().startsWith('sale_')) ||
                    (filter == 'corrections' && r['kind'] == 'correction') ||
                    (filter == 'reservations' &&
                        r['kind'].toString().startsWith('hold_')))
                .toList();
            if (rows.isEmpty) {
              return EmptyState(s.noMovementsTitle, s.noMovementsBody);
            }
            return Column(
                children: [for (final row in rows) StockMovementCard(row)]);
          }),
        ]));
  }
}

class StockMovementCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const StockMovementCard(this.row, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final change = num.parse('${row['total_delta']}') -
        num.parse('${row['reserved_delta']}') -
        num.parse('${row['sold_delta']}');
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Surface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(s.movement('${row['kind']}'),
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(
                change == 0
                    ? '—'
                    : '${change > 0 ? '+' : '−'}${amount(change.abs())}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: change < 0 ? OColors.secondary : OColors.positive))
          ]),
          const SizedBox(height: 4),
          Text(stockDate(row['created_at'], s),
              style: Theme.of(context).textTheme.bodySmall),
          if ('${row['reason']}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(row['reason'])
          ],
          const SizedBox(height: 12),
          Text(
              s.balanceAfter(amount(row['available_after']),
                  amount(row['reserved_after']), amount(row['sold_after'])),
              style: const TextStyle(fontSize: 12, color: OColors.secondary)),
        ])));
  }
}

class SalesScreen extends ConsumerStatefulWidget {
  final String? id;
  const SalesScreen({super.key, this.id});
  @override
  ConsumerState<SalesScreen> createState() => _SalesState();
}

class _SalesState extends ConsumerState<SalesScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (widget.id == null) ...[
        Text(s.knowWhatSold,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(s.salesIntro),
        const SizedBox(height: 20),
        Wrap(
            spacing: 8,
            children: {
              'all': s.allSales,
              'omoterra': 'Omoterra',
              'external': s.elsewhere
            }
                .entries
                .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    onSelected: (_) => setState(() => filter = e.key)))
                .toList()),
        const SizedBox(height: 20),
      ],
      ResourceView(
          widget.id == null
              ? '/supplier/sales'
              : '/supplier/sales/${widget.id}', builder: (data) {
        final rows = widget.id == null
            ? (data as List)
                .where((r) => filter == 'all' || r['source'] == filter)
                .toList()
            : [data];
        if (rows.isEmpty) {
          return EmptyState(s.noSalesTitle, s.noSalesBody,
              action: OmoterraButton(s.viewMyStock,
                  onPressed: () => context.go('/stock')));
        }
        return Column(children: [
          for (final row in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                    onTap: widget.id == null
                        ? () => context.push('/sales/${row['id']}')
                        : null,
                    child: Surface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            SupplyArt(row['category'], size: 56),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(s.label(row['category']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(stockUnits(
                                      row['quantity'], row['unit_type'], s)),
                                  Text(
                                      row['source'] == 'omoterra'
                                          ? s.omoterraDelivery
                                          : s.soldElsewhere,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: OColors.secondary))
                                ]))
                          ]),
                          const SizedBox(height: 12),
                          Text(stockDate(row['sold_at'], s),
                              style: Theme.of(context).textTheme.bodySmall),
                          if (row['status'] == 'reversed') ...[
                            const SizedBox(height: 10),
                            const StatusText('reversed'),
                            Text(row['reversal_reason'] ?? '')
                          ],
                          if (widget.id != null) ...[
                            const SizedBox(height: 16),
                            Text(s.saleNo(row['id']
                                .toString()
                                .substring(0, 8)
                                .toUpperCase())),
                            if (row['total'] != null) ...[
                              const SizedBox(height: 12),
                              MoneySummary({
                                s.recordedUnitPrice: tsh(row['unit_price']),
                                s.saleValue: tsh(row['total'])
                              })
                            ],
                            if (row['note'] != '') ...[
                              const SizedBox(height: 12),
                              Text(row['note'])
                            ],
                            const SizedBox(height: 16),
                            Text(row['source'] == 'omoterra'
                                ? s.recordedAtDelivery
                                : s.deductedWhenRecorded),
                            const SizedBox(height: 20),
                            if (row['source'] == 'external' &&
                                row['status'] != 'reversed')
                              TextButton(
                                  onPressed: () => omoterraSheet(
                                      context,
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s.reverseSaleTitle,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            const SizedBox(height: 12),
                                            Text(s.reverseSaleBody),
                                            const SizedBox(height: 20),
                                            DataForm(
                                                path:
                                                    '/supplier/sales/${row['id']}/reverse',
                                                fields: [
                                                  FormFieldSpec('reason',
                                                      s.reasonForReversal,
                                                      multiline: true)
                                                ],
                                                button: s.reverseSaleButton,
                                                onSuccess: (_) {
                                                  refreshStock(
                                                      ref, row['listing_id']);
                                                  ref.invalidate(resourceProvider(
                                                      '/supplier/sales/${widget.id}'));
                                                  Navigator.pop(context);
                                                })
                                          ])),
                                  child: Text(s.saleRecordedByMistake)),
                            OmoterraButton(s.viewStockHistory,
                                secondary: true,
                                onPressed: () => context.push(
                                    '/stock/${row['listing_id']}/history')),
                          ],
                        ]))))
        ]);
      }),
    ]);
  }
}
