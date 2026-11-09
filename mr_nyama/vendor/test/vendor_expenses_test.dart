import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/expenses/expense_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/features/sales/checkout.dart';
import 'helpers.dart';

final at = DateTime.utc(2026, 10, 23, 12);
const categories = ['Mkaa', 'Usafiri'];

class _FailingExpenseStore extends ExpenseStore {
  _FailingExpenseStore(super.db);
  @override
  Future<void> submit(
          {required String id,
          required String vendorId,
          required String stationKey,
          required String category,
          required int amount,
          required DateTime spentAt,
          String? item,
          String? note}) =>
      throw StateError('disk full');
}

class DelayedExpenseCatalogue extends FakeVendorRepository {
  Completer<CatalogSnapshot>? pendingCatalog;
  @override
  Future<CatalogSnapshot> catalog(String token) =>
      pendingCatalog?.future ?? super.catalog(token);
}

/// A server that answers the vendor's own handover list.
class HandoverVendor extends FakeVendorRepository
    implements VendorHandoverRepository {
  List<VendorHandover> rows = [];
  AuthFailure? failure;
  int fetches = 0;
  @override
  Future<List<VendorHandover>> handovers(String token) async {
    fetches++;
    if (failure case final f?) throw f;
    return rows;
  }
}

VendorHandover handoverAt(String id, int amount, DateTime at, String receiver,
        {String status = 'recorded', String? note}) =>
    VendorHandover(
        id: id,
        amount: amount,
        receivedAt: at,
        businessDate: DateTime.utc(2026, 10, 23),
        receiver: receiver,
        status: status,
        note: note);

