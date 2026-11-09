import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';
import 'package:mr_nyama_vendor/shared/widgets/product_card.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';
import 'package:mr_nyama_vendor/shared/widgets/rows.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';

import 'helpers.dart';

Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (final route in [
    MNRoutes.home,
    MNRoutes.sales,
    MNRoutes.products,
    MNRoutes.receive,
    MNRoutes.history,
    MNRoutes.closeDay,
    MNRoutes.profile,
  ]) {
    testWidgets('$route meets tap-target, label and contrast guidelines',
        (tester) async {
      final handle = tester.ensureSemantics();
      final app = await pumpApp(tester, initial: route);
      if (route == MNRoutes.sales) {
        app.container.read(cartProvider.notifier).add('sample', 2);
        await tester.pumpAndSettle();
      }
      if (route == MNRoutes.profile) {
        // Thin text at 1x has only blurred edge pixels, which the contrast
        // check reads as a pale text colour. Measure at a phone's density.
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        tester.view
          ..physicalSize = tester.view.physicalSize * 3
          ..devicePixelRatio = 3;
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } else {
        await expectAccessible(tester);
      }
      handle.dispose();
    });
  }

  for (final route in [MNRoutes.pin, MNRoutes.activate, MNRoutes.forgotPin]) {
    testWidgets('sign-in $route meets the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      app.router.go(route);
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      handle.dispose();
    });
  }

  testWidgets('photographic login: tap targets and labels', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, startAs: StartAs.signedOut);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    // The phone field is announced with its label and country code.
    expect(
        find.bySemanticsLabel(RegExp('Namba ya simu, \\+255')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('catalogue, cart and saved sale meet the guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    final app = await pumpApp(tester,
        initial: MNRoutes.sales,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    app.router.push(MNRoutes.cart);
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await tester.tap(find.text('Taslimu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi mauzo'));
    await tester.pumpAndSettle();
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('history and sale details meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    final now = DateTime.utc(2026, 10, 9, 12);
    final app = await pumpApp(tester, now: now);
    await app.container.read(salesStoreProvider).saveSale(SaleDraft(
            clientId: 'aaaa-0001',
            vendorId: 'v1',
            recordedAt: now,
            payment: PaymentMethod.cash,
            lines: const [
              DraftLine(
                  productId: 'kuku',
                  productName: 'Kuku mzima',
                  quantity: 1,
                  unitPrice: 9000)
            ]));
    app.router.push(MNRoutes.history);
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    app.router.push(MNRoutes.saleDetail('aaaa-0001'));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('receiving screens meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    final api = FakeVendorRepository()
      ..deliveryList = [
        DeliveryManifest(
            consignmentId: 'c1',
            version: 1,
            reference: 'OMT-2041',
            sender: 'Omoterra',
            stationKey: 'S1',
            stationName: 'Kariakoo',
            dispatchedAt: DateTime.utc(2026, 10, 9, 5),
            lines: const [
              ManifestLine(
                  lineId: 'L1',
                  productId: 'kuku',
                  productName: 'Kuku mzima',
                  quantity: 50),
            ]),
      ];
    final app = await pumpApp(tester, api: api);
    app.router.push(MNRoutes.receive);
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    app.router.push(MNRoutes.delivery('c1'));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    // The reference delivery screen has one "Pokea bidhaa" action that opens
    // the per-line counting steppers (it replaced "Idadi tofauti").
    await tester.tap(find.widgetWithText(MNButton, 'Pokea bidhaa'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Punguza Kuku mzima'));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('damage and closing screens meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    final now = DateTime.utc(2026, 10, 9, 17);
    final app = await pumpApp(tester,
        now: now, api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    for (final route in [MNRoutes.damaged, MNRoutes.newDamage]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    }
    app.router.go(MNRoutes.closeDay);
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await app.container.read(closingStoreProvider).submit(
        countId: 'a11y',
        vendorId: 'v1',
        stationKey: 'S1',
        now: now,
        products: await app.container.read(productsProvider.future),
        counted: {'kuku': 5, 'paja': 0});
    app.router.go(MNRoutes.dayClosed);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('components meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    setScreen(tester, reducedMotion: true);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: mrNyamaTheme(),
        home: Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [
            MNButton('Hifadhi', onPressed: () {}),
            MNButton.secondary('Rudi', onPressed: () {}),
            MNButton.destructive('Futa', onPressed: () {}),
            MNTextButton('Ona yote', onPressed: () {}),
            Row(children: [
              MNIconButton(MNIconData.search,
                  label: 'Tafuta', onPressed: () {}),
              MNQuantitySelector(
                  value: 2, itemLabel: 'Kuku', onChanged: (_) {}),
            ]),
            SizedBox(
              width: 173,
              child: MNProductCard(
                  name: 'Kidali (Robo)',
                  price: 2500,
                  remaining: '28',
                  quantity: 1,
                  onTap: () {},
                  onAdd: () {},
                  onDecrease: () {}),
            ),
            const MNTransactionRow(
                time: '10:42',
                product: 'Kuku',
                quantity: 2,
                paymentMethod: 'Taslimu',
                mobileMoney: false,
                amount: 24000),
            MNMenuRow(
                icon: MNIconData.key, label: 'Badilisha PIN', onTap: () {}),
            const MNSyncIndicator(status: MNSyncStatus.waiting),
            const MNSyncIndicator(status: MNSyncStatus.sent),
            const Center(child: MNPinDots(filled: 2)),
            MNPinKeypad(onDigit: (_) {}, onBackspace: () {}),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('text stays readable at 2× scale on a small phone',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, size: const Size(320, 568), textScale: 2);
    await expectAccessible(tester);
    handle.dispose();
  });
}
