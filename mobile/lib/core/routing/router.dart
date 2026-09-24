import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/session.dart';
import '../api/repository.dart';
import '../../features/authentication/screens.dart';
import '../../features/buyer/screens.dart';
import '../../features/buyer/requests.dart';
import '../../features/supplier/screens.dart';
import '../../features/supplier/market_demand_screen.dart';
import '../../features/supplier/inventory_screens.dart';
import '../../shared/widgets/supply_art.dart';
import '../../features/account/screens.dart';
import '../../features/account/role_registration_screen.dart';
import '../../shared/widgets/components.dart';
import '../theme/theme.dart';
import 'animated_route.dart';

String? routeGuard(String path,
    {required bool signedIn,
    required bool setup,
    required List<String> roles,
    String? activeRole}) {
  final authRoute = ['/language', '/welcome', '/phone', '/otp'].contains(path);
  if (!signedIn) return authRoute ? null : '/welcome';
  if (!setup) return path == '/setup' ? null : '/setup';
  if (authRoute || path == '/setup' || path == '/') {
    return '/${preferredRole(roles, activeRole)}';
  }
  final supplierPath = path.startsWith('/supplier') ||
      path.startsWith('/stock') ||
      path.startsWith('/batches') ||
      path.startsWith('/payouts') ||
      path.startsWith('/sales');
  final commonPath =
      path.startsWith('/account') || path.startsWith('/register-role');
  if (activeRole != null && !commonPath) {
    final selected = preferredRole(roles, activeRole);
    if (supplierPath != (selected == 'supplier')) return '/$selected';
  }
  if (supplierPath && !roles.contains('supplier')) return '/buyer';
  if (!supplierPath && !commonPath && !roles.contains('buyer')) {
    return '/supplier';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => notifier.value++);
  ref.listen(activeRoleProvider, (_, __) => notifier.value++);
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
              : !user.roles.any((r) => r == 'buyer' || r == 'supplier') ||
                      user.name.isEmpty
                  ? '/setup'
                  : '/${preferredRole(user.roles, ref.read(activeRoleProvider))}';
        }
        if (user == null &&
            !['/language', '/welcome', '/phone', '/otp']
                .contains(state.uri.path)) {
          return '/language';
        }
        return routeGuard(state.uri.path,
            signedIn: user != null,
            setup: user != null &&
                user.name.isNotEmpty &&
                user.roles.any((r) => r == 'buyer' || r == 'supplier'),
            roles: user?.roles ?? [],
            activeRole: ref.read(activeRoleProvider));
      },
      routes: [
        GoRoute(
            path: '/session',
            pageBuilder: (_, state) => NoTransitionPage<void>(
                key: state.pageKey, child: const SessionScreen())),
        omoterraRoute(
            path: '/language', builder: (_, __) => const LanguageScreen()),
        omoterraRoute(
            path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        omoterraRoute(path: '/phone', builder: (_, __) => const PhoneScreen()),
        omoterraRoute(
            path: '/otp',
            builder: (_, state) => state.extra is Map<String, dynamic>
                ? OtpScreen(state.extra! as Map<String, dynamic>)
                : const PhoneScreen()),
        omoterraRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
        omoterraRoute(
            path: '/register-role/:role',
            builder: (_, state) =>
                RoleRegistrationScreen(state.pathParameters['role']!)),
        ShellRoute(
            pageBuilder: (_, state, child) => NoTransitionPage<void>(
                key: state.pageKey,
                child: AppShell(path: state.uri.path, child: child)),
            routes: [
              omoterraRoute(
                  path: '/buyer',
                  animate: false,
                  builder: (_, __) => const BuyerHome()),
              omoterraRoute(
                  path: '/explore',
                  animate: false,
                  builder: (_, s) => ExploreScreen(
                      initialCategory:
                          s.uri.queryParameters['category'] ?? '')),
              omoterraRoute(
                  path: '/orders',
                  animate: false,
                  builder: (_, __) => const OrdersScreen()),
              omoterraRoute(
                  path: '/account',
                  animate: false,
                  builder: (_, __) => const AccountScreen()),
              omoterraRoute(
                  path: '/supplier',
                  animate: false,
                  builder: (_, __) => const SupplierHome()),
              omoterraRoute(
                  path: '/supplier-demand',
                  animate: false,
                  builder: (_, __) => const MarketDemandScreen()),
              omoterraRoute(
                  path: '/stock',
                  animate: false,
                  builder: (_, __) => const StockScreen()),
              omoterraRoute(
                  path: '/supplier-orders',
                  animate: false,
                  builder: (_, __) => const SupplierOrders()),
              omoterraRoute(
                  path: '/sales',
                  animate: false,
                  builder: (_, __) => const SalesScreen()),
              omoterraRoute(
                  path: '/sales/:id',
                  builder: (_, s) => SalesScreen(id: s.pathParameters['id'])),
              omoterraRoute(
                  path: '/supplier-demand/:id',
                  builder: (_, s) =>
                      DemandDetailScreen(s.pathParameters['id']!)),
              omoterraRoute(
                  path: '/supplier-orders/:id',
                  builder: (_, s) =>
                      SupplierOrders(id: s.pathParameters['id'])),
            ]),
        omoterraRoute(
            path: '/listing/:id',
            builder: (_, s) => ListingDetail(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/checkout/:id',
            builder: (_, s) => CheckoutScreen(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/confirmation/:id',
            builder: (_, s) => OrderConfirmation(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/order/:id',
            builder: (_, s) => OrderDetail(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/request', builder: (_, __) => const RequestSupplyScreen()),
        omoterraRoute(
            path: '/request-submitted/:id',
            builder: (_, s) => RequestSubmitted(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/requests/:id',
            builder: (_, s) => RequestDetail(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/business', builder: (_, __) => const BusinessScreen()),
        omoterraRoute(
            path: '/business/:type/request',
            builder: (_, s) =>
                BusinessScreen(type: s.pathParameters['type'], request: true)),
        omoterraRoute(
            path: '/business/:type',
            builder: (_, s) => BusinessScreen(type: s.pathParameters['type'])),
        omoterraRoute(
            path: '/business-submitted',
            builder: (context, _) => Scaffold(
                appBar: const OmoterraAppBar(),
                body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyState('Request received',
                        'Your request has been received. An Omoterra team member will contact you.',
                        action: OmoterraButton('Back to Home',
                            onPressed: () => context.go('/buyer')))))),
        omoterraRoute(
            path: '/account/support',
            builder: (_, __) => const AccountInfoScreen('support')),
        omoterraRoute(
            path: '/account/terms',
            builder: (_, __) => const AccountInfoScreen('terms')),
        omoterraRoute(
            path: '/account/privacy',
            builder: (_, __) => const AccountInfoScreen('privacy')),
        omoterraRoute(
            path: '/account/edit', builder: (_, __) => const ProfileScreen()),
        omoterraRoute(
            path: '/addresses', builder: (_, __) => const AddressesScreen()),
        omoterraRoute(
            path: '/addresses/new',
            builder: (_, s) => AddressesScreen(
                create: true, edit: s.extra as Map<String, dynamic>?)),
        omoterraRoute(
            path: '/stock/:id/correct',
            builder: (_, s) =>
                StockChangeScreen(s.pathParameters['id']!, 'correct')),
        omoterraRoute(
            path: '/stock/:id/add',
            builder: (_, s) =>
                StockChangeScreen(s.pathParameters['id']!, 'add')),
        omoterraRoute(
            path: '/stock/:id/sell',
            builder: (_, s) => RecordSaleScreen(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/stock/:id/history',
            builder: (_, s) => StockHistoryScreen(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/stock/new', builder: (_, __) => const AddStockScreen()),
        omoterraRoute(
            path: '/batches/new',
            builder: (_, __) => const SupplierBatchScreen()),
        omoterraRoute(
            path: '/stock/:id',
            builder: (_, s) => StockDetail(s.pathParameters['id']!)),
        omoterraRoute(
            path: '/payouts', builder: (_, __) => const PayoutScreen()),
        omoterraRoute(
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
        path.startsWith('/sales') ||
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
    final resourceFailures = ref.watch(resourceFailuresProvider);
    final showScreenError = resourceFailures.isNotEmpty && !onSupplierHome;
    final screenError = resourceFailures.values.firstOrNull;
    // The tabbed screens are the root of the signed-in app, so the system
    // back gesture should leave the app rather than be swallowed.
    return ExitOnBack(
        child: Scaffold(
            // The hero can sit under the chrome on Home. Other supplier
            // screens reserve the same transparent chrome height so their
            // first controls never hide beneath it.
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Visibility(
                          visible: !showScreenError,
                          maintainState: true,
                          child: child,
                        ),
                        if (showScreenError)
                          ListView(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                            children: [
                              ErrorState(
                                screenError!,
                                retry: () {
                                  for (final path in resourceFailures.keys) {
                                    if (path.startsWith('@listing|')) {
                                      ref.invalidate(listingsProvider(
                                          path.substring('@listing|'.length)));
                                    } else {
                                      ref.invalidate(resourceProvider(path));
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
                    ))),
            bottomNavigationBar: _BottomNav(
                selected: routes.indexOf(path),
                onSelect: (i) => context.go(routes[i]),
                onDemand: () =>
                    context.go(supplier ? '/supplier-demand' : '/explore'),
                supplier: supplier)));
  }
}

/// The floating bottom nav: a rounded white bar holding the role’s tabs,
/// lifted off the screen edge so it reads as its own surface.
class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onDemand;
  final bool supplier;
  const _BottomNav(
      {required this.selected,
      required this.onSelect,
      required this.onDemand,
      required this.supplier});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bar = PhysicalShape(
      clipper: _DemandNavClipper(),
      color: const Color(0xFFF1F7F4),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: OColors.forest.withValues(alpha: .14),
      child: SizedBox(
        height: 80,
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                  const Color(0xFFFCFEFC),
                  const Color(0xFFEDF5F1)
                ])),
            child: CustomPaint(
                painter: _NavLeavesPainter(),
                child: Row(children: [
                  _tab(0, Icons.home_outlined, Icons.home, 'Home'),
                  _tab(
                      1,
                      supplier ? Icons.inventory_2_outlined : Icons.search,
                      supplier ? Icons.inventory_2 : Icons.search,
                      supplier ? 'Stock' : 'Explore'),
                  const Spacer(),
                  _tab(2, Icons.inventory_2_outlined, Icons.inventory_2,
                      'Orders'),
                  _tab(3, Icons.person_outline, Icons.person, 'Account'),
                ]))),
      ),
    );
    final demandButton = Material(
      color: OColors.forest,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onDemand,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          padding: const EdgeInsets.all(4),
          child:
              Image.asset('assets/icons/white-icon.png', fit: BoxFit.contain),
        ),
      ),
    );
    return Padding(
      padding:
          EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 0 ? bottomInset : 10),
      child: SizedBox(
        height: 92,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, right: 0, top: 12, child: bar),
          Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                  child: Semantics(
                      button: true,
                      selected: selected == -1,
                      label: supplier ? 'Demand' : 'Explore',
                      child: demandButton))),
        ]),
      ),
    );
  }

  Widget _tab(int i, IconData icon, IconData selectedIcon, String label) {
    final active = i == selected;
    return Expanded(
        child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: InkWell(
                onTap: () => onSelect(i),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                          duration: AppMotion.control,
                          curve: AppMotion.settle,
                          width: active ? 48 : 44,
                          height: 32,
                          decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFFE0EFE7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20)),
                          child: AnimatedSwitcher(
                              duration: AppMotion.quick,
                              switchInCurve: AppMotion.enter,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                          opacity: animation, child: child)),
                              child: Icon(active ? selectedIcon : icon,
                                  key: ValueKey(active),
                                  size: 23,
                                  color: active
                                      ? OColors.forest
                                      : const Color(0xFF6F7775)))),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                          duration: AppMotion.control,
                          curve: AppMotion.settle,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: active
                                  ? OColors.forest
                                  : const Color(0xFF6F7775)),
                          child: Text(label)),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                          duration: AppMotion.control,
                          curve: AppMotion.settle,
                          width: active ? 19 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                              color:
                                  active ? OColors.forest : Colors.transparent,
                              borderRadius: BorderRadius.circular(3))),
                    ]))));
  }
}

