import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/logo.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/states.dart';
import 'cart.dart';
import 'checkout.dart';
import 'product_images.dart';
import 'quantity_sheet.dart';
import 'sales_store.dart';

/// Mauzo: the two-column product grid. One tap adds one unit, instantly;
/// the stepper adjusts; long-press (or the number) opens the quantity sheet
/// for typing a number. The cart bar sits above the navigation (shell).
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  int _category = 0;

  void _add(Product product) {
    HapticFeedback.selectionClick();
    ref.read(cartProvider.notifier).add(product.id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final refresh = ref.watch(catalogRefreshProvider);
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark
            .copyWith(statusBarColor: MNColors.pageBackground),
        child: Scaffold(
          backgroundColor: MNColors.pageBackground,
          body: SafeArea(
              bottom: false,
              child: MNRefreshArea(
                color: MNColors.red,
                onRefresh: () => ref
                    .refresh(catalogRefreshProvider.future)
                    .then((_) {}, onError: (_) {}),
                child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                          child: _SalesHeading(
                              brand: strings.brand,
                              title: strings.sales,
                              history: strings.history,
                              onHistory: () => context.push(MNRoutes.history))),
                      if (products case AsyncData(:final value)
                          when value.isNotEmpty)
                        _Catalog(
                            products: value,
                            category: _category,
                            onCategory: (i) => setState(() => _category = i),
                            quantities: cart.lines,
                            onAdd: _add,
                            onDecrease: (p) => ref
                                .read(cartProvider.notifier)
                                .setQuantity(p.id, cart.quantityOf(p.id) - 1),
                            onOpen: (p) => showQuantitySheet(context, p))
                      else
                        SliverFillRemaining(
                            hasScrollBody: true,
                            child: MNAsyncView(
                              value: products,
                              isEmpty: (value) => value.isEmpty,
                              refreshing: refresh.isLoading,
                              loadingRows: 4,
                              empty: (_) => MNEmptyState(
                                  icon: MNIconData.bag,
                                  title: strings.noProducts,
                                  // Downloaded and empty: the station holds
                                  // nothing yet, the network is fine.
                                  message: refresh.hasValue
                                      ? strings.catalogNothingReceived
                                      : strings.catalogOffline,
                                  action: MNButton.secondary(strings.retry,
                                      onPressed: () => ref
                                          .invalidate(catalogRefreshProvider))),
                              onRetry: () => ref.invalidate(productsProvider),
                              data: (_) => const SizedBox.shrink(),
                            )),
                    ]),
              )),
        ));
  }
}

class _Catalog extends ConsumerWidget {
  final List<Product> products;
  final int category;
  final ValueChanged<int> onCategory;
  final Map<String, int> quantities;
  final void Function(Product) onAdd;
  final void Function(Product) onDecrease;
  final void Function(Product) onOpen;

  const _Catalog(
      {required this.products,
      required this.category,
      required this.onCategory,
      required this.quantities,
      required this.onAdd,
      required this.onDecrease,
      required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    // The stock as it will be after the cart too, cuts included.
    final stock = ref.watch(saleStockProvider);
    final categories = <String>{
      for (final p in products)
        if (p.category.isNotEmpty) p.category
    }.toList();
    final selected = category > categories.length ? 0 : category;
    final shown = selected == 0
        ? products
        : products.where((p) => p.category == categories[selected - 1]);
    return SliverMainAxisGroup(slivers: [
      if (categories.length > 1)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: MNSpace.x2),
            child: MNChipBar(
              labels: [
                strings.all,
                for (final c in categories) strings.category(c)
              ],
              selected: selected,
              onSelect: onCategory,
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            MNSpace.x4, MNSpace.x3, MNSpace.x4, MNSpace.x6),
        sliver: SliverToBoxAdapter(
          child: MNProductGrid(children: [
            for (final p in shown)
              MNProductCard(
                key: ValueKey(p.id),
                referenceStyle: true,
                name: p.name,
                price: p.price,
                image: productImageFor(p.imageKey, productName: p.name),
                // The pieces lying at the station once the cart is taken;
                // none left but more can be cut says so. Oversold shows 0;
                // the lines carry the flag.
                remaining: switch ((
                  p.remaining == null
                      ? null
                      : stock.remaining[p.id] ?? p.remaining,
                  stock.sellable[p.id] ?? p.availableToSell
                )) {
                  (null, _) => null,
                  (final int left, final int? can)
                      when left <= 0 && (can ?? 0) > 0 =>
                    strings.cutOnSale,
                  (final int left, _) => (left < 0 ? 0 : left).toString(),
                },
                quantity: quantities[p.id] ?? 0,
                selected: (quantities[p.id] ?? 0) > 0,
                onTap: () => onAdd(p),
                onAdd: () => onAdd(p),
                onDecrease: () => onDecrease(p),
                onLongPress: () => onOpen(p),
                onQuantityTap: () => onOpen(p),
              ),
          ]),
        ),
      ),
    ]);
  }
}

/// Brand, history and large title follow the light screen pattern. They scroll
/// away with the grid, leaving the cart bar reachable above navigation.
class _SalesHeading extends StatelessWidget {
  final String brand, title, history;
  final VoidCallback onHistory;
  const _SalesHeading(
      {required this.brand,
      required this.title,
      required this.history,
      required this.onHistory});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox.square(
              dimension: 30, child: MNLogo(height: 30, semanticLabel: brand)),
          const SizedBox(width: 10),
          Expanded(
              child: ExcludeSemantics(
                  child: Text(brand, style: MNText.brandTitle))),
          MNIconButton(MNIconData.list,
              label: history, color: MNColors.ink, onPressed: onHistory),
        ]),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(title, style: MNText.pageTitle)),
        const SizedBox(height: 4),
      ]));
}
