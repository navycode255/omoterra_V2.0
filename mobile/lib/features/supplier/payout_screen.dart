import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/components.dart';

class PayoutScreen extends StatelessWidget {
  final String? id;
  const PayoutScreen({super.key, this.id});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(id == null ? s.yourPayouts : s.payoutDetails)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView(
              id == null ? '/supplier/payouts' : '/supplier/payouts/$id',
              builder: (data) {
            if (id != null) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusText(data['status']),
                    const SizedBox(height: 24),
                    MoneySummary({
                      s.askingPriceTimes(amount(data['quantity'])): tsh(
                          num.parse('${data['farmer_asking_price_per_unit']}') *
                              num.parse('${data['quantity']}')),
                      s.commissionTimes(amount(data['quantity'])): tsh(
                          num.parse('${data['commission_amount_per_unit']}') *
                              num.parse('${data['quantity']}')),
                      s.yourPayout: tsh(data['total_payable'])
                    }),
                    if (data['payment_reference'] != null) ...[
                      const SizedBox(height: 24),
                      Text(s.paymentReference('${data['payment_reference']}'))
                    ]
                  ]);
            }
            final rows = data as List;
            if (rows.isEmpty) {
              return EmptyState(s.noPayoutsTitle, s.noPayoutsBody);
            }
            return Column(children: [
              MoneySummary({
                for (final status in ['pending', 'paid'])
                  s.status(status): tsh(rows
                      .where((r) => r['status'] == status)
                      .fold<num>(0,
                          (sum, r) => sum + num.parse('${r['total_payable']}')))
              }),
              const SizedBox(height: 24),
              for (final row in rows)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tsh(row['total_payable'])),
                    subtitle: StatusText(row['status']),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/payouts/${row['id']}'))
            ]);
          })
        ]));
  }
}
