import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';
import 'package:omoterra/shared/widgets/rating.dart';

class _Recorder extends LocalRepository {
  final writes = <(String, Map<String, dynamic>)>[];
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    writes.add((path, data));
    return {};
  }
}

Widget _host(Widget child, [OmoterraRepository? repository]) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repository ?? LocalRepository())
    ],
    child: MaterialApp(
        theme: omoterraTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child))));

void main() {
  testWidgets('a buyer must pick stars before submitting, then it is sent',
      (tester) async {
    final repository = _Recorder();
    var rated = false;
    await tester.pumpWidget(_host(
        RateOrderCard(
            orderId: 'o1',
            rating: null,
            canRate: true,
            onRated: () => rated = true),
        repository));
    final submit = find.widgetWithText(FilledButton, 'Submit rating');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('4 stars'));
    await tester.pump();
    expect(find.text('Very good'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Good birds');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.writes.single.$1, '/orders/o1/rating');
    expect(repository.writes.single.$2, {'stars': 4, 'comment': 'Good birds'});
    expect(rated, isTrue);
    expect(find.text('Your rating'), findsOneWidget);
  });

  testWidgets('a rating past its edit window shows without an Edit button',
      (tester) async {
    await tester.pumpWidget(_host(RateOrderCard(
        orderId: 'o1',
        rating: const {'stars': 3, 'comment': 'OK'},
        canRate: false,
        onRated: () {})));
    expect(find.text('Your rating'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('new suppliers are labelled new, not given a low score',
      (tester) async {
    await tester.pumpWidget(_host(const Column(children: [
      RatingBadge({'rating': null, 'ratings': 1}),
      RatingBadge({'rating': 4.7, 'ratings': 12}),
      ReputationStrip({'rating': null, 'ratings': 1, 'deliveries': 2}),
    ])));
    expect(find.text('New supplier'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // no quality checks yet
  });

  testWidgets('supplier sees their reviews without who wrote them',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
        child: MaterialApp(
            theme: omoterraTheme(), home: const SupplierReviewsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('4.6 of 5 from 12 buyer ratings'), findsOneWidget);
    expect(find.text('Healthy birds and collected on time.'), findsOneWidget);
  });
}
