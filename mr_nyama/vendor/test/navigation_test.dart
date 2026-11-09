import 'package:mr_nyama_vendor/shared/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mr_nyama_vendor/core/routing/router.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/dev/showcase.dart';
import 'package:mr_nyama_vendor/features/home/home_screen.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/features/stock/stock_screen.dart';
import 'package:mr_nyama_vendor/shared/widgets/bottom_nav.dart';
import 'package:mr_nyama_vendor/shared/widgets/cart_summary.dart';
import 'package:mr_nyama_vendor/shared/widgets/avatar.dart';

import 'helpers.dart';

Finder backButton() => find.bySemanticsLabel('Rudi');

/// An action on the Nyumbani screen (button or menu row), by its text.
Finder homeAction(String label) =>
    find.descendant(of: find.byType(HomeScreen), matching: find.text(label));

Iterable<String> paths(List<RouteBase> routes) sync* {
  for (final r in routes) {
    if (r is GoRoute) yield r.path;
    yield* paths(r.routes);
  }
}

void main() {
  testWidgets('opens on Nyumbani with exactly three destinations',
      (tester) async {
    final app = await pumpApp(tester);
    expect(app.router.state.uri.path, MNRoutes.home);
    final nav = tester.widget<MNBottomNav>(find.byType(MNBottomNav));
    expect(nav.items.map((i) => i.label), ['Nyumbani', 'Mauzo', 'Bidhaa']);
  });

  testWidgets('top-level tabs never show a back button', (tester) async {
    await pumpApp(tester);
    for (final tab in ['Mauzo', 'Bidhaa', 'Nyumbani']) {
      await tester.tap(find.descendant(
          of: find.byType(MNBottomNav), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(backButton(), findsNothing, reason: tab);
    }
  });

  testWidgets('tabs keep their state while switching', (tester) async {
    await pumpApp(tester);
    final home = tester.element(find.byType(HomeScreen));
    await tester.tap(find.text('Bidhaa').last);
    await tester.pumpAndSettle();
    final stock = tester.element(find.byType(StockScreen));
    await tester.tap(find.text('Nyumbani').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bidhaa').last);
    await tester.pumpAndSettle();
    // Same elements: the tab subtrees were kept, not rebuilt from scratch.
    expect(tester.element(find.byType(StockScreen)), same(stock));
    expect(tester.element(find.byType(HomeScreen, skipOffstage: false)),
        same(home));
  });

  testWidgets('secondary destinations open above the tabs with a back button',
      (tester) async {
    final app = await pumpApp(tester);
    // Rows of the approved Nyumbani reference (22 October 2026).
    final destinations = {
      'Pokea bidhaa': MNRoutes.receive,
      'Vimeharibika': MNRoutes.damaged,
    };
    for (final MapEntry(key: label, value: path) in destinations.entries) {
      await tester.tap(homeAction(label));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, path);
      expect(find.byType(MNBottomNav),
          path == MNRoutes.receive ? findsOneWidget : findsNothing);
      await tester.tap(backButton());
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, MNRoutes.home);
    }

    // Locate the actual profile control, including when the heading is scrolled away.
    final profileAction = find.byWidgetPredicate(
        (widget) => widget is MNPressable && widget.semanticLabel == 'Wasifu');
    await tester.scrollUntilVisible(profileAction, -200,
        scrollable: find
            .descendant(
                of: find.byType(HomeScreen), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(profileAction);
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.profile);
    await tester.tap(backButton());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mauzo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Historia'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.history);
    await tester.tap(backButton());
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.sales);

    await tester.tap(find.text('Bidhaa').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Funga siku'), 200,
        scrollable: find
            .descendant(
                of: find.byType(StockScreen), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Funga siku'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.closeDay);
    await tester.tap(backButton());
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.products);
  });

  testWidgets('Nyumbani shows the four daily jobs', (tester) async {
    final app = await pumpApp(tester);
    for (final label in [
      'Rekodi mauzo',
      'Pokea bidhaa',
      'Vimeharibika',
      'Funga siku'
    ]) {
      expect(homeAction(label), findsOneWidget, reason: label);
    }
    expect(homeAction('Sokoni'), findsNothing);
    await tester.tap(homeAction('Funga siku'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.closeDay);
  });

  testWidgets('home profile control shows the uploaded photo when available',
      (tester) async {
    final app = await pumpApp(tester);
    expect(find.text('AM'), findsOneWidget);
    expect(tester.widget<MNPersonPhoto>(find.byType(MNPersonPhoto)).imageUrl,
        isNull);

    await app.container.read(sessionProvider.notifier).updateProfile(
        testProfile.copyWith(
            profileImageUrl: 'https://storage.test/profiles/asha/photo.jpg'));
    await tester.pump();

    final photo = tester.widget<MNPersonPhoto>(find.byType(MNPersonPhoto));
    expect(photo.imageUrl, 'https://storage.test/profiles/asha/photo.jpg');
    expect(photo.size, 38);
  });

  testWidgets('Gharama and Wateja wa mkopo open from Zaidi', (tester) async {
    final app = await pumpApp(tester);
    expect(homeAction('Gharama'), findsNothing);
    expect(homeAction('Wateja wa mkopo'), findsNothing);
    for (final (label, path) in [
      ('Gharama', MNRoutes.expenses),
      ('Wateja wa mkopo', MNRoutes.credit),
    ]) {
      await tester.tap(homeAction('Zaidi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, path);
      await tester.tap(backButton());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the bottom navigation still has exactly three tabs',
      (tester) async {
    await pumpApp(tester);
    final nav = tester.widget<MNBottomNav>(find.byType(MNBottomNav));
    expect(nav.items.map((i) => i.label), ['Nyumbani', 'Mauzo', 'Bidhaa']);
  });

  testWidgets('Rekodi mauzo opens the Mauzo tab', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(homeAction('Rekodi mauzo'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.sales);
    expect(backButton(), findsNothing);
  });

  testWidgets('the active cart survives tabs and secondary screens',
      (tester) async {
    final app = await pumpApp(tester,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
    final cart = app.container.read(cartProvider.notifier);
    cart.add('kuku', 2);
    await tester.tap(find.text('Mauzo').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bidhaa 2'), findsOneWidget);

    await tester.tap(find.text('Nyumbani').last);
    await tester.pumpAndSettle();
    await tester.tap(homeAction('Pokea bidhaa'));
    await tester.pumpAndSettle();
    await tester.tap(backButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mauzo').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bidhaa 2'), findsOneWidget);
    expect(app.container.read(cartProvider).quantityOf('kuku'), 2);
    expect(find.byType(MNCartBar), findsOneWidget);
  });

  testWidgets('Android back on Mauzo returns to Nyumbani', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('Mauzo').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.home);
  });

  testWidgets('reduced motion: screens change without transitions',
      (tester) async {
    final app = await pumpApp(tester, reducedMotion: true);
    await tester.tap(homeAction('Pokea bidhaa'));
    await tester.pump();
    expect(app.router.state.uri.path, MNRoutes.receive);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('development showcase is isolated', () {
    test('off unless explicitly enabled, and never in release', () {
      expect(devShowcaseEnabled, isFalse);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(paths(container.read(routerProvider).configuration.routes),
          isNot(contains(MNRoutes.showcase)));
    });

    testWidgets('an unknown path does not open the showcase', (tester) async {
      await pumpApp(tester, initial: MNRoutes.showcase);
      expect(find.textContaining('SAMPULI'), findsNothing);
    });
  });
}
