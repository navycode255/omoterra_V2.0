import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/stock_video.dart';
import '../../shared/widgets/supply_art.dart';
import 'inventory_screens.dart';

class StockDetail extends ConsumerWidget {
  final String id;
  const StockDetail(this.id, {super.key});
  Future<void> action(BuildContext context, WidgetRef ref,
      Map<String, dynamic> row, String action) async {
    await omoterraSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action == 'confirm' ? 'Confirm your stock' : 'Pause listing',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(action == 'confirm'
              ? 'Are ${stockUnits(row['quantity_available'], row['unit_type'])} still available?'
              : 'Buyers will no longer be able to reserve this stock. Existing confirmed orders remain reserved.'),
          const SizedBox(height: 24),
          DataForm(
              path: '/supplier/stock/$id',
              method: 'PATCH',
              fixed: {'action': action},
              fields: const [],
              button: action == 'confirm'
                  ? 'Confirm ${amount(row['quantity_available'])}'
                  : 'Pause listing',
              onSuccess: (_) {
                refreshStock(ref, id);
                Navigator.pop(context);
              }),
          if (action == 'confirm')
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/stock/$id/correct');
                },
                child: const Text('The count is different')),
        ]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: OmoterraAppBar(title: const Text('Stock details'), actions: [
        IconButton(
            tooltip: 'Refresh stock',
            onPressed: () => refreshStock(ref, id),
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/supplier/stock/$id',
            builder: (row) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ProductImage(List<String>.from(row['photos']),
                      category: row['category'], height: 190),
                  if (row['video'] != null) ...[
                    const SizedBox(height: 10),
                    StockVideoTile(row['video']),
                  ],
                  const SizedBox(height: 20),
                  Text(label(row['category']),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  StatusText(row['listing_status']),
                  const SizedBox(height: 20),
                  StockBalances([row]),
                  const SizedBox(height: 20),
                  OmoterraButton('Record a sale',
                      onPressed: num.parse('${row['quantity_available']}') > 0
                          ? () => context.push('/stock/$id/sell')
                          : null),
                  const SizedBox(height: 8),
                  const Text(
                      'Omoterra deliveries are recorded automatically. Use this button for goods sold elsewhere.',
                      style: TextStyle(fontSize: 12, color: OColors.secondary)),
                  const SectionHeader('Manage your stock'),
                  _action(
                      context,
                      'Correct stock count',
                      'Fix an entry mistake. Sold history stays unchanged.',
                      'history',
                      '/stock/$id/correct'),
                  _action(
                      context,
                      'Add stock received',
                      'Increase this batch with a receipt in history.',
                      'crate',
                      '/stock/$id/add'),
                  _action(
                      context,
                      'Photos & video',
                      'Add, change or remove what buyers see.',
                      'crate',
                      '/stock/$id/media'),
                  _action(
                      context,
                      'Stock history',
                      'See sales, corrections and reservations.',
                      'receipt',
                      '/stock/$id/history'),
                  const SectionHeader('Stock information'),
                  MoneySummary({
                    'Recorded total':
                        stockUnits(row['quantity_total'], row['unit_type']),
                    'Your asking price':
                        '${tsh(row['farmer_asking_price_per_unit'])} / ${row['unit_type']}',
                    'Region': row['region']
                  }),
                  const SizedBox(height: 12),
                  MoneySummary(Map<String, dynamic>.from(row['specs'])
                      .map((k, v) => MapEntry(label(k), '$v'))),
                  if (!['pending_review', 'rejected']
                      .contains(row['listing_status'])) ...[
                    const SizedBox(height: 24),
                    OmoterraButton('Confirm availability',
                        secondary: true,
                        onPressed: () => action(context, ref, row, 'confirm')),
                    TextButton(
                        onPressed: () => action(context, ref, row, 'pause'),
                        child: const Text('Pause listing')),
                  ],
                ]))
      ]));
  Widget _action(BuildContext context, String title, String subtitle,
          String kind, String route) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SupplyArt(kind, size: 46),
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => context.push(route)));
}
