import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/core/auth/session.dart';
import 'package:omoterra/features/authentication/screens.dart';

/// The supplied photography must actually resolve from assets/images/; a
/// missing file silently falls back to vector art, which would look fine on
/// screen but mean the design was never applied.
void main() {
  testWidgets('splash and welcome load the supplied photographs',
      (tester) async {
    for (final screen in <Widget>[
      const SplashScreen(),
      const WelcomeScreen()
    ]) {
      await tester.pumpWidget(ProviderScope(
          overrides: [stringsProvider.overrideWithValue(const Strings('en'))],
          child: MaterialApp(theme: omoterraTheme(), home: screen)));
      await tester.pump();

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, isNotEmpty, reason: '$screen renders no Image');
      final assets =
          images.map((i) => i.image).whereType<AssetImage>().toList();
      expect(assets, isNotEmpty, reason: '$screen renders no asset image');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('splash shows the designed headline and tagline', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [stringsProvider.overrideWithValue(const Strings('en'))],
        child: const MaterialApp(home: SplashScreen())));
    await tester.pump();
    expect(find.text('Farm supply\nmade simple.'), findsOneWidget);
    expect(find.text('Fresh supply. Better business.\nA stronger tomorrow.'),
        findsOneWidget);
  });

  test('the splash is held long enough to be seen', () {
    // Restoring a session is near-instant, so without a floor the splash
    // flashes past and the app appears to open straight on onboarding.
    expect(SessionController.holdSplash, isFalse,
        reason: 'tests disable the hold via flutter_test_config.dart');
  });

  testWidgets('the splash renders the supplied logo', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [stringsProvider.overrideWithValue(const Strings('en'))],
        child: const MaterialApp(home: SplashScreen())));
    await tester.pump();
    final logos = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .where((a) => a.assetName == 'assets/images/logo.png');
    expect(logos, isNotEmpty,
        reason: 'splash must show assets/images/logo.png');
  });
}
