import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/supply_art.dart';
import 'inventory_screens.dart';
import 'stock_list_screen.dart';

class SupplierHome extends ConsumerWidget {
  const SupplierHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    final name =
        ref.watch(sessionProvider).valueOrNull?.name.split(' ').first ?? '';
    return ListView(padding: EdgeInsets.zero, children: [
      _Banner(greeting: s.greeting(name)),
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          // Pulled up to overlap the banner's bottom edge, as drawn.
          child: Transform.translate(
              offset: const Offset(0, -28),
              child: Column(children: [
                _StockSummary(labels: s),
                const SizedBox(height: 12),
                _PayoutSummary(labels: s),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                      child: OmoterraButton(s.addStock,
                          icon: Icons.add,
                          onPressed: () => context.push('/stock/new'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: OmoterraButton('Sales records',
                          icon: Icons.receipt_long_outlined,
                          secondary: true,
                          onPressed: () => context.push('/sales'))),
                ]),
                SectionHeader(s.yourStock,
                    action: s.viewAll, onTap: () => context.go('/stock')),
                const StockList()
              ])))
    ]);
  }
}

/// Stock balances plus the "needs confirmation" nudge, if any — split out of
/// build() so the ResourceView's builder closure isn't nested five levels
/// deep inside the rest of the screen.
class _StockSummary extends StatelessWidget {
  final Strings labels;
  const _StockSummary({required this.labels});
  @override
  Widget build(BuildContext context) =>
      ResourceView('/supplier/stock', builder: (rows) {
        final s = labels;
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
                          border: Border.all(color: const Color(0xFFF0DEC4))),
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
                                    fontSize: 13, color: OColors.secondary)),
                            const SizedBox(height: 8),
                            TextButton(
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 34)),
                                onPressed: () =>
                                    context.push('/stock/${row['id']}'),
                                child: Text(s.confirmQty(
                                    amount(row['quantity_available']))))
                          ])))
        ]);
      });
}

class _PayoutSummary extends StatelessWidget {
  final Strings labels;
  const _PayoutSummary({required this.labels});
  @override
  Widget build(BuildContext context) =>
      ResourceView('/supplier/payouts', builder: (rows) {
        final s = labels;
        final pending = (rows as List)
            .where((r) => r['status'] == 'pending')
            .fold<num>(
                0, (sum, r) => sum + num.parse('${r['total_payable']}'));
        return InkWell(
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
                                fontSize: 12.5, color: OColors.secondary)),
                        const SizedBox(height: 5),
                        Text(tsh(pending),
                            style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: OColors.forest)),
                      ])),
                  const Icon(Icons.chevron_right, color: OColors.forest),
                ])));
      });
}

/// The full-bleed header photo behind the transparent nav (see AppShell),
/// with the greeting overlaid — this is the one screen where the nav sits on
/// top of a photo rather than a plain white bar.
class _Banner extends StatelessWidget {
  final String greeting;
  const _Banner({required this.greeting});
  @override
  Widget build(BuildContext context) => SizedBox(
      // Tall enough to clear the status bar + transparent nav above the
      // greeting text and still leave the photo room to read as a banner.
      height: MediaQuery.paddingOf(context).top + 220,
      child: Stack(fit: StackFit.expand, children: [
        const BrandImage('supplier_banner', fallbackArt: 'cattle'),
        const Positioned.fill(child: PhotoScrim(opacity: .18)),
        Positioned(
            right: -10,
            top: MediaQuery.paddingOf(context).top + 40,
            child: const Opacity(
                opacity: .55, child: LeafWatermark(size: 120))),
        Positioned(
            left: 20,
            right: 20,
            bottom: 44,
            child: Text(greeting,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 8)
                    ]))),
      ]));
}
