import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/sales/sale_success_mark.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/motion/fire.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'helpers.dart';

/// Runs a system for [ms] at 60 fps; returns the peak particle count.
int run(FireSystem s, double ms, {double from = 0}) {
  var peak = 0;
  for (var t = from; t <= ms; t += 1000 / 60) {
    s.step(t, 1 / 60);
    peak = math.max(peak, s.liveParticles);
  }
  return peak;
}

double opacityOf(WidgetTester tester, Finder finder) {
  final opacities = tester
      .widgetList<Opacity>(
          find.ancestor(of: finder, matching: find.byType(Opacity)))
      .map((o) => o.opacity);
  final animated = tester
      .widgetList<AnimatedOpacity>(
          find.ancestor(of: finder, matching: find.byType(AnimatedOpacity)))
      .map((o) => o.opacity);
  return [...opacities, ...animated].fold(1.0, (a, b) => a * b);
}

void main() {
  group('Signature B engine matches the approved prototype', () {
    test('intensity and flame height curves', () {
      expect(fungaSikuIntensity(500), 1);
      expect(fungaSikuIntensity(1100), closeTo(.65, 1e-9));
      expect(fungaSikuIntensity(2000), .3);
      expect(fungaSikuIntensity(4100), closeTo(.15, 1e-9));
      expect(fungaSikuIntensity(4700), 0);
      expect(fungaSikuHeight(200), .55);
      expect(fungaSikuHeight(650), closeTo(.775, 1e-9));
      expect(fungaSikuHeight(900), 1);
      expect(fungaSikuHeight(1300), closeTo(.4, 1e-9));
    });

    test('13 burners light from the centre outward by 400 ms', () {
      final spec = FireSpec.fungaSiku();
      expect(spec.emitterX, hasLength(13));
      expect(spec.emitterX.first, 15);
      expect(spec.emitterX.last, 375);
      expect(spec.igniteMs[6], 150);
      expect(spec.igniteMs.first, 400);
      expect(spec.igniteMs.last, 400);
    });

    test('never more than 400 live flames; the loop ends by itself', () {
      final s = FireSystem(FireSpec.fungaSiku(), random: math.Random(1));
      final peak = run(s, 1600);
      expect(peak, greaterThan(100));
      expect(peak, lessThanOrEqualTo(400));
      run(s, 6500, from: 1600);
      expect(s.finished, isTrue);
    });

    test('the sale flame is small and out in well under a second', () {
      final s = FireSystem(FireSpec.saleSuccess(), random: math.Random(2));
      expect(run(s, 400), lessThanOrEqualTo(120));
      run(s, 1300, from: 400);
      expect(s.finished, isTrue);
    });
  });

  group('sale saved: Signature A', () {
    Widget mark(String id) => ProviderScope(
        child: MaterialApp(
            theme: mrNyamaTheme(),
            home: Scaffold(
                body: Center(
                    child: SaleSuccessMark(key: ValueKey(id), playId: id)))));

    testWidgets('plays once per sale; a rebuild never replays it',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Widget scoped(Widget child) =>
          UncontrolledProviderScope(container: container, child: child);
      await tester.pumpWidget(scoped(mark('sale-1')));
      expect(find.byType(FireCanvas), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse); // no endless loop
      // The screen is rebuilt later (for example after a sync).
      await tester.pumpWidget(scoped(const SizedBox()));
      await tester.pumpWidget(scoped(mark('sale-1')));
      expect(find.byType(FireCanvas), findsNothing);
      // A different sale plays again.
      await tester.pumpWidget(scoped(mark('sale-2')));
      expect(find.byType(FireCanvas), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: the finished mark, no flame', (tester) async {
      setScreen(tester, reducedMotion: true);
      await tester.pumpWidget(mark('sale-1'));
      expect(find.byType(FireCanvas), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the next sale can start while the mark is still playing',
        (tester) async {
      final app = await pumpApp(tester,
          api: FakeVendorRepository()..catalogSnapshot = testCatalog);
      final sale = await app.container.read(salesStoreProvider).saveSale(
              SaleDraft(
                  clientId: 'sale-1',
                  vendorId: 'v1',
                  recordedAt: DateTime.now(),
                  payment: PaymentMethod.cash,
                  lines: const [
                DraftLine(
                    productId: 'kuku',
                    productName: 'Kuku mzima',
                    quantity: 1,
                    unitPrice: 9000)
              ]));
      app.router.go(MNRoutes.saleSaved(sale.clientId));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(FireCanvas), findsOneWidget); // still animating
      expect(find.text('TSh 9,000'), findsOneWidget); // the real amount
      await tester.tap(find.text('Rekodi Mauzo Mengine'));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, MNRoutes.sales);
    });
  });

  group('Funga Siku: Signature B', () {
    Future<TestApp> closeDay(WidgetTester tester,
        {bool reducedMotion = false}) async {
      final now = DateTime.utc(2026, 10, 9, 17);
      final app = await pumpApp(tester,
          now: now,
          reducedMotion: reducedMotion,
          api: FakeVendorRepository()..catalogSnapshot = testCatalog);
      await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
      await app.container.read(closingStoreProvider).submit(
          countId: 'count-1',
          vendorId: 'v1',
          stationKey: 'S1',
          now: now,
          products: await app.container
              .read(salesStoreProvider)
              .watchProducts()
              .first,
          counted: {'kuku': 5, 'paja': 2});
      app.router.go(MNRoutes.dayClosed);
      await tester.pump();
      await tester.pump();
      return app;
    }

    Finder headline() => find.textContaining('IMEFUNGWA!', findRichText: true);
    Finder statusLine() => find.text('Hesabu imehifadhiwa kwenye simu.');
    Finder home() => find.widgetWithText(MNButton, 'Rudi Nyumbani');

    testWidgets('follows the approved timeline', (tester) async {
      await closeDay(tester);
      expect(find.byType(FireCanvas), findsOneWidget);
      expect(find.text('Ruka'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityOf(tester, headline()), 0);

      await tester.pump(const Duration(milliseconds: 700)); // 1300: headline
      await tester.pump(const Duration(milliseconds: 280)); // 1580
      expect(opacityOf(tester, headline()), 1);
      expect(opacityOf(tester, statusLine()), 0);
      expect(tester.widget<MNButton>(home()).onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 100)); // 1680: reveal
      await tester.pump(const Duration(milliseconds: 250));
      expect(opacityOf(tester, statusLine()), 1);
      expect(find.text('Inasubiri kutumwa.'), findsOneWidget);
      expect(tester.widget<MNButton>(home()).onPressed, isNotNull);
      expect(find.text('Ruka'), findsNothing);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse); // the loop stopped
    });

    testWidgets('"Ruka" jumps to the settled frame', (tester) async {
      await closeDay(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Ruka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacityOf(tester, statusLine()), 1);
      expect(tester.widget<MNButton>(home()).onPressed, isNotNull);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: settled frame at once, no fire',
        (tester) async {
      await closeDay(tester, reducedMotion: true);
      expect(find.byType(FireCanvas), findsNothing);
      expect(opacityOf(tester, headline()), 1);
      expect(opacityOf(tester, statusLine()), 1);
      expect(find.text('Ruka'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('plays once per closing; reopening shows it settled',
        (tester) async {
      final app = await closeDay(tester);
      await tester.pumpAndSettle();
      app.router.go(MNRoutes.home);
      await tester.pumpAndSettle();
      app.router.go(MNRoutes.dayClosed);
      await tester.pump();
      await tester.pump();
      expect(find.byType(FireCanvas), findsNothing);
      expect(opacityOf(tester, statusLine()), 1);
    });
  });

  testWidgets('cart total rolls to its new value', (tester) async {
    await pumpApp(tester,
        initial: MNRoutes.sales,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuku mzima'));
    await tester.pump(const Duration(milliseconds: 80));
    // Mid-roll: the new total is already shown and sliding in.
    expect(find.text('Bidhaa 2 · TSh 18,000'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Bidhaa 1 · TSh 9,000'), findsNothing);
  });
}
