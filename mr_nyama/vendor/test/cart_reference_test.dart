import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/features/sales/kikapu_sheets.dart';
import 'package:mr_nyama_vendor/features/sales/sale_success_mark.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/motion/fire.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/payment_option.dart';

import 'helpers.dart';

/// Fails the first [failures] saves, then saves normally.
class FlakyStore extends SalesStore {
  int failures;
  int attempts = 0;
  FlakyStore(super.db, this.failures);

  @override
  Future<SavedSale> saveSale(SaleDraft draft) {
    attempts++;
    if (failures > 0) {
      failures--;
      throw StateError('disk full');
    }
    return super.saveSale(draft);
  }
}

Future<TestApp> openCart(WidgetTester tester,
    {Map<String, int> lines = const {'kuku': 1, 'paja': 2, 'kidali': 1},
    FakeVendorRepository? api,
    FlakyStore Function(SalesStore)? store,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reducedMotion = false}) async {
  final app = await pumpApp(tester,
      api: api ?? (FakeVendorRepository()..catalogSnapshot = testCatalog),
      initial: MNRoutes.sales,
      size: size,
      textScale: textScale,
      reducedMotion: reducedMotion,
      overrides: [
        if (store != null)
          salesStoreProvider.overrideWith(
              (ref) => store(SalesStore(ref.watch(databaseProvider)))),
      ]);
  final cart = app.container.read(cartProvider.notifier);
  for (final MapEntry(:key, :value) in lines.entries) {
    cart.add(key, value);
  }
  app.router.push(MNRoutes.cart);
  await tester.pumpAndSettle();
  return app;
}

Finder saveButton() => find.widgetWithText(MNButton, 'Hifadhi mauzo');