void main() {
  test(
      'expense claim is durable, scoped, idempotent and awaits office approval',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    await SalesStore(db).replaceCatalog(
        const CatalogSnapshot(products: [], expenseCategories: categories));
    final store = ExpenseStore(db);
    Future<void> save() => store.submit(
        id: 'e1',
        vendorId: 'v1',
        stationKey: 'S1',
        category: 'Mkaa',
        amount: 3000,
        spentAt: at,
        note: 'Mkaa umeisha');
    await save();
    await save();
    expect(await db.select(db.sales).get(), isEmpty);
    final op = (await db.select(db.outbox).get()).single;
    expect(op.opType, 'expense');
    expect(jsonDecode(op.payload)['amount'], 3000);
    expect((await store.watchExpenses('v1').first).single.status, 'saved');
    expect(await store.watchExpenses('v2').first, isEmpty);
    await (db.update(db.outbox)..where((o) => o.opId.equals('e1')))
        .write(const OutboxCompanion(status: Value('synchronized')));
    expect((await store.watchExpenses('v1').first).single.status, 'pending');
    await store.cacheReviews('v1', [
      {
        'id': 'server-e1',
        'client_id': 'e1',
        'category': 'Mkaa',
        'amount': 3000,
        'business_date': '2026-10-23',
        'status': 'approved',
        'note': 'Mkaa umeisha'
      }
    ]);
    expect((await store.watchExpenses('v1').first).single.status, 'approved');
    await store.cacheReviews(
        'v1', []); // A bounded server history never erases an older decision.
    expect((await store.watchExpenses('v1').first).single.status, 'approved');
  });

  test('unknown categories and invalid amounts do not enter the sync queue',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = ExpenseStore(db);
    await SalesStore(db).replaceCatalog(
        const CatalogSnapshot(products: [], expenseCategories: categories));
    for (final (category, amount) in [
      ('Unknown', 10),
      ('Mkaa', 0),
      ('Mkaa', 100000001)
    ]) {
      await expectLater(
          store.submit(
              id: 'invalid',
              vendorId: 'v1',
              stationKey: 'S1',
              category: category,
              amount: amount,
              spentAt: at),
          throwsFormatException);
    }
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  testWidgets('a failed expense save says not saved, never "Mauzo"',
      (tester) async {
    final app = await pumpApp(tester,
        now: at,
        api: FakeVendorRepository()
          ..catalogSnapshot = const CatalogSnapshot(
              products: [], expenseCategories: categories),
        overrides: [
          expenseStoreProvider.overrideWith(
              (ref) => _FailingExpenseStore(ref.watch(databaseProvider)))
        ]);
    app.router.go(MNRoutes.expenses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mkaa').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3000');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hifadhi'));
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    expect(find.text('Haikuhifadhiwa. Jaribu tena.'), findsOneWidget);
    expect(find.textContaining('Mauzo'), findsNothing);
  });

  testWidgets('vendor records an expense from Nyumbani', (tester) async {
    final app = await pumpApp(tester,
        now: at,
        api: FakeVendorRepository()
          ..catalogSnapshot = const CatalogSnapshot(
              products: [], expenseCategories: categories));
    await tester.ensureVisible(find.text('Zaidi'));
    await tester.tap(find.text('Zaidi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gharama'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.expenses);
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mkaa').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3000');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hifadhi'));
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    expect((await app.db.select(app.db.outbox).get()).single.opType, 'expense');
    expect(find.textContaining('inasubiri kutumwa'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'categories the owner adds later reach a phone whose tabs are open',
      (tester) async {
    final api = FakeVendorRepository()
      ..catalogSnapshot =
          const CatalogSnapshot(products: [], expenseCategories: []);
    final app = await pumpApp(tester, now: at, api: api);
    // The tabs downloaded the catalogue before the owner set categories.
    app.router.go(MNRoutes.sales);
    await tester.pumpAndSettle();
    api.catalogSnapshot =
        const CatalogSnapshot(products: [], expenseCategories: categories);
    app.router.go(MNRoutes.expenses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Mkaa'), findsOneWidget);
    expect(find.text('Usafiri'), findsOneWidget);
  });

  testWidgets('category picker updates while the office list is downloading',
      (tester) async {
    final api = DelayedExpenseCatalogue()
      ..catalogSnapshot =
          const CatalogSnapshot(products: [], expenseCategories: []);
    final app = await pumpApp(tester, now: at, api: api);
    api.pendingCatalog = Completer<CatalogSnapshot>();
    app.router.go(MNRoutes.expenses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Mengineyo').last, findsOneWidget);
    api.pendingCatalog!.complete(
        const CatalogSnapshot(products: [], expenseCategories: categories));
    await tester
        .runAsync(() => app.container.read(catalogRefreshProvider.future));
    await tester.pumpAndSettle();
    expect(find.text('Mkaa'), findsOneWidget);
    expect(find.text('Usafiri'), findsOneWidget);
  });

  testWidgets(
      'a failed category download is shown and can be retried from the form',
      (tester) async {
    final api = FakeVendorRepository()
      ..catalogFailure = const AuthFailure(AuthFailureKind.offline);
    final app = await pumpApp(tester, now: at, api: api);
    app.router.go(MNRoutes.expenses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Aina za gharama hazijasasishwa.'), findsWidgets);
    api.catalogFailure = null;
    api.catalogSnapshot =
        const CatalogSnapshot(products: [], expenseCategories: categories);
    await tester.tap(find.text('Jaribu tena').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Mkaa'), findsOneWidget);
    expect(find.text('Usafiri'), findsOneWidget);
  });

  testWidgets('cached categories remain available when refresh fails',
      (tester) async {
    final api = FakeVendorRepository()
      ..catalogFailure = const AuthFailure(AuthFailureKind.offline);
    final app = await pumpApp(tester, now: at, api: api);
    await tester.runAsync(() => SalesStore(app.db).replaceCatalog(
        const CatalogSnapshot(products: [], expenseCategories: categories)));
    app.router.go(MNRoutes.expenses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Mkaa'), findsOneWidget);
    expect(find.text('Usafiri'), findsOneWidget);
  });

  testWidgets('the catalogue is downloaded again when the app comes back',
      (tester) async {
    final api = FakeVendorRepository()
      ..catalogSnapshot =
          const CatalogSnapshot(products: [], expenseCategories: []);
    final app = await pumpApp(tester, now: at, api: api);
    app.router.go(MNRoutes.sales);
    await tester.pumpAndSettle();
    api.catalogSnapshot =
        const CatalogSnapshot(products: [], expenseCategories: categories);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(
        await tester.runAsync(() => ExpenseStore(app.db)
            .watchCategories()
            .first
            .timeout(const Duration(seconds: 5))),
        categories);
  });

  testWidgets(
      'without categories the vendor records Mengineyo and what was bought',
      (tester) async {
    final app = await pumpApp(tester,
        now: at,
        api: FakeVendorRepository()
          ..catalogSnapshot =
              const CatalogSnapshot(products: [], expenseCategories: []));
    await tester.ensureVisible(find.text('Zaidi'));
    await tester.tap(find.text('Zaidi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza gharama'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mengineyo').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Kiberiti');
    await tester.enterText(find.byType(TextField).at(1), '500');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hifadhi'));
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    final payload =
        jsonDecode((await app.db.select(app.db.outbox).get()).single.payload)
            as Map;
    expect((payload['category'], payload['item'], payload['amount']),
        ('Mengineyo', 'Kiberiti', 500));
    expect(find.text('Mengineyo · Kiberiti'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('a category with items needs one of them; Mengineyo needs it written',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    await SalesStore(db)
        .replaceCatalog(const CatalogSnapshot(products: [], expenseCategories: [
      'Usafi'
    ], expenseItems: {
      'Usafi': ['Sabuni']
    }));
    final store = ExpenseStore(db);
    Future<void> save(String id, String category, String? item) => store.submit(
        id: id,
        vendorId: 'v1',
        stationKey: 'S1',
        category: category,
        item: item,
        amount: 1000,
        spentAt: at);
    await expectLater(save('a', 'Usafi', null), throwsFormatException);
    await expectLater(save('b', 'Usafi', 'Mafuta'), throwsFormatException);
    await expectLater(save('c', 'Mengineyo', null), throwsFormatException);
    await save('d', 'Usafi', 'Sabuni');
    await save('e', 'Mengineyo', 'Kiberiti');
    final payloads = [
      for (final o in await db.select(db.outbox).get())
        jsonDecode(o.payload) as Map
    ];
    expect([for (final p in payloads) p['item']], ['Sabuni', 'Kiberiti']);
  });

  group('Makabidhiano, read-only', () {
    final rows = [
      handoverAt('h3', 9000, DateTime.utc(2026, 10, 23, 12), 'Neema Said',
          note: 'Amekabidhi mwisho'),
      handoverAt('h2', 3000, DateTime.utc(2026, 10, 23, 9), 'Asha Juma',
          status: 'confirmed'),
      handoverAt('h1', 1500, DateTime.utc(2026, 10, 23, 6), 'Neema Said',
          status: 'reversed'),
    ];

    testWidgets(
        'the vendor day lists every handover with its time and receiver',
        (tester) async {
      await pumpApp(tester,
          now: at,
          initial: MNRoutes.handovers,
          api: HandoverVendor()..rows = rows);
      expect(find.text('Makabidhiano'), findsWidgets);
      expect(find.text('TSh 9,000'), findsOneWidget);
      expect(find.text('TSh 3,000'), findsOneWidget);
      expect(find.text('TSh 1,500'), findsOneWidget);
      // East Africa time: 12:00 UTC is 15:00.
      expect(find.textContaining('Saa 15:00'), findsOneWidget);
      expect(find.textContaining('Saa 12:00'), findsOneWidget);
      expect(find.textContaining('Saa 09:00'), findsOneWidget);
      expect(find.text('Alipokea: Neema Said'), findsNWidgets(2));
      expect(find.text('Alipokea: Asha Juma'), findsOneWidget);
      expect(find.text('Amekabidhi mwisho'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the vendor sees handovers read-only, with status',
        (tester) async {
      await pumpApp(tester,
          now: at,
          initial: MNRoutes.handovers,
          api: HandoverVendor()..rows = rows);
      expect(find.text('Imerekodiwa'), findsOneWidget);
      expect(find.text('Imethibitishwa'), findsOneWidget);
      expect(find.text('Imebatilishwa'), findsOneWidget);
      expect(
          find.text('Haya yamerekodiwa na ofisi kwa jina lako. '
              'Huwezi kuyabadilisha.'),
          findsOneWidget);
      // Nothing to press: no button and no field on the page.
      expect(find.byType(MNButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the vendor sees confirmed and pending cash figures separately',
        (tester) async {
      final api = HandoverVendor()
        ..moneySummaryValue = const VendorMoneySummary(
          owed: 5000,
          credit: 700,
          unverifiedCashSales: 2500,
          unconfirmedHandovers: 3000,
          pendingVendorExpenses: 1200,
        );
      await pumpApp(tester, now: at, initial: MNRoutes.handovers, api: api);

      expect(find.text('Hali ya fedha'), findsOneWidget);
      expect(
          find.text('Kiasi kilichothibitishwa kinachodaiwa'), findsOneWidget);
      expect(
          find.text('Mauzo taslimu yanayosubiri uthibitisho'), findsOneWidget);
      expect(
          find.text('Makabidhiano yanayosubiri uthibitisho'), findsOneWidget);
      expect(find.text('Gharama zinazosubiri idhini'), findsOneWidget);
      expect(find.text('TSh 5,000'), findsOneWidget);
      expect(find.text('TSh 2,500'), findsOneWidget);
      expect(find.text('TSh 3,000'), findsWidgets);
      expect(find.textContaining('yanaonyeshwa kando; havibadilishi kiasi'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offline the vendor page shows the load error, swipe to retry',
        (tester) async {
      final api = HandoverVendor()
        ..failure = const AuthFailure(AuthFailureKind.offline);
      await pumpApp(tester, now: at, initial: MNRoutes.handovers, api: api);
      expect(find.byType(MNErrorState), findsOneWidget);
      // A swipe retries; there is no button.
      expect(find.byType(MNButton), findsNothing);
      final calls = api.fetches;
      api
        ..failure = null
        ..rows = rows;
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(api.fetches, greaterThan(calls));
      expect(find.byType(MNErrorState), findsNothing);
      expect(find.text('TSh 9,000'), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      await pumpApp(tester,
          now: at, initial: MNRoutes.handovers, api: HandoverVendor());
      expect(find.text('Hakuna makabidhiano katika siku 31 zilizopita.'),
          findsOneWidget);
    });

    testWidgets('Akaunti leads to Makabidhiano', (tester) async {
      final app = await pumpApp(tester,
          now: at, initial: MNRoutes.profile, api: HandoverVendor());
      await tester.ensureVisible(find.text('Makabidhiano'));
      await tester.tap(find.text('Makabidhiano'));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, MNRoutes.handovers);
    });
  });
}
