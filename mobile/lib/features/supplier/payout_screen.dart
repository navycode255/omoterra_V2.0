import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import 'order_progress.dart';

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
                    Text(_state(s, data),
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: OColors.secondary)),
                    if (data['reference'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          '${s.label('${data['category']}')} · ${s.orderNo('${data['reference']}')}',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                    if (awaitsConfirmation(data)) ...[
                      const SizedBox(height: 16),
                      PayoutConfirmCard(data),
                    ],
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
                    ],
                    if ((data['confirmations'] as List? ?? const [])
                        .isNotEmpty) ...[
                      SectionHeader(s.payoutHistory),
                      for (final answer in data['confirmations'] as List)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                                [
                                  s.answer(answer['outcome'] == 'received',
                                      s.dateText(answer['created_at'])),
                                  if (answer['payment_reference'] != null)
                                    s.refText('${answer['payment_reference']}'),
                                  if ('${answer['note'] ?? ''}'.isNotEmpty)
                                    '“${answer['note']}”',
                                ].join(' · '),
                                style:
                                    const TextStyle(color: OColors.secondary))),
                    ],
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
                    subtitle: Text(_state(s, row),
                        style: TextStyle(
                            fontSize: 12.5,
                            color: awaitsConfirmation(row)
                                ? OColors.warning
                                : OColors.secondary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/payouts/${row['id']}'))
            ]);
          })
        ]));
  }
}

/// Where a payout is, from the supplier's side.
String _state(Strings s, Map payout) => payout['status'] != 'paid'
    ? s.payoutNotSent
    : payout['supplier_confirmation'] == 'received'
        ? s.receivedOn(s.dateText(payout['supplier_confirmed_at']))
        : payout['supplier_confirmation'] == 'not_received'
            ? s.orderStage('payout_disputed')
            : s.orderStage('confirm_payout');
