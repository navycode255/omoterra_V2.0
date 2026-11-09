import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/dev/showcase.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/bottom_nav.dart';

import 'helpers.dart';

/// Overflow ("A RenderFlex overflowed…") and clipping errors are reported as
/// test failures by the framework, so pumping each screen at each size and
/// text scale is the check. The showcase is scrolled to the end so every
/// component is laid out.
void main() {
  const routes = [
    MNRoutes.home,
    MNRoutes.sales,
    MNRoutes.products,
    MNRoutes.receive,
    MNRoutes.damaged,
    MNRoutes.history,
    MNRoutes.closeDay,
    MNRoutes.profile,
    MNRoutes.changePin,
  ];
  const signInRoutes = [
    MNRoutes.login,
    MNRoutes.pin,
    MNRoutes.activate,
    MNRoutes.createPin,
    MNRoutes.forgotPin,
  ];

  FakeVendorRepository busyDay() => FakeVendorRepository()
    ..dashboardSummary = DashboardSummary(
        date: DateTime(2026, 10, 7),
        todayTotal: 1245000,
        saleCount: 124,
        recent: [
          for (var i = 0; i < 3; i++)
            SaleSummary(
                id: '$i',
                recordedAt: DateTime(2026, 10, 7, 10, i),
                product: 'Kuku mzima wa kuchoma',
                quantity: 12,
                payment: PaymentMethod.mpesa,
                amount: 108000),
        ]);

  for (final MapEntry(key: name, value: size) in phoneSizes.entries) {
    for (final scale in textScales) {
      testWidgets('every screen fits at $name, text ×$scale', (tester) async {
        final app =
            await pumpApp(tester, size: size, textScale: scale, api: busyDay());
        // A full cart exercises the cart bar too.
        app.container.read(cartProvider.notifier).add('sample', 12);
        for (final route in routes) {
          app.router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
        }
      });

      testWidgets('sign-in screens fit at $name, text ×$scale', (tester) async {
        final app = await pumpApp(tester,
            size: size, textScale: scale, startAs: StartAs.signedOut);
        for (final route in signInRoutes) {
          app.router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
        }
      });

      testWidgets('checkout fits at $name, text ×$scale', (tester) async {
        final app = await pumpApp(tester,
            size: size,
            textScale: scale,
            initial: MNRoutes.sales,
            api: FakeVendorRepository()..catalogSnapshot = testCatalog);
        expect(tester.takeException(), isNull, reason: 'catalogue');
        app.container.read(cartProvider.notifier)
          ..add('kuku', 120)
          ..add('paja', 4) // more than recorded: warning shown
          ..add('kidali', 3);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'cart bar');
        app.router.push(MNRoutes.cart);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'cart');
        await tester.tap(find.bySemanticsLabel(RegExp('^Idadi ya Kuku mzima')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'quantity sheet');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        final sale = await app.container.read(salesStoreProvider).saveSale(
                SaleDraft(
                    clientId: 'layout',
                    vendorId: 'v1',
                    recordedAt: DateTime(2026, 10, 9, 11, 25),
                    payment: PaymentMethod.cash,
                    lines: const [
                  DraftLine(
                      productId: 'kuku',
                      productName: 'Kuku mzima',
                      quantity: 120,
                      unitPrice: 9000)
                ]));
        app.router.go(MNRoutes.saleSaved(sale.clientId));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sale saved');
      });

      testWidgets('history fits at $name, text ×$scale', (tester) async {
        final now = DateTime.utc(2026, 10, 9, 12);
        final app =
            await pumpApp(tester, size: size, textScale: scale, now: now);
        final store = app.container.read(salesStoreProvider);
        for (final (i, id) in ['aaaa-0001', 'bbbb-0002'].indexed) {
          await store.saveSale(SaleDraft(
              clientId: id,
              vendorId: 'v1',
              recordedAt: now.subtract(Duration(minutes: i)),
              payment: PaymentMethod.mpesa,
              lines: const [
                DraftLine(
                    productId: 'kuku',
                    productName: 'Kuku mzima wa kuchoma na viungo',
                    quantity: 120,
                    unitPrice: 9000),
                DraftLine(
                    productId: 'paja',
                    productName: 'Paja (Robo)',
                    quantity: 4,
                    unitPrice: 2000),
              ]));
        }
        await app.container.read(historyStoreProvider).voidSale(
            voidId: 'void-1',
            saleClientId: 'aaaa-0001',
            reason: VoidReason.customerCancelled,
            actorId: 'v1',
            now: now);
        app.router.push(MNRoutes.history);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'history');
        for (final id in ['aaaa-0001', 'bbbb-0002']) {
          app.router.push(MNRoutes.saleDetail(id));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: id);
        }
      });

      testWidgets('receiving fits at $name, text ×$scale', (tester) async {
        final api = FakeVendorRepository()
          ..deliveryList = [
            DeliveryManifest(
                consignmentId: 'c1',
                version: 1,
                reference: 'OMT-20411',
                sender: 'Omoterra Logistics',
                stationKey: 'S1',
                stationName: 'Kariakoo Soko Kuu',
                dispatchedAt: DateTime.utc(2026, 10, 9, 5),
                lines: const [
                  ManifestLine(
                      lineId: 'L1',
                      productId: 'kuku',
                      productName: 'Kuku mzima wa kuchoma na viungo',
                      quantity: 120),
                  ManifestLine(
                      lineId: 'L2',
                      productId: 'kidali',
                      productName: 'Kidali (Robo)',
                      quantity: 30,
                      imageKey: 'kidali'),
                ]),
          ];
        final app =
            await pumpApp(tester, size: size, textScale: scale, api: api);
        app.router.push(MNRoutes.receive);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'list');
        app.router.push(MNRoutes.delivery('c1'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'details');
        await tester.ensureVisible(find.text('Pokea bidhaa'));
        await tester.tap(find.text('Pokea bidhaa'));
        await tester.pumpAndSettle();
        // Rows below the fold are built lazily: scroll to the control.
        final minus = find.bySemanticsLabel(RegExp('^Punguza Kuku'));
        await tester.scrollUntilVisible(minus, 200,
            scrollable: find
                .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable))
                .first);
        await tester.ensureVisible(minus.first); // clear of the bottom bar
        await tester.pumpAndSettle();
        await tester.tap(minus.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'counting');
        await tester.ensureVisible(find.text('Hifadhi'));
        final save =
            tester.widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'));
        expect(save.onPressed, isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'reason error');
      });

      testWidgets('damage and closing fit at $name, text ×$scale',
          (tester) async {
        final app = await pumpApp(tester,
            size: size,
            textScale: scale,
            now: DateTime.utc(2026, 10, 9, 17),
            api: FakeVendorRepository()..catalogSnapshot = testCatalog);
        Future<void> tapText(String text) async {
          await tester.ensureVisible(find.text(text).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: text);
        }

        app.router.push(MNRoutes.newDamage);
        await tester.pumpAndSettle();
        await tapText('Kuku mzima');
        await tapText('Endelea');
        await tapText('Imemwagika');
        await tapText('Endelea');
        await tapText('Hifadhi ripoti');
        app.router.go(MNRoutes.damaged);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'damage history');

        app.router.go(MNRoutes.closeDay);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'closing count');
        final store = app.container.read(closingStoreProvider);
        final products = await app.container.read(productsProvider.future);
        await store.submit(
            countId: 'layout',
            vendorId: 'v1',
            stationKey: 'S1',
            now: DateTime.utc(2026, 10, 9, 17),
            products: products,
            counted: {'kuku': 1200, 'paja': 0});
        app.router.go(MNRoutes.dayClosed);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'day closed');
        app.router.go(MNRoutes.closeDay);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'closing status');
      });

      testWidgets('every component fits at $name, text ×$scale',
          (tester) async {
        setScreen(tester, size: size, textScale: scale, reducedMotion: true);
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                theme: mrNyamaTheme(), home: const ShowcaseScreen())));
        await tester.pumpAndSettle();
        final list = find.byType(Scrollable).first;
        final position = tester.state<ScrollableState>(list).position;
        // Move the outer list itself: the empty and error state samples
        // scroll internally at large text and would absorb a drag.
        while (position.pixels < position.maxScrollExtent) {
          position.jumpTo(math.min(
              position.pixels + size.height / 2, position.maxScrollExtent));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.byType(MNBottomNav), findsOneWidget,
            reason: 'scrolled to the last showcase section');
      });
    }
  }

  testWidgets(
      'safe areas: header clears the status bar, navigation the '
      'gesture bar', (tester) async {
    await pumpApp(tester);
    final title = tester.getTopLeft(find.text('Nyumbani').first);
    expect(title.dy, greaterThanOrEqualTo(24));
    final nav = tester.getRect(find.byType(MNBottomNav));
    expect(nav.bottom, 844);
    final navLabel = tester.getBottomLeft(find.descendant(
        of: find.byType(MNBottomNav), matching: find.text('Bidhaa')));
    expect(navLabel.dy, lessThanOrEqualTo(844 - 24));
  });

  testWidgets('major buttons are 56 px tall', (tester) async {
    setScreen(tester, reducedMotion: true);
    await tester.pumpWidget(ProviderScope(
        child:
            MaterialApp(theme: mrNyamaTheme(), home: const ShowcaseScreen())));
    await tester.pumpAndSettle();
    final save = find.text('Hifadhi mauzo');
    expect(
        tester
            .getSize(find
                .ancestor(of: save, matching: find.byType(ConstrainedBox))
                .first)
            .height,
        MNSize.button);
  });
}
