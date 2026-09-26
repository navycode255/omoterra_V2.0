import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/support_contact.dart';
import '../../shared/widgets/components.dart';

class SupplierOrders extends ConsumerWidget {
  final String? id;
  const SupplierOrders({super.key, this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    final path = id == null ? '/supplier/orders' : '/supplier/orders/$id';
    final request = ref.watch(resourceProvider(path));
    if (request.hasError) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorState(request.error!,
              retry: () => ref.invalidate(resourceProvider(path))),
        ],
      );
    }
    if (!request.hasValue) return const LoadingSkeleton();

    final data = request.value;
    final rows = id == null ? data as List : [data];
    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [EmptyState(s.noReservationsTitle, s.noReservationsBody)],
      );
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(id == null ? s.ordersAndReservations : s.collectionDetails,
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
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
                  Text(s.reservationNo(
                      row['id'].toString().substring(0, 8).toUpperCase())),
                  const SizedBox(height: 8),
                  Text(
                    '${s.label(row['category'])} · ${amount(row['quantity'])} ${s.unit('${row['unit_type']}', num.tryParse('${row['quantity']}'))}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(row['expected_collection_date'] == null
                      ? s.collectionTbc
                      : s.collectionExpected(
                          s.dateText(row['expected_collection_date']))),
                  const SizedBox(height: 8),
                  StatusText(row['status']),
                  if (id != null) ...[
                    const SizedBox(height: 16),
                    Text(row['instructions']),
                    for (final settlement in row['settlements'])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            s.settlement(tsh(settlement['total_payable']))),
                        subtitle: StatusText(settlement['status']),
                        onTap: () =>
                            context.push('/payouts/${settlement['id']}'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      if (id != null)
        SupportContact(
            topic: s.collectionTopic(id!.substring(0, 8).toUpperCase())),
    ]);
  }
}
