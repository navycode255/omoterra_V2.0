import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import 'inventory_screens.dart';
import 'stock_list_screen.dart';

class SupplierHome extends ConsumerWidget {
  const SupplierHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
              s.greeting(ref
                      .watch(sessionProvider)
                      .valueOrNull
                      ?.name
                      .split(' ')
                      .first ??
                  ''),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          ResourceView('/supplier/stock', builder: (rows) {
            return Column(children: [
              StockBalances(rows, labels: s),
              for (final row in rows)
                if (row['listing_status'] == 'needs_confirmation')
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFDF8F0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFF0DEC4))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.schedule,
                                      size: 17, color: OColors.warning),
                                  const SizedBox(width: 7),
                                  Text(s.confirmStock,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                    s.confirmStockBody(
                                        amount(row['quantity_available']),
                                        label(row['category']).toLowerCase()),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: OColors.secondary)),
                                const SizedBox(height: 8),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 34)),
                                    onPressed: () =>
                                        context.push('/stock/${row['id']}'),
                                    child: Text(
                                        s.confirmQty(amount(
                                            row['quantity_available']))))
                              ])))
            ]);
          }),
          const SizedBox(height: 12),
          ResourceView('/supplier/payouts',
              builder: (rows) => InkWell(
                  onTap: () => context.push('/payouts'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: OColors.soft,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(s.expectedPayment,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: OColors.secondary)),
                              const SizedBox(height: 5),
                              Text(
                                  tsh((rows as List)
                                      .where((r) => r['status'] == 'pending')
                                      .fold<num>(
                                          0,
                                          (sum, r) => sum +
                                              num.parse(
                                                  '${r['total_payable']}'))),
                                  style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                      color: OColors.forest)),
                            ])),
                        const Icon(Icons.chevron_right, color: OColors.forest),
                      ])))),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: () => context.push('/stock/new'),
              icon: const Icon(Icons.add, size: 19),
              label: Text(s.addStock)),
          const SizedBox(height: 10),
          OmoterraButton('Sales records',
              secondary: true, onPressed: () => context.push('/sales')),
          SectionHeader(s.yourStock,
              action: s.viewAll, onTap: () => context.go('/stock')),
          const StockList()
        ]);
  }
}
