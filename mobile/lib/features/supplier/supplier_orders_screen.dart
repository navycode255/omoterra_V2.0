import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/components.dart';

class SupplierOrders extends StatelessWidget {
  final String? id;
  const SupplierOrders({super.key, this.id});
  @override
  Widget build(BuildContext context) {
    final body = ListView(padding: const EdgeInsets.all(20), children: [
      Text(id == null ? 'Orders & reservations' : 'Collection details',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
      ResourceView(id == null ? '/supplier/orders' : '/supplier/orders/$id',
          builder: (data) {
        final rows = id == null ? data as List : [data];
        if (rows.isEmpty) {
          return const EmptyState('No reservations yet',
              'When buyers reserve your approved stock, collection details will appear here.');
        }
        return Column(children: [
          for (final row in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                    onTap: id == null
                        ? () => context.push('/supplier-orders/${row['id']}')
                        : null,
                    child: Surface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              'Reservation #${row['id'].toString().substring(0, 8).toUpperCase()}'),
                          const SizedBox(height: 8),
                          Text(
                              '${label(row['category'])} · ${amount(row['quantity'])} ${row['unit_type']}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(row['expected_collection_date'] == null
                              ? 'Collection to be confirmed'
                              : 'Collection expected ${row['expected_collection_date']}'),
                          const SizedBox(height: 8),
                          StatusText(row['status']),
                          if (id != null) ...[
                            const SizedBox(height: 16),
                            Text(row['instructions']),
                            for (final p in row['settlements'])
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      'Settlement ${tsh(p['total_payable'])}'),
                                  subtitle: StatusText(p['status']),
                                  onTap: () =>
                                      context.push('/payouts/${p['id']}'))
                          ]
                        ]))))
        ]);
      })
    ]);
    return id == null ? body : Scaffold(appBar: OmoterraAppBar(), body: body);
  }
}
