import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';
import 'package:omoterra/shared/widgets/components.dart';

class PendingSupplierHomeRepository extends LocalRepository {
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/profile') return {'status': 'under_review'};
    return super.read(path, query);
  }
}

class NoBatchesRepository extends LocalRepository {
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/batches') return [];
    return super.read(path, query);
  }
}

class FailingSupplierHomeRepository extends LocalRepository {
  final Set<String> failingPaths;
  FailingSupplierHomeRepository({this.failingPaths = const {}});

  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/profile' &&
        !failingPaths.contains('/supplier/profile')) {
      return {'status': 'under_review'};
    }
    if (failingPaths.contains(path) || path == '/supplier/batches') {
      throw const ApiFailure('Not Found');
    }
    return super.read(path, query);
  }
}

/// Preview stock with every listing's status replaced.
class _StockRepository extends LocalRepository {
  final String Function(Map row) status;
  _StockRepository(this.status);
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    final data = await super.read(path, query);
    if (path != '/supplier/stock') return data;
    return [
      for (final row in data as List)
        {...Map<String, dynamic>.from(row), 'listing_status': status(row)}
    ];
  }
}

Widget host(Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(theme: omoterraTheme(), home: Scaffold(body: child)));

void main() {
  testWidgets('supplier home leaves stock and reservations to the bottom nav',
      (tester) async {
    await tester.pumpWidget(host(const SupplierHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Grow Beyond\nthe Farm'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Add Stock'), findsNothing);
    expect(find.text('Reservations'), findsNothing);
    expect(find.widgetWithText(SupplierTile, 'My Stock'), findsNothing);
    expect(tester.getTopLeft(find.text('Market Demand')).dy,
        lessThan(tester.getTopLeft(find.text('Payouts')).dy));
    expect(tester.getTopLeft(find.text('Payouts')).dy,
        tester.getTopLeft(find.text('Sales')).dy);
    expect(find.text('Track completed earnings'), findsNothing);
  });

  testWidgets('supplier home has no add-production prompt without batches',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(NoBatchesRepository())
        ],
        child: MaterialApp(
            theme: omoterraTheme(),
            home: const Scaffold(body: SupplierHome()))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Add your current production'), findsNothing);
    expect(find.text('Market Demand'), findsOneWidget);
  });

  testWidgets('under-review home skips unavailable supplier feature requests',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(FailingSupplierHomeRepository()),
      ],
      child: MaterialApp(
        theme: omoterraTheme(),
        home: const AppShell(path: '/supplier', child: SupplierHome()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Registration under review'), findsOneWidget);
    expect(find.text('Market Demand'), findsNothing);
    expect(find.text('Add Stock'), findsNothing);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('pending supplier status is a notice, not an error',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(PendingSupplierHomeRepository()),
      ],
      child: MaterialApp(
        theme: omoterraTheme(),
        home: const AppShell(path: '/supplier', child: SupplierHome()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Registration under review'), findsOneWidget);
    expect(find.text('We’ll let you know when your supplier account is ready.'),
        findsOneWidget);
    expect(find.text('Market Demand'), findsNothing);
    expect(find.text('Add your current production'), findsNothing);
    expect(find.text('Add Stock'), findsNothing);
    expect(find.text('My Stock'), findsNothing);
    expect(find.text('Reservations'), findsNothing);
    expect(find.text('Payouts'), findsNothing);
    expect(find.text('Sales'), findsNothing);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('stock screen shows one error instead of failing sections',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(FailingSupplierHomeRepository(
          failingPaths: const {'/supplier/stock', '/supplier/batches'},
        )),
      ],
      child: MaterialApp(
        theme: omoterraTheme(),
        home: const AppShell(path: '/stock', child: StockScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('My stock'), findsNothing);
    expect(find.text('Available listings'), findsNothing);
  });

  testWidgets('orders screen shows one error and hides its content',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(FailingSupplierHomeRepository(
          failingPaths: const {'/supplier/orders'},
        )),
      ],
      child: MaterialApp(
        theme: omoterraTheme(),
        home: const AppShell(path: '/supplier-orders', child: SupplierOrders()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Orders & reservations'), findsNothing);
  });

  testWidgets(
      'the stock card has a photo, status dot and an overflow menu, not just text',
      (tester) async {
    await tester.pumpWidget(host(const StockScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz), findsWidgets);
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('Correct stock count'), findsOneWidget);
    expect(find.text('Add stock received'), findsOneWidget);
  });

  testWidgets('the top nav is transparent over the banner on Supplier Home',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
        child: MaterialApp(
            theme: omoterraTheme(),
            home: const AppShell(path: '/supplier', child: SupplierHome()))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBodyBehindAppBar, isTrue);
    // Home is the one supplier screen that lets back leave the app.
    expect(find.byWidgetPredicate((w) => w is PopScope), findsNothing);
  });

  testWidgets('back from a supplier tab returns Home instead of exiting',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
        child: MaterialApp(
            theme: omoterraTheme(),
            home: const AppShell(path: '/stock', child: SizedBox()))));
    await tester.pump();
    final guard = tester
        .widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope).first);
    expect(guard.canPop, isFalse);
  });

  testWidgets('quick stats keep stock units separate', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(_StockRepository((row) => 'live'))
    ], child: MaterialApp(theme: omoterraTheme(), home: const SupplierHome())));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsNWidgets(2));
    expect(find.text('Reserved'), findsNWidgets(2));
    expect(find.text('300'), findsOneWidget);
    expect(find.text('25'), findsNWidgets(2));
  });

  testWidgets('supplier navigation includes Demand alongside Stock and Orders',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
        child: MaterialApp(
            theme: omoterraTheme(),
            home: const AppShell(path: '/supplier', child: SupplierHome()))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.text('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Demand'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) => w is Material && w.shape is CircleBorder),
        findsOneWidget);
  });

  testWidgets('Market Demand and Buyer ratings are compact and the same height',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const SupplierHome()));
    await tester.pump(const Duration(seconds: 1));
    final demand = tester.getSize(find
        .ancestor(
            of: find.text('Market Demand'), matching: find.byType(SupplierTile))
        .first);
    final ratings = tester.getSize(find
        .ancestor(
            of: find.text('Buyer Ratings'), matching: find.byType(SupplierTile))
        .first);
    // As in the design: Market Demand a little taller than Buyer Ratings.
    expect((demand.height - ratings.height).abs(), lessThanOrEqualTo(12));
    expect(demand.height, lessThanOrEqualTo(64));
  });

  testWidgets('Quick Stats and the first stock figures show without scrolling',
      (tester) async {
    // A common Android phone: 360x780 with a 32px status bar.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(NoBatchesRepository())
        ],
        child: MaterialApp(
            theme: omoterraTheme(),
            home: const AppShell(path: '/supplier', child: SupplierHome()))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final navTop = tester.getTopLeft(find.text('Home')).dy - 20;
    final order = ['Market Demand', 'Payouts', 'Quick Stats']
        .map((t) => tester.getTopLeft(find.text(t).first).dy)
        .toList();
    expect(order, orderedEquals([...order]..sort()),
        reason: 'Market Demand, then Payouts/Sales, then Quick Stats');
    expect(tester.getBottomLeft(find.text('Quick Stats')).dy, lessThan(navTop));
    // The first figure (its number and label) sits above the bottom nav.
    expect(tester.getBottomLeft(find.text('Total Stock').first).dy,
        lessThan(navTop));

    // Buyer ratings comes after the stock figures.
    await tester.scrollUntilVisible(find.text('Buyer Ratings'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.getTopLeft(find.text('Buyer Ratings')).dy,
        greaterThan(tester.getTopLeft(find.text('Quick Stats')).dy));
  });

  testWidgets('Market Demand opens on the first tap, even near its top edge',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 27);
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/supplier', routes: [
      GoRoute(
          path: '/supplier',
          builder: (_, __) =>
              const AppShell(path: '/supplier', child: SupplierHome())),
      GoRoute(
          path: '/supplier-demand',
          builder: (_, __) => const Scaffold(body: Text('demand page'))),
    ]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(NoBatchesRepository())
        ],
        child:
            MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
    await tester.pump(const Duration(seconds: 1));
    final card = find
        .ancestor(
            of: find.text('Market Demand'), matching: find.byType(SupplierTile))
        .first;
    // 6 points below the card's top edge: this used to land on the photo.
    await tester.tapAt(tester.getTopLeft(card) + const Offset(60, 6));
    await tester.pumpAndSettle();
    expect(find.text('demand page'), findsOneWidget);
  });

  testWidgets('quick stats wait for approval instead of counting pending stock',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider
          .overrideWithValue(_StockRepository((row) => 'pending_review'))
    ], child: MaterialApp(theme: omoterraTheme(), home: const SupplierHome())));
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Stats available after approval.'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
  });
}
