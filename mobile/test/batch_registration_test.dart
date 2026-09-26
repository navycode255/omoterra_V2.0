import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/supplier_batch_screen.dart';

class _Supplier extends LocalRepository {
  final Map<String, dynamic>? profile;
  Map<String, dynamic>? sent;
  _Supplier(this.profile);
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async =>
      path == '/supplier/profile' ? profile : super.read(path, query);
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    sent = data;
    return {'id': 'batch-1'};
  }
}

const _profile = {
  'region': 'Pwani',
  'internal_pickup_address': 'Maili Moja farm road',
  'categories': ['broilers'],
};

Future<_Supplier> _open(WidgetTester tester,
    {Map<String, dynamic>? profile = _profile,
    String location = '/batches/new'}) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Supplier(profile);
  final router = GoRouter(initialLocation: '/demand', routes: [
    GoRoute(
        path: '/demand',
        builder: (context, _) => Scaffold(
            body: TextButton(
                onPressed: () => context.push(location),
                child: const Text('open')))),
    GoRoute(path: '/stock', builder: (_, __) => const Text('stock page')),
    GoRoute(
        path: '/batches/new',
        builder: (_, s) => SupplierBatchScreen(
            category: s.uri.queryParameters['category'],
            returnToDemand: s.uri.queryParameters['from'] == 'demand')),
  ]);
  await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _next(WidgetTester tester, String label) async {
  await tester.tap(find.text('Next: $label'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('three steps send a complete batch', (tester) async {
    final repo = await _open(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    // Live birds are always live: no form to choose.
    expect(find.text('Supplied as'), findsNothing);

    await _next(tester, 'Ready date & price');
    expect(find.text('This field is required'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('batch_quantity')), '12.5');
    await _next(tester, 'Ready date & price');
    expect(find.text('Use a whole number'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('batch_quantity')), '1450');
    await tester.enterText(find.byKey(const Key('batch_subtype')), 'Ross 308');
    await tester.enterText(find.byKey(const Key('batch_age')), '24');
    await _next(tester, 'Ready date & price');

    expect(find.text('2 of 3'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('batch_min')), '2.2');
    await tester.enterText(find.byKey(const Key('batch_max')), '1.8');
    await _next(tester, 'Pickup & photos');
    expect(find.text('Max must be at least Min'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('batch_min')), '1.8');
    await tester.enterText(find.byKey(const Key('batch_max')), '2.2');
    await tester.enterText(find.byKey(const Key('batch_price')), '9500');
    await _next(tester, 'Pickup & photos');

    expect(find.text('3 of 3'), findsOneWidget);
    // Filled from the supplier's saved profile.
    expect(find.text('Maili Moja farm road'), findsOneWidget);
    expect(find.text('Pwani'), findsOneWidget);
    await tester.tap(find.text('Register batch'));
    await tester.pumpAndSettle();

    final sent = repo.sent!;
    expect(sent['category'], 'broilers');
    expect(sent['subtype'], 'Ross 308');
    expect(sent['initial_quantity'], '1450');
    expect(sent['current_age'], '24');
    expect(sent['age_unit'], 'weeks');
    expect(sent['form'], 'live');
    expect(sent['expected_min_weight_kg'], '1.8');
    expect(sent['expected_max_weight_kg'], '2.2');
    expect(sent['asking_price_per_unit'], '9500');
    expect(sent['region'], 'Pwani');
    expect(sent['private_pickup_location'], 'Maili Moja farm road');
    expect(DateTime.parse(sent['expected_ready_date']).isAfter(DateTime.now()),
        isTrue);
    expect(find.text('stock page'), findsOneWidget);
  });

  testWidgets('meat is never live and has no weight range', (tester) async {
    final repo = await _open(tester, location: '/batches/new?category=beef');
    expect(find.text('Supplied as'), findsOneWidget);
    expect(find.text('Dressed'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('batch_quantity')), '42.5');
    await _next(tester, 'Ready date & price');
    expect(find.byKey(const Key('batch_min')), findsNothing);
    await _next(tester, 'Pickup & photos');
    await tester.tap(find.text('Register batch'));
    await tester.pumpAndSettle();
    expect(repo.sent!['form'], 'dressed');
    expect(repo.sent!['initial_quantity'], '42.5');
    expect(repo.sent!['expected_min_weight_kg'], isNull);
  });

  testWidgets('opened from a demand, it starts on that product and returns',
      (tester) async {
    await _open(tester, location: '/batches/new?category=goats&from=demand');
    expect(find.text('Goats'), findsWidgets);
    await tester.enterText(find.byKey(const Key('batch_quantity')), '8');
    await _next(tester, 'Ready date & price');
    await _next(tester, 'Pickup & photos');
    await tester.tap(find.text('Register batch'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('stock page'), findsNothing);
  });

  testWidgets('without pickup details those come first', (tester) async {
    await _open(tester, profile: null);
    expect(find.text('Your pickup details first'), findsOneWidget);
    expect(find.text('Save and continue'), findsOneWidget);
  });
}
