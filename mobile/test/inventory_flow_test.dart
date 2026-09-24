import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/inventory_screens.dart';

const stock = {
  'id': 'sample',
  'category': 'broilers',
  'unit_type': 'bird',
  'quantity_available': '70',
  'quantity_reserved': '10',
  'quantity_sold': '20',
};

Future<void> showScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: [
    resourceProvider('/supplier/stock/sample')
        .overrideWith((ref) async => stock),
  ], child: MaterialApp(theme: omoterraTheme(), home: screen)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('correction counts on-hand including reserved, excludes sold',
      (tester) async {
    await showScreen(tester, const StockChangeScreen('sample', 'correct'));
    expect(find.text('80'), findsOneWidget);
    expect(find.textContaining('does not record a sale'), findsOneWidget);
    expect(find.text('Quantity sold (bird)'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Save correction to history'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale form explicitly separates external and automatic sales',
      (tester) async {
    await showScreen(tester, const RecordSaleScreen('sample'));
    expect(find.textContaining('automatically when delivered'), findsOneWidget);
    expect(find.text('Quantity sold (bird)'), findsOneWidget);
    expect(find.text('Why was the count incorrect?'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Record sale & deduct stock'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock summary keeps birds and kilograms separate',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: omoterraTheme(),
        home: Scaffold(
            body: StockBalances([
          stock,
          {...stock, 'unit_type': 'kg', 'quantity_available': '5'}
        ]))));
    expect(find.text('70'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('75'), findsNothing);
  });
}
