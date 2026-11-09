import 'package:mr_nyama_vendor/shared/widgets/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/shared/widgets/bottom_nav.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/payment_option.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'helpers.dart';

Future<TestApp> openSales(WidgetTester tester,
    {CatalogSnapshot catalog = testCatalog,
    Size size = const Size(390, 844),
    bool reducedMotion = false}) async {
  final app = await pumpApp(tester,
      api: FakeVendorRepository()..catalogSnapshot = catalog,
      initial: MNRoutes.sales,
      size: size,
      reducedMotion: reducedMotion);
  await tester.pumpAndSettle();
  return app;
}

Future<void> tapProduct(WidgetTester tester, String name,
    {int times = 1}) async {
  await tester.ensureVisible(find.text(name));
  await tester.pumpAndSettle();
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text(name));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

Finder cartBar() => find.bySemanticsLabel(RegExp('^Angalia kikapu'));

Future<void> openCart(WidgetTester tester) async {
  await tester.tap(cartBar());
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String payment) async {
  await tester.ensureVisible(find.widgetWithText(MNPaymentOption, payment));
  await tester.tap(find.widgetWithText(MNPaymentOption, payment));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MNButton, 'Hifadhi mauzo'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the grid shows server prices, what is left, and no price '
      'when none is configured', (tester) async {
    final app = await openSales(tester);
    expect(find.text('Kuku mzima'), findsOneWidget);
    expect(find.text('TSh 9,000'), findsOneWidget);
    expect(find.text('Imesalia: 8'), findsOneWidget);
    expect(find.text('Maini'), findsOneWidget);
    expect(find.text('Bei haijawekwa'), findsOneWidget);
    await tapProduct(tester, 'Maini');
    expect(app.container.read(cartProvider).isEmpty, isTrue);
  });

  testWidgets('single-product sale: tap, cart, cash, saved', (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Kuku mzima');
    expect(find.text('Bidhaa 1 · TSh 9,000'), findsOneWidget);
    await openCart(tester);
    expect(app.router.state.uri.path, MNRoutes.cart);

    // Payment must be chosen first.
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi mauzo'))
            .onPressed,
        isNull);
    await choose(tester, 'Taslimu');
    await save(tester);

    // Saved on the phone; no sync service answers, so it is not "sent".
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
    expect(find.text('Inasubiri mtandao'), findsOneWidget);
    expect(find.text('Yametumwa ofisini'), findsNothing);
    final sales = await app.db.select(app.db.sales).get();
    expect(sales.single.paymentMethod, 'cash');
    expect(sales.single.total, 9000);
    expect(app.container.read(cartProvider).isEmpty, isTrue);

    await tester.tap(find.text('Sawa'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.sales);
    expect(cartBar(), findsNothing);
  });

  testWidgets('multi-product sale with exact line and grand totals',
      (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Kuku mzima', times: 2);
    await tapProduct(tester, 'Kidali (Robo)', times: 3);
    expect(find.text('Bidhaa 5 · TSh 25,500'), findsOneWidget);
    await openCart(tester);
    expect(find.text('TZS 18,000'), findsOneWidget);
    expect(find.text('TZS 7,500'), findsOneWidget);
    expect(find.text('TZS 25,500'), findsOneWidget);
    await choose(tester, 'Taslimu');
    await save(tester);
    final lines = await app.db.select(app.db.saleLines).get();
    expect({for (final l in lines) l.productId: l.lineTotal},
        {'kuku': 18000, 'kidali': 7500});
    expect((await app.db.select(app.db.sales).get()).single.total, 25500);
  });

  testWidgets('rapid repeated taps each add one, none are dropped',
      (tester) async {
    final app = await openSales(tester);
    await tester.ensureVisible(find.text('Kidali (Robo)'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.text('Kidali (Robo)'));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('kidali'), 12);
  });

  testWidgets('quantity: stepper, typed number, remove and clear',
      (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Kuku mzima');
    await tester.tap(find.bySemanticsLabel('Ongeza Kuku mzima'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('kuku'), 2);

    // Direct entry: tap the number, type 12, set.
    await tester.tap(find.bySemanticsLabel('Idadi ya Kuku mzima'));
    await tester.pumpAndSettle();
    for (final d in ['1', '2']) {
      await tester.tap(find.descendant(
          of: find.byType(MNPinKeypad), matching: find.text(d)));
      await tester.pump();
    }
    await tester.tap(find.text('Weka idadi'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('kuku'), 12);

    await tapProduct(tester, 'Kidali (Robo)');
    await openCart(tester);
    await tester.tap(find.bySemanticsLabel('Punguza Kuku mzima'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('kuku'), 11);
    expect(find.text('TZS 99,000'), findsOneWidget);

    await tester.drag(find.text('Kuku mzima'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futa'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('kuku'), 0);

    await tester.tap(find.text('Futa zote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futa zote').last);
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).isEmpty, isTrue);
  });

  testWidgets('M-Pesa uses the configured number and is recorded as chosen',
      (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Paja (Robo)');
    await openCart(tester);
    expect(find.text('Mteja amelipia 123456'), findsOneWidget);
    await choose(tester, 'M-Pesa ya Mr. Nyama');
    await save(tester);
    expect((await app.db.select(app.db.sales).get()).single.paymentMethod,
        'mpesa');
  });

  testWidgets('without a configured number, M-Pesa is not offered',
      (tester) async {
    await openSales(tester,
        catalog: CatalogSnapshot(products: testCatalog.products));
    await tapProduct(tester, 'Paja (Robo)');
    await openCart(tester);
    expect(find.text('Haijawekwa na ofisi'), findsNothing);
    expect(find.widgetWithText(MNPaymentOption, 'M-Pesa ya Mr. Nyama'),
        findsNothing);
    expect(
        tester
            .widget<MNPaymentOption>(
                find.widgetWithText(MNPaymentOption, 'Taslimu'))
            .onTap,
        isNotNull);
  });

  testWidgets('a double tap on save records one sale', (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    await choose(tester, 'Taslimu');
    final button = find.widgetWithText(MNButton, 'Hifadhi mauzo');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.sales).get(), hasLength(1));
  });

  testWidgets('offline: sales still save on the phone and wait to sync',
      (tester) async {
    final app = await openSales(tester);
    app.api.catalogFailure = const AuthFailure(AuthFailureKind.offline);
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    await choose(tester, 'Taslimu');
    await save(tester);
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
    await tester.tap(find.text('Sawa'));
    await tester.pumpAndSettle();
    app.router.go(MNRoutes.home);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Inasubiri kusawazisha'), findsWidgets);
  });

  testWidgets('selling more than recorded warns, still saves, and flags it',
      (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Paja (Robo)', times: 4); // 3 recorded
    await openCart(tester);
    expect(find.text('Huna Paja (Robo) wa kutosha kwenye rekodi.'),
        findsOneWidget);
    expect(find.text('Mauzo yatahifadhiwa; ofisi itakagua idadi.'),
        findsOneWidget);
    await choose(tester, 'Taslimu');
    await save(tester);
    final line = (await app.db.select(app.db.saleLines).get()).single;
    expect(line.exceedsRecordedStock, isTrue);
    expect(line.quantity, 4);
    // No stock was created: the server's figure is unchanged.
    final product = (await app.db.select(app.db.catalogProducts).get())
        .firstWhere((p) => p.id == 'paja');
    expect(product.available, 3);
  });

  testWidgets(
      'the cart stays across tabs and is reachable above the '
      'navigation', (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Kuku mzima', times: 2);
    for (final tab in ['Nyumbani', 'Bidhaa', 'Mauzo']) {
      await tester.tap(find.descendant(
          of: find.byType(MNBottomNav), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(cartBar(), findsOneWidget, reason: tab);
      expect(tester.getRect(cartBar()).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(MNBottomNav)).top + 1),
          reason: tab);
    }
    expect(app.container.read(cartProvider).quantityOf('kuku'), 2);
  });

  testWidgets('signing out empties the cart', (tester) async {
    final app = await openSales(tester);
    await tapProduct(tester, 'Kuku mzima');
    app.router.push(MNRoutes.profile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toka kwenye akaunti'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(MNAccountSignOutSheet),
        matching: find.text('Toka kwenye akaunti')));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).isEmpty, isTrue);
  });

  testWidgets('reduced motion: checkout settles without animation',
      (tester) async {
    await openSales(tester, reducedMotion: true);
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    await choose(tester, 'Taslimu');
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi mauzo'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