/// A single continuous navigation surface with a concave center cradle for
/// the floating demand action.
class _DemandNavClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const radius = 24.0;
    final center = size.width / 2;
    final path = Path()..moveTo(radius, 0);
    path.lineTo(center - 62, 0);
    path.cubicTo(center - 42, 0, center - 36, 9, center - 31, 28);
    path.cubicTo(center - 26, 43, center - 16, 50, center, 50);
    path.cubicTo(center + 16, 50, center + 26, 43, center + 31, 28);
    path.cubicTo(center + 36, 9, center + 42, 0, center + 62, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    return path..close();
  }

  @override
  bool shouldReclip(covariant _DemandNavClipper oldClipper) => false;
}

class _NavLeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD6E9DE).withValues(alpha: .72);
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final upper = Path()
        ..moveTo(-8, 40)
        ..cubicTo(-7, 17, 7, 6, 24, 10)
        ..cubicTo(14, 25, 9, 35, -8, 40)
        ..close();
      final lower = Path()
        ..moveTo(-6, 71)
        ..cubicTo(-8, 48, 4, 36, 20, 32)
        ..cubicTo(16, 52, 9, 65, -6, 71)
        ..close();
      canvas.drawPath(upper, paint);
      canvas.drawPath(lower, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NavLeavesPainter oldDelegate) => false;
}

