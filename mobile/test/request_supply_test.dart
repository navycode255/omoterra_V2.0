import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/buyer/screens.dart';

class _Recorder extends LocalRepository {
  Map<String, dynamic>? sent;
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    sent = data;
    return {'id': 'req-1'};
  }
}

Future<_Recorder> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _Recorder();
  final router = GoRouter(initialLocation: '/request', routes: [
    GoRoute(path: '/request', builder: (_, __) => const RequestSupplyScreen()),
    GoRoute(
        path: '/request-submitted/:id',
        builder: (_, s) => Text('submitted ${s.pathParameters['id']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('step 1 needs a quantity before going on', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Next: Delivery Details'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsOneWidget);
    expect(find.text('2 of 2'), findsNothing);
  });

  testWidgets('max weight below min is caught on step 1', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('request_quantity')), '500');
    await tester.enterText(find.byKey(const Key('request_min')), '2.5');
    await tester.enterText(find.byKey(const Key('request_max')), '1.8');
    await tester.tap(find.text('Next: Delivery Details'));
    await tester.pumpAndSettle();
    expect(find.text('Max must be at least Min'), findsOneWidget);
  });

  testWidgets('two steps send exactly what the backend accepts',
      (tester) async {
    final repository = await _open(tester);
    await tester.enterText(find.byKey(const Key('request_quantity')), '500');
    await tester.tap(find.text('Next: Delivery Details'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    final sent = repository.sent!;
    expect(sent['category'], 'broilers');
    expect(sent['unit_type'], 'bird');
    expect(sent['quantity'], '500');
    // Blank optional numbers go as nothing, not '' (which the API rejects).
    expect(sent['minimum_weight_kg'], isNull);
    expect(sent['maximum_weight_kg'], isNull);
    expect(sent['delivery_region'], 'Dar es Salaam');
    expect(sent['delivery_area'], 'Kinondoni');
    expect(sent['requirement_type'], 'one_time');
    expect(sent['recurrence_frequency'], '');
    expect(sent['preferred_weekdays'], isEmpty);
    expect(
        DateTime.parse(sent['needed_by_date'] as String)
            .isAfter(DateTime.now()),
        isTrue);
    expect(find.text('submitted req-1'), findsOneWidget);
  });

  testWidgets('clearing the date blocks submitting', (tester) async {
    final repository = await _open(tester);
    await tester.enterText(find.byKey(const Key('request_quantity')), '500');
    await tester.tap(find.text('Next: Delivery Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear date'));
    await tester.pump();
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a date'), findsWidgets);
    expect(repository.sent, isNull);
  });
}