Future<void> payCash(WidgetTester tester) async {
  await tester.scrollUntilVisible(
      find.widgetWithText(MNPaymentOption, 'Taslimu'), 100,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.widgetWithText(MNPaymentOption, 'Taslimu'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(saveButton());
  await tester.tap(saveButton());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('swipe left reveals Futa; undo restores the line in place',
      (tester) async {
    final app = await openCart(tester);
    expect(find.text('Futa'), findsNothing);
    await tester.drag(find.text('Paja (Robo)'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Futa'), findsOneWidget);
    // Revealing alone removes nothing.
    expect(app.container.read(cartProvider).quantityOf('paja'), 2);

    await tester.tap(find.text('Futa'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('paja'), 0);
    expect(find.text('Paja (Robo) limefutwa.'), findsOneWidget);

    await tester.tap(find.text('Rudisha'));
    await tester.pumpAndSettle();
    final lines = app.container.read(cartProvider).lines;
    expect(lines.keys.toList(), ['kuku', 'paja', 'kidali']);
    expect(lines['paja'], 2);
    expect(find.text('Paja (Robo) limefutwa.'), findsNothing);
  });

  testWidgets('the undo snackbar leaves after a few seconds', (tester) async {
    await openCart(tester);
    await tester.drag(find.text('Paja (Robo)'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futa'));
    await tester.pumpAndSettle();
    expect(find.text('Rudisha'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Rudisha'), findsNothing);
  });

  testWidgets('Futa zote asks first: Ghairi keeps the items', (tester) async {
    final app = await openCart(tester);
    await tester.tap(find.text('Futa zote'));
    await tester.pumpAndSettle();
    expect(find.text('Futa bidhaa zote?'), findsOneWidget);
    expect(
        find.text('Hii itaondoa bidhaa zote kwenye kikapu.'), findsOneWidget);
    await tester.tap(find.text('Ghairi'));
    await tester.pumpAndSettle();
    expect(find.text('Futa bidhaa zote?'), findsNothing);
    expect(app.container.read(cartProvider).itemCount, 4);

    await tester.tap(find.text('Futa zote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futa zote').last);
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).isEmpty, isTrue);
    expect(find.text('Kikapu ni tupu'), findsOneWidget);
  });

  testWidgets('empty cart: message and Ongeza bidhaa, no totals or payment',
      (tester) async {
    final app = await openCart(tester, lines: const {});
    expect(find.text('Kikapu ni tupu'), findsOneWidget);
    expect(find.text('Ongeza bidhaa kuanza mauzo.'), findsOneWidget);
    expect(find.text('Jumla'), findsNothing);
    expect(find.text('Aina ya malipo'), findsNothing);
    expect(saveButton(), findsNothing);
    await tester.tap(find.text('Ongeza bidhaa'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.sales);
  });

  testWidgets('no payment is preselected; saving waits for a choice',
      (tester) async {
    final app = await openCart(tester);
    expect(find.text('TZS 15,500'), findsOneWidget); // 9,000 + 4,000 + 2,500
    expect(
        tester
            .widget<MNPaymentOption>(
                find.widgetWithText(MNPaymentOption, 'Taslimu'))
            .selected,
        isFalse);
    expect(tester.widget<MNButton>(saveButton()).onPressed, isNull);
    await tester.tap(saveButton(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.sales).get(), isEmpty);
    await payCash(tester);
    expect(tester.widget<MNButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets(
      'saved on the phone: the sheet shows at once and switches to sent '
      'only when the server accepts the sale', (tester) async {
    final gate = Completer<void>();
    final api = FakeVendorRepository()
      ..catalogSnapshot = testCatalog
      ..syncFailure = null
      ..syncGate = gate;
    final app = await openCart(tester, api: api);
    await payCash(tester);
    await tapSave(tester);

    // Shown without waiting for the network, and not claiming "sent".
    expect(find.byType(SaleResultSheet), findsOneWidget);
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
    expect(find.text('Inasubiri mtandao'), findsOneWidget);
    expect(find.text('Yametumwa ofisini'), findsNothing);
    expect(find.byType(SaleSuccessMark), findsNothing);
    expect(app.container.read(cartProvider).isEmpty, isTrue);
    final sale = (await app.db.select(app.db.sales).get()).single;
    expect(sale.syncStatus, 'saved');
    expect(api.calls.where((c) => c.startsWith('sync')), isNotEmpty);

    // The server answers: the same sheet now says sent, with the signature.
    final sheet = tester.element(find.byType(SaleResultSheet));
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(FireCanvas), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(SaleResultSheet)), same(sheet));
    expect(find.text('Mauzo yamehifadhiwa'), findsOneWidget);
    expect(find.text('Yametumwa ofisini'), findsOneWidget);
    expect(find.text('Imesawazishwa'), findsOneWidget);
    expect(find.byType(SaleSuccessMark), findsOneWidget);
    expect((await app.db.select(app.db.sales).get()).single.syncStatus, 'sent');

    await tester.tap(find.text('Sawa'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.sales);
    expect(app.container.read(cartProvider).isEmpty, isTrue);
  });

  testWidgets('a refused sale never shows as sent', (tester) async {
    final api = FakeVendorRepository()
      ..catalogSnapshot = testCatalog
      ..syncFailure = null
      ..syncDecision =
          (op) => OperationResult(op.opId, OperationOutcome.rejected, 'x');
    await openCart(tester, api: api);
    await payCash(tester);
    await tapSave(tester);
    expect(find.text('Yametumwa ofisini'), findsNothing);
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
  });

  testWidgets('a failed save keeps the cart; Jaribu tena saves it once',
      (tester) async {
    late FlakyStore flaky;
    final app =
        await openCart(tester, store: (s) => flaky = FlakyStore(s.db, 1));
    await payCash(tester);
    await tapSave(tester);
    expect(find.text('Imeshindikana kuhifadhi'), findsOneWidget);
    expect(find.textContaining('wasiliana na ofisi'), findsOneWidget);
    expect(app.container.read(cartProvider).itemCount, 4);
    expect(await app.db.select(app.db.sales).get(), isEmpty);

    await tester.tap(find.text('Jaribu tena'));
    await tester.pumpAndSettle();
    expect(flaky.attempts, 2);
    expect(await app.db.select(app.db.sales).get(), hasLength(1));
    expect(find.text('Mauzo yamehifadhiwa kwenye simu'), findsOneWidget);
  });

  testWidgets('Ghairi on a failed save returns to the intact cart',
      (tester) async {
    final app = await openCart(tester, store: (s) => FlakyStore(s.db, 1));
    await payCash(tester);
    await tapSave(tester);
    await tester.tap(find.text('Ghairi'));
    await tester.pumpAndSettle();
    expect(find.text('Imeshindikana kuhifadhi'), findsNothing);
    expect(app.router.state.uri.path, MNRoutes.cart);
    expect(app.container.read(cartProvider).itemCount, 4);
    expect(find.text('Paja (Robo)'), findsOneWidget);
  });

  testWidgets('reduced motion: the sent sheet shows the settled check',
      (tester) async {
    final api = FakeVendorRepository()
      ..catalogSnapshot = testCatalog
      ..syncFailure = null;
    await openCart(tester, api: api, reducedMotion: true);
    await payCash(tester);
    await tester.tap(saveButton());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Yametumwa ofisini'), findsOneWidget);
    expect(find.byType(SaleSuccessMark), findsOneWidget);
    expect(find.byType(FireCanvas), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets('no overflow at ${size.width.toInt()} px, text ×$scale',
        (tester) async {
      final gate = Completer<void>();
      final api = FakeVendorRepository()
        ..catalogSnapshot = testCatalog
        ..syncFailure = null
        ..syncGate = gate;
      await openCart(tester, api: api, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.drag(find.text('Kuku mzima'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Futa'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Futa zote'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ghairi'));
      await tester.pumpAndSettle();
      await payCash(tester);
      await tapSave(tester);
      expect(tester.takeException(), isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Yametumwa ofisini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty cart has no overflow at 320 px and text ×2',
      (tester) async {
    await openCart(tester,
        lines: const {}, size: const Size(320, 568), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap targets are at least 48 px and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await openCart(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    for (final f in [
      find.bySemanticsLabel('Punguza Kuku mzima'),
      find.bySemanticsLabel('Ongeza Kuku mzima'),
    ]) {
      final size = tester.getSize(f);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await tester.drag(find.text('Paja (Robo)'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futa'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('Futa zote'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('screen readers can remove a line without swiping',
      (tester) async {
    final app = await openCart(tester);
    final row = tester.widget<Semantics>(find.ancestor(
        of: find.text('Paja (Robo)'),
        matching: find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.customSemanticsActions != null)));
    final actions = row.properties.customSemanticsActions!;
    expect(actions.keys.single.label, 'Futa Paja (Robo)');
    actions.values.single();
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('paja'), 0);
    expect(find.text('Rudisha'), findsOneWidget);
  });
}
