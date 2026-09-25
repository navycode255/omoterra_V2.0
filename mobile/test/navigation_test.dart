import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/authentication/screens.dart';
import 'package:omoterra/shared/widgets/components.dart';

Widget harness(Widget child) => ProviderScope(
    overrides: [stringsProvider.overrideWithValue(const Strings('en'))],
    child: MaterialApp(theme: omoterraTheme(), home: child));

void main() {
  testWidgets('onboarding uses the iOS-style chevron, not the Material arrow',
      (tester) async {
    // PhoneScreen is always reached by pushing on top of onboarding, so it
    // always has something to pop back to; a bare `home:` mount (nothing to
    // pop) would be an unrealistic setup and hide the chevron on purpose.
    await tester.pumpWidget(harness(Builder(
        builder: (context) => Scaffold(
            body: Center(
                child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const PhoneScreen())),
                    child: const Text('open')))))));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackChevron), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('the back chevron pops the route', (tester) async {
    await tester.pumpWidget(harness(Builder(
        builder: (context) => Scaffold(
            body: Center(
                child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const PhoneScreen())),
                    child: const Text('open')))))));
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);

    await tester.tap(find.byType(BackChevron));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsNothing);
  });

  testWidgets(
      'OmoterraAppBar shows the chevron once pushed, and hides it at the root',
      (tester) async {
    await tester.pumpWidget(harness(const Scaffold(
        appBar: OmoterraAppBar(title: Text('Root')), body: SizedBox())));
    await tester.pump();
    expect(find.byType(BackChevron), findsNothing);

    await tester.pumpWidget(harness(Builder(
        builder: (context) => Scaffold(
            body: Center(
                child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                                appBar: OmoterraAppBar(title: Text('Pushed')),
                                body: SizedBox()))),
                    child: const Text('open')))))));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackChevron), findsOneWidget);
  });

  testWidgets('a root screen lets the system back gesture leave the app',
      (tester) async {
    await tester.pumpWidget(harness(const ExitOnBack(child: SizedBox())));
    await tester.pump();

    // canPop false here would swallow the gesture and trap the user, which is
    // what the welcome and home screens did before.
    final scope = tester.widget<PopScope>(find.descendant(
        of: find.byType(ExitOnBack), matching: find.byType(PopScope)));
    expect(scope.canPop, isTrue);
  });
}
