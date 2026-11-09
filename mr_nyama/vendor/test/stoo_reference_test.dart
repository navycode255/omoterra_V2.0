import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/theme/tokens.dart' show MNColors;
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart';
import 'package:mr_nyama_vendor/features/office/station_screen.dart';
import 'package:mr_nyama_vendor/features/office/stock_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'helpers.dart';
import 'office_stock_production_test.dart' show stockOffice;

void main() {
  for (final empty in [true, false]) {
    testWidgets('Stoo reference ${empty ? 'empty' : 'populated'}',
        (tester) async {
      final office = stockOffice();
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut,
          now: DateTime.utc(2026, 10, 24, 12),
          office: office,
          overrides: [
            officeStationsProvider.overrideWith((ref) async => const [
                  OfficeStation(
                      id: 's1',
                      code: 'B',
                      name: 'Bunju B',
                      stockLocationId: 'loc'),
                ]),
            stationStockProvider.overrideWith((ref, id) async => empty
                ? []
                : [
                    {'quantity': 6, 'unit': 'bird'},
                  ]),
            stockDaysProvider.overrideWith((ref, key) async => OfficeStockDays(
                stationId: 's1',
                days: empty
                    ? []
                    : [
                        OfficeStockDay(
                          vendorDayId: 'day',
                          vendorName: 'Test vendor',
                          businessDate: DateTime.utc(2026, 10, 24),
                          statusWire: 'open',
                        )
                      ])),
            stockReturnsProvider.overrideWith((ref, key) async => empty
                ? []
                : [
                    OfficeStockReturn(
                        id: 'return',
                        businessDate: DateTime.utc(2026, 10, 23),
                        lines: const [
                          StockReturnLine(
                              product: 'KUKU',
                              name: 'Kuku mzima',
                              unit: 'bird',
                              quantity: 4)
                        ]),
                  ]),
          ]);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(office.owner);
      app.router.push(MNRoutes.officeStock('s1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.widget<MNButton>(
          find.widgetWithText(MNButton, const Strings('sw').returnGoods));
      expect(button.onPressed == null, empty);
      expect(find.text('Bunju B'), findsOneWidget);
      if (!empty) {
        expect(find.text('4 kuku'), findsOneWidget);
        expect(find.text('Hesabu za kila siku'), findsOneWidget);
      }
      if (Platform.environment['MN_STOO_PREVIEWS'] == '1') {
        final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary));
        final image =
            (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
        final bytes = await tester
            .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        await tester.runAsync(() =>
            File('/tmp/stoo-${empty ? 'empty' : 'populated'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List()));
        image.dispose();
      }
    });
  }

  group('stock measures', () {
    const kuku = OfficeStockMeasure(
        productCode: 'KUKU',
        productName: 'Kuku mzima',
        book: 25,
        pendingSales: 3,
        pendingDamage: 2,
        heldPhoneSales: 5,
        estimatedAvailable: 20,
        lastCount: OfficeLastCount(
            counted: 24, businessDate: null, status: 'confirmed'),
        lastVariance: -1,
        countGap: -1);
    const quiet = OfficeStockMeasure(
        productCode: 'PAJA',
        productName: 'Paja',
        book: 8,
        estimatedAvailable: 8);
    const sw = Strings('sw');

    Future<void> open(
        WidgetTester tester, List<OfficeStockMeasure> rows) async {
      final office = stockOffice();
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut,
          now: DateTime.utc(2026, 10, 24, 12),
          office: office,
          overrides: [
            officeStationsProvider.overrideWith((ref) async => const [
                  OfficeStation(
                      id: 's1',
                      code: 'B',
                      name: 'Bunju B',
                      stockLocationId: 'loc'),
                ]),
            stationStockProvider.overrideWith((ref, id) async => []),
            stockDaysProvider.overrideWith((ref, key) async =>
                const OfficeStockDays(stationId: 's1', days: [])),
            stockReturnsProvider.overrideWith((ref, key) async => []),
            stockMeasuresProvider.overrideWith((ref, id) async => rows),
          ]);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(office.owner);
      app.router.push(MNRoutes.officeStock('s1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('Kwenye stoo sasa shows book, pending and estimate apart',
        (t) async {
      await open(t, [kuku]);
      expect(find.text(sw.measuresHeading), findsOneWidget);
      expect(find.text('Kuku mzima'), findsOneWidget);
      expect(find.text(sw.measureEstimate), findsOneWidget);
      // Each figure is its own line, none merged into another.
      for (final (label, value) in [
        (sw.measureBook, '25'),
        (sw.measurePendingSales, '3'),
        (sw.measurePendingDamage, '2'),
        (sw.measureCounted, '24'),
        (sw.measureVariance, '-1'),
      ]) {
        final row =
            find.ancestor(of: find.text(label), matching: find.byType(Row));
        expect(find.descendant(of: row.first, matching: find.text(value)),
            findsOneWidget,
            reason: label);
      }
      expect(find.text('20'), findsOneWidget); // the main number
    });

    testWidgets('held sales show as a warning, count_gap only when non-zero',
        (t) async {
      await open(t, [kuku, quiet]);
      final held = t.widget<Text>(find.text(sw.measureHeldSales));
      expect(held.style!.color, MNColors.warning);
      final gap = t.widget<Text>(find.text(sw.measureGap));
      expect(gap.style!.color, MNColors.warning);
      // The quiet product has no held sales, no gap and nothing pending: one
      // of each label only (Kuku's), and no pending lines for Paja.
      expect(find.text(sw.measureHeldSales), findsOneWidget);
      expect(find.text(sw.measureGap), findsOneWidget);
      expect(find.text(sw.measurePendingSales), findsOneWidget);
    });

    testWidgets('each measure explains itself through the help button',
        (t) async {
      await open(t, [kuku]);
      await t.ensureVisible(find.text(sw.measuresHelpTitle));
      await t.tap(find.text(sw.measuresHelpTitle));
      await t.pumpAndSettle();
      expect(
          find.text(sw.measuresHelpTitle), findsNWidgets(2)); // button + sheet
      final help = t.widget<Text>(find.byWidgetPredicate((w) =>
          w is Text && (w.data ?? '').startsWith('${sw.measureEstimate}:')));
      for (final label in [
        sw.measureEstimate,
        sw.measureBook,
        sw.measurePendingSales,
        sw.measurePendingDamage,
        sw.measureHeldSales,
        sw.measureCounted,
        sw.measureVariance,
        sw.measureGap,
      ]) {
        expect(help.data, contains('$label:'));
      }
    });
  });
}
