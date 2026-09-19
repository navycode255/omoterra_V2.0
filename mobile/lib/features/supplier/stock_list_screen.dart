import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                child: InkWell(
                    onTap: () => context.push('/stock/${row['id']}'),
                    child: Surface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(label(row['category']),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                              '${amount(row['quantity_available'])} ${row['unit_type']} available · ${amount(row['quantity_reserved'])} reserved'),
                          const SizedBox(height: 8),
                          StatusText(row['listing_status'])
                        ]))))
        ]);
      });
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
