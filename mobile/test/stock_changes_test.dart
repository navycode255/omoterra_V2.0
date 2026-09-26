import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';

class _Stock extends LocalRepository {
  String status = 'changes_requested';
  final sent = <Map<String, dynamic>>[];
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/stock/s1') {
      return {
        'id': 's1',
        'category': 'broilers',
        'unit_type': 'bird',
        'listing_status': status,
        'review_note': 'Add a clearer photo of the birds',
        'approved': false,
        'photos': <String>[],
        'specs': <String, dynamic>{},
        'region': 'Pwani',
        'quantity_total': '10',
        'quantity_reserved': '0',
        'quantity_sold': '0',
        'quantity_available': '10',
        'farmer_asking_price_per_unit': '9000',
      };
    }
    return super.read(path, query);
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    sent.add(data);
    status = 'pending_review';
    return {'id': 's1'};
  }
}

void main() {
  testWidgets('the supplier sees what to change and sends the stock back',
      (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Stock();
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            theme: omoterraTheme(), home: const StockDetail('s1'))));
    await tester.pumpAndSettle();
    expect(find.text('Omoterra asked for changes'), findsOneWidget);
    expect(find.text('Add a clearer photo of the birds'), findsOneWidget);
    // Unapproved stock can't be confirmed or paused.
    expect(find.text('Confirm availability'), findsNothing);

    await tester.tap(find.text('Send back for review'));
    await tester.pumpAndSettle();
    expect(repo.sent.single['action'], 'resubmit');
    expect(find.text('Omoterra asked for changes'), findsNothing);
  });
}
