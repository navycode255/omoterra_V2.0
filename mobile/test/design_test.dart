import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/authentication/screens.dart';

/// Renders a screen with a chosen account language so the designed copy and
/// its Swahili translation can both be asserted.
Widget harness(Widget child, {String language = 'en'}) => ProviderScope(
    overrides: [stringsProvider.overrideWithValue(Strings(language))],
    child: MaterialApp(theme: omoterraTheme(), home: child));

void main() {
  testWidgets('welcome uses the designed English copy', (tester) async {
    await tester.pumpWidget(harness(const WelcomeScreen()));
    await tester.pump();
    expect(find.text('Welcome to Omoterra'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('welcome renders in Swahili when the account prefers it',
      (tester) async {
    await tester.pumpWidget(harness(const WelcomeScreen(), language: 'sw'));
    await tester.pump();
    expect(find.text('Karibu Omoterra'), findsOneWidget);
    expect(find.text('Anza Sasa'), findsOneWidget);
    expect(find.text('Tayari nina akaunti'), findsOneWidget);
  });

  testWidgets('phone entry shows the +255 prefix and a masked example',
      (tester) async {
    await tester.pumpWidget(harness(const PhoneScreen()));
    await tester.pump();
    expect(find.text('+255'), findsOneWidget);
    // The placeholder must not look like a real subscriber number.
    expect(find.text('712 *** ***'), findsOneWidget);
  });

  testWidgets('otp screen renders one box per digit', (tester) async {
    await tester.pumpWidget(harness(const OtpScreen({
      'challenge_id': 'test',
      'otp_length': 6,
      'resend_after_seconds': 45,
      'phone': '+255746484666',
    })));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.textContaining('00:45'), findsOneWidget);
  });

  testWidgets('role selection offers both capabilities as cards',
      (tester) async {
    await tester.pumpWidget(harness(const SetupScreen()));
    await tester.pump();
    expect(find.text('How will you use Omoterra?'), findsOneWidget);
    expect(find.text('Buy Supply'), findsOneWidget);
    expect(find.text('Sell Supply'), findsOneWidget);
  });
}
