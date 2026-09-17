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
                appBar: AppBar(),
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
          appBar: AppBar(),
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
    return Scaffold(
        appBar: AppBar(title: const BrandMark(size: 23), actions: [
          Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                  child: Text(supplier ? 'SUPPLIER' : 'BUYER',
                      style:
                          const TextStyle(fontSize: 10, letterSpacing: 1.5))))
        ]),
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(resourceProvider);
                  ref.invalidate(listingsProvider);
                },
                child: child)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: routes.indexOf(path).clamp(0, 3),
            onDestinationSelected: (i) => context.go(routes[i]),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(
                      supplier ? Icons.inventory_2_outlined : Icons.search),
                  label: supplier ? 'Stock' : 'Explore'),
              const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline), label: 'Account')
            ]));
  }
}
