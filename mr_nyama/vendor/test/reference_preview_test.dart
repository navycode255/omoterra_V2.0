import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'helpers.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/features/home/dashboard.dart';
import 'package:mr_nyama_vendor/features/sales/product_images.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';
import 'receiving_flow_test.dart' show delivery;

void main() {
  testWidgets('reference screens render at the supplied image proportions',
      (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    final api = FakeVendorRepository()
      ..deliveryList = [delivery()]
      ..catalogSnapshot = const CatalogSnapshot(products: [
        CatalogItem(
            id: 'firigisi', name: 'Firigisi', price: 1000, available: 24),
        CatalogItem(id: 'kidali', name: 'Kidali', price: 2500, available: 12),
        CatalogItem(
            id: 'mishkaki', name: 'Kuku mishkaki', price: 1500, available: 18),
        CatalogItem(id: 'mzima', name: 'Kuku mzima', price: 9000, available: 6),
        CatalogItem(id: 'nusu', name: 'Nusu kuku', price: 4500, available: 8),
        CatalogItem(id: 'paja', name: 'Paja', price: 2000, available: 10),
      ])
      ..dashboardSummary = DashboardSummary(
          date: DateTime(2026, 10, 22),
          todayTotal: 0,
          saleCount: 0,
          cashTotal: 0,
          mpesaTotal: 0,
          recent: []);
    final app = await pumpApp(tester,
        api: api,
        now: DateTime.utc(2026, 10, 23, 12),
        size: const Size(390, 824),
        overrides: [
          syncStatusProvider.overrideWith((ref) => MNSyncStatus.waiting),
          syncOutstandingCountProvider.overrideWith((ref) => 3),
        ]);
    app.container.read(cartProvider.notifier)
      ..add('nusu', 1)
      ..add('paja', 2)
      ..add('mishkaki', 1);
    await app.container.read(salesStoreProvider).saveSale(SaleDraft(
            clientId: 'preview-sale-1',
            vendorId: 'v1',
            recordedAt: DateTime.utc(2026, 10, 23, 12),
            payment: PaymentMethod.cash,
            lines: const [
              DraftLine(
                  productId: 'nusu',
                  productName: 'Nusu kuku',
                  quantity: 2,
                  unitPrice: 4500)
            ]));
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(() => Future.wait([
          precacheImage(const AssetImage('assets/brand/icon.png'), context),
          for (final p in api.catalogSnapshot.products)
            precacheImage(
                productImageFor(p.imageKey, productName: p.name)!, context),
        ]));
    await tester.pumpAndSettle();
    for (final (name, route) in [
      ('nyumbani', MNRoutes.home),
      ('bidhaa', MNRoutes.products),
      ('pokea', MNRoutes.receive),
      ('historia', MNRoutes.history),
      ('kikapu', MNRoutes.cart),
      ('funga-siku', MNRoutes.closeDay)
    ]) {
      tester.view.physicalSize = const Size(390, 824);
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary));
      final image =
          (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
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
    debugDisableShadows = previousShadows;
  });
}
