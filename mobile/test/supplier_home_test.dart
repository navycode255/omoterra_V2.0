import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';
import 'package:omoterra/shared/widgets/components.dart';

Widget host(Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(
        theme: omoterraTheme(), home: Scaffold(body: child)));

void main() {
  testWidgets('supplier home shows the banner greeting and a live stock row',
      (tester) async {
    await tester.pumpWidget(host(const SupplierHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.textContaining('Good morning'), findsOneWidget);
    // Broilers is 'live' in the preview fixtures; its dot must render green,
    // not the generic grey a status without a dedicated colour gets.
    final live = tester.widget<StatusText>(find.byType(StatusText).first);
    expect(live.status, 'live');
    final text = tester.widget<Text>(find.descendant(
        of: find.byWidget(live), matching: find.byType(Text)));
    expect(text.style?.color, OColors.positive);
  });

  testWidgets(
      'the stock card has a photo, status dot and an overflow menu, not just text',
      (tester) async {
    await tester.pumpWidget(host(const StockScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.byIcon(Icons.more_horiz), findsWidgets);
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('Correct stock count'), findsOneWidget);
    expect(find.text('Add stock received'), findsOneWidget);
  });

  testWidgets('the top nav is transparent over the banner on Supplier Home',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
        child: MaterialApp(
            theme: omoterraTheme(),
            home: const AppShell(path: '/supplier', child: SupplierHome()))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBodyBehindAppBar, isTrue);
  });

  testWidgets(
      'the stats card column headers render in full, not truncated, and columns have dividers',
      (tester) async {
    await tester.pumpWidget(host(const SupplierHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Reserved'), findsOneWidget);
    expect(find.text('Sold'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsWidgets);
  });

  testWidgets('the bottom nav is four plain tabs with Orders in its own slot',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
        child: MaterialApp(
            theme: omoterraTheme(),
            home:
                const AppShell(path: '/supplier', child: SupplierHome()))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    // No raised circular centre button any more — the four tabs sit in a
    // plain rounded bar.
    expect(
        find.byWidgetPredicate(
            (w) => w is Material && w.shape is CircleBorder),
        findsNothing);
  });
}
