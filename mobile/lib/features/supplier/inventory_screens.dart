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

String stockUnits(Object? value, String unit) =>
    '${amount(value)} ${unit == 'kg' ? 'kg' : num.tryParse('$value') == 1 ? unit : '${unit}s'}';
String stockDate(Object? date) {
  final parsed = DateTime.tryParse('$date');
  return parsed == null
      ? '$date'
      : DateFormat('d MMM yyyy · HH:mm').format(parsed.toLocal());
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

  /// Optional translations. Omitted in tests, which render this directly.
  final Strings? labels;
  const StockBalances(this.rows, {super.key, this.labels});
  @override
  Widget build(BuildContext context) {
    final units = rows.map((r) => r['unit_type'] as String).toSet();
    final columns = [
      (
        Icons.inventory_2_outlined,
        labels?.availableStat ?? 'Available',
        'quantity_available'
      ),
      (Icons.schedule, labels?.reservedStat ?? 'Reserved', 'quantity_reserved'),
      (Icons.bar_chart, labels?.soldStat ?? 'Sold', 'quantity_sold'),
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
            const Padding(
                padding: EdgeInsets.only(top: 12, left: 10),
                child: Text('Your stock balances will appear here.')),
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
    return Scaffold(
        appBar: OmoterraAppBar(
            title:
                Text(correction ? 'Correct stock count' : 'Add to this stock')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView('/supplier/stock/$id',
              builder: (row) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SupplyArt(row['category'], size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Text(label(row['category']),
                                  style:
                                      Theme.of(context).textTheme.titleLarge))
                        ]),
                        const SizedBox(height: 24),
                        StockBalances([row]),
                        const SizedBox(height: 24),
                        Text(
                            correction
                                ? 'Fix a recording mistake'
                                : 'Received more of the same stock?',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(correction
                            ? 'Enter the actual stock still on hand, including reserved stock. This corrects your balance; it does not record a sale or change your sold history.'
                            : 'Use this for newly received stock with the same specifications. For a different batch or product, add a new listing.'),
                        const SizedBox(height: 24),
                        DataForm(
                            path:
                                '/supplier/stock/$id/${correction ? 'corrections' : 'additions'}',
                            fields: [
                              FormFieldSpec(
                                  correction ? 'counted_on_hand' : 'quantity',
                                  correction
                                      ? 'Actual stock on hand (${row['unit_type']})'
                                      : 'Quantity received (${row['unit_type']})',
                                  numeric: true,
                                  initial: correction
                                      ? '${num.parse('${row['quantity_available']}') + num.parse('${row['quantity_reserved']}')}'
                                      : ''),
                              FormFieldSpec(
                                  'reason',
                                  correction
                                      ? 'Why was the count incorrect?'
                                      : 'Stock received / batch note',
                                  multiline: true)
                            ],
                            button: correction
                                ? 'Save correction to history'
                                : 'Add stock & save history',
                            onSuccess: (_) {
                              refreshStock(ref, id);
                              context.pop();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(correction
                                      ? 'Count corrected. Sold history is unchanged.'
                                      : 'Stock added and recorded in history.')));
                            }),
                      ]))
        ]));
  }
}

class RecordSaleScreen extends ConsumerWidget {
  final String id;
  const RecordSaleScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: OmoterraAppBar(title: const Text('Record a sale')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/supplier/stock/$id',
            builder: (row) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    SupplyArt(row['category'], size: 72),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(label(row['category']),
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(
                              '${stockUnits(row['quantity_available'], row['unit_type'])} available')
                        ]))
                  ]),
                  const SizedBox(height: 24),
                  const Surface(
                      color: OColors.soft,
                      child: Text(
                          'For goods sold outside Omoterra. Omoterra orders record their sales automatically when delivered—do not enter them again here.')),
                  const SizedBox(height: 24),
                  DataForm(
                      path: '/supplier/stock/$id/sales',
                      fields: [
                        FormFieldSpec(
                            'quantity', 'Quantity sold (${row['unit_type']})',
                            numeric: true),
                        FormFieldSpec('sold_on', 'Date sold',
                            date: true,
                            initial: DateTime.now()
                                .toIso8601String()
                                .split('T')
                                .first),
                        FormFieldSpec('unit_price',
                            'Sale price per ${row['unit_type']} (TZS, optional)',
                            numeric: true, optional: true),
                        const FormFieldSpec('note', 'Sale note (optional)',
                            optional: true, multiline: true),
                      ],
                      transform: (data) => {
                            ...data,
                            'unit_price': data['unit_price'] == ''
                                ? null
                                : data['unit_price']
                          },
                      button: 'Record sale & deduct stock',
                      reviewTitle: 'Confirm this sale',
                      reviewCopy:
                          'This records goods already sold outside Omoterra and deducts only available stock. It does not collect a payment.',
                      onSuccess: (sale) {
                        refreshStock(ref, id);
                        context.pushReplacement('/sales/${sale['id']}');
                      }),
                ]))
      ]));
}

