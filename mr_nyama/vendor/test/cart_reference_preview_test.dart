// Kikapu reference previews (approved 22 October 2026). Opt-in, so the
// normal suite stays fast:
//   flutter test test/cart_reference_preview_test.dart \
//     --dart-define=CART_PREVIEWS=true
// Writes 390×844 @2x PNGs to ../../output/vendor-cart-previews/.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/features/sales/checkout.dart';
import 'package:mr_nyama_vendor/features/sales/product_images.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/payment_option.dart';

import 'helpers.dart';

const _enabled = bool.fromEnvironment('CART_PREVIEWS');

/// The reference image's three products. Prices are test data.
const previewCatalog = CatalogSnapshot(products: [
  CatalogItem(
      id: 'nusu',
      name: 'Nusu kuku',
      price: 4500,
      imageKey: 'nusu',
      available: 8),
  CatalogItem(
      id: 'paja', name: 'Paja', price: 2000, imageKey: 'paja', available: 10),
  CatalogItem(
      id: 'mishkaki',
      name: 'Kuku mishikaki',
      price: 2500,
      imageKey: 'mishkaki',
      available: 18),
]);

class _FailingStore extends SalesStore {
  _FailingStore(super.db);
  @override
  Future<SavedSale> saveSale(SaleDraft draft) async =>
      throw StateError('disk full');
}

Future<TestApp> _open(WidgetTester tester,
    {FakeVendorRepository? api, bool failSave = false}) async {
  final app = await pumpApp(tester,
      api: api ?? (FakeVendorRepository()..catalogSnapshot = previewCatalog),
      initial: MNRoutes.sales,
      overrides: [
        if (failSave)
          salesStoreProvider.overrideWith(
              (ref) => _FailingStore(ref.watch(databaseProvider))),
      ]);
  tester.view
    ..padding = const FakeViewPadding(top: 47, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() => Future.wait([
        for (final p in previewCatalog.products)
          precacheImage(
              productImageFor(p.imageKey, productName: p.name)!, context),
      ]));
  return app;
}

Future<void> _fill(TestApp app, WidgetTester tester,
    {Map<String, int> lines = const {
      'nusu': 1,
      'paja': 2,
      'mishkaki': 1
    }}) async {
  final cart = app.container.read(cartProvider.notifier);
  for (final MapEntry(:key, :value) in lines.entries) {
    cart.add(key, value);
  }
  app.router.push(MNRoutes.cart);
  await tester.pumpAndSettle();
}

Future<void> _cash(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MNPaymentOption, 'Taslimu'));
  await tester.pumpAndSettle();
}

Future<void> shot(WidgetTester tester, String name) async {
  final boundary = tester
      .firstRenderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/vendor-cart-previews');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  testWidgets('top row: list, swipe, undo, empty, no payment', (tester) async {
    final app = await _open(tester);
    await _fill(app, tester);
    await _cash(tester);
    await shot(tester, '1-kikapu');

    await tester.drag(find.text('Paja'), const Offset(-90, 0));
    await tester.pumpAndSettle();
    await shot(tester, '2-swipe');

    await tester.tap(find.text('Futa'));
    await tester.pumpAndSettle();
    await shot(tester, '3-undo');

    await tester.tap(find.text('Rudisha'));
    await tester.pumpAndSettle();
    app.container.read(cartProvider.notifier).clear();
    await tester.pumpAndSettle();
    await shot(tester, '4-empty');

    app.container.invalidate(checkoutProvider);
    app.container.read(cartProvider.notifier)
      ..add('nusu')
      ..add('paja', 2);
    await tester.pumpAndSettle();
    await shot(tester, '5-no-payment');
  }, skip: !_enabled);

  testWidgets('bottom row: clear, sent, pending, failed', (tester) async {
    final app = await _open(tester);
    await _fill(app, tester);
    await tester.tap(find.text('Futa zote'));
    await tester.pumpAndSettle();
    await shot(tester, '6-futa-zote');
    await tester.tap(find.text('Ghairi'));
    await tester.pumpAndSettle();

    // Pending: the server has not answered yet.
    final gate = Completer<void>();
    app.api
      ..syncFailure = null
      ..syncGate = gate;
    await _cash(tester);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi mauzo'));
    await tester.pumpAndSettle();
    await shot(tester, '8-pending');

    // The server accepts it: the same sheet turns into "sent".
    gate.complete();
    await tester.pumpAndSettle();
    await shot(tester, '7-sent');
  }, skip: !_enabled);

  testWidgets('save failure sheet', (tester) async {
    final app = await _open(tester, failSave: true);
    await _fill(app, tester);
    await _cash(tester);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi mauzo'));
    await tester.pumpAndSettle();
    await shot(tester, '9-failed');
  }, skip: !_enabled);
}
