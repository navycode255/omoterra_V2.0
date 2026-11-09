import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/router.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/receiving/receiving_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart'
    show databaseProvider;
import 'package:mr_nyama_vendor/core/theme/icon_data.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/icon.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';

import 'helpers.dart';

DeliveryManifest delivery(
        {String id = 'c1',
        String reference = 'OMT-2041',
        String station = 'S1',
        int version = 1}) =>
    DeliveryManifest(
        consignmentId: id,
        version: version,
        reference: reference,
        sender: 'Omoterra',
        stationKey: station,
        stationName: station == 'S1' ? 'Kariakoo' : 'Mwenge',
        dispatchedAt: DateTime.utc(2026, 10, 9, 5),
        lines: const [
          ManifestLine(
              lineId: 'L1',
              productId: 'kuku',
              productName: 'Kuku mzima',
              quantity: 50),
          ManifestLine(
              lineId: 'L2',
              productId: 'kidali',
              productName: 'Kidali (Robo)',
              quantity: 30,
              imageKey: 'kidali'),
        ]);

Future<TestApp> openReceiving(WidgetTester tester,
    {List<DeliveryManifest>? deliveries}) async {
  final api = FakeVendorRepository()..deliveryList = deliveries ?? [delivery()];
  final app = await pumpApp(tester, api: api);
  app.router.push(MNRoutes.receive);
  await tester.pumpAndSettle();
  return app;
}

