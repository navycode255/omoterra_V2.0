import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/order_progress.dart';

class _RecordingRepository extends LocalRepository {
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    calls.add((path, data));
    return {};
  }
}

const _payout = {
  'id': 'pay-1',
  'status': 'paid',
  'total_payable': '27000.00',
  'paid_at': '2026-10-07T08:00:00Z',
  'payment_reference': 'MPESA-1',
  'supplier_confirmation': null,
  'reference': 'A1B2C3D4',
  'order_hold_id': 'hold-1',
};

Widget _host(_RecordingRepository repository, Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
        theme: omoterraTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child))));

void main() {
  testWidgets('confirming a received payout posts the answer', (tester) async {
    final repository = _RecordingRepository();
    await tester
        .pumpWidget(_host(repository, const PayoutConfirmCard(_payout)));
    expect(find.text('Omoterra sent you TZS 27,000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('payout_received')));
    await tester.pumpAndSettle();
    expect(repository.calls.single.$1, '/supplier/payouts/pay-1/confirm');
    expect(repository.calls.single.$2['received'], isTrue);
  });

  testWidgets('reporting not received sends the note', (tester) async {
    final repository = _RecordingRepository();
    await tester
        .pumpWidget(_host(repository, const PayoutConfirmCard(_payout)));
    await tester.tap(find.byKey(const Key('payout_not_received')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('payout_note')), 'Nothing yet');
    await tester.tap(find.text('Report not received'));
    await tester.pumpAndSettle();
    expect(
        repository.calls.single.$2, {'received': false, 'note': 'Nothing yet'});
  });

  testWidgets('a disputed payout only offers "I have now received it"',
      (tester) async {
    await tester.pumpWidget(_host(
        _RecordingRepository(),
        PayoutConfirmCard({..._payout, 'supplier_confirmation': 'not_received'})));
    expect(find.text('I have now received it'), findsOneWidget);
    expect(find.byKey(const Key('payout_not_received')), findsNothing);
  });

  testWidgets('the timeline shows every step with its notes', (tester) async {
    const order = {
      'stage': 'awaiting_buyer_payment',
      'unit_type': 'bird',
      'expected_collection_date': '2026-10-03',
      'accepted_quantity': '38',
      'rejected_quantity': '2',
      'settlements': [],
      'steps': [
        {'key': 'ordered', 'done': true, 'at': '2026-10-01T08:00:00Z'},
        {'key': 'collection_scheduled', 'done': true, 'at': null},
        {'key': 'collected', 'done': true, 'at': '2026-10-03T08:00:00Z'},
        {'key': 'in_transit', 'done': true, 'at': null},
        {'key': 'delivered', 'done': true, 'at': null},
        {'key': 'buyer_paid', 'done': false, 'at': null},
        {'key': 'payout_sent', 'done': false, 'at': null},
        {'key': 'payout_confirmed', 'done': false, 'at': null},
      ],
    };
    await tester.pumpWidget(_host(
        _RecordingRepository(),
        const Column(children: [
          OrderStageText('awaiting_buyer_payment'),
          OrderTimeline(order)
        ])));
    expect(
        find.text('●  Delivered · waiting for buyer payment'), findsOneWidget);
    expect(find.text('Buyer paid Omoterra'), findsOneWidget);
    expect(find.textContaining('38 birds accepted · 2 birds not accepted'),
        findsOneWidget);
  });
}
