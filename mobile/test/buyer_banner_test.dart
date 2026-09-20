import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/buyer/screens.dart';

Widget host(Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(
        theme: omoterraTheme(), home: Scaffold(body: child)));

void main() {
  testWidgets('the banner carries no overlaid text or button of its own',
      (tester) async {
    await tester.pumpWidget(host(const BuyerHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    // Each slide's artwork has its headline and call to action baked in, so
    // the card must not draw its own on top of them.
    expect(find.text('Explore Now'), findsNothing);
    expect(find.text('Buy Supply'), findsNothing);
  });

  testWidgets('the banner image fills the card at its native 8:3 ratio',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const BuyerHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final ratio = tester.getSize(find.byType(AspectRatio).first);
    // The three banner assets are all authored at 2048x768, so the card's
    // box must match that or cover() silently crops the baked-in text.
    expect(ratio.width / ratio.height, closeTo(8 / 3, 0.01));
  });
}
