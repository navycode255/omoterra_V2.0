import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';

Widget harness() => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(theme: omoterraTheme(), home: const AddStockScreen()));

void main() {
  testWidgets('selecting Eggs shows tray and egg-size fields, not bird specs',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Eggs'));
    await tester.tap(find.text('Eggs'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Quantity (tray)'), findsOneWidget);
    expect(find.text('Tray Size'), findsOneWidget);
    expect(find.text('Egg Size'), findsOneWidget);
    expect(find.text('Expected ready date'), findsOneWidget);

    // Bird-only fields must not leak into the eggs spec set.
    expect(find.text('Breed Type'), findsNothing);
    expect(find.text('Live Or Dressed'), findsNothing);
  });

  testWidgets('tray size options are 12, 24 and 30 eggs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Eggs'));
    await tester.tap(find.text('Eggs'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30 eggs'));
    await tester.pumpAndSettle();
    expect(find.text('12 eggs'), findsOneWidget);
    expect(find.text('24 eggs'), findsOneWidget);
  });
}
