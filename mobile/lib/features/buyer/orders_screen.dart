import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/domain.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';

class OrderConfirmation extends ConsumerWidget {
  final String id;
  const OrderConfirmation(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(children: [
                  const Spacer(),
                  Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                          color: OColors.soft, shape: BoxShape.circle),
                      child: Center(
                          child: Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                  color: OColors.forest,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 33)))),
                  const SizedBox(height: 26),
                  Text(s.orderConfirmed,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(s.orderConfirmedBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: OColors.secondary, height: 1.5)),
                  const SizedBox(height: 26),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: OColors.pale,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: OColors.border)),
                      child: Column(children: [
                        Text(s.orderNumber,
                            style: const TextStyle(
                                fontSize: 12, color: OColors.muted)),
                        const SizedBox(height: 4),
                        Text('OMT-${id.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                      ])),
                  const Spacer(),
                  OmoterraButton(s.trackOrder,
                      onPressed: () => context.go('/order/$id')),
                  const SizedBox(height: 10),
                  OmoterraButton(s.backHome,
                      secondary: true, onPressed: () => context.go('/buyer')),
                ]))));
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<OrdersScreen> {
  bool past = false;
  @override
  Widget build(BuildContext context) => Consumer(builder: (context, ref, _) {
        final s = ref.s;
        return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Segmented pills, as drawn.
              Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: OColors.soft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                        child: _Segment(
                            label: s.active,
                            selected: !past,
                            onTap: () => setState(() => past = false))),
                    Expanded(
                        child: _Segment(
                            label: s.past,
                            selected: past,
                            onTap: () => setState(() => past = true))),
                  ])),
              const SizedBox(height: 18),
              ResourceView('/orders', builder: (rows) {
                final orders = (rows as List)
                    .map((r) =>
                        BuyerOrder.fromJson(Map<String, dynamic>.from(r)))
                    .where((o) =>
                        ['delivered', 'cancelled'].contains(o.status) == past)
                    .toList();
                if (orders.isEmpty) {
                  return EmptyState(s.noOrdersTitle, s.noOrdersBody,
                      action: Column(children: [
                        OmoterraButton(s.buySupplyCard,
                            onPressed: () => context.go('/explore')),
                        TextButton(
                            onPressed: () => context.push('/request'),
                            child: Text(s.requestSupply))
                      ]));
                }
                return Column(
                    children: orders
                        .map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OrderCard(order: o, statusLabel: s)))
                        .toList());
              }),
              SectionHeader(s.requestSupply),
              ResourceView('/requests',
                  builder: (rows) => Column(children: [
                        for (final r in rows)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${label(r['category'])} · ${amount(r['quantity'])} ${r['unit_type']}'),
                              subtitle: StatusText(r['status']),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/requests/${r['id']}'))
                      ]))
            ]);
      });
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: selected ? OColors.forest : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : OColors.secondary))));
}

class _OrderCard extends StatelessWidget {
  final BuyerOrder order;
  final Strings statusLabel;
  const _OrderCard({required this.order, required this.statusLabel});
  @override
  Widget build(BuildContext context) {
    final item = order.items.isEmpty ? null : order.items.first;
    return InkWell(
        onTap: () => context.push('/order/${order.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OColors.border)),
            child: Row(children: [
              SizedBox(
                  width: 64,
                  child: ProductImage(const [],
                      category: '${item?['category'] ?? 'crate'}', height: 64)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('OMT-${order.id.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    if (item != null)
                      Text(
                          '${label(item['category'])} × ${amount(item['quantity'])}',
                          style: const TextStyle(
                              fontSize: 12.5, color: OColors.secondary)),
                    const SizedBox(height: 5),
                    Text(tsh(order.total),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    StatusText(order.status),
                  ])),
              const Icon(Icons.chevron_right, color: OColors.muted),
            ])));
  }
}

class OrderDetail extends ConsumerWidget {
  final String id;
  const OrderDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: OmoterraAppBar(
          title: Text('Order #${id.substring(0, 8).toUpperCase()}'),
          actions: [
            IconButton(
                tooltip: 'Refresh order',
                onPressed: () =>
                    ref.invalidate(resourceProvider('/orders/$id')),
                icon: const Icon(Icons.refresh))
          ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/orders/$id', builder: (data) {
          final order = BuyerOrder.fromJson(Map<String, dynamic>.from(data));
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your supply, on its way',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Surface(child: OrderProgress(order.status)),
                if (order.message != null) ErrorState(order.message!),
                const SectionHeader('Order summary'),
                MoneySummary({
                  for (final i in order.items)
                    '${label(i['category'])} · ${amount(i['quantity'])} ${i['unit_type']}':
                        tsh(i['subtotal']),
                  'Total': tsh(order.total)
                }),
                const SectionHeader('Delivery'),
                Surface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.address['recipient_name']),
                      Text(
                          '${order.address['address_text']}, ${order.address['district_area']}'),
                      Text(order.address['region']),
                      const SizedBox(height: 8),
                      Text('Preferred date: ${order.deliveryDate}')
                    ])),
                const SectionHeader('Payment'),
                MoneySummary({
                  'Method': label(order.paymentMethod),
                  'Status': label(order.paymentStatus)
                }),
                if (order.status == 'confirmed') ...[
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => omoterraSheet(
                          context,
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cancel this order?',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                const Text(
                                    'Your reserved stock will be released. This is available before collection starts.'),
                                const SizedBox(height: 20),
                                DataForm(
                                    path: '/orders/$id/cancel',
                                    fields: const [],
                                    button: 'Cancel order',
                                    onSuccess: (_) {
                                      ref.invalidate(
                                          resourceProvider('/orders/$id'));
                                      ref.invalidate(
                                          resourceProvider('/orders'));
                                      Navigator.pop(context);
                                    })
                              ])),
                      child: const Text('Cancel order'))
                ],
                const SectionHeader('Activity'),
                for (final event in order.activity)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, size: 20),
                      title: Text(event['label']),
                      subtitle: Text(event['at'].toString().split('T').first))
              ]);
        })
      ]));
}
