import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/history/history_screen.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'helpers.dart';

/// 9 October 2026, 15:00 in Dar es Salaam.
final now = DateTime.utc(2026, 10, 9, 12);

Future<void> record(TestApp app, String id, DateTime at,
        {String vendor = 'v1',
        PaymentMethod payment = PaymentMethod.cash,
        List<DraftLine>? lines}) =>
    app.container.read(salesStoreProvider).saveSale(SaleDraft(
        clientId: id,
        vendorId: vendor,
        recordedAt: at,
        payment: payment,
        lines: lines ??
            const [
              DraftLine(
                  productId: 'kuku',
                  productName: 'Kuku mzima',
                  quantity: 2,
                  unitPrice: 9000),
              DraftLine(
                  productId: 'paja',
                  productName: 'Paja (Robo)',
                  quantity: 1,
                  unitPrice: 2000),
            ]));

Future<TestApp> openHistory(WidgetTester tester,
    {Future<void> Function(TestApp app)? seed}) async {
  final app = await pumpApp(tester, now: now);
  await seed?.call(app);
  app.router.push(MNRoutes.history);
  await tester.pumpAndSettle();
  return app;
}

Finder voidButton() => find.widgetWithText(MNButton, 'Batilisha mauzo haya');

Future<void> openSale(WidgetTester tester, String product) async {
  await tester.tap(find.textContaining(product).first);
  await tester.pumpAndSettle();
}

