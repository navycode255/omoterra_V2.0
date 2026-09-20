import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/session.dart';
import '../api/repository.dart';
import '../../features/authentication/screens.dart';
import '../../features/buyer/screens.dart';
import '../../features/buyer/requests.dart';
import '../../features/supplier/screens.dart';
import '../../features/supplier/inventory_screens.dart';
import '../../shared/widgets/supply_art.dart';
import '../../features/account/screens.dart';
import '../../shared/widgets/components.dart';
import '../theme/theme.dart';

String? routeGuard(String path,
    {required bool signedIn,
    required bool setup,
    required List<String> roles}) {
  final authRoute = ['/welcome', '/phone', '/otp'].contains(path);
  if (!signedIn) return authRoute ? null : '/welcome';
  if (!setup) return path == '/setup' ? null : '/setup';
  if (authRoute || path == '/setup' || path == '/') {
    return roles.contains('buyer') ? '/buyer' : '/supplier';
  }
  final supplierPath = path.startsWith('/supplier') ||
      path.startsWith('/stock') ||
      path.startsWith('/payouts') ||
      path.startsWith('/sales');
  final commonPath = path.startsWith('/account');
  if (supplierPath && !roles.contains('supplier')) return '/buyer';
  if (!supplierPath && !commonPath && !roles.contains('buyer')) {
    return '/supplier';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => notifier.value++);
  final router = GoRouter(
      initialLocation: '/buyer',
      refreshListenable: notifier,
      redirect: (context, state) {
        final session = ref.read(sessionProvider);
        if (session.isLoading || session.hasError) {
          return state.uri.path == '/session' ? null : '/session';
        }
        final user = session.valueOrNull;
        if (state.uri.path == '/session') {
          return user == null
              ? '/welcome'
              : user.roles.contains('buyer')
                  ? '/buyer'
                  : '/supplier';
        }
        return routeGuard(state.uri.path,
            signedIn: user != null,
            setup: user != null &&
                user.name.isNotEmpty &&
                user.roles.any((r) => r == 'buyer' || r == 'supplier'),
            roles: user?.roles ?? []);
      },
      routes: [
        GoRoute(path: '/session', builder: (_, __) => const SessionScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        GoRoute(path: '/phone', builder: (_, __) => const PhoneScreen()),
        GoRoute(
            path: '/otp',
            builder: (_, state) => state.extra is Map<String, dynamic>
                ? OtpScreen(state.extra! as Map<String, dynamic>)
                : const PhoneScreen()),
        GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
        ShellRoute(
            builder: (_, state, child) =>
                AppShell(path: state.uri.path, child: child),
            routes: [
              GoRoute(path: '/buyer', builder: (_, __) => const BuyerHome()),
              GoRoute(
                  path: '/explore',
                  builder: (_, s) => ExploreScreen(
                      initialCategory:
                          s.uri.queryParameters['category'] ?? '')),
              GoRoute(
                  path: '/orders', builder: (_, __) => const OrdersScreen()),
              GoRoute(
                  path: '/account', builder: (_, __) => const AccountScreen()),
              GoRoute(
                  path: '/supplier', builder: (_, __) => const SupplierHome()),
              GoRoute(path: '/stock', builder: (_, __) => const StockScreen()),
              GoRoute(
                  path: '/supplier-orders',
                  builder: (_, __) => const SupplierOrders()),
            ]),
        GoRoute(
            path: '/listing/:id',
            builder: (_, s) => ListingDetail(s.pathParameters['id']!)),
        GoRoute(
            path: '/checkout/:id',
            builder: (_, s) => CheckoutScreen(s.pathParameters['id']!)),
        GoRoute(
            path: '/confirmation/:id',
            builder: (_, s) => OrderConfirmation(s.pathParameters['id']!)),
        GoRoute(
            path: '/order/:id',
            builder: (_, s) => OrderDetail(s.pathParameters['id']!)),
        GoRoute(
            path: '/request', builder: (_, __) => const RequestSupplyScreen()),
        GoRoute(
            path: '/request-submitted/:id',
            builder: (_, s) => RequestSubmitted(s.pathParameters['id']!)),
        GoRoute(
            path: '/requests/:id',
            builder: (_, s) => RequestDetail(s.pathParameters['id']!)),
        GoRoute(path: '/business', builder: (_, __) => const BusinessScreen()),
        GoRoute(
            path: '/business/:type/request',
            builder: (_, s) =>
                BusinessScreen(type: s.pathParameters['type'], request: true)),
        GoRoute(
            path: '/business/:type',
            builder: (_, s) => BusinessScreen(type: s.pathParameters['type'])),
        GoRoute(
            path: '/business-submitted',
            builder: (context, _) => Scaffold(
                appBar: const OmoterraAppBar(),
                body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyState('Request received',
                        'Your request has been received. An Omoterra team member will contact you.',
                        action: OmoterraButton('Back to Home',
                            onPressed: () => context.go('/buyer')))))),
        GoRoute(
            path: '/account/support',
            builder: (_, __) => const AccountInfoScreen('support')),
        GoRoute(
            path: '/account/terms',
            builder: (_, __) => const AccountInfoScreen('terms')),
        GoRoute(
            path: '/account/privacy',
            builder: (_, __) => const AccountInfoScreen('privacy')),
        GoRoute(
            path: '/account/edit', builder: (_, __) => const ProfileScreen()),
        GoRoute(
            path: '/addresses', builder: (_, __) => const AddressesScreen()),
        GoRoute(
            path: '/addresses/new',
            builder: (_, s) => AddressesScreen(
                create: true, edit: s.extra as Map<String, dynamic>?)),
        GoRoute(
            path: '/stock/:id/correct',
            builder: (_, s) =>
                StockChangeScreen(s.pathParameters['id']!, 'correct')),
        GoRoute(
            path: '/stock/:id/add',
            builder: (_, s) =>
                StockChangeScreen(s.pathParameters['id']!, 'add')),
        GoRoute(
            path: '/stock/:id/sell',
            builder: (_, s) => RecordSaleScreen(s.pathParameters['id']!)),
        GoRoute(
            path: '/stock/:id/history',
            builder: (_, s) => StockHistoryScreen(s.pathParameters['id']!)),
        GoRoute(path: '/sales', builder: (_, __) => const SalesScreen()),
        GoRoute(
            path: '/sales/:id',
            builder: (_, s) => SalesScreen(id: s.pathParameters['id'])),
        GoRoute(path: '/stock/new', builder: (_, __) => const AddStockScreen()),
        GoRoute(
            path: '/stock/:id',
            builder: (_, s) => StockDetail(s.pathParameters['id']!)),
        GoRoute(
            path: '/supplier-orders/:id',
            builder: (_, s) => SupplierOrders(id: s.pathParameters['id'])),
        GoRoute(path: '/payouts', builder: (_, __) => const PayoutScreen()),
        GoRoute(
            path: '/payouts/:id',
            builder: (_, s) => PayoutScreen(id: s.pathParameters['id'])),
      ],
      errorBuilder: (context, _) => Scaffold(
          appBar: const OmoterraAppBar(),
          body: Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyState(
                  'Page unavailable', 'Return to your home to continue.',
                  action: OmoterraButton('Home',
                      onPressed: () => context.go('/buyer'))))));
  ref.onDispose(() {
    router.dispose();
    notifier.dispose();
  });
  return router;
});

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    // While the stored session is being restored the designed splash stands in
    // for a loading state; only a real failure replaces it with recovery UI.
    if (!session.hasError) return const SplashScreen();
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: session.hasError
                    ? Column(children: [
                        ErrorState(session.error!,
                            retry: () => ref.invalidate(sessionProvider)),
                        TextButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(sessionProvider.notifier)
                                    .logout();
                              } catch (_) {}
                            },
                            child: const Text('Sign in again'))
                      ])
                    : const SizedBox.shrink())));
  }
}

