import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart'
    show AuthFailure, AuthFailureKind;
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'office_verification_test.dart' show openAs;
import 'owner_performance_test.dart' show PerformanceOffice, office;

/// Every state of the owner-approved scorecard reference (31 October 2026).
/// `--dart-define=REFERENCE_CAPTURES=true` also writes each to
/// output/scorecard-reference for comparing against the supplied image.
const _captures = bool.fromEnvironment('REFERENCE_CAPTURES');
const en = Strings('en');
const _even = {
  'sales': 20,
  'money': 20,
  'stock': 20,
  'discipline': 20,
  'conduct': 20
};

Future<void> capture(WidgetTester tester, String name) async {
  if (!_captures) return;
  await tester.pump(const Duration(milliseconds: 400));
  RenderObject? node = tester.renderObject(find.byType(Scaffold).first);
  RenderRepaintBoundary? root;
  while (node != null) {
    if (node is RenderRepaintBoundary) root = node;
    node = node.parent;
  }
  final image = (await tester.runAsync(() => root!.toImage(pixelRatio: 1)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/scorecard-reference');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

Map<String, Object?> areas(
        {int? sales, int? money, int? stock, int? discipline, int? conduct}) =>
    {
      'sales': sales,
      'money': money,
      'stock': stock,
      'discipline': discipline,
      'conduct': conduct
    };

Scorecard card(
        {int? score,
        Map<String, Object?>? area,
        Map<String, int>? weights = _even,
        String chickens = '0',
        int earned = 0,
        int estimated = 0,
        bool worked = true}) =>
    Scorecard.fromJson({
      'vendor': {'id': 'v1', 'name': 'Maternus Joshua'},
      'from': '2026-10-26',
      'to': '2026-11-01',
      'score': score,
      'areas': area ?? areas(),
      'weights': weights,
      'bonus': {
        'chicken_equivalents': chickens,
        'earned': earned,
        'estimated': estimated,
        'adjustments': 0
      },
      'days': [
        if (worked)
          {
            'business_date': '2026-10-30',
            'station': {'id': 's1', 'name': 'Mr. Nyama 101'},
            'score': score,
            'areas': area ?? areas(),
            'rating_changes': 2,
          }
      ],
    });

Future<void> open(WidgetTester tester, PerformanceOffice o) async {
  final app = await openAs(tester, o,
      roles: const ['business_owner'],
      route: MNRoutes.officePerformanceVendor('v1'),
      size: const Size(390, 726),
      overrides: [
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30, 9)),
      ]);
  app.container.read(languageProvider.notifier).state = 'en';
  tester.view
    ..padding = const FakeViewPadding(top: 34, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 34, bottom: 34);
  await tester.pumpAndSettle();
}

Future<void> iconFont(WidgetTester tester) async {
  if (!_captures) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await tester.runAsync(loader.load);
}

Future<void> typeScore(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(
        find.descendant(of: find.byType(MNPinKeypad), matching: find.text(d)));
    await tester.pump();
  }
}

