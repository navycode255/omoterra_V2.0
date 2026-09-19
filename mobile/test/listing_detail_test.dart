import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/buyer/screens.dart';

Widget host(Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(theme: omoterraTheme(), home: child));

void main() {
  testWidgets(
      'Buy Now sits on its own row below quantity and total, not squeezed beside them',
      (tester) async {
    await tester.pumpWidget(host(const ListingDetail('local-cattle')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final buyNow = tester.getRect(find.widgetWithText(FilledButton, 'Buy Now'));
    final total = tester.getRect(find.text('Order Total'));

    // Buy Now is below the total, not sharing its row — a lower top edge
    // than the total's own top edge is what "its own row underneath" means.
    expect(buyNow.top, greaterThan(total.top));
    // And it spans essentially the full width of the bar now that nothing
    // else shares the row with it.
    expect(buyNow.width, greaterThan(300));
  });

  testWidgets('the sticky bar does not overflow at 320px width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const ListingDetail('local-cattle')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
