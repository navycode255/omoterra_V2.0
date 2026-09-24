import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/market_demand_screen.dart';

Widget host(Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(theme: omoterraTheme(), home: Scaffold(body: child)));

void main() {
  test('supplier-only roles can reach demand and buyers cannot', () {
    expect(
        routeGuard('/supplier-demand/1',
            signedIn: true, setup: true, roles: ['supplier']),
        isNull);
    expect(
        routeGuard('/supplier-demand',
            signedIn: true, setup: true, roles: ['buyer']),
        '/buyer');
  });
  testWidgets('demand filters, search and zero matched progress work',
      (tester) async {
    await tester.pumpWidget(host(const MarketDemandScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(DemandCard), findsNWidgets(3));
    final bars = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .toList();
    expect(bars[1].value, 0);
    await tester.tap(find.text('Goats'));
    await tester.pumpAndSettle();
    expect(find.byType(DemandCard), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.tap(find.byTooltip('Search demand'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mbezi');
    await tester.pumpAndSettle();
    expect(find.byType(DemandCard), findsOneWidget);
    expect(find.textContaining('200 Broilers'), findsOneWidget);
    expect(find.textContaining('Monday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offer validates quantity and preview does not claim submission',
      (tester) async {
    final row = Map<String, dynamic>.from(
        await LocalRepository().read('/supplier/demand/preview-demand-1'));
    await tester
        .pumpWidget(host(SingleChildScrollView(child: SupplyOfferForm(row))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Supply'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a quantity within remaining demand'),
        findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '100');
    tester.widget<TextFormField>(fields.at(1)).controller!.text = DateTime.now()
        .add(const Duration(days: 2))
        .toIso8601String()
        .split('T')
        .first;
    await tester.enterText(fields.at(2), '1.9');
    await tester.tap(find.text('Submit Supply'));
    await tester.pumpAndSettle();
    expect(find.text('Supply offer received'), findsNothing);
    expect(find.textContaining('Preview', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('demand detail fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const DemandDetailScreen('preview-demand-1')));
    await tester.pumpAndSettle();
    expect(find.text('500 Broilers'), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
