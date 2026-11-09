import 'dart:convert';

import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'helpers.dart';
import 'sales_flow_test.dart' show choose, openCart, tapProduct;

/// 26 October 2026, 08:00 in Dar es Salaam: yesterday is 25 October.
final morning = DateTime.utc(2026, 10, 26, 5);
final yesterdayNoon = DateTime.utc(2026, 10, 25, 9);

Future<void> sell(SalesStore store, String id, DateTime at) =>
    store.saveSale(SaleDraft(
        clientId: id,
        vendorId: 'v1',
        stationKey: 'S1',
        recordedAt: at,
        payment: PaymentMethod.cash,
        lines: const [
          DraftLine(
              productId: 'kuku',
              productName: 'Kuku mzima',
              quantity: 1,
              unitPrice: 9000,
              priceVersion: 'v1')
        ]));

void main() {
  late AppDatabase db;
  late SalesStore sales;
  late ClosingStore closing;

  setUp(() async {
    db = testDatabase();
    sales = SalesStore(db);
    closing = ClosingStore(db);
    await sales.replaceCatalog(testCatalog);
  });
  tearDown(() => db.close());

  Future<YesterdayClosing> state() => closing.yesterdayState(
      vendorId: 'v1', stationKey: 'S1', now: morning, tracksStock: true);

  Future<ClosingView> close({String id = 'k1'}) async => closing.submit(
      countId: id,
      vendorId: 'v1',
      stationKey: 'S1',
      now: morning,
      products: await sales.watchProducts().first,
      counted: {
        for (final p in productsToCount(await sales.watchProducts().first))
          p.id: 1
      },
      businessDay: DateTime.utc(2026, 10, 25));

  test('a day not worked needs no closing', () async {
    expect(await state(), YesterdayClosing.none);
    await expectLater(close(), throwsA(isA<ClosingRefused>()));
  });

  test('worked yesterday, nothing today: close yesterday this morning',
      () async {
    await sell(sales, 's1', yesterdayNoon);
    expect(await state(), YesterdayClosing.open);
    final view = await close();
    expect(view.businessDate, DateTime.utc(2026, 10, 25));
    final op = (await db.select(db.outbox).get())
        .firstWhere((o) => o.opType == 'closing_count');
    final payload = jsonDecode(op.payload) as Map;
    expect(payload['business_date'], '2026-10-25');
    expect(await state(), YesterdayClosing.closed);
  });

  test('once today has a sale, yesterday can no longer be closed', () async {
    await sell(sales, 's1', yesterdayNoon);
    await sell(sales, 's2', morning);
    expect(await state(), YesterdayClosing.missed);
    await expectLater(close(), throwsA(isA<ClosingRefused>()));
  });

  testWidgets(
      'yesterday count has review and submit actions and saves yesterday',
      (tester) async {
    final app = await pumpApp(tester,
        now: morning,
        connectivity: Stream.value(false),
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
    await sell(app.container.read(salesStoreProvider), 's1', yesterdayNoon);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.closeDay);
    await tester.pumpAndSettle();
    for (final name in ['Kuku mzima', 'Paja (Robo)']) {
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(MNPinKeypad), matching: find.text('1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MNButton, 'Hifadhi'));
      await tester.pumpAndSettle();
    }
    await freezeCount(tester);
    expect(find.text("Hifadhi na funga siku"), findsOneWidget);
    expect(tester.widget<MNButton>(find.widgetWithText(MNButton, "Hifadhi na funga siku")).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    final records = await app.db.select(app.db.closingCounts).get();
    expect(records, hasLength(1));
    expect(records.single.businessDate, '2026-10-25');
    final outbox = await app.db.select(app.db.outbox).get();
    expect(
        outbox.where((event) => event.opType == 'closing_count'), hasLength(1));
  });

  testWidgets('the cart waits until yesterday is closed', (tester) async {
    final app = await pumpApp(tester,
        now: morning,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog,
        initial: MNRoutes.sales);
    await sell(app.container.read(salesStoreProvider), 's1', yesterdayNoon);
    await tester.pumpAndSettle();
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    await choose(tester, 'Taslimu');
    expect(find.textContaining('haikufungwa'), findsOneWidget);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi mauzo'))
            .onPressed,
        isNull);
    expect(find.widgetWithText(MNButton, 'Funga siku ya jana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nyumbani shows yesterday in today\'s card and opens Funga Siku',
      (tester) async {
    final app = await pumpApp(tester,
        now: morning,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog,
        initial: MNRoutes.home);
    // The phone already holds the catalogue from earlier selling.
    await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
    await sell(app.container.read(salesStoreProvider), 's1', yesterdayNoon);
    await tester.pumpAndSettle();
    expect(find.text('Siku ya jana haijafungwa'), findsOneWidget);
    expect(find.textContaining('Funga kabla ya mauzo ya leo'), findsOneWidget);
    // One row, no separate banner button.
    expect(find.widgetWithText(MNButton, 'Funga siku ya jana'), findsNothing);
    await tester.ensureVisible(find.text('Siku ya jana haijafungwa'));
    await tester.tap(find.text('Siku ya jana haijafungwa'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.closeDay);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missed day says a supervisor will open a case, not that the '
      'office handles the count', (tester) async {
    final app = await pumpApp(tester,
        now: morning,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog,
        initial: MNRoutes.home);
    await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
    await sell(app.container.read(salesStoreProvider), 's1', yesterdayNoon);
    await sell(app.container.read(salesStoreProvider), 's2', morning);
    await tester.pumpAndSettle();
    expect(find.textContaining('Msimamizi atafungua kesi ya siku hii'),
        findsOneWidget);
    expect(find.textContaining('Ofisi itashughulikia'), findsNothing);
    expect(find.textContaining('handles the count'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