Future<void> confirm(WidgetTester tester) async {
  if (find.text('Ndiyo, thibitisha').evaluate().isEmpty) {
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Ndiyo, thibitisha'));
  await tester.pumpAndSettle();
}

class _FailingReceivingStore extends ReceivingStore {
  _FailingReceivingStore(super.db);
  @override
  Future<ReceiptView> submitReceipt({
    required String receiptId,
    required String eventId,
    required String consignmentId,
    required int consignmentVersion,
    required String sessionStationKey,
    required String actorId,
    required DateTime receivedAt,
    DateTime? recordedAt,
    required List<LineCount> counts,
    Map<String, String> notes = const {},
  }) =>
      throw StateError('disk full');
}

void main() {
  testWidgets('a failed receipt save says not saved, never "Mauzo"',
      (tester) async {
    final api = FakeVendorRepository()..deliveryList = [delivery()];
    final app = await pumpApp(tester, api: api, overrides: [
      receivingStoreProvider.overrideWith(
          (ref) => _FailingReceivingStore(ref.watch(databaseProvider)))
    ]);
    app.router.push(MNRoutes.receive);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    await confirm(tester);
    await tester.scrollUntilVisible(
        find.text('Haikuhifadhiwa. Jaribu tena.'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Haikuhifadhiwa. Jaribu tena.'), findsOneWidget);
    expect(find.textContaining('Mauzo'), findsNothing);
  });

  testWidgets('pending list: reference, route, product count, status',
      (tester) async {
    await openReceiving(tester);
    expect(find.textContaining('OMT-2041'), findsOneWidget);
    expect(find.text('Omoterra'), findsOneWidget);
    // Two products (50 + 30 units): their quantities are not added up or
    // called chickens.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('bidhaa'), findsOneWidget);
    expect(find.text('80'), findsNothing);
  });

  testWidgets('no pending deliveries', (tester) async {
    await openReceiving(tester, deliveries: []);
    expect(find.text('Hakuna bidhaa zinazosubiri'), findsOneWidget);
  });

  testWidgets('full receipt: saved on the phone, not shown as accepted',
      (tester) async {
    final app = await openReceiving(tester);
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    expect(find.text('Zimetumwa: 50'), findsOneWidget);
    expect(find.text('Zimetumwa: 30'), findsOneWidget);
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MNButton, 'Hifadhi'), findsOneWidget);
    await confirm(tester);

    expect(find.text('Upokeaji umehifadhiwa'), findsOneWidget);
    expect(find.text('Umepokea 80 kati ya 80'), findsOneWidget);
    expect(find.text('Imehifadhiwa kwenye simu'), findsOneWidget);
    expect(find.text('Inasubiri kusawazisha'), findsOneWidget);
    expect(find.textContaining('Imepokelewa'), findsNothing);
    final receipt = (await app.db.select(app.db.receipts).get()).single;
    expect(receipt.syncStatus, 'saved');
    expect(receipt.stationKey, 'S1');
    expect(receipt.actorId, 'v1');

    await tester.tap(find.text('Rudi kwenye orodha'));
    await tester.pumpAndSettle();
    expect(find.text('Hakuna bidhaa zinazosubiri'), findsOneWidget);
    await tester.tap(find.text('Zilizopokelewa'));
    await tester.pumpAndSettle();
    expect(find.text('Imehifadhiwa kwenye simu'), findsOneWidget);
  });

  testWidgets('partial receipt: a difference needs a reason', (tester) async {
    final app = await openReceiving(tester);
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.bySemanticsLabel('Punguza Kuku mzima'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNull);
    expect(await app.db.select(app.db.receipts).get(), isEmpty);

    await tester.ensureVisible(find.text('Zimeharibika'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zimeharibika'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Zimepungua kwenye lori.');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.text('Umepokea 78 kati ya 80'), findsOneWidget);
    final line = (await app.db.select(app.db.receiptLines).get())
        .firstWhere((l) => l.lineId == 'L1');
    expect([line.accepted, line.rejected, line.reason], [48, 2, 'damaged']);
  });

  testWidgets('wrong quantity typed directly; above dispatched is impossible',
      (tester) async {
    final app = await openReceiving(tester);
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    // + is disabled at the dispatched quantity.
    final plus = tester.widget<MNQuantityButton>(find.ancestor(
        of: find.bySemanticsLabel('Ongeza Kidali (Robo)'),
        matching: find.byType(MNQuantityButton)));
    expect(plus.onPressed, isNull);
    // Typing above the dispatched quantity is ignored.
    final count =
        find.bySemanticsLabel(RegExp('^Weka idadi uliyopokea, Kidali'));
    await tester.ensureVisible(count);
    await tester.pumpAndSettle();
    await tester.tap(count);
    await tester.pumpAndSettle();
    for (final d in ['9', '9']) {
      await tester.tap(find.descendant(
          of: find.byType(MNPinKeypad), matching: find.text(d)));
      await tester.pump();
    }
    await tester.tap(find.text('Weka idadi'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(MNRollingNumber), matching: find.text('9')),
        findsOneWidget);
    await tester.tap(find.text('Hazikufika (zimepungua)'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Zimepungua kwenye lori.');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    await confirm(tester);
    final line = (await app.db.select(app.db.receiptLines).get())
        .firstWhere((l) => l.lineId == 'L2');
    expect([line.accepted, line.rejected, line.reason], [9, 0, 'short']);
  });

  testWidgets('a double confirm records one receipt', (tester) async {
    final app = await openReceiving(tester);
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.tap(find.text('Pokea bidhaa'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    final yes = find.text('Ndiyo, thibitisha');
    await tester.tap(yes);
    await tester.tap(yes, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.receipts).get(), hasLength(1));
  });

  testWidgets('offline: cached deliveries can still be counted',
      (tester) async {
    final app = await openReceiving(tester);
    app.api.deliveriesFailure = const AuthFailure(AuthFailureKind.offline);
    app.router.pop();
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.receive);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.text('Imehifadhiwa kwenye simu'), findsOneWidget);
  });

  testWidgets('manifest changed after the count: conflict, count kept',
      (tester) async {
    final app = await openReceiving(tester);
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    await confirm(tester);
    await app.container
        .read(receivingStoreProvider)
        .replaceDeliveries([delivery(version: 2)]);
    app.router.go(MNRoutes.delivery('c1'));
    await tester.pumpAndSettle();
    expect(find.text('Inahitaji ukaguzi'), findsOneWidget);
    expect(
        find.text('Orodha ya mzigo ilibadilika baada ya kuhesabu. Ofisi '
            'itakagua; hesabu yako haijabadilishwa.'),
        findsOneWidget);
    expect(find.text('Umepokea: 50'), findsOneWidget);
    expect(find.text('Pokea bidhaa'), findsNothing);
  });

  testWidgets('another station\'s delivery cannot be received', (tester) async {
    await openReceiving(tester,
        deliveries: [delivery(reference: 'OMT-9', station: 'S2')]);
    expect(find.bySemanticsLabel(RegExp('Kituo kingine')), findsOneWidget);
    await tester.tap(find.textContaining('OMT-9'));
    await tester.pumpAndSettle();
    expect(find.text('Mzigo huu si wa kituo chako. Huwezi kuupokea.'),
        findsOneWidget);
    expect(find.widgetWithText(MNButton, 'Pokea bidhaa'), findsNothing);
    expect(find.widgetWithText(MNButton, 'Hifadhi'), findsNothing);
  });

  testWidgets('only the server can mark a receipt accepted', (tester) async {
    final app = await openReceiving(tester);
    await tester.tap(find.textContaining('OMT-2041'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    await confirm(tester);
    final eventId = (await app.db.select(app.db.receipts).get()).single.eventId;
    await app.container
        .read(receivingStoreProvider)
        .applyReceiptResult(eventId, status: ReceivingStatus.accepted);
    await tester.pumpAndSettle();
    expect(find.text('Hesabu yako imepokelewa ofisini.'), findsOneWidget);
  });

  group('the saved screen and its help say what is true for each status', () {
    Future<void> saveThen(WidgetTester tester, ReceivingStatus? status) async {
      final app = await openReceiving(tester);
      await tester.tap(find.textContaining('OMT-2041'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pokea bidhaa'));
      await tester.pumpAndSettle();
      await confirm(tester);
      if (status != null) {
        final eventId =
            (await app.db.select(app.db.receipts).get()).single.eventId;
        await app.container
            .read(receivingStoreProvider)
            .applyReceiptResult(eventId, status: status);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.bySemanticsLabel('Msaada'));
      await tester.pumpAndSettle();
    }

    const stockLine =
        'Bidhaa zitaongezwa kwenye hesabu yako baada ya kutumwa ofisini.';
    const acceptedLine = 'Hesabu yako imepokelewa ofisini.';

    testWidgets('saved on the phone', (tester) async {
      await saveThen(tester, null);
      expect(find.text('Imehifadhiwa kwenye simu'), findsOneWidget);
      expect(find.text(stockLine), findsOneWidget);
      expect(find.text(acceptedLine), findsNothing);
      expect(find.text('Upokeaji umehifadhiwa'), findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is MNIcon && w.icon == MNIconData.check),
          findsOneWidget);
    });

    testWidgets('help on the delivery screen follows the status',
        (tester) async {
      final app = await openReceiving(tester);
      await tester.tap(find.textContaining('OMT-2041'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Msaada'));
      await tester.pumpAndSettle();
      expect(find.text(stockLine), findsOneWidget);
      expect(find.text(acceptedLine), findsNothing);
      expect(app.router.state.uri.path, MNRoutes.delivery('c1'));
    });

    testWidgets('accepted', (tester) async {
      await saveThen(tester, ReceivingStatus.accepted);
      expect(find.text('Imehifadhiwa kwenye simu'), findsNothing);
      expect(find.text(stockLine), findsNothing);
      // The body and the help both say it.
      expect(find.text(acceptedLine), findsNWidgets(2));
    });

    for (final (status, label) in [
      (ReceivingStatus.conflict, 'Inahitaji ukaguzi'),
      (ReceivingStatus.rejected, 'Imekataliwa'),
    ]) {
      testWidgets('$status', (tester) async {
        await saveThen(tester, status);
        // The headline and icon do not say the receipt succeeded.
        expect(find.text(label), findsOneWidget);
        expect(find.text('Upokeaji umehifadhiwa'), findsNothing);
        expect(
            find.byWidgetPredicate(
                (w) => w is MNIcon && w.icon == MNIconData.check),
            findsNothing);
        expect(find.text('Imehifadhiwa kwenye simu'), findsNothing);
        expect(find.byType(MNSyncIndicator), findsNothing);
        expect(find.text(stockLine), findsNothing);
        expect(find.text(acceptedLine), findsNothing);
      });
    }
  });

  test('no driver, vehicle or route screens exist in Mr. Nyama', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Iterable<String> paths(List<RouteBase> routes) sync* {
      for (final r in routes) {
        if (r is GoRoute) yield r.path;
        yield* paths(r.routes);
      }
    }

    final all = paths(container.read(routerProvider).configuration.routes);
    expect(
        all.where(
            (p) => RegExp('dereva|driver|gari|njia|route|vehicle').hasMatch(p)),
        isEmpty);
  });
}
