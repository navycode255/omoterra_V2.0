import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/sync_indicator.dart';
import 'sale_success_mark.dart';
import 'sales_store.dart';

final _savedSaleProvider = FutureProvider.autoDispose
    .family<SavedSale?, String>(
        (ref, id) => ref.watch(salesStoreProvider).sale(id));

/// "Mauzo Yamehifadhiwa!": read back from the phone's database, so it only
/// ever describes a sale that was really saved. The sync line says where
/// the sale stands: on the phone, waiting to be sent.
class SaleSavedScreen extends ConsumerWidget {
  final String clientId;
  const SaleSavedScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final sale = ref.watch(_savedSaleProvider(clientId));
    return PopScope(
      // Back goes to the catalogue, never to the emptied cart.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(MNRoutes.sales);
      },
      child: Scaffold(
        backgroundColor: MNColors.white,
        body: SafeArea(
          child: switch (sale) {
            AsyncData(value: final s?) => _Saved(sale: s),
            AsyncData() || AsyncError() => const MNErrorState(),
            _ => const SizedBox.shrink(),
          },
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              MNButton(strings.recordAnother,
                  onPressed: () => context.go(MNRoutes.sales)),
              const SizedBox(height: MNSpace.x2),
              MNButton.secondary(strings.backHome,
                  onPressed: () => context.go(MNRoutes.home)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Saved extends ConsumerWidget {
  final SavedSale sale;
  const _Saved({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MNSpace.x6),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: MNSpace.x6),
              SaleSuccessMark(
                  key: ValueKey(sale.clientId), playId: sale.clientId),
              const SizedBox(height: MNSpace.x6),
              Semantics(
                liveRegion: true,
                child: Text(strings.saleSaved,
                    textAlign: TextAlign.center, style: MNText.heading),
              ),
              const SizedBox(height: MNSpace.x2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatTsh(sale.total),
                    style: MNText.amountLarge.copyWith(color: MNColors.red)),
              ),
              const SizedBox(height: MNSpace.x2),
              Text(strings.itemsAt(sale.itemCount, sale.recordedAt),
                  textAlign: TextAlign.center,
                  style: MNText.body.copyWith(color: MNColors.ink2)),
              const SizedBox(height: MNSpace.x6),
              Text(strings.savedOnPhone,
                  style: MNText.status.copyWith(color: MNColors.ink2)),
              const SizedBox(height: MNSpace.x1),
              MNSyncIndicator(
                  status: sale.sent ? MNSyncStatus.sent : MNSyncStatus.waiting),
              const SizedBox(height: MNSpace.x6),
            ],
          ),
        ),
      ),
    );
  }
}