class AppShell extends ConsumerWidget {
  final String path;
  final Widget child;
  const AppShell({super.key, required this.path, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final supplier = path.startsWith('/supplier') ||
        path == '/stock' ||
        (path == '/account' &&
            (ref.watch(activeRoleProvider) == 'supplier' ||
                user?.roles.contains('buyer') == false));
    final routes = supplier
        ? ['/supplier', '/stock', '/supplier-orders', '/account']
        : ['/buyer', '/explore', '/orders', '/account'];
    // Supplier Home carries its own full-bleed banner photo behind the nav,
    // so only that one screen extends the body behind the app bar. Every
    // other tab — buyer and supplier alike — keeps the plain nav bar. The
    // nav Row below is never role-conditional: same logo, same padding,
    // same role pill in the same place, whichever role is active.
    final onSupplierHome = path == '/supplier';
    // The tabbed screens are the root of the signed-in app, so the system
    // back gesture should leave the app rather than be swallowed.
    return ExitOnBack(
        child: Scaffold(
        extendBodyBehindAppBar: onSupplierHome,
        appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: SafeArea(
                bottom: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                    // The logo hugs the left edge on its own (not Expanded,
                    // which would center it in the leftover space); the role
                    // switcher sits at the right with whatever room remains.
                    child: Row(children: [
                      const BrandMark(size: 21),
                      const Spacer(),
                      _RoleSwitcher(supplier: supplier),
                    ])))),
        body: SafeArea(
            top: false,
            child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(resourceProvider);
                  ref.invalidate(listingsProvider);
                },
                child: child)),
        bottomNavigationBar: _BottomNav(
            selected: routes.indexOf(path).clamp(0, 3),
            onSelect: (i) => context.go(routes[i]),
            items: [
              const _NavItem(Icons.home_outlined, Icons.home, 'Home'),
              _NavItem(
                  supplier ? Icons.inventory_2_outlined : Icons.search,
                  supplier ? Icons.inventory_2 : Icons.search,
                  supplier ? 'Stock' : 'Explore'),
              const _NavItem(Icons.receipt_long_outlined, Icons.receipt_long,
                  'Orders'),
              const _NavItem(
                  Icons.person_outline, Icons.person, 'Account'),
            ])));
  }
}

