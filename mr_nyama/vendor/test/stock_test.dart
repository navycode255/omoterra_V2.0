import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/rows.dart';

import 'helpers.dart';

void main() {
  testWidgets(
      'stock chevron opens live details and sales stays an explicit action',
      (tester) async {
    final app = await pumpApp(tester,
        initial: MNRoutes.products,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kuku mzima'));
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(find.text('Imesalia: 8'), findsOneWidget);
    expect(find.text('TSh 9,000'), findsOneWidget);
    await tester.tap(find.text('Rekodi mauzo'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.sales);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Bidhaa lists the products with what is left', (tester) async {
    final app = await pumpApp(tester,
        initial: MNRoutes.products,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
    await tester.pumpAndSettle();
    expect(find.byType(MNStockRow), findsNWidgets(testCatalog.products.length));
    for (final p in testCatalog.products) {
      expect(find.text(p.name), findsOneWidget);
    }
    expect(find.text('Hakuna bidhaa bado'), findsNothing);
    // The actions precede the products in the same scroll.
    expect(find.text('Pokea bidhaa'), findsOneWidget);
  });

  testWidgets('a sale saved on the phone lowers what is left', (tester) async {
    final app = await pumpApp(tester,
        initial: MNRoutes.products,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    final store = app.container.read(salesStoreProvider);
    await store.replaceCatalog(testCatalog);
    await tester.pumpAndSettle();
    final kuku = testCatalog.products.firstWhere((p) => p.id == 'kuku');
    Finder left(int n) => find.descendant(
        of: find.widgetWithText(MNStockRow, kuku.name),
        matching: find.text('$n'));
    expect(left(kuku.available!), findsOneWidget);
    await store.saveSale(SaleDraft(
        clientId: 'stock-1',
        vendorId: 'v1',
        recordedAt: DateTime.now(),
        payment: PaymentMethod.cash,
        lines: [
          DraftLine(
              productId: 'kuku',
              productName: kuku.name,
              quantity: 2,
              unitPrice: kuku.price!)
        ]));
    await tester.pumpAndSettle();
    expect(left(kuku.available! - 2), findsOneWidget);
  });

  testWidgets('swiping products scrolls the top actions away and back',
      (tester) async {
    final catalog = CatalogSnapshot(products: [
      for (var i = 0; i < 24; i++)
        CatalogItem(
            id: 'product-$i', name: 'Bidhaa $i', price: 2000, category: 'kuku'),
    ]);
    await pumpApp(tester,
        initial: MNRoutes.products,
        api: FakeVendorRepository()..catalogSnapshot = catalog);
    await tester.pumpAndSettle();
    final action = find.text('Pokea bidhaa');
    final start = tester.getTopLeft(action).dy;
    // Start the gesture on a product, where the old nested list trapped it.
    await tester.drag(find.byType(MNStockRow).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(action).dy, lessThan(start - 100));
    expect(action.hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('Bidhaa 23'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Bidhaa 23').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(MNStockRow).last, const Offset(0, 10000));
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no catalogue yet: a quiet empty state', (tester) async {
    await pumpApp(tester, initial: MNRoutes.products);
    await tester.pumpAndSettle();
    expect(find.text('Hakuna bidhaa bado'), findsOneWidget);
  });
}
