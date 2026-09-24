import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/authentication/screens.dart';

Widget harness() => ProviderScope(
    overrides: [stringsProvider.overrideWithValue(const Strings('en'))],
    child: MaterialApp(theme: omoterraTheme(), home: const PhoneScreen()));

void main() {
  testWidgets('the in-app keypad enters the number', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    for (final digit in '746484'.split('')) {
      await tester.tap(find.widgetWithText(InkWell, digit).first);
      await tester.pump();
    }
    expect(find.text('746 484'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('746 48'), findsOneWidget);
  });

  testWidgets('the custom keypad can be hidden and shown again',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, '1'), findsOneWidget);

    await tester.tap(find.text('Hide keyboard'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, '1'), findsNothing);
    expect(find.text('Show keyboard'), findsOneWidget);

    await tester.tap(find.text('Show keyboard'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, '1'), findsOneWidget);
  });

  testWidgets('no system keyboard is ever requested', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // A TextField anywhere on this screen would raise the OS keyboard and
    // defeat the custom pad.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('a leading zero is refused', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(InkWell, '0').first);
    await tester.pump();
    // Nothing is entered and the reason is explained.
    expect(find.text('712 *** ***'), findsOneWidget);
    expect(find.textContaining('Drop the leading 0'), findsOneWidget);

    // A zero is fine once the number has started.
    await tester.tap(find.widgetWithText(InkWell, '7').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, '0').first);
    await tester.pump();
    expect(find.text('70'), findsOneWidget);
  });

  testWidgets('the placeholder masks the example number', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text('712 *** ***'), findsOneWidget);
  });

  testWidgets('the number stops at nine digits', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.widgetWithText(InkWell, '7').first);
      await tester.pump();
    }
    expect(find.text('777 777 777'), findsOneWidget);
  });

  testWidgets('every key is reachable by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness());
    await tester.pump();

    for (final digit in ['0', '1', '5', '9']) {
      expect(find.bySemanticsLabel(digit), findsOneWidget,
          reason: 'key $digit must carry a spoken label');
    }
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);
    expect(find.bySemanticsLabel('Phone number'), findsOneWidget);
    handle.dispose();
  });
}
