import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

class StockList extends StatelessWidget {
  final String status;
  const StockList({super.key, this.status = ''});
  @override
  Widget build(BuildContext context) =>
      ResourceView('/supplier/stock', builder: (rows) {
        final list = (rows as List)
            .where((r) => status.isEmpty || r['listing_status'] == status)
            .toList();
        if (list.isEmpty) {
          return EmptyState('No stock listed yet',
              'Add your available livestock and Omoterra will review it before it goes live.',
              action: OmoterraButton('Add Stock',
                  onPressed: () => context.push('/stock/new')));
        }
        return Column(children: [
          for (final row in list)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StockCard(row))
        ]);
      });
}

class _StockCard extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _StockCard(this.row);
  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
      onTap: () => context.push('/stock/${row['id']}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OColors.border)),
          child: Row(children: [
            SizedBox(
                width: 56,
                child: ProductImage(List<String>.from(row['photos'] ?? []),
                    category: row['category'], height: 56)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label(row['category']),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '${amount(row['quantity_available'])} available · ${amount(row['quantity_reserved'])} reserved',
                      style: const TextStyle(
                          fontSize: 12.5, color: OColors.secondary)),
                  const SizedBox(height: 6),
                  StatusText(row['listing_status']),
                ])),
            PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: OColors.muted),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (route) => context.push(route),
                itemBuilder: (context) => [
                      PopupMenuItem(
                          value: '/stock/${row['id']}',
                          child: const Text('View details')),
                      PopupMenuItem(
                          value: '/stock/${row['id']}/correct',
                          child: const Text('Correct stock count')),
                      PopupMenuItem(
                          value: '/stock/${row['id']}/add',
                          child: const Text('Add stock received')),
                    ]),
          ])));
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockState();
}

class _StockState extends State<StockScreen> {
  String status = '';
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        SectionHeader('My stock',
            action: '+ Add', onTap: () => context.push('/stock/new')),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: [
              '',
              'live',
              'pending_review',
              'needs_confirmation',
              'paused',
              'sold_out'
            ]
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(s.isEmpty ? 'All stock' : label(s)),
                            selected: status == s,
                            onSelected: (_) => setState(() => status = s))))
                    .toList())),
        const SizedBox(height: 24),
        StockList(status: status)
      ]);
}
