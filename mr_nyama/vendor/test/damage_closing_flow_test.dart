import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';

import 'helpers.dart';

/// A closing store whose save always fails.
class _FailingClosingStore extends ClosingStore {
  _FailingClosingStore(super.db);
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

/// 9 October 2026, 20:00 in Dar es Salaam.
final now = DateTime.utc(2026, 10, 9, 17);

Future<TestApp> open(WidgetTester tester, String route) async {
  final app = await pumpApp(tester,
      now: now, api: FakeVendorRepository()..catalogSnapshot = testCatalog);
  app.router.push(route);
  await tester.pumpAndSettle();
  return app;
}

MNButton button(WidgetTester tester, String label) =>
    tester.widget<MNButton>(find.widgetWithText(MNButton, label));

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> reportDamage(WidgetTester tester,
    {String product = 'Kuku mzima', int plus = 2}) async {
  await tapText(tester, 'Ripoti bidhaa iliyoharibika');
  await tapText(tester, product);
  for (var i = 0; i < plus; i++) {
    await tester.tap(find.bySemanticsLabel('Ongeza $product'));
    await tester.pump();
  }
  await tapText(tester, 'Endelea');
  await tapText(tester, 'Imeungua');
  await tapText(tester, 'Endelea');
}

void main() {
  group('damage reports', () {
    testWidgets('report: product, quantity, reason, check, saved',
        (tester) async {
      final app = await open(tester, MNRoutes.damaged);
      expect(find.text('Hakuna ripoti za uharibifu'), findsOneWidget);
      await reportDamage(tester);
      expect(find.text('Kagua ripoti'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Imeungua'), findsOneWidget);
      final explanation = find
          .text('Ofisi itakagua ripoti hii kabla ya kuihesabu kama hasara.');
      expect(explanation, findsNothing);
      await tester.tap(find.byTooltip('Msaada'));
      await tester.pumpAndSettle();
      expect(explanation, findsOneWidget);
      await tester.tapAt(const Offset(20, 100));
      await tester.pumpAndSettle();
      await tapText(tester, 'Hifadhi ripoti');
      expect(find.text('Ripoti imehifadhiwa.'), findsOneWidget);

      final saved = (await app.db.select(app.db.damageReports).get()).single;
      expect([saved.productId, saved.quantity, saved.reason],
          ['kuku', 3, 'burnt']);
      // A report is not a loss: no stock figure changes on the phone.
      final kuku = (await app.db.select(app.db.catalogProducts).get())
          .firstWhere((p) => p.id == 'kuku');
      expect(kuku.available, 8);

      await tapText(tester, 'Rudi');
      expect(find.text('Kuku mzima × 3'), findsOneWidget);
      expect(find.text('Inasubiri kutumwa'), findsOneWidget);
    });

    testWidgets('validation: quantity above zero and a reason are required',
        (tester) async {
      await open(tester, MNRoutes.newDamage);
      await tapText(tester, 'Kuku mzima');
      final minus = tester.widget<MNQuantityButton>(find.ancestor(
          of: find.bySemanticsLabel('Punguza Kuku mzima'),
          matching: find.byType(MNQuantityButton)));
      expect(minus.onPressed, isNull); // cannot go below 1
      // Typing 0 disables "Endelea".
      await tester.tap(find.bySemanticsLabel(RegExp('^Idadi iliyoharibika, ')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(MNPinKeypad), matching: find.text('0')));
      await tester.pump();
      await tapText(tester, 'Weka idadi');
      expect(button(tester, 'Endelea').onPressed, isNull);
      await tester.tap(find.bySemanticsLabel('Ongeza Kuku mzima'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Endelea');
      expect(button(tester, 'Endelea').onPressed, isNull); // no reason yet
    });

    testWidgets('duplicates: a double tap saves once; a similar report asks',
        (tester) async {
      final app = await open(tester, MNRoutes.damaged);
      await reportDamage(tester);
      final save = find.widgetWithText(MNButton, 'Hifadhi ripoti');
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await app.db.select(app.db.damageReports).get(), hasLength(1));

      await tapText(tester, 'Ripoti nyingine');
      await tapText(tester, 'Kuku mzima');
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.bySemanticsLabel('Ongeza Kuku mzima'));
        await tester.pump();
      }
      await tapText(tester, 'Endelea');
      await tapText(tester, 'Imeungua');
      await tapText(tester, 'Endelea');
      await tapText(tester, 'Hifadhi ripoti');
      expect(
          find.text('Ripoti kama hii imehifadhiwa sasa hivi'), findsOneWidget);
      await tapText(tester, 'Hapana');
      expect(await app.db.select(app.db.damageReports).get(), hasLength(1));
    });
  });

  group('Funga Siku', () {
    Future<void> countAll(WidgetTester tester) async {
      for (final (name, digit) in [('Kuku mzima', '5'), ('Paja (Robo)', '2')]) {
        await tapText(tester, name);
        await tester.tap(find.descendant(
            of: find.byType(MNPinKeypad), matching: find.text(digit)));
        await tester.pumpAndSettle();
        await tapText(tester, 'Hifadhi');
      }
    }

    testWidgets('count, review, confirm, saved; precise statuses',
        (tester) async {
      final app = await open(tester, MNRoutes.closeDay);
      expect(find.text('0 kati ya 2 zimehesabiwa'), findsOneWidget);
      expect(find.text('Kuku mzima'), findsOneWidget);

      expect(find.text('Kidali (Robo)'), findsNothing); // not tracked
      expect(find.text('—'), findsNWidgets(2)); // nothing pre-filled

      await tapText(tester, 'Endelea kuhesabu');
      expect(find.text('Hesabu bidhaa zote kwanza.'), findsOneWidget);

      await countAll(tester);
      await freezeCount(tester);
      expect(find.textContaining('Umehesabu: 5'), findsOneWidget);
      expect(find.textContaining('Umehesabu: 2'), findsOneWidget);
      expect(
          find.text(
              'Funga Siku hurekodi hesabu tu. Mauzo, pesa na bidhaa hukaguliwa na ofisi kando.'),
          findsNothing);
      await tapText(tester, 'Hifadhi na funga siku');
      expect(find.text('Funga siku kwa hesabu hii?'), findsOneWidget);
      await tapText(tester, 'Ndiyo, funga siku');

      expect(find.textContaining('IMEFUNGWA!'), findsOneWidget);
      expect(find.text('Hesabu imehifadhiwa kwenye simu.'), findsOneWidget);
      expect(find.text('Inasubiri kutumwa.'), findsOneWidget);
      expect(find.text('Imetumwa ofisini.'), findsNothing);
      expect(find.text('Inasubiri uthibitisho wa ofisi.'), findsNothing);
      final lines = await app.db.select(app.db.closingCountLines).get();
      expect({for (final l in lines) l.productId: l.counted},
          {'kuku': 5, 'paja': 2});
    });

    testWidgets('a failed count save says not saved, never "Mauzo"',
        (tester) async {
      final app = await pumpApp(tester,
          now: now,
          api: FakeVendorRepository()..catalogSnapshot = testCatalog,
          overrides: [
            closingStoreProvider.overrideWith(
                (ref) => _FailingClosingStore(ref.watch(databaseProvider)))
          ]);
      app.router.push(MNRoutes.closeDay);
      await tester.pumpAndSettle();
      await countAll(tester);
      await freezeCount(tester);
      await tapText(tester, 'Hifadhi na funga siku');
      await tapText(tester, 'Ndiyo, funga siku');
      expect(find.text('Haikuhifadhiwa. Jaribu tena.'), findsOneWidget);
      expect(find.textContaining('Mauzo'), findsNothing);
    });

    testWidgets('a double confirm saves one count', (tester) async {
      final app = await open(tester, MNRoutes.closeDay);
      await countAll(tester);
      await freezeCount(tester);
      await tapText(tester, 'Hifadhi na funga siku');
      final yes = find.text('Ndiyo, funga siku');
      await tester.tap(yes);
      await tester.tap(yes, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await app.db.select(app.db.closingCounts).get(), hasLength(1));
    });

    testWidgets('offline: the count saves on the phone', (tester) async {
      final app = await open(tester, MNRoutes.closeDay);
      app.api.catalogFailure = const AuthFailure(AuthFailureKind.offline);
      await countAll(tester);
      await freezeCount(tester);
      await tapText(tester, 'Hifadhi na funga siku');
      await tapText(tester, 'Ndiyo, funga siku');
      expect(find.text('Hesabu imehifadhiwa kwenye simu.'), findsOneWidget);
    });

    testWidgets(
        'after closing: read-only; corrections are for the office; '
        'statuses follow the server', (tester) async {
      final app = await open(tester, MNRoutes.closeDay);
      await countAll(tester);
      await freezeCount(tester);
      await tapText(tester, 'Hifadhi na funga siku');
      await tapText(tester, 'Ndiyo, funga siku');
      await tapText(tester, 'Rudi Nyumbani');

      app.router.push(MNRoutes.closeDay);
      await tester.pumpAndSettle();
      expect(find.text('Hesabu ya leo imehifadhiwa'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Ongeza')), findsNothing);
      expect(
          find.text('Marekebisho ya hesabu hufanywa na ofisi.'), findsNothing);
      await tester.tap(find.byTooltip('Msaada'));
      await tester.pumpAndSettle();
      expect(find.text('Marekebisho ya hesabu hufanywa na ofisi.'),
          findsOneWidget);
      await tester.tapAt(const Offset(20, 100));
      await tester.pumpAndSettle();

      final countId =
          (await app.db.select(app.db.closingCounts).get()).single.countId;
      final store = app.container.read(closingStoreProvider);
      await store.applyResult(countId);
      await tester.pumpAndSettle();
      expect(find.text('Imetumwa ofisini.'), findsOneWidget);
      expect(find.text('Inasubiri uthibitisho wa ofisi.'), findsOneWidget);
      expect(find.text('Inasubiri kutumwa.'), findsNothing);
      await store.applyResult(countId, officeConfirmed: true);
      await tester.pumpAndSettle();
      expect(find.text('Imethibitishwa na ofisi.'), findsOneWidget);
      expect(find.text('Inasubiri uthibitisho wa ofisi.'), findsNothing);
    });

    testWidgets(
        'another vendor at the kituo already counted: the day is closed and '
        'the vendor is told so, not blamed', (tester) async {
      final app = await open(tester, MNRoutes.closeDay);
      app.api
        ..syncFailure = null
        ..syncDecision = (op) => op.opType == 'closing_count'
            ? OperationResult(
                op.opId, OperationOutcome.conflict, 'station_counted')
            : OperationResult(op.opId, OperationOutcome.accepted);
      await countAll(tester);
      await freezeCount(tester);
      await tapText(tester, 'Hifadhi na funga siku');
      await tapText(tester, 'Ndiyo, funga siku');
      await tapText(tester, 'Rudi Nyumbani');

      app.router.push(MNRoutes.closeDay);
      await tester.pumpAndSettle();
      expect((await app.db.select(app.db.outbox).get()).single.resultReason,
          'station_counted');
      expect(find.text('Hesabu ya leo imehifadhiwa'), findsOneWidget);
      expect(find.text('Imetumwa ofisini.'), findsOneWidget);
      expect(find.text('Kituo kimeshahesabiwa leo na muuzaji mwenzako.'),
          findsOneWidget);
      expect(find.text('Inahitaji ukaguzi wa ofisi.'), findsNothing);

      app.router.push(MNRoutes.sync);
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Kituo kimeshahesabiwa leo na muuzaji mwenzako. '
              'Siku yako imefungwa.'),
          findsOneWidget);
      expect(find.textContaining('ofisi itakagua'), findsNothing);
    });
  });
}
