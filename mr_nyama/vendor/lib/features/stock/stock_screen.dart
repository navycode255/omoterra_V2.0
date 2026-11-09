import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../sales/checkout.dart';
import '../sales/product_images.dart';
import '../sales/sales_store.dart';

/// One scroll viewport for heading, actions, live stock and closing action.
class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final refresh = ref.watch(catalogRefreshProvider);
    final products = ref.watch(productsProvider);
    return MNReferencePage(
        child: MNRefreshArea(
      color: MNColors.red,
      onRefresh: () => ref
          .refresh(catalogRefreshProvider.future)
          .then((_) {}, onError: (_) {}),
      child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: MNVendorHeading(
                    brand: strings.brand, title: strings.products)),
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                sliver: SliverToBoxAdapter(
                    child: Column(children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final children = [
                      _StockAction(
                          icon: MNIconData.receiveBox,
                          label: strings.referenceReceive,
                          onTap: () => context.push(MNRoutes.receive)),
                      _StockAction(
                          icon: MNIconData.brokenBox,
                          label: strings.referenceDamaged,
                          onTap: () => context.push(MNRoutes.damaged)),
                    ];
                    if (MediaQuery.textScalerOf(context).scale(16) > 23) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            children[0],
                            const SizedBox(height: 8),
                            children[1]
                          ]);
                    }
                    return IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Expanded(child: children[0]),
                          const SizedBox(width: 8),
                          Expanded(child: children[1])
                        ]));
                  }),
                  const SizedBox(height: 16),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 44, 10),
                      child: Row(children: [
                        Expanded(
                            child: Semantics(
                                header: true,
                                child: Text(strings.myStock,
                                    style: MNText.referenceSection))),
                        SizedBox(
                            width: 46,
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(strings.stockQuantity,
                                    style: MNText.referenceCaption))),
                      ])),
                ]))),
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                sliver: switch (products) {
                  AsyncData(:final value) when value.isNotEmpty =>
                    SliverToBoxAdapter(
                        child: MNReferenceSurface(
                            child: Column(children: [
                      for (final (i, p) in value.indexed)
                        MNStockRow(
                            first: i == 0,
                            referenceStyle: true,
                            name: p.name,
                            unit: strings.stockUnit(p.name),
                            image: productImageFor(p.imageKey,
                                productName: p.name),
                            quantity: p.remaining == null
                                ? null
                                : (p.remaining! < 0 ? 0 : p.remaining!)
                                    .toString(),
                            onTap: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => _StockDetails(product: p))),
                    ]))),
                  AsyncData() when !refresh.isLoading => SliverToBoxAdapter(
                      child: MNEmptyState(
                          icon: MNIconData.box,
                          title: strings.noProducts,
                          message: strings.notConnected)),
                  AsyncError(:final error) => SliverToBoxAdapter(
                      child: MNErrorState(
                          error: error,
                          onRetry: () => ref.invalidate(productsProvider))),
                  _ => const SliverToBoxAdapter(
                      child: SizedBox(
                          height: MNSize.row * 4,
                          child: MNLoadingState(rows: 4))),
                }),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 32),
                sliver: SliverToBoxAdapter(
                    child: MNReferenceSurface(
                        child: MNReferenceMenuAction(
                            icon: MNIconData.lock,
                            label: strings.referenceCloseDay,
                            color: MNColors.referenceMuted,
                            onTap: () => context.push(MNRoutes.closeDay))))),
          ]),
    ));
  }
}

class _StockAction extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final VoidCallback onTap;
  const _StockAction(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => MNReferenceSurface(
      child: MNPressable(
          onTap: onTap,
          semanticLabel: label,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Row(children: [
                MNIcon(icon, size: 26),
                const SizedBox(width: 12),
                Expanded(
                    child: ExcludeSemantics(
                        child: Text(label, style: MNText.referenceBody)))
              ]))));
}

/// Read-only stock details; selling is an explicit action in Mauzo.
class _StockDetails extends ConsumerWidget {
  final Product product;
  const _StockDetails({required this.product});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final current = ref.watch(productsProvider).valueOrNull;
    final p = current?.where((p) => p.id == product.id).firstOrNull ?? product;
    final remaining = p.remaining;
    return SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                      child: MNProductImage.thumb(
                          image:
                              productImageFor(p.imageKey, productName: p.name),
                          size: 100)),
                  const SizedBox(height: 16),
                  Text(p.name, style: MNText.referenceSection),
                  if (strings.stockUnit(p.name).isNotEmpty)
                    Text(strings.stockUnit(p.name),
                        style: MNText.referenceCaption),
                  const SizedBox(height: 12),
                  Text(
                      remaining == null
                          ? strings.unknownQuantity
                          : strings
                              .remaining('${remaining < 0 ? 0 : remaining}'),
                      style: MNText.referenceBody),
                  Text(p.price == null ? strings.noPrice : formatTsh(p.price!),
                      style: MNText.referenceBody),
                  const SizedBox(height: 24),
                  MNButton(strings.recordSale, onPressed: () {
                    Navigator.pop(context);
                    context.go(MNRoutes.sales);
                  }),
                ])));
  }
}