const movementLabels = {
  'opening_balance': 'Opening stock balance',
  'sale_reversed': 'Sale reversed · stock returned',
  'correction': 'Stock count corrected',
  'stock_added': 'Stock received',
  'sale_external': 'Sold outside Omoterra',
  'sale_omoterra': 'Sold through Omoterra',
  'hold_created': 'Stock reserved',
  'hold_confirmed': 'Reservation confirmed',
  'hold_released': 'Reserved stock released',
  'hold_expired': 'Reservation expired',
  'hold_cancelled': 'Reservation cancelled',
  'availability_confirmed': 'Availability confirmed',
  'listing_paused': 'Listing paused',
};

class StockHistoryScreen extends StatefulWidget {
  final String id;
  const StockHistoryScreen(this.id, {super.key});
  @override
  State<StockHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<StockHistoryScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: OmoterraAppBar(title: const Text('Stock history')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('A record of every movement',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'Sales, count corrections, incoming stock and reservations stay separate. Your history is never overwritten.'),
        const SizedBox(height: 20),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: ['all', 'sales', 'corrections', 'reservations']
                    .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(label(f)),
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
            return const EmptyState('No movements here yet',
                'Matching stock movements will appear here as you use this stock record.');
          }
          return Column(
              children: [for (final row in rows) StockMovementCard(row)]);
        }),
      ]));
}

class StockMovementCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const StockMovementCard(this.row, {super.key});
  @override
  Widget build(BuildContext context) {
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
                child: Text(movementLabels[row['kind']] ?? label(row['kind']),
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
          Text(stockDate(row['created_at']),
              style: Theme.of(context).textTheme.bodySmall),
          if ('${row['reason']}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(row['reason'])
          ],
          const SizedBox(height: 12),
          Text(
              'Balance after: ${amount(row['available_after'])} available · ${amount(row['reserved_after'])} reserved · ${amount(row['sold_after'])} sold',
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
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.id == null) ...[
          const Text('Know what has sold.',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Review completed sales and transaction history.'),
          const SizedBox(height: 20),
          Wrap(
              spacing: 8,
              children: {
                'all': 'All sales',
                'omoterra': 'Omoterra',
                'external': 'Elsewhere'
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
            return EmptyState('No sales recorded yet',
                'Record a sale from a stock detail page. Omoterra deliveries will appear automatically.',
                action: OmoterraButton('View my stock',
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
                                    Text(label(row['category']),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(stockUnits(
                                        row['quantity'], row['unit_type'])),
                                    Text(
                                        row['source'] == 'omoterra'
                                            ? 'Omoterra delivery'
                                            : 'Sold elsewhere',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: OColors.secondary))
                                  ]))
                            ]),
                            const SizedBox(height: 12),
                            Text(stockDate(row['sold_at']),
                                style: Theme.of(context).textTheme.bodySmall),
                            if (row['status'] == 'reversed') ...[
                              const SizedBox(height: 10),
                              const StatusText('reversed'),
                              Text(row['reversal_reason'] ?? '')
                            ],
                            if (widget.id != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                  'Sale #${row['id'].toString().substring(0, 8).toUpperCase()}'),
                              if (row['total'] != null) ...[
                                const SizedBox(height: 12),
                                MoneySummary({
                                  'Recorded unit price': tsh(row['unit_price']),
                                  'Sale value': tsh(row['total'])
                                })
                              ],
                              if (row['note'] != '') ...[
                                const SizedBox(height: 12),
                                Text(row['note'])
                              ],
                              const SizedBox(height: 16),
                              Text(row['source'] == 'omoterra'
                                  ? 'Recorded automatically at delivery. Settlement is shown under Payouts.'
                                  : 'Stock was deducted when this sale was recorded. This is a sales record, not an Omoterra payment.'),
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
                                              const Text(
                                                  'Reverse an incorrect sale',
                                                  style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 12),
                                              const Text(
                                                  'Use this only when this sale was recorded by mistake. The stock will be returned, and the original sale and reversal will both stay in history.'),
                                              const SizedBox(height: 20),
                                              DataForm(
                                                  path:
                                                      '/supplier/sales/${row['id']}/reverse',
                                                  fields: const [
                                                    FormFieldSpec('reason',
                                                        'Reason for reversal',
                                                        multiline: true)
                                                  ],
                                                  button:
                                                      'Reverse sale & return stock',
                                                  onSuccess: (_) {
                                                    refreshStock(
                                                        ref, row['listing_id']);
                                                    ref.invalidate(resourceProvider(
                                                        '/supplier/sales/${widget.id}'));
                                                    Navigator.pop(context);
                                                  })
                                            ])),
                                    child: const Text(
                                        'This sale was recorded by mistake')),
                              OmoterraButton('View stock history',
                                  secondary: true,
                                  onPressed: () => context.push(
                                      '/stock/${row['listing_id']}/history')),
                            ],
                          ]))))
          ]);
        }),
      ]);
}
