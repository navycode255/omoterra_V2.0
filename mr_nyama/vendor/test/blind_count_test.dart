import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/closing/count_entry_screen.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'helpers.dart';
import 'history_flow_test.dart' show record;

/// 9 October 2026, 20:00 in Dar es Salaam. Catalogue: Kuku mzima expected 8,
/// Paja (Robo) expected 3.
final now = DateTime.utc(2026, 10, 9, 17);

class _FailingStore extends ClosingStore {
  _FailingStore(super.db);
  @override
  Future<ClosingView> submit({
    required String countId,
    required String vendorId,
    required String stationKey,
    required DateTime now,
    required List<Product> products,
    required Map<String, int> counted,
    Map<String, String> reasons = const {},
    Map<String, String> notes = const {},
    DateTime? businessDay,
    bool frozen = false,
  }) =>
      throw StateError('disk full');
}

Future<TestApp> open(WidgetTester tester,
    {Size size = const Size(390, 844),
    double textScale = 1,
    bool reducedMotion = false,
    List<Override> overrides = const []}) async {
  final app = await pumpApp(tester,
      now: now,
      size: size,
      textScale: textScale,
      reducedMotion: reducedMotion,
      overrides: overrides,
      api: FakeVendorRepository()..catalogSnapshot = testCatalog);
  app.router.push(MNRoutes.closeDay);
  await tester.pumpAndSettle();
  return app;
}

Future<void> count(WidgetTester tester, String name, String digits) async {
  await tester.ensureVisible(find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  for (final d in digits.split('')) {
    await tester.tap(find.descendant(
        of: find.byType(MNPinKeypad), matching: find.text(d)));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(MNButton, 'Hifadhi'));
  await tester.pumpAndSettle();
}

Future<void> countBoth(WidgetTester tester, String kuku, String paja) async {
  await count(tester, 'Kuku mzima', kuku);
  await count(tester, 'Paja (Robo)', paja);
}

Future<void> askFreeze(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MNButton, 'Hakiki hesabu'));
  await tester.pumpAndSettle();
}

Future<void> confirmFreeze(WidgetTester tester) async {
  await askFreeze(tester);
  await tester.tap(find.text('Endelea').last);
  await tester.pumpAndSettle();
}

MNButton saveButton(WidgetTester tester) => tester.widget<MNButton>(
    find.widgetWithText(MNButton, 'Hifadhi na funga siku'));

void expectNoExpectedFigure() {
  expect(find.text('Baki inayotarajiwa'), findsNothing);
  expect(find.textContaining('Tofauti'), findsNothing);
  expect(find.textContaining('Rekodi'), findsNothing);
  expect(find.text('Zenye tofauti'), findsNothing);
}

