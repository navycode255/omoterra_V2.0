import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/authentication/screens.dart';

const challenge = {
  'challenge_id': 'test-challenge',
  'otp_length': 6,
  'resend_after_seconds': 45,
  'phone': '+255746484666',
};

Widget harness() => ProviderScope(
    overrides: [
      stringsProvider.overrideWithValue(const Strings('en')),
      repositoryProvider.overrideWithValue(LocalRepository()),
    ],
    child: MaterialApp(
        theme: omoterraTheme(), home: const OtpScreen(challenge)));

Future<void> tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.widgetWithText(InkWell, digit).first);
  await tester.pump();
}

void main() {
  testWidgets('no system keyboard is used for OTP entry', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(NumberPad), findsOneWidget);
  });

  testWidgets('the title is rendered in the forest theme colour',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final title = tester.widget<Text>(find.text('Enter OTP'));
    expect(title.style?.color, OColors.forest);
  });

  /// Text within the OTP boxes only, excluding the keypad's own digit labels.
  Finder boxText(WidgetTester tester, String value) => find.byWidgetPredicate(
      (w) => w is Text && w.data == value && w.style?.fontWeight == FontWeight.w700);

  testWidgets('digits fill left to right and the cursor advances',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tapDigit(tester, '1');
    expect(boxText(tester, '1'), findsOneWidget);

    await tapDigit(tester, '2');
    await tapDigit(tester, '3');
    expect(boxText(tester, '1'), findsOneWidget);
    expect(boxText(tester, '2'), findsOneWidget);
    expect(boxText(tester, '3'), findsOneWidget);
  });

  testWidgets('backspace moves the cursor back and clears the last digit',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tapDigit(tester, '1');
    await tapDigit(tester, '2');
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(boxText(tester, '2'), findsNothing);
    expect(boxText(tester, '1'), findsOneWidget);
  });

  testWidgets('a dash separates the two groups of three', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('entering the final digit submits automatically',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    for (final digit in '123456'.split('')) {
      await tapDigit(tester, digit);
    }
    // The sixth digit triggers submit() without a Verify tap; the button
    // shows its busy label while the async verify call is in flight.
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Please wait…'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
