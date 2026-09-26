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

/// A date [days] from today, as the API sends it.
String day(int days) =>
    DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;

final demand = <String, dynamic>{
  'id': 'demand-1',
  'category': 'broilers',
  'unit_type': 'bird',
  'quantity': '20',
  'secured_quantity': '0',
  'remaining_quantity': '20',
  'needed_by_date': day(2),
  'requirement_type': 'recurring',
  'recurrence_frequency': 'monthly',
};
final batch = <String, dynamic>{
  'id': 'br024abc',
  'category': 'broilers',
  'status': 'growing',
  'available_to_commit': '48',
  'expected_ready_date': day(1),
  'expected_min_weight_kg': '0.85',
  'expected_max_weight_kg': '0.99',
  'asking_price_per_unit': '9500.00',
};

class _Batches extends LocalRepository {
  final List<Map<String, dynamic>> batches;
  Map<String, dynamic>? sent;
  _Batches(this.batches);
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async =>
      path == '/supplier/batches' ? batches : super.read(path, query);
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    sent = data;
    return {'id': 'offer-1'};
  }
}

Widget offerHost(OmoterraRepository repo) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
        theme: omoterraTheme(),
        home: Scaffold(
            body: SingleChildScrollView(child: SupplyOfferForm(demand)))));

String field(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

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
  testWidgets('without an offerable batch only the way to add one is shown',
      (tester) async {
    await tester.pumpWidget(offerHost(_Batches([])));
    await tester.pumpAndSettle();
    expect(find.text('Register a production batch first'), findsOneWidget);
    expect(find.text('Register production batch'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Submit offer'), findsNothing);
    expect(find.text('Please wait…'), findsNothing);
  });

  testWidgets('a batch not ready by the deadline cannot back an offer',
      (tester) async {
    await tester.pumpWidget(offerHost(_Batches([
      {...batch, 'expected_ready_date': day(30)}
    ])));
    await tester.pumpAndSettle();
    expect(find.text('No batch ready in time'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('the offer is filled from the batch and sent as edited',
      (tester) async {
    final repo = _Batches([batch]);
    await tester.pumpWidget(offerHost(repo));
    await tester.pumpAndSettle();
    expect(find.text('48 birds'), findsOneWidget);
    // Prefilled: all 20 still needed, the batch's date, its average weight
    // and asking price.
    expect(field(tester, 'offer_quantity'), '20');
    expect(field(tester, 'offer_weight'), '0.92');
    expect(field(tester, 'offer_price'), '9500');
    expect(find.text('Submit offer'), findsOneWidget);
    expect(find.text('Please wait…'), findsNothing);

    await tester.enterText(find.byKey(const Key('offer_quantity')), '25');
    await tester.tap(find.text('Submit offer'));
    await tester.pumpAndSettle();
    expect(find.text('Only 20 birds still needed'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('offer_quantity')), '15');
    await tester.tap(find.text('Submit offer'));
    await tester.pumpAndSettle();
    expect(repo.sent!['batch_id'], 'br024abc');
    expect(repo.sent!['offered_quantity'], '15');
    expect(repo.sent!['expected_ready_date'], day(1));
    expect(repo.sent!['expected_min_weight_kg'], 0.92);
    expect(find.text('Supply offer received'), findsOneWidget);
  });

  testWidgets(
      'recurring demand explains the current cycle behind the info icon',
      (tester) async {
    await tester.pumpWidget(offerHost(_Batches([batch])));
    await tester.pumpAndSettle();
    expect(find.textContaining('reserved only after'), findsNothing);
    await tester.tap(find.byTooltip('About offers'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reserved only after'), findsOneWidget);
    expect(find.textContaining('current cycle only'), findsOneWidget);
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
