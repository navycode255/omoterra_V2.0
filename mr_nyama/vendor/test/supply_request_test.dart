import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/supply_requests.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/notifications/notifications_state.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';

SupplyRequest request(String id,
        {String status = 'pending',
        int step = 0,
        String kind = 'station',
        SupplyAdvance? advance,
        SupplySettlement? settlement,
        num? received,
        List<SupplyDelivery> deliveries = const [],
        bool decided = false}) =>
    SupplyRequest(
        id: id,
        stationId: 'st1',
        stationName: 'Kariakoo',
        status: status,
        currentStep: step,
        estimatedTotal: 18000,
        neededBy: '2026-11-10',
        steps: [
          SupplyStep(
              index: 0,
              kind: kind,
              approve: decided ? true : null,
              decidedBy: decided ? 'Juma' : null),
          const SupplyStep(index: 1, kind: 'final'),
        ],
        lines: [
          SupplyLine(
              id: 'l1',
              productId: 'kuku',
              productName: 'Kuku mzima',
              quantity: 2,
              unit: 'pc',
              estimatedUnitPrice: 9000,
              received: received,
              difference: received == null ? null : received - 2)
        ],
        deliveries: deliveries,
        settlement: settlement,
        advance: advance);

class SupplyApi extends FakeVendorRepository implements VendorSupplyRepository {
  final requests = <SupplyRequest>[];
  final outstanding = <OutstandingAdvance>[];
  final sent = <SupplyDraft>[];
  final settled = <String>[];
  Object? failNext;

  @override
  Future<SupplyRequest> createSupplyRequest(
      String token, SupplyDraft draft) async {
    sent.add(draft);
    if (failNext case final e?) {
      failNext = null;
      throw e;
    }
    final made = request('new');
    requests.insert(0, made);
    return made;
  }

  @override
  Future<List<SupplyRequest>> supplyRequests(String token) async =>
      List.of(requests);

  @override
  Future<SupplyRequest> supplyRequestById(String token, String id) async =>
      requests.firstWhere((r) => r.id == id);

  @override
  Future<SupplyRequest> withdrawSupplyRequest(String token, String id,
          {required String clientId}) async =>
      request(id, status: 'withdrawn');

  @override
  Future<SupplyRequest> settleSupply(String token, String id,
      {required String clientId,
      required int spent,
      required int changeReturned,
      required String supplier}) async {
    settled.add('$id $spent $changeReturned $supplier');
    outstanding.clear();
    return request(id, status: 'purchased');
  }