Future<void> voidWithReason(WidgetTester tester) async {
  await tester.tap(voidButton());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Idadi si sahihi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Endelea'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ndiyo, batilisha'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('today\'s sales: compact rows and a total', (tester) async {
    await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now.subtract(const Duration(hours: 2)));
      await record(app, 'bbbb-0002', now.subtract(const Duration(hours: 1)),
          payment: PaymentMethod.mpesa,
          lines: const [
            DraftLine(
                productId: 'kidali',
                productName: 'Kidali (Robo)',
                quantity: 3,
                unitPrice: 2500)
          ]);
    });
    expect(find.text('Historia ya mauzo'), findsOneWidget);
    expect(find.byType(HistoryRow), findsNWidgets(2));
    // Newest first: 14:00 then 13:00 EAT.
    expect(tester.getTopLeft(find.text('14:00')).dy,
        lessThan(tester.getTopLeft(find.text('13:00')).dy));
    expect(find.text('Kuku mzima × 2 +1'), findsOneWidget);
    expect(find.text('TSh 20,000'), findsOneWidget);
    expect(find.text('TSh 27,500'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Inasubiri kusawazisha')),
        findsNWidgets(2));
  });

  testWidgets('no sales: a quiet empty state', (tester) async {
    await openHistory(tester);
    expect(find.text('Hakuna mauzo siku hii'), findsOneWidget);
  });

  testWidgets('choosing yesterday shows yesterday', (tester) async {
    await openHistory(tester, seed: (app) async {
      await record(app, 'yday-0001', now.subtract(const Duration(days: 1)));
    });
    expect(find.byType(HistoryRow), findsNothing);
    await tester.tap(find.text('Jana'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryRow), findsOneWidget);
    // Seven days are offered.
    expect(find.text('Wiki hii'), findsOneWidget);
  });

  testWidgets('details: reference, lines, totals, payment, time, states',
      (tester) async {
    await openHistory(tester, seed: (app) async {
      await record(app, '3f2a9c1b-0001', now);
    });
    await openSale(tester, 'Kuku mzima');
    expect(find.text('Maelezo ya mauzo'), findsOneWidget);
    expect(find.text('MN-3F2A9C1B'), findsOneWidget);
    expect(find.text('Kuku mzima'), findsOneWidget);
    expect(find.text('2 × TSh 9,000'), findsOneWidget);
    expect(find.text('18,000'), findsOneWidget);
    expect(find.text('1 × TSh 2,000'), findsOneWidget);
    expect(find.text('TSh 20,000'), findsOneWidget); // headline and total
    expect(find.text('Taslimu'), findsOneWidget);
    expect(find.text('15:00 · 9 Okt 2026'), findsOneWidget);
    expect(find.text('Haijathibitishwa'), findsOneWidget);
    expect(voidButton(), findsOneWidget);
  });

  testWidgets('void: reason, confirmation, kept and struck through',
      (tester) async {
    final app = await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now);
    });
    await openSale(tester, 'Kuku mzima');
    await voidWithReason(tester);
    expect(find.text('Yamebatilishwa saa 15:00 · Idadi si sahihi'),
        findsOneWidget);
    expect(find.text('Ombi la kubatilisha linasubiri kutumwa ofisini.'),
        findsOneWidget);
    expect(voidButton(), findsNothing);
    final headline = tester.widget<Text>(find.text('TSh 20,000').first);
    expect(headline.style!.decoration, TextDecoration.lineThrough);
    final saved = await app.db.select(app.db.saleVoids).get();
    expect(saved.single.reason, 'wrong_quantity');
    expect(saved.single.actorId, 'v1');
    expect(await app.db.select(app.db.sales).get(), hasLength(1));

    await tester.tap(find.bySemanticsLabel('Rudi'));
    await tester.pumpAndSettle();
    expect(find.text('Hakuna mauzo siku hii'),
        findsOneWidget); // voids are hidden by default
  });

  testWidgets('cancelling at either step voids nothing', (tester) async {
    final app = await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now);
    });
    await openSale(tester, 'Kuku mzima');
    await tester.tap(voidButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mteja ameghairi, bidhaa zimerudi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapana'));
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.saleVoids).get(), isEmpty);
    expect(voidButton(), findsOneWidget);
  });

  testWidgets('a double tap on void opens one flow and records one void',
      (tester) async {
    final app = await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now);
    });
    await openSale(tester, 'Kuku mzima');
    await tester.tap(voidButton());
    await tester.tap(voidButton(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Sababu ya kubatilisha'), findsOneWidget);
    await tester.tap(find.text('Yamerekodiwa mara mbili'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    final yes = find.text('Ndiyo, batilisha');
    await tester.tap(yes);
    await tester.tap(yes, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.saleVoids).get(), hasLength(1));
  });

  testWidgets('verified sales: no void, office-only note', (tester) async {
    await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now);
      await app.container.read(historyStoreProvider).markVerified('aaaa-0001');
    });
    expect(find.bySemanticsLabel(RegExp('Imethibitishwa')), findsOneWidget);
    await openSale(tester, 'Kuku mzima');
    expect(voidButton(), findsOneWidget);
    expect(find.text('Mauzo yaliyothibitishwa hubadilishwa na ofisi tu.'),
        findsNothing);
    await tester.tap(voidButton());
    await tester.pumpAndSettle();
    expect(find.text('Huwezi kubatilisha mauzo haya'), findsOneWidget);
    expect(find.text('Mauzo yaliyothibitishwa hubadilishwa na ofisi tu.'),
        findsOneWidget);
    await tester.tap(find.text('Sawa'));
    await tester.pumpAndSettle();
    expect(find.text('Mauzo yaliyothibitishwa hubadilishwa na ofisi tu.'),
        findsNothing);
    expect(find.text('Imethibitishwa'), findsOneWidget);
  });

  testWidgets('earlier days and other vendors\' sales cannot be voided',
      (tester) async {
    await openHistory(tester, seed: (app) async {
      await record(app, 'yday-0001', now.subtract(const Duration(days: 1)));
      await record(app, 'othr-0001', now, vendor: 'v2');
    });
    await openSale(tester, 'Kuku mzima');
    expect(voidButton(), findsNothing);
    await tester.tap(find.bySemanticsLabel('Rudi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jana'));
    await tester.pumpAndSettle();
    await openSale(tester, 'Kuku mzima');
    expect(voidButton(), findsOneWidget);
    expect(
        find.text(
            'Mauzo ya siku zilizopita hayawezi kubatilishwa kwenye simu.'),
        findsNothing);
    await tester.tap(voidButton());
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Mauzo ya siku zilizopita hayawezi kubatilishwa kwenye simu.'),
        findsOneWidget);
  });

  testWidgets(
      'offline conflict: the refused void is explained and the sale '
      'stands', (tester) async {
    final app = await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now);
    });
    await openSale(tester, 'Kuku mzima');
    await voidWithReason(tester);
    final voidId = (await app.db.select(app.db.saleVoids).get()).single.voidId;
    final store = app.container.read(historyStoreProvider);
    await store.markVerified('aaaa-0001');
    await store.applyVoidResult(voidId,
        accepted: false, rejectionReason: 'already_verified');
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Mauzo yamethibitishwa, kwa hiyo hayawezi kubatilishwa kwenye simu. Mwambie msimamizi wako.'),
        findsOneWidget);
    expect(find.text('Imethibitishwa'), findsOneWidget);
    expect(voidButton(), findsOneWidget);
    final headline = tester.widget<Text>(find.text('TSh 20,000').first);
    expect(headline.style!.decoration, isNull);
  });

  testWidgets('a refused void after closing explains it plainly',
      (tester) async {
    final app = await openHistory(tester, seed: (app) async {
      await record(app, 'aaaa-0001', now.subtract(const Duration(hours: 1)));
    });
    await openSale(tester, 'Kuku mzima');
    await voidWithReason(tester);
    final voidId = (await app.db.select(app.db.saleVoids).get()).single.voidId;
    final store = app.container.read(historyStoreProvider);
    // Verified automatically when the count arrived: the server sends the void
    // to review, and the vendor is told who to speak to, with no office jargon.
    await store.markVerified('aaaa-0001');
    await store.applyVoidResult(voidId,
        accepted: false, rejectionReason: 'already_verified');
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Mauzo yamethibitishwa, kwa hiyo hayawezi kubatilishwa kwenye simu. Mwambie msimamizi wako.'),
        findsOneWidget);
    expect(find.textContaining('moja kwa moja'), findsNothing);
    expect(
        find.text('Ofisi haikukubali kubatilisha mauzo haya.'), findsNothing);
  });

  testWidgets('a long day scrolls to its first sale', (tester) async {
    await openHistory(tester, seed: (app) async {
      for (var i = 0; i < 40; i++) {
        await record(app, 'bulk-${i.toString().padLeft(4, '0')}',
            now.subtract(Duration(minutes: 5 * i)));
      }
    });
    expect(find.text('11:45'), findsNothing); // the oldest, off screen
    await tester.scrollUntilVisible(find.text('11:45'), 400,
        scrollable: find.descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable)));
    expect(find.text('11:45'), findsOneWidget);
  });
}
