import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/authentication/screens.dart';
import 'package:omoterra/shared/widgets/components.dart';

void main() {
  testWidgets('welcome remains usable on a small phone with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: omoterraTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: const WelcomeScreen()));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Get started'), 200);
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('payment failure uses a distinct cancelled tracker',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: omoterraTheme(),
        home: const Scaffold(body: OrderProgress('cancelled'))));
    expect(find.text('●  Cancelled'), findsOneWidget);
    expect(find.text('Delivered'), findsNothing);
  });
}