void main() {
  testWidgets('while counting: no expected figure, difference or Rekodi',
      (tester) async {
    await open(tester);
    expectNoExpectedFigure();
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(find.byType(CountEntryScreen), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(MNPinKeypad), matching: find.text('5')));
    await tester.pumpAndSettle();
    // 5 against an expected 8 would be a difference; nothing shows it, and
    // the number alone is enough to save.
    expectNoExpectedFigure();
    expect(find.text('Sababu ya tofauti (lazima)'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNotNull);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi'));
    await tester.pumpAndSettle();
    expectNoExpectedFigure();
    // The filter has no "with differences" option while counts are open.
    await tester.tap(find.byTooltip('Chuja'));
    await tester.pumpAndSettle();
    expect(find.text('Imehesabiwa'), findsWidgets);
    expect(find.text('Zenye tofauti'), findsNothing);
  });

  testWidgets('a figure can be changed freely while counting', (tester) async {
    await open(tester);
    await count(tester, 'Kuku mzima', '5');
    expect(find.text('5'), findsOneWidget);
    await count(tester, 'Kuku mzima', '7');
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('Hakiki hesabu asks first; staying keeps the count open',
      (tester) async {
    await open(tester);
    await countBoth(tester, '5', '2');
    await askFreeze(tester);
    expect(find.text('Ukiendelea huwezi kubadilisha hesabu.'), findsOneWidget);
    await tester.tap(find.text('Rudi kuhesabu'));
    await tester.pumpAndSettle();
    // Still counting: a figure opens and can change.
    await count(tester, 'Kuku mzima', '6');
    expect(find.text('6'), findsOneWidget);
    expectNoExpectedFigure();
  });

  testWidgets(
      'after the freeze: figures show, cannot change, Back leaves and keeps them',
      (tester) async {
    final app = await open(tester);
    await countBoth(tester, '5', '2');
    await confirmFreeze(tester);
    expect(find.textContaining('Umehesabu: 5'), findsOneWidget);
    expect(find.textContaining('Baki inayotarajiwa: 8'), findsOneWidget);
    expect(find.textContaining('Tofauti: -3'), findsOneWidget);
    expect(find.textContaining('Baki inayotarajiwa: 3'), findsOneWidget);
    expect(find.textContaining('Tofauti: -1'), findsOneWidget);
    // It promises no recount: the figures stay, and the office fixes a typo.
    expect(find.textContaining('utahesabu upya'), findsNothing);
    expect(find.textContaining('ofisi'), findsWidgets);
    // The figures are not tappable any more.
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(find.byType(CountEntryScreen), findsNothing);
    // Android Back leaves at once: nothing asks, nothing can be discarded.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Toka bila kuhifadhi?'), findsNothing);
    expect(find.widgetWithText(MNButton, 'Hifadhi na funga siku'), findsNothing);
    expect(await app.db.select(app.db.closingCounts).get(), isEmpty);
  });

  testWidgets(
      'BYPASS: seeing the expected figures, leaving and reopening goes straight '
      'back to the frozen figures', (tester) async {
    final app = await open(tester);
    await countBoth(tester, '0', '0');
    await confirmFreeze(tester);
    // The expected figures have been seen.
    expect(find.textContaining('Baki inayotarajiwa: 8'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.closeDay);
    await tester.pumpAndSettle();
    // No way to type them: the first figures stand.
    expect(find.widgetWithText(MNButton, 'Hakiki hesabu'), findsNothing);
    expect(find.widgetWithText(MNButton, 'Hifadhi na funga siku'), findsOneWidget);
    expect(find.textContaining('Umehesabu: 0'), findsNWidgets(2));
    expect(find.textContaining('Tofauti: -8'), findsOneWidget);
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(find.byType(CountEntryScreen), findsNothing);
  });

  testWidgets('the frozen count lives on the phone, by vendor, station and day',
      (tester) async {
    final app = await open(tester);
    await countBoth(tester, '5', '2');
    await confirmFreeze(tester);
    final row = (await app.db.select(app.db.settings).get())
        .singleWhere((r) => r.key.startsWith('frozen_count'));
    expect(row.key, contains(testProfile.id));
    expect(row.key, contains(testProfile.stationKey));
    expect(row.key, contains('2026-10-09'));
    final saved = jsonDecode(row.value) as Map;
    expect(saved['count_id'], isNotEmpty);
    expect(saved['day'], '2026-10-09');
    expect([
      for (final p in saved['products'] as List)
        [p['id'], p['counted'], p['expected']]
    ], unorderedEquals([
      ['kuku', 5, 8],
      ['paja', 2, 3]
    ]));
  });

  testWidgets('a fresh screen with a frozen count saves that count id',
      (tester) async {
    final app = await open(tester);
    await countBoth(tester, '8', '3');
    await confirmFreeze(tester);
    final saved = jsonDecode((await app.db.select(app.db.settings).get())
        .singleWhere((r) => r.key.startsWith('frozen_count'))
        .value) as Map;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.closeDay);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    final [count] = await app.db.select(app.db.closingCounts).get();
    expect(count.countId, saved['count_id']);
    // Cleared only now.
    expect(
        (await app.db.select(app.db.settings).get())
            .where((r) => r.key.startsWith('frozen_count')),
        isEmpty);
  });

  testWidgets('a catalogue refresh after the freeze changes nothing',
      (tester) async {
    final app = await open(tester, size: const Size(390, 1600));
    await countBoth(tester, '8', '3');
    await confirmFreeze(tester);
    final first = testCatalog.products.first;
    final added = CatalogItem(
        id: 'new-product',
        name: 'Bidhaa mpya',
        category: first.category,
        price: first.price,
        priceVersion: first.priceVersion,
        available: 2);
    // A new product arrives, and the expected figures move.
    await tester.runAsync(() => SalesStore(app.db).replaceCatalog(
        CatalogSnapshot(products: [
          for (final p in testCatalog.products)
            CatalogItem(
                id: p.id,
                name: p.name,
                category: p.category,
                price: p.price,
                priceVersion: p.priceVersion,
                available: 99),
          added
        ])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Not in this count, and the expected figure is the one frozen.
    expect(find.text('Bidhaa mpya'), findsNothing);
    expect(find.textContaining('Baki inayotarajiwa: 8'), findsOneWidget);
    expect(find.textContaining('Baki inayotarajiwa: 99'), findsNothing);
    expect(find.textContaining('Tofauti'), findsNothing);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    final lines = await app.db.select(app.db.closingCountLines).get();
    expect({for (final l in lines) l.productId: l.recorded},
        {'kuku': 8, 'paja': 3});
    final op = (await app.db.select(app.db.outbox).get())
        .firstWhere((o) => o.opType == 'closing_count');
    expect(op.payload, isNot(contains('new-product')));
  });

  testWidgets('a count frozen at 23:58 saves on the frozen date',
      (tester) async {
    // 23:58 on 9 October in Dar es Salaam.
    var clock = DateTime.utc(2026, 10, 9, 20, 58);
    final app = await pumpApp(tester,
        size: const Size(390, 1200),
        seed: (store) => store.signIn(lastActive: clock),
        overrides: [clockProvider.overrideWithValue(() => clock)],
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    app.router.push(MNRoutes.closeDay);
    await tester.pumpAndSettle();
    await countBoth(tester, '8', '3');
    await confirmFreeze(tester);
    // Midnight passes, and a sale of the new day is made on the phone.
    clock = DateTime.utc(2026, 10, 9, 21, 10);
    await record(app, 'next-day-sale', clock);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    final [count] = await app.db.select(app.db.closingCounts).get();
    expect(count.businessDate, '2026-10-09');
    final op = (await app.db.select(app.db.outbox).get())
        .firstWhere((o) => o.opType == 'closing_count');
    expect(jsonDecode(op.payload)['business_date'], '2026-10-09');
    // Counted before midnight: the server takes a count made on its own day even
    // after the new day has begun, and refuses one made the next morning.
    final counted = jsonDecode(op.payload)['counted_at'] as String;
    expect(DateTime.parse(counted).toUtc(), DateTime.utc(2026, 10, 9, 20, 58));
  });

  testWidgets('a difference needs a reason and a note; others do not',
      (tester) async {
    await open(tester);
    await countBoth(tester, '8', '2'); // Kuku matches, Paja is 1 short
    await confirmFreeze(tester);
    expect(find.text('Sababu ya tofauti (lazima)'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    await tester.tap(find.text('Pungua wakati wa mauzo'));
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNull); // note still missing
    await tester.enterText(find.byType(TextField), 'Wateja wengi leo.');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('nothing differing goes straight to the save step',
      (tester) async {
    final app = await open(tester);
    await countBoth(tester, '8', '3');
    await confirmFreeze(tester);
    expect(find.text('Sababu ya tofauti (lazima)'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('IMEFUNGWA!'), findsOneWidget);
    expect(await app.db.select(app.db.closingCounts).get(), hasLength(1));
  });

  testWidgets('one write with the reasons; payload and stored lines unchanged',
      (tester) async {
    final app = await open(tester);
    await countBoth(tester, '5', '3');
    await confirmFreeze(tester);
    await tester.tap(find.text('Zimeharibika (ripoti kando)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tatu zilianguka.');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    final lines = await app.db.select(app.db.closingCountLines).get();
    final kuku = lines.firstWhere((l) => l.productId == 'kuku');
    expect(
        [kuku.counted, kuku.recorded, kuku.reason, kuku.note],
        [5, 8, 'damaged', 'Tatu zilianguka.']);
    final paja = lines.firstWhere((l) => l.productId == 'paja');
    expect([paja.counted, paja.recorded, paja.reason, paja.note],
        [3, 3, null, null]);
    final op = (await app.db.select(app.db.outbox).get())
        .firstWhere((o) => o.opType == 'closing_count');
    final payload = jsonDecode(op.payload) as Map;
    expect(
        payload.keys,
        containsAll(
            ['count_id', 'business_date', 'counted_at', 'lines', 'reasons']
                .where(payload.containsKey)));
    expect(payload.toString(), contains('Tatu zilianguka.'));
    expect(payload.toString(), contains('damaged'));
  });

  testWidgets('a failed save shows an error, no fire, and stays frozen',
      (tester) async {
    final app = await open(tester, overrides: [
      closingStoreProvider
          .overrideWith((ref) => _FailingStore(ref.watch(databaseProvider)))
    ]);
    await countBoth(tester, '8', '3');
    await confirmFreeze(tester);
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi na funga siku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, funga siku'));
    await tester.pumpAndSettle();
    expect(find.text('Haikuhifadhiwa. Jaribu tena.'), findsOneWidget);
    expect(find.textContaining('IMEFUNGWA'), findsNothing);
    expect(await app.db.select(app.db.closingCounts).get(), isEmpty);
    expect(saveButton(tester).onPressed, isNotNull); // retry stays available
    expect(find.byType(CountEntryScreen), findsNothing);
    // Not saved: the frozen figures stay on the phone.
    expect(
        (await app.db.select(app.db.settings).get())
            .where((r) => r.key.startsWith('frozen_count')),
        hasLength(1));
  });

  testWidgets('reduced motion, 320 px and 2x text: both steps fit',
      (tester) async {
    await open(tester,
        size: const Size(320, 568), textScale: 2.0, reducedMotion: true);
    await count(tester, 'Kuku mzima', '5');
    await count(tester, 'Paja (Robo)', '2');
    expectNoExpectedFigure();
    expect(tester.takeException(), isNull);
    await confirmFreeze(tester);
    await tester.scrollUntilVisible(find.textContaining('Umehesabu: 5'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Umehesabu: 5'), findsOneWidget);
    expect(find.widgetWithText(MNButton, 'Hifadhi na funga siku'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
