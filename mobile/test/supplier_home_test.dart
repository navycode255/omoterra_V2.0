import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Sales Records'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Add Stock'), findsNothing);
    expect(find.text('Reservations'), findsNothing);
    expect(find.widgetWithText(SupplierTile, 'My Stock'), findsNothing);
    expect(tester.getTopLeft(find.text('Market Demand')).dy,
        lessThan(tester.getTopLeft(find.text('Payouts')).dy));
    expect(tester.getTopLeft(find.text('Payouts')).dy,
        tester.getTopLeft(find.text('Sales Records')).dy);
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
    expect(find.text('Sales Records'), findsNothing);
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
    await tester.pumpWidget(host(const SupplierHome()));
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
}
