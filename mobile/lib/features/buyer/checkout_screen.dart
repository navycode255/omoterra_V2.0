import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/domain.dart';
import '../../shared/widgets/components.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String id;
  const CheckoutScreen(this.id, {super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<CheckoutScreen> {
  String? address;
  DateTime date = DateTime.now();
  final key = newKey();
  bool busy = false;
  Object? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (address == null) {
      setState(() =>
          error = ApiFailure(ref.read(stringsProvider).chooseDeliveryAddress));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await ref.read(repositoryProvider).write(
          '/orders',
          {
            'reservation_id': widget.id,
            'delivery_address_id': address,
            'preferred_delivery_date': date.toIso8601String().split('T').first,
            'payment_method': 'pay_on_delivery'
          },
          key: key);
      ref.invalidate(resourceProvider('/orders'));
      ref.invalidate(listingsProvider);
      if (mounted) context.go('/confirmation/${response['id']}');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.checkout)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView('/reservations/${widget.id}', builder: (data) {
            final hold = Reservation.fromJson(Map<String, dynamic>.from(data));
            final remaining = hold.expiresAt.difference(DateTime.now());
            final expired = remaining.isNegative || hold.status != 'active';
            // The server decides which methods this order may use.
            final allowed = List<String>.from(
                data['payment_methods'] as List? ?? const ['pay_on_delivery']);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label(data['listing']['category']),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  MoneySummary({
                    s.quantity:
                        '${amount(hold.quantity)} ${s.unit('${data['listing']['unit_type']}', num.tryParse(hold.quantity))}',
                    s.pricePerUnit:
                        tsh(data['listing']['buyer_price_per_unit']),
                    s.estimatedTotal: tsh(num.parse(hold.quantity) *
                        num.parse('${data['listing']['buyer_price_per_unit']}'))
                  }),
                  const SizedBox(height: 12),
                  Text(
                      expired
                          ? s.reservationExpired
                          : s.stockHeldFor(
                              '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'),
                      style: TextStyle(
                          color: expired ? OColors.error : OColors.secondary)),
                  SectionHeader(s.deliveryAddressTitle),
                  ResourceView('/addresses', builder: (rows) {
                    // Start on the default delivery address (listed first).
                    if (address == null && (rows as List).isNotEmpty) {
                      address = ((rows.firstWhere(
                          (a) => a['is_default'] == true,
                          orElse: () => rows.first)) as Map)['id'] as String?;
                    }
                    return Column(children: [
                      for (final a in rows)
                        ListTile(
                            selected: address == a['id'],
                            leading: Icon(address == a['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            onTap: busy
                                ? null
                                : () => setState(() => address = a['id']),
                            title: Text(a['label']),
                            subtitle:
                                Text('${a['district_area']}, ${a['region']}')),
                      TextButton.icon(
                          onPressed: () async {
                            await context.push('/addresses/new');
                            ref.invalidate(resourceProvider('/addresses'));
                          },
                          icon: const Icon(Icons.add),
                          label: Text(s.addDeliveryAddress))
                    ]);
                  }),
                  SectionHeader(s.preferredDelivery),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.date(date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: busy
                          ? null
                          : () async {
                              final chosen = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime.now()
                                      .subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)));
                              if (chosen != null) setState(() => date = chosen);
                            }),
                  SectionHeader(ref.s.paymentMethod),
                  // Both methods render as designed. Pay Now stays disabled until
                  // the backend actually lists it, so no buyer can select a method
                  // that cannot complete.
                  _PaymentOption(
                      title: ref.s.payNow,
                      subtitle: ref.s.payNowSoon,
                      icon: Icons.smartphone_outlined,
                      selected: false,
                      enabled: allowed.contains('pay_now'),
                      onTap: null),
                  const SizedBox(height: 10),
                  _PaymentOption(
                      title: ref.s.payOnDelivery,
                      subtitle: ref.s.payOnDeliveryBody,
                      icon: Icons.payments_outlined,
                      selected: true,
                      enabled: true,
                      onTap: () {}),
                  if (error != null) ErrorState(error!),
                  const SizedBox(height: 24),
                  OmoterraButton(ref.s.confirmOrder,
                      busy: busy, onPressed: expired ? null : submit)
                ]);
          })
        ]));
  }
}

class _PaymentOption extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool selected, enabled;
  final VoidCallback? onTap;
  const _PaymentOption(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.selected,
      required this.enabled,
      this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: enabled ? 1 : .55,
      child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: selected ? OColors.soft : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: selected ? OColors.forest : OColors.border,
                      width: selected ? 1.5 : 1)),
              child: Row(children: [
                Icon(icon,
                    size: 21, color: enabled ? OColors.forest : OColors.muted),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: OColors.secondary)),
                    ])),
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? OColors.forest : OColors.border),
              ]))));
}
