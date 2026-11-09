import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/credit/credit_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/payment_option.dart';

import 'helpers.dart';
import 'sales_flow_test.dart' show choose, openCart, save, tapProduct;

const rehema = CreditCustomerData(
    id: 'c1', name: 'Mama Rehema', creditLimit: 50000, owed: 5000);
const juma = CreditCustomerData(id: 'c2', name: 'Juma Ally');

Future<TestApp> openWithCustomers(WidgetTester tester,
    {List<CreditCustomerData> customers = const [rehema, juma],
    String initial = MNRoutes.sales}) async {
  final app = await pumpApp(tester,
      api: FakeVendorRepository()
        ..catalogSnapshot = testCatalog
        ..creditCustomerList = customers,
      initial: initial);
  await tester.pumpAndSettle();
  return app;
}

class _FailingCreditStore extends CreditStore {
  _FailingCreditStore(super.db);
  @override
  Future<void> submitRepayment(
          {required String id,
          required String vendorId,
          required String stationKey,
          required String customerId,
          required int amount,
          required String method,
          required DateTime receivedAt,
          String? note}) =>
      throw StateError('disk full');
}

void main() {
  testWidgets('a failed repayment save says not saved, never "Mauzo"',
      (tester) async {
    final app = await pumpApp(tester,
        api: FakeVendorRepository()
          ..catalogSnapshot = testCatalog
          ..creditCustomerList = const [rehema, juma],
        initial: MNRoutes.credit,
        overrides: [
          creditStoreProvider.overrideWith(
              (ref) => _FailingCreditStore(ref.watch(databaseProvider)))
        ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mama Rehema'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2000');
    await tester.tap(find.widgetWithText(MNButton, 'Pokea malipo'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.credit);
    expect(find.text('Haikuhifadhiwa. Jaribu tena.'), findsOneWidget);
    expect(find.textContaining('Mauzo'), findsNothing);
  });

  testWidgets('a credit sale names a customer the office allows credit for',
      (tester) async {
    final app = await openWithCustomers(tester);
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    await choose(tester, 'Mkopo');
    // The picker: Juma has no limit, so credit is not allowed for him.
    expect(find.text('Ofisi haijaweka kikomo: hawezi kukopa'), findsOneWidget);
    expect(find.textContaining('Anadaiwa TSh 5,000'), findsOneWidget);
    await tester.tap(find.text('Mama Rehema').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Mama Rehema ·'), findsOneWidget);
    await save(tester);

    final sale = (await app.db.select(app.db.sales).get()).single;
    expect((sale.paymentMethod, sale.creditCustomerId, sale.creditCustomerName),
        ('credit', 'c1', 'Mama Rehema'));
    final op = (await app.db.select(app.db.outbox).get()).single;
    final payload = jsonDecode(op.payload) as Map;
    expect(
        (payload['payment_method'], payload['customer_id']), ('credit', 'c1'));
    // What she owes now counts the unsent sale.
    final customers = await app.container.read(creditStoreProvider).load();
    expect(customers.firstWhere((c) => c.id == 'c1').owed, 14000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('over the limit the vendor is warned and can still save',
      (tester) async {
    await openWithCustomers(tester, customers: const [
      CreditCustomerData(
          id: 'c1', name: 'Mama Rehema', creditLimit: 10000, owed: 5000)
    ]);
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    await choose(tester, 'Mkopo');
    await tester.tap(find.text('Mama Rehema').last);
    await tester.pumpAndSettle();
    expect(
        find.textContaining('zaidi ya kikomo cha TSh 10,000'), findsOneWidget);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi mauzo'))
            .onPressed,
        isNotNull);
  });

  testWidgets('without credit customers Mkopo cannot be chosen',
      (tester) async {
    await openWithCustomers(tester, customers: const []);
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    expect(
        find.text('Hakuna wateja wa mkopo kituoni. Ofisi ndiyo inawasajili.'),
        findsOneWidget);
    expect(
        tester
            .widget<MNPaymentOption>(
                find.widgetWithText(MNPaymentOption, 'Mkopo'))
            .onTap,
        isNull);
  });

  testWidgets('the vendor takes a repayment; no more than is owed',
      (tester) async {
    final app = await openWithCustomers(tester, initial: MNRoutes.credit);
    expect(find.text('Wateja wa mkopo'), findsWidgets);
    expect(find.text('TSh 5,000'), findsWidgets);
    await tester.tap(find.text('Mama Rehema'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '6000');
    await tester.tap(find.widgetWithText(MNButton, 'Pokea malipo'));
    await tester.pumpAndSettle();
    expect(
        find.text('Kiasi kisizidi anachodaiwa (TSh 5,000).'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '2000');
    await tester.tap(find.widgetWithText(MNButton, 'Pokea malipo'));
    await tester.pumpAndSettle();
    expect(find.text('Malipo yamehifadhiwa kwenye simu.'), findsOneWidget);
    final op = (await app.db.select(app.db.outbox).get()).single;
    expect(op.opType, 'credit_repayment');
    final payload = jsonDecode(op.payload) as Map;
    expect((payload['customer_id'], payload['amount'], payload['method']),
        ('c1', 2000, 'cash'));
    expect(find.text('TSh 3,000'), findsWidgets);
    expect(find.text('Rekodi 1 bado hazijatumwa ofisini'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no M-Pesa number a repayment is cash, nothing to choose',
      (tester) async {
    await pumpApp(tester,
        api: FakeVendorRepository()
          ..catalogSnapshot = CatalogSnapshot(products: testCatalog.products)
          ..creditCustomerList = const [rehema],
        initial: MNRoutes.credit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mama Rehema'));
    await tester.pumpAndSettle();
    expect(find.text('Amelipaje?'), findsNothing);
    expect(find.textContaining('M-Pesa'), findsNothing);
    expect(find.text('Taslimu itaongezwa kwenye fedha unazokabidhi ofisini.'),
        findsOneWidget);
  });

  testWidgets('with an M-Pesa number the vendor can choose it', (tester) async {
    // The number arrives with the catalogue, which Mauzo downloads.
    final app = await openWithCustomers(tester, customers: const [rehema]);
    app.router.push(MNRoutes.credit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mama Rehema'));
    await tester.pumpAndSettle();
    expect(find.text('Amelipaje?'), findsOneWidget);
  });

  test('a credit sale must name its customer, and only a credit sale',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = SalesStore(db);
    SaleDraft draft(PaymentMethod p, String? customer) => SaleDraft(
            clientId: 's-${p.name}-$customer',
            vendorId: 'v1',
            recordedAt: DateTime(2026, 10, 25, 12),
            payment: p,
            customerId: customer,
            lines: const [
              DraftLine(
                  productId: 'kuku',
                  productName: 'Kuku mzima',
                  quantity: 1,
                  unitPrice: 9000,
                  priceVersion: 'v1')
            ]);
    expect(() => store.saveSale(draft(PaymentMethod.credit, null)),
        throwsArgumentError);
    expect(() => store.saveSale(draft(PaymentMethod.cash, 'c1')),
        throwsArgumentError);
    await store.saveSale(draft(PaymentMethod.credit, 'c1'));
  });
}