void main() {
  testWidgets('01 weights not set', (tester) async {
    await iconFont(tester);
    final o = office()..vendorCard = card(weights: null, worked: false);
    await open(tester, o);
    expect(find.text(en.opNoScore), findsOneWidget);
    expect(find.text(en.opWeightsNotSet), findsOneWidget);
    expect(find.text(en.opSetWeights), findsOneWidget);
    expect(find.text(en.opAreaValue(null)), findsNWidgets(5));
    expect(find.text(en.opRatePerformance), findsOneWidget);
    expect(find.text('26 Oct 2026 – 1 Nov 2026'), findsOneWidget);
    expect(find.text('TZS 0'), findsNWidgets(2));
    await capture(tester, '01');
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 not rated yet', (tester) async {
    final o = office()..vendorCard = card(worked: false);
    await open(tester, o);
    expect(find.text(en.opNotRatedYet), findsOneWidget);
    expect(find.text(en.opMeasured(0, 5)), findsOneWidget);
    await capture(tester, '02');
  });

  testWidgets('03 score pending', (tester) async {
    final o = office()
      ..vendorCard = card(area: areas(money: 50, discipline: 80));
    await open(tester, o);
    expect(find.text(en.opScorePending), findsOneWidget);
    expect(find.text(en.opMeasured(2, 5)), findsOneWidget);
    expect(find.text('50/100'), findsOneWidget);
    await capture(tester, '03');
  });

  testWidgets('04 partial score', (tester) async {
    final o = office()
      ..vendorCard = card(
          score: 64,
          area: areas(sales: 70, money: 50, discipline: 80),
          chickens: '420',
          earned: 84000,
          estimated: 96000);
    await open(tester, o);
    expect(find.text('64'), findsOneWidget);
    expect(find.text(en.opPartial), findsOneWidget);
    expect(find.text(en.opMeasured(3, 5)), findsOneWidget);
    expect(find.text('420 pcs'), findsOneWidget);
    expect(find.text('TZS 84,000'), findsOneWidget);
    await capture(tester, '04');
  });

  testWidgets('05 fully rated', (tester) async {
    final o = office()
      ..vendorCard = card(
          score: 72,
          area: areas(
              sales: 70, money: 50, stock: 60, discipline: 80, conduct: 70),
          chickens: '480',
          earned: 120000,
          estimated: 140000);
    await open(tester, o);
    expect(find.text(en.opAllMeasured), findsOneWidget);
    expect(find.text(en.opEqualWeights), findsOneWidget);
    expect(find.text(en.opUpdateRating), findsOneWidget);
    expect(find.text(en.opRatePerformance), findsNothing);
    await capture(tester, '05');
  });

  testWidgets('06–08 rating money: typing, out of range, saved',
      (tester) async {
    await iconFont(tester);
    final o = office()
      ..vendorCard = card(area: areas(money: 50, discipline: 80));
    await open(tester, o);
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('Rate Money'), findsOneWidget);
    await typeScore(tester, '120');
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text(en.opRateOutOfRange), findsOneWidget);
    await capture(tester, '07');
    await tester.tap(find.text(en.opSaveShort));
    await tester.pump();
    expect(o.rated, isEmpty);

    await tester.tap(find.bySemanticsLabel(en.close));
    await tester.pump();
    await typeScore(tester, '85');
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text(en.opRateOutOfRange), findsNothing);
    await capture(tester, '06');
    await tester.tap(find.text(en.opSaveShort));
    await tester.pumpAndSettle();
    expect(o.rated, ['v1 2026-10-30 money 85']);
    expect(find.text(en.opRatingUpdated), findsOneWidget);
    expect(find.text('Money: 50 → 85', findRichText: true), findsOneWidget);
    expect(find.text(en.opRatingRecorded), findsOneWidget);
    await capture(tester, '08');
    await tester.tap(find.text(en.done));
    await tester.pumpAndSettle();
    expect(find.text(en.opRatingUpdated), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused rating keeps the sheet and says why', (tester) async {
    final o = office()
      ..vendorCard = card(area: areas(money: 50, discipline: 80))
      ..refuseRating =
          const OfficeError(OfficeErrorKind.refused, 'There is no work.');
    await open(tester, o);
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    await typeScore(tester, '85');
    await tester.tap(find.text(en.opSaveShort));
    await tester.pumpAndSettle();
    expect(find.text('Rate Money'), findsOneWidget);
    expect(find.textContaining('There is no work.'), findsOneWidget);
    expect(find.text(en.opRatingUpdated), findsNothing);
  });

  testWidgets('a period with no work says there is nothing to rate',
      (tester) async {
    final o = office()..vendorCard = card(worked: false);
    await open(tester, o);
    await tester.tap(find.text(en.opRatePerformance));
    await tester.pumpAndSettle();
    expect(find.text(en.opRateChoose), findsOneWidget);
    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text(en.opNoWorkDay), findsOneWidget);
  });

  for (final (name, score, area, changes) in [
    ('09', null, areas(money: 50, discipline: 80), 1),
    ('10', 76, areas(sales: 90, money: 70, stock: 60, discipline: 80), 2),
  ]) {
    testWidgets('$name day detail', (tester) async {
      final o = office()
        ..vendorCard = card(score: score, area: area)
        ..dayCards['2026-10-30'] = Scorecard.fromJson({
          'vendor': {'id': 'v1', 'name': 'Maternus Joshua'},
          'from': '2026-10-30',
          'to': '2026-10-30',
          'score': score,
          'areas': area,
          'weights': _even,
          'days': [
            {
              'business_date': name == '09' ? '2026-10-28' : '2026-10-30',
              'station': {'id': 's1', 'name': 'Mr. Nyama 101'},
              'score': score,
              'areas': area,
              'rating_changes': changes,
            }
          ],
        });
      await open(tester, o);
      final row = find.textContaining('30 Oct 2026 · Mr. Nyama 101');
      await tester.scrollUntilVisible(row, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(en.opRatingHistory), findsOneWidget);
      expect(find.text(en.opChanges(changes)), findsOneWidget);
      if (name == '09') {
        expect(find.text(en.opNoScore), findsOneWidget);
        expect(find.text(en.opNotAllRated), findsOneWidget);
      } else {
        expect(find.text('76'), findsOneWidget);
        expect(find.text(en.opNotAllRated), findsNothing);
        expect(find.text(en.opPartial), findsNothing);
      }
      await capture(tester, name);
      await tester.tap(find.text(en.opRatingHistory));
      await tester.pumpAndSettle();
      expect(find.text(en.opNoRatingChanges), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed history shows the error screen and recovers on a swipe',
      (tester) async {
    final o = office()
      ..vendorCard = card(area: areas(money: 50, discipline: 80))
      ..historyFailure = StateError('server');
    await open(tester, o);
    final row = find.textContaining('30 Oct 2026 · Mr. Nyama 101');
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.opRatingHistory));
    await tester.pumpAndSettle();
    expect(find.text(en.errorTitle), findsOneWidget);
    expect(find.text(en.retry), findsNothing);
    if (_captures) {
      final image = tester.widget<Image>(find.byType(Image).last);
      await tester.runAsync(() => precacheImage(
          image.image, tester.element(find.byType(Scaffold).last)));
      await tester.pumpAndSettle();
      await capture(tester, 'error');
    }
    o.historyFailure = null;
    await tester.drag(find.text(en.errorTitle), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text(en.errorTitle), findsNothing);
    expect(find.text(en.opNoRatingChanges), findsOneWidget);
  });

  testWidgets('no network on the history shows the no-internet screen',
      (tester) async {
    final o = office()
      ..vendorCard = card(area: areas(money: 50, discipline: 80))
      ..historyFailure = const AuthFailure(AuthFailureKind.offline);
    await open(tester, o);
    final row = find.textContaining('30 Oct 2026 · Mr. Nyama 101');
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.opRatingHistory));
    await tester.pumpAndSettle();
    expect(find.text(en.noInternetTitle), findsOneWidget);
    expect(find.text(en.noInternetBody), findsOneWidget);
    if (_captures) {
      final image = tester.widget<Image>(find.byType(Image).last);
      await tester.runAsync(() => precacheImage(
          image.image, tester.element(find.byType(Scaffold).last)));
      await tester.pumpAndSettle();
      await capture(tester, 'no-network');
    }
    o.historyFailure = null;
    await tester.drag(find.text(en.noInternetTitle), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text(en.noInternetTitle), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(768, 1024)]) {
    testWidgets('fits $size', (tester) async {
      final o = office()
        ..vendorCard = card(
            score: 72,
            area: areas(
                sales: 70, money: 50, stock: 60, discipline: 80, conduct: 70),
            chickens: '480',
            earned: 120000,
            estimated: 140000);
      await openAs(tester, o,
          roles: const ['business_owner'],
          route: MNRoutes.officePerformanceVendor('v1'),
          size: size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Fedha'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