  @override
  Future<List<OutstandingAdvance>> supplyOutstanding(String token) async =>
      List.of(outstanding);
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('seller sees Omba mzigo row', (tester) async {
    final app = await pumpApp(tester, api: SupplyApi());
    await tester.pumpAndSettle();
    expect(find.text('Omba mzigo', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Omba mzigo'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.supplyRequests);
    expect(find.text('Hakuna maombi bado'), findsOneWidget);
  });

  testWidgets('form uses select sheet and stepper (no OS picker)',
      (tester) async {
    final api = SupplyApi()..catalogSnapshot = testCatalog;
    await pumpApp(tester, api: api, initial: MNRoutes.supplyRequestNew);
    // The product is chosen in the themed sheet, not a dropdown.
    await tester.tap(find.byType(MNFieldButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Bidhaa nyingine (andika)'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    await tester.tap(find.text('Bidhaa nyingine (andika)'));
    await tester.pumpAndSettle();
    expect(find.text('Idadi'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Ongeza')), findsWidgets);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(DropdownMenu<String>), findsNothing);
    await reveal(tester, find.text('Inahitajika tarehe'));
    await tester.tap(find.byType(MNFieldButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(MNSheet), findsWidgets);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('failed send keeps draft and client id', (tester) async {
    final api = SupplyApi()
      ..failNext = const AuthFailure(AuthFailureKind.offline);
    final app =
        await pumpApp(tester, api: api, initial: MNRoutes.supplyRequestNew);
    await tester.tap(find.byType(MNFieldButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bidhaa nyingine (andika)'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mkaa');
    await tester.enterText(fields.at(1), 'gunia');
    await tester.enterText(fields.at(2), '5000');
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Tuma ombi'));
    await tester.tap(find.text('Tuma ombi'));
    await tester.pumpAndSettle();
    expect(api.sent, hasLength(1));
    expect(find.text('Haijatumwa — jaribu tena'), findsOneWidget);
    expect(app.router.state.uri.path, MNRoutes.supplyRequestNew);
    expect(find.text('Mkaa'), findsOneWidget); // the draft is still there
    await reveal(tester, find.text('Tuma ombi'));
    await tester.tap(find.text('Tuma ombi'));
    await tester.pumpAndSettle();
    expect(api.sent, hasLength(2));
    expect(api.sent[1].clientId, api.sent[0].clientId);
    expect(api.sent[1].toJson()['lines'], api.sent[0].toJson()['lines']);
    // Sent: the form closes.
    expect(app.router.state.uri.path, MNRoutes.supplyRequests);
  });

  testWidgets('status shows who it waits for', (tester) async {
    final api = SupplyApi()
      ..requests.addAll([
        request('a'),
        request('b', step: 1, kind: 'final'),
        request('c', status: 'approved'),
        request('d', status: 'rejected'),
        request('e', status: 'withdrawn'),
        request('f', status: 'closed'),
      ]);
    await pumpApp(tester, api: api, initial: MNRoutes.supplyRequests);
    expect(find.text('Inasubiri msimamizi wa kituo au Kiongozi wa Kituo'),
        findsOneWidget);
    // Not stage two or three until the server says so.
    final texts = [
      'Inasubiri Mmiliki au Fedha',
      'Imeidhinishwa',
      'Imekataliwa',
      'Imeondolewa',
      'Imekamilika',
    ];
    for (final t in texts) {
      await tester.scrollUntilVisible(find.text(t), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('holder sees Eleza matumizi until closed', (tester) async {
    final api = SupplyApi()
      ..requests.add(request('a',
          status: 'funded', advance: const SupplyAdvance(amount: 20000)))
      ..outstanding.add(const OutstandingAdvance(
          requestId: 'a', status: 'funded', amount: 20000));
    final app = await pumpApp(tester, api: api);
    await tester.pumpAndSettle();
    expect(find.text('Fedha za manunuzi: TZS 20,000 hazijaelezwa'),
        findsOneWidget);
    expect(find.text('Eleza matumizi'), findsOneWidget);
    await tester.tap(find.text('Eleza matumizi'));
    await tester.pumpAndSettle();
    expect(find.byType(MNSheet), findsWidgets);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '15000');
    await tester.enterText(fields.at(1), '1000');
    await tester.enterText(fields.at(2), 'Soko');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuma matumizi'));
    await tester.pumpAndSettle();
    // 15,000 + 1,000 is not 20,000: nothing was sent.
    expect(api.settled, isEmpty);
    expect(find.textContaining('TSh 20,000'), findsWidgets);
    await tester.enterText(fields.at(1), '5000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuma matumizi'));
    await tester.pumpAndSettle();
    expect(api.settled, ['a 15000 5000 Soko']);
    // Explained: no longer held.
    expect(find.text('Eleza matumizi'), findsNothing);
    expect(app.router.state.uri.path, MNRoutes.home);
  });

  test('every supply notice opens the right request page', () {
    const office = {
      'supply_request_waiting': '/ofisi/maombi-ya-mzigo/r1',
      'supply_request_funding': '/ofisi/maombi-ya-mzigo/r1',
      'supply_settlement_recorded': '/ofisi/maombi-ya-mzigo/r1',
    };
    office.forEach((kind, route) =>
        expect(supplyNotificationRoute(kind, 'r1', office: true), route));
    for (final kind in [
      'supply_request_step_approved',
      'supply_request_approved',
      'supply_request_rejected',
      'supply_advance_given',
      'supply_settlement_confirmed',
    ]) {
      expect(supplyNotificationRoute(kind, 'r1', office: false),
          '/maombi-ya-mzigo/r1',
          reason: kind);
    }
    expect(supplyNotificationRoute('sale_voided', 'r1', office: false), isNull);
  });
}
