import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/providers.dart'
    show apiUrl, apiUrlAllowed;
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/features/sales/product_images.dart';
import 'package:mr_nyama_vendor/features/sales/sales_screen.dart';

import 'helpers.dart';

void main() {
  test('menu photo fallback respects explicit catalogue image keys', () {
    expect(productImageFor(null, productName: ' Kuku mzima '),
        const AssetImage('assets/owner/mzima.png'));
    expect(productImageFor('kidali', productName: 'Kuku mzima'),
        const AssetImage('assets/images/grill.png'));
    expect(
        productImageFor('unrecognised-key', productName: 'Kuku mzima'), isNull);
    expect(productImageFor(null, productName: 'Special ya leo'), isNull);
    final upload = 'uploads/${'a' * 32}/${'b' * 64}.jpg';
    final image = productImageFor(upload, productName: 'Kuku mzima');
    if (apiUrlAllowed(apiUrl)) {
      expect(image, isA<NetworkImage>());
      expect((image as NetworkImage).url, endsWith(upload));
    } else {
      // With no configured host, never substitute menu art for an upload.
      expect(image, isNull);
    }
  });

  testWidgets('Mauzo heading scrolls with products; quick cart stays reachable',
      (tester) async {
    final app = await pumpApp(tester,
        initial: MNRoutes.sales,
        api: FakeVendorRepository()
          ..catalogSnapshot = const CatalogSnapshot(products: [
            CatalogItem(
                id: 'firigisi',
                name: 'Firigisi',
                price: 1000,
                category: 'kuku',
                available: 24),
            CatalogItem(
                id: 'kidali',
                name: 'Kidali (Robo)',
                price: 2500,
                category: 'kuku',
                available: 12),
            CatalogItem(
                id: 'mishkaki',
                name: 'Kuku mishkaki',
                price: 1500,
                category: 'kuku',
                available: 18),
            CatalogItem(
                id: 'mzima',
                name: 'Kuku mzima',
                price: 9000,
                category: 'kuku',
                available: 6),
            CatalogItem(
                id: 'nusu',
                name: 'Nusu kuku',
                price: 4500,
                category: 'kuku',
                available: 8),
            CatalogItem(
                id: 'paja',
                name: 'Paja',
                price: 2000,
                category: 'kuku',
                available: 10),
            CatalogItem(
                id: 'ndizi',
                name: 'Ndizi kaanga',
                price: 500,
                category: 'vyakula',
                available: 20),
          ]));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SalesScreen));
    await tester.runAsync(() => Future.wait([
          precacheImage(const AssetImage('assets/brand/icon.png'), context),
          for (final name in [
            'Firigisi',
            'Kidali (Robo)',
            'Kuku mishkaki',
            'Kuku mzima',
            'Nusu kuku',
            'Paja',
            'Ndizi kaanga'
          ])
            precacheImage(productImageFor(null, productName: name)!, context),
        ]));
    await tester.pumpAndSettle();
    await _capture(tester, 'mauzo');
    await tester.tap(find.text('Firigisi'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('firigisi'), 1);
    await _capture(tester, 'mauzo-selected');

    final scroll = find.descendant(
        of: find.byType(SalesScreen), matching: find.byType(CustomScrollView));
    await tester.drag(scroll, const Offset(0, -520));
    await tester.pumpAndSettle();
    // The large page title and brand do not take up fixed space during sales.
    expect(find.text('Mr. Nyama').hitTestable(), findsNothing);
    final cart = find.bySemanticsLabel(RegExp('^Angalia kikapu'));
    expect(cart.hitTestable(), findsOneWidget);
    await tester.tap(cart);
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.cart);
    expect(app.container.read(cartProvider).quantityOf('firigisi'), 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester
      .firstRenderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/vendor-screen-previews');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}
