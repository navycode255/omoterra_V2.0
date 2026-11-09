import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/features/home/progress_card.dart';

import 'helpers.dart';

const sw = Strings('sw');

VendorProgress progress(
        {bool earned = false,
        int? stars = 4,
        String? period = 'weekly',
        ({int chickens, int amount})? next = (chickens: 3, amount: 1000)}) =>
    VendorProgress.fromJson({
      'business_date': '2026-10-26',
      'chicken_equivalents': '12',
      'verified_equivalents': '10',
      'target': 10,
      'next_step': next == null
          ? null
          : {'chickens': next.chickens, 'amount': next.amount},
      'bonus_today': {'amount': 2500, 'state': earned ? 'earned' : 'estimated'},
      'pay_period': period,
      'period_total': period == null
          ? null
          : {
              'from': '2026-10-26',
              'to': '2026-11-01',
              'earned': 4000,
              'estimated': 2500,
              'adjustments': -500
            },
      'score': stars == null ? null : 78,
      'stars': stars,
      // A server field the card must never show.
      'profit': 60000,
    });

Future<FakeVendorRepository> open(WidgetTester tester, VendorProgress value,
    {Size size = const Size(390, 844), double textScale = 1}) async {
  final api = FakeVendorRepository()..progressValue = value;
  await pumpApp(tester, api: api, size: size, textScale: textScale);
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets(
      'chickens against the target, next step, estimated bonus, stars, period',
      (tester) async {
    await open(tester, progress());
    expect(find.byType(ProgressCard), findsOneWidget);
    expect(find.text(sw.progressChickens('12', 10)), findsOneWidget);
    expect(find.text(sw.progressNextStep(3, 'TSh 1,000')), findsOneWidget);
    expect(
        find.textContaining('TSh 2,500 · ${sw.progressEstimated}',
            findRichText: true),
        findsOneWidget);
    expect(find.text(sw.progressStars(4)), findsOneWidget);
    expect(find.text(sw.progressPeriod('weekly')), findsOneWidget);
    expect(
        find.textContaining(sw.progressPeriodAmount('TSh 3,500', 'TSh 2,500'),
            findRichText: true),
        findsOneWidget);
    expect(find.text(sw.progressEstimatedNote), findsOneWidget);
    expect(find.textContaining('60,000'), findsNothing); // never profit
    expect(tester.takeException(), isNull);
  });

  testWidgets('a closed day shows the bonus as earned', (tester) async {
    await open(tester, progress(earned: true, next: null));
    expect(
        find.textContaining('TSh 2,500 · ${sw.progressEarned}',
            findRichText: true),
        findsOneWidget);
    expect(find.text(sw.progressEstimatedNote), findsNothing);
    expect(find.textContaining('zaidi kupata bonasi'), findsNothing);
  });

  testWidgets('without stars or a pay period those lines are left out',
      (tester) async {
    await open(tester, progress(stars: null, period: null));
    expect(find.byType(ProgressCard), findsOneWidget);
    expect(find.textContaining('Nyota'), findsNothing);
    expect(find.text(sw.progressPeriod('weekly')), findsNothing);
  });

  testWidgets('nothing configured: no card', (tester) async {
    await open(tester, VendorProgress.none);
    expect(find.text(sw.progressTitle), findsNothing);
  });

  testWidgets('a failed fetch (offline) shows no card and no error',
      (tester) async {
    final api = FakeVendorRepository()
      ..progressValue = progress()
      ..progressFailure = const AuthFailure(AuthFailureKind.offline);
    await pumpApp(tester, api: api);
    await tester.pumpAndSettle();
    expect(find.text(sw.progressTitle), findsNothing);
    expect(api.progressCalls, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(360, 740)]) {
    testWidgets('fits ${size.width.toInt()} px at 2× text', (tester) async {
      await open(tester, progress(), size: size, textScale: 2);
      await tester.scrollUntilVisible(find.text(sw.progressEstimatedNote), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }
}
