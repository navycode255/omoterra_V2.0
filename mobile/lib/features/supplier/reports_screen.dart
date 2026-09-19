import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

/// A summary built entirely from data the app already fetches elsewhere
/// (sales + payouts) — there is no dedicated reports endpoint, so this reads
/// the same two resources Sales records and Payouts already use rather than
/// asking the backend for something new.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const OmoterraAppBar(title: Text('Reports')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Your business at a glance',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
            'Pulled from your sales and payout records — nothing to set up.',
            style: TextStyle(color: OColors.secondary)),
        const SizedBox(height: 20),
        ResourceView('/supplier/sales', builder: (rows) {
          final sales = List<Map<String, dynamic>>.from(rows as List)
              .where((r) => r['status'] != 'reversed')
              .toList();
          final byCategory = <String, num>{};
          for (final s in sales) {
            byCategory[label(s['category'])] = (byCategory[label(s['category'])] ?? 0) +
                num.parse('${s['quantity']}');
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Sold'),
            if (byCategory.isEmpty)
              const EmptyState('Nothing sold yet',
                  'Recorded sales and Omoterra deliveries will summarise here.')
            else
              MoneySummary({
                for (final e in byCategory.entries) e.key: amount(e.value)
              }),
          ]);
        }),
        const SizedBox(height: 24),
        ResourceView('/supplier/payouts', builder: (rows) {
          final payouts = List<Map<String, dynamic>>.from(rows as List);
          final pending = payouts
              .where((r) => r['status'] == 'pending')
              .fold<num>(
                  0, (sum, r) => sum + num.parse('${r['total_payable']}'));
          final paid = payouts
              .where((r) => r['status'] == 'paid')
              .fold<num>(
                  0, (sum, r) => sum + num.parse('${r['total_payable']}'));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Earned'),
            MoneySummary({'Pending': tsh(pending), 'Paid out': tsh(paid)}),
          ]);
        }),
      ]));
}