/// Explicit role selection is persisted before navigating to its home.
class _RoleSwitcher extends ConsumerWidget {
  final bool supplier;
  const _RoleSwitcher({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles =
        ref.watch(sessionProvider).valueOrNull?.roles ?? const <String>[];
    final options = <OmoterraPickerOption<String>>[
      if (roles.contains('buyer'))
        const OmoterraPickerOption(
            value: 'buyer',
            title: Text('Buyer'),
            icon: Icons.shopping_basket_outlined,
            subtitle: 'Browse and buy supply'),
      if (roles.contains('supplier'))
        const OmoterraPickerOption(
            value: 'supplier',
            title: Text('Supplier'),
            icon: Icons.storefront_outlined,
            subtitle: 'Manage and sell your supply'),
      if (!roles.contains('buyer'))
        const OmoterraPickerOption(
            value: 'register:buyer',
            title: Text('Register as buyer'),
            icon: Icons.shopping_basket_outlined,
            subtitle: 'Complete buyer details to add this role'),
      if (!roles.contains('supplier'))
        const OmoterraPickerOption(
            value: 'register:supplier',
            title: Text('Register as supplier'),
            icon: Icons.storefront_outlined,
            subtitle: 'Complete supplier details to add this role'),
    ];
    return OmoterraActionDropdown(
      title: 'Choose account type',
      selected: supplier ? 'supplier' : 'buyer',
      options: options,
      onSelected: (role) async {
        if (role.startsWith('register:')) {
          context.push('/register-role/${role.substring('register:'.length)}');
          return;
        }
        try {
          await ref.read(sessionProvider.notifier).switchRole(role);
          if (context.mounted) {
            context.go(role == 'buyer' ? '/buyer' : '/supplier');
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'We couldn’t switch roles just now. Please try again.')));
          }
        }
      },
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
        ]),
      ),
    );
  }
}
