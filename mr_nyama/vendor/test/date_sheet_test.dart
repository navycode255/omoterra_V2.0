import 'package:mr_nyama_vendor/shared/widgets/pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/shared/widgets/date_sheet.dart';

import 'helpers.dart';

// 24 October 2026, noon in Dar es Salaam.
final _now = DateTime.utc(2026, 10, 24, 9);
final _today = DateTime.utc(2026, 10, 24);
const sw = Strings('sw');

Finder _day(int y, int m, int d) => find.byKey(ValueKey('mn-date-$y-$m-$d'));

/// A page with one button that opens [open]; the result lands in [out].
Widget _host(Future<Object?> Function(BuildContext) open, List<Object?> out) =>
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(() => _now)],
      child: MaterialApp(
        theme: mrNyamaTheme(),
        home: Scaffold(
          body: Center(
            child: Builder(
                builder: (context) => TextButton(
                    onPressed: () async => out.add(await open(context)),
                    child: const Text('Fungua'))),
          ),
        ),
      ),
    );

Future<List<Object?>> _open(
    WidgetTester tester, Future<Object?> Function(BuildContext) open,
    {bool settle = true}) async {
  final out = <Object?>[];
  await tester.pumpWidget(_host(open, out));
  await tester.tap(find.text('Fungua'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return out;
}

Future<void> _confirm(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.textContaining(label));
  await tester.tap(find.textContaining(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('returns the chosen day as a UTC date', (tester) async {
    setScreen(tester);
    final out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: DateTime.utc(2026, 10, 20),
            first: DateTime.utc(2026),
            last: _today));
    expect(find.text(sw.moneyChooseDate), findsOneWidget);
    expect(find.text('Oktoba 2026'), findsOneWidget);
    for (final w in sw.weekdayInitials) {
      expect(find.text(w), findsOneWidget);
    }
    await tester.tap(_day(2026, 10, 15));
    await tester.pump();
    await _confirm(tester, sw.useThisDate);
    expect(out.single, DateTime.utc(2026, 10, 15));
    expect((out.single as DateTime).isUtc, isTrue);
  });

  testWidgets('dismissing returns null', (tester) async {
    setScreen(tester);
    final out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: _today, first: DateTime.utc(2020), last: _today));
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(out.single, isNull);
  });

  testWidgets('days outside the range are disabled', (tester) async {
    setScreen(tester);
    final out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: DateTime.utc(2026, 10, 12),
            first: DateTime.utc(2026, 10, 10),
            last: DateTime.utc(2026, 10, 20)));
    for (final d in [9, 21, 24]) {
      expect(tester.getSemantics(_day(2026, 10, d)),
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
          reason: 'day $d');
      await tester.tap(_day(2026, 10, d), warnIfMissed: false);
      await tester.pump();
    }
    expect(
        tester.getSemantics(_day(2026, 10, 12)),
        isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasSelectedState: true,
            isSelected: true));
    // Both months are the range's own month: no way out.
    expect(tester.getSemantics(find.bySemanticsLabel(sw.previousMonth)),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false));
    expect(tester.getSemantics(find.bySemanticsLabel(sw.nextMonth)),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false));
    // Today is out of range, so there are no quick chips.
    expect(find.text(sw.todayLabel), findsNothing);
    expect(find.text(sw.yesterdayLabel), findsNothing);
    await _confirm(tester, sw.useThisDate);
    expect(out.single, DateTime.utc(2026, 10, 12));
  });

  testWidgets('an initial day outside the range is clamped', (tester) async {
    setScreen(tester);
    final out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: DateTime.utc(2027, 3, 1),
            first: DateTime.utc(2026, 10, 1),
            last: _today));
    await _confirm(tester, sw.useThisDate);
    expect(out.single, _today);
  });

  testWidgets('Leo and Jana pick today and yesterday', (tester) async {
    setScreen(tester);
    var out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: DateTime.utc(2026, 9, 3),
            first: DateTime.utc(2026),
            last: _today));
    expect(find.text('Septemba 2026'), findsOneWidget);
    await tester.tap(find.text(sw.yesterdayLabel));
    await tester.pumpAndSettle();
    expect(find.text('Oktoba 2026'), findsOneWidget);
    await _confirm(tester, sw.useThisDate);
    expect(out.single, DateTime.utc(2026, 10, 23));

    out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: DateTime.utc(2026, 9, 3),
            first: DateTime.utc(2026),
            last: _today));
    await tester.tap(find.text(sw.todayLabel));
    await tester.pumpAndSettle();
    await _confirm(tester, sw.useThisDate);
    expect(out.single, _today);

    // Only today in range: no "Jana".
    await _open(
        tester,
        (c) =>
            showMNDateSheet(c, initial: _today, first: _today, last: _today));
    expect(find.text(sw.todayLabel), findsOneWidget);
    expect(find.text(sw.yesterdayLabel), findsNothing);
  });

  testWidgets('month navigation moves within the range', (tester) async {
    setScreen(tester);
    final out = await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: _today,
            first: DateTime.utc(2026, 8, 15),
            last: DateTime.utc(2026, 11, 30)));
    final prev = find.bySemanticsLabel(sw.previousMonth);
    final next = find.bySemanticsLabel(sw.nextMonth);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Novemba 2026'), findsOneWidget);
    expect(tester.getSemantics(next),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false));
    await tester.tap(prev);
    await tester.pumpAndSettle();
    await tester.tap(prev);
    await tester.pumpAndSettle();
    await tester.tap(prev);
    await tester.pumpAndSettle();
    expect(find.text('Agosti 2026'), findsOneWidget);
    expect(tester.getSemantics(prev),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false));
    await tester.tap(_day(2026, 8, 20));
    await tester.pump();
    await _confirm(tester, sw.useThisDate);
    expect(out.single, DateTime.utc(2026, 8, 20));
  });

  testWidgets('a period: first tap starts it, second ends it', (tester) async {
    setScreen(tester);
    final out = await _open(
        tester,
        (c) => showMNDateRangeSheet(c,
            start: DateTime.utc(2026, 10, 1),
            end: _today,
            first: DateTime.utc(2020),
            last: _today));
    expect(find.text(sw.chooseDateRange), findsOneWidget);
    await tester.tap(_day(2026, 10, 12));
    await tester.pump();
    await tester.tap(_day(2026, 10, 5)); // before the start: starts again
    await tester.pump();
    await tester.tap(_day(2026, 10, 9));
    await tester.pump();
    expect(
        find.text(sw.stockRange('5 Okt 2026', '9 Okt 2026')), findsOneWidget);
    await _confirm(tester, sw.useThisPeriod);
    expect(out.single, (DateTime.utc(2026, 10, 5), DateTime.utc(2026, 10, 9)));
  });

  testWidgets('time sheet steps and types a 24-hour time', (tester) async {
    setScreen(tester);
    final out =
        await _open(tester, (c) => showMNTimeSheet(c, hour: 23, minute: 5));
    expect(find.text('23'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('${sw.decrease} ${sw.hourLabel}'));
    await tester.pumpAndSettle();
    expect(find.text('22'), findsOneWidget);
    // Tap the minutes to type them on the keypad.
    await tester.tap(find.bySemanticsLabel('${sw.minuteLabel}, 05'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(MNPinKeypad), matching: find.text('4')));
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.byType(MNPinKeypad), matching: find.text('5')));
    await tester.pump();
    await tester.tap(find.text(sw.setQuantity));
    await tester.pumpAndSettle();
    await _confirm(tester, sw.useThisTime);
    expect(out.single, (hour: 22, minute: 45));
  });

  testWidgets('targets are at least 48 px', (tester) async {
    setScreen(tester);
    await _open(
        tester,
        (c) => showMNDateSheet(c,
            initial: _today, first: DateTime.utc(2026), last: _today));
    for (final f in [
      find.bySemanticsLabel(sw.previousMonth),
      find.bySemanticsLabel(sw.nextMonth),
      find.bySemanticsLabel(sw.todayLabel),
      find.bySemanticsLabel(sw.yesterdayLabel),
      _day(2026, 10, 1),
      _day(2026, 10, 24),
    ]) {
      final size = tester.getSize(f);
      expect(size.width, greaterThanOrEqualTo(48), reason: '$f');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$f');
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'fits 320 px at 2× text without overflow'
        '${reduced ? ' (reduced motion)' : ''}', (tester) async {
      setScreen(tester,
          size: const Size(320, 568), textScale: 2, reducedMotion: reduced);
      final out = await _open(
          tester,
          (c) => showMNDateSheet(c,
              initial: DateTime.utc(2026, 9, 30),
              first: DateTime.utc(2026),
              last: _today));
      expect(tester.takeException(), isNull);
      // Day cells keep a 48 px tap height even when narrower than 48.
      expect(
          tester.getSize(_day(2026, 9, 30)).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(find.bySemanticsLabel(sw.nextMonth));
      await tester.tap(find.bySemanticsLabel(sw.nextMonth));
      if (reduced) {
        // No transition: one frame shows the new month alone.
        await tester.pump();
        expect(find.text('Septemba 2026'), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.text('Oktoba 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _confirm(tester, sw.useThisDate);
      expect(out.single, DateTime.utc(2026, 9, 30));

      await _open(
          tester,
          (c) => showMNDateRangeSheet(c,
              start: DateTime.utc(2026, 10, 1),
              end: _today,
              first: DateTime.utc(2020),
              last: _today));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await _open(tester, (c) => showMNTimeSheet(c, hour: 9, minute: 30));
      expect(tester.takeException(), isNull);
      expect(find.text('09'), findsOneWidget);
    });
  }

  testWidgets('English copy', (tester) async {
    setScreen(tester);
    final out = <Object?>[];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => _now),
          languageProvider.overrideWith((ref) => 'en'),
        ],
        child: MaterialApp(
            theme: mrNyamaTheme(),
            home: Scaffold(
                body: Builder(
                    builder: (c) => TextButton(
                        onPressed: () async => out.add(await showMNDateSheet(c,
                            initial: _today,
                            first: DateTime.utc(2020),
                            last: _today)),
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    const en = Strings('en');
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(en.todayLabel), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    expect(find.text(en.useThisDate), findsOneWidget);
  });

  group('date wheel', () {
    Future<List<Object?>> wheel(WidgetTester tester, DateTime initial) => _open(
        tester,
        (context) => showMNDateWheelSheet(context,
            initial: initial,
            first: _today.subtract(const Duration(days: 365)),
            last: _today));

    testWidgets('opens on the initial day and returns it', (tester) async {
      setScreen(tester);
      final out = await wheel(tester, DateTime.utc(2026, 10, 21));
      expect(find.text('Tarehe maalum'), findsOneWidget);
      // The centre row is bold; the rows around it are muted.
      final centre = tester.widget<Text>(find.text('Jumatano'));
      expect(centre.style!.fontWeight, FontWeight.w800);
      expect(tester.widget<Text>(find.text('Jumanne')).style!.color,
          MNColors.disabledText);
      await _confirm(tester, 'Tumia tarehe');
      expect(out, [DateTime.utc(2026, 10, 21)]);
    });

    testWidgets('tapping a nearby row moves the choice to it', (tester) async {
      setScreen(tester);
      final out = await wheel(tester, DateTime.utc(2026, 10, 21));
      await tester.tap(find.text('Jumanne'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('Jumanne')).style!.fontWeight,
          FontWeight.w800);
      await _confirm(tester, 'Tumia tarehe');
      expect(out, [DateTime.utc(2026, 10, 20)]);
    });

    testWidgets('never scrolls past the last day', (tester) async {
      setScreen(tester);
      final out = await wheel(tester, _today);
      await tester.drag(find.text('Jumamosi'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await _confirm(tester, 'Tumia tarehe');
      expect(out, [_today]);
    });

    testWidgets('closing returns nothing', (tester) async {
      setScreen(tester);
      final out = await wheel(tester, _today);
      await tester.tap(find.bySemanticsLabel('Funga'));
      await tester.pumpAndSettle();
      expect(out, [null]);
    });

    testWidgets('fits a small phone at double text', (tester) async {
      setScreen(tester, size: const Size(320, 568), textScale: 2);
      await wheel(tester, _today);
      expect(tester.takeException(), isNull);
      expect(find.text('Tumia tarehe'), findsOneWidget);
    });
  });
}