class _NavItem {
  final IconData icon, selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

/// The floating bottom nav: a rounded white bar holding the four tabs,
/// lifted off the screen edge so it reads as its own surface.
class _BottomNav extends StatelessWidget {
  final int selected;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;
  const _BottomNav(
      {required this.selected, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 8 : 16),
        child: Container(
            height: 64,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ]),
            child: Row(
                children: [_tab(0), _tab(1), _tab(2), _tab(3)])));
  }

  Widget _tab(int i) {
    final item = items[i];
    final active = i == selected;
    return Expanded(
        child: Semantics(
            button: true,
            selected: active,
            label: item.label,
            child: InkWell(
                onTap: () => onSelect(i),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(active ? item.selectedIcon : item.icon,
                          size: 23,
                          color: active ? OColors.forest : OColors.muted),
                      const SizedBox(height: 3),
                      Text(item.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  active ? OColors.forest : OColors.muted)),
                    ]))));
  }
}

/// The pill in the top nav that switches between Buyer and Supplier right
/// there, instead of going via Account. Account still has its own switch
/// too — this is a second, faster place to do the same thing, not a
/// replacement for it. The shell's chrome (tabs, colours) is keyed off the
/// route rather than the active-role provider alone, so picking a role here
/// also lands on that role's home tab — the same one tap away, just without
/// a detour through Account first.
class _RoleSwitcher extends ConsumerWidget {
  final bool supplier;
  const _RoleSwitcher({required this.supplier});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
      tooltip: 'Switch role',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (role) async {
        await ref.read(sessionProvider.notifier).switchRole(role);
        if (context.mounted) {
          context.go(role == 'buyer' ? '/buyer' : '/supplier');
        }
      },
      itemBuilder: (context) => [
            _roleItem('buyer', 'Buyer', !supplier),
            _roleItem('supplier', 'Supplier', supplier),
          ],
      child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
              color: OColors.soft, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.person, size: 15, color: OColors.forest),
            const SizedBox(width: 5),
            Text(supplier ? 'SUPPLIER' : 'BUYER',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    color: OColors.forest)),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: OColors.forest),
          ])));

  PopupMenuItem<String> _roleItem(String role, String label, bool active) =>
      PopupMenuItem(
          value: role,
          child: Row(children: [
            Icon(active ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: active ? OColors.forest : OColors.muted),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ]));
}
