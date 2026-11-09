import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/sync/sync_engine.dart';
import '../core/theme/theme.dart';
import '../core/routing/routes.dart';
import '../features/history/history_recovery.dart';
import '../features/sales/checkout.dart';
import '../shared/widgets/bottom_nav.dart';
import '../shared/widgets/cart_summary.dart';

/// The three main destinations: Nyumbani | Mauzo | Bidhaa. Each tab keeps
/// its own state (an indexed stack). Android back on Mauzo or Bidhaa
/// returns to Nyumbani; back on Nyumbani leaves the app.
///
/// The tabs stay alive all day, so the catalogue (prices, photos, expense
/// categories) is downloaded again when the app returns to the foreground
/// and after every successful sync, not only when a tab first opens.
class MNShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  const MNShell({super.key, required this.shell});
  @override
  ConsumerState<MNShell> createState() => _MNShellState();
}

class _MNShellState extends ConsumerState<MNShell> with WidgetsBindingObserver {
  StatefulNavigationShell get shell => widget.shell;

  void _select(int index) =>
      // Tapping the open tab returns it to its first screen.
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A new phone (or a reinstall) gets the vendor's records back from the
    // server; quietly, never in the way of selling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(historyRecoveryProvider.notifier).recoverIfEmpty();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(catalogRefreshProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncEngineProvider, (before, after) {
      if (before?.running == true &&
          !after.running &&
          after.lastOutcome == 'ok') {
        ref.invalidate(catalogRefreshProvider);
      }
    });
    final strings = ref.watch(stringsProvider);
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: MNTabTransition(index: shell.currentIndex, child: shell),
        // The active cart stays reachable above the navigation on every tab.
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          MNCartBar(
            itemCount: ref
                .watch(cartLinesProvider)
                .fold(0, (n, line) => n + line.quantity),
            total: ref.watch(cartTotalProvider),
            onTap: () => context.push(MNRoutes.cart),
          ),
          MNBottomNav(
            currentIndex: shell.currentIndex,
            onSelect: _select,
            items: [
              MNNavItem(MNIconData.home, strings.home),
              MNNavItem(MNIconData.bag, strings.sales),
              MNNavItem(MNIconData.box, strings.products),
            ],
          ),
        ]),
      ),
    );
  }
}
