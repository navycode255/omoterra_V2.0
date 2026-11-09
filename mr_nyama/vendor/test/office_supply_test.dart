import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';

import 'helpers.dart';
import 'lead_session_test.dart' show LeadApi, LeadOffice, seedLead;
import 'office_delivery_entry_test.dart'
    show ReceivingOffice, addProduct, choose, save;
import 'office_test.dart' show FakeOfficeRepository;
import 'supply_request_test.dart' show request;

class SupplyOffice extends FakeOfficeRepository
    implements OfficeSupplyRepository {
  final waiting = <SupplyRequest>[];
  final own = <SupplyRequest>[];
  final open = <OutstandingAdvance>[];

  /// Every request the server knows, by id (what a read by id finds).
  final all = <String, SupplyRequest>{};
  final calls = <String>[];
  Object? failNext;

  void _maybeFail() {
    if (failNext case final e?) {
      failNext = null;
      throw e;
    }
  }

  @override
  Future<List<SupplyRequest>> waitingSupplyRequests() async => List.of(waiting);
  @override
  Future<List<SupplyRequest>> ownSupplyRequests() async => List.of(own);
  @override
  Future<List<OutstandingAdvance>> officeSupplyOutstanding() async =>
      List.of(open);

  @override
  Future<SupplyRequest> supplyRequestById(String id) async {
    final found = [...waiting, ...own, ...all.values].where((r) => r.id == id);
    if (found.isEmpty) throw const SupplyError('not_found', 404);
    return found.first;
  }

  @override
  Future<List<SupplyRequest>> supplyRequestsByStatus(String status,
      {String? stationId}) async {
    calls.add('status $status ${stationId ?? ''}');
    return [
      for (final r in all.values)
        if (r.status == status &&
            (stationId == null || r.stationId == stationId))
          r
    ];
  }

  @override
  Future<SupplyRequest> decideSupplyRequest(String id,
      {required String clientId,
      required int step,
      required bool approve,
      String? reason}) async {
    _maybeFail();
    calls.add('decide $id $step $approve ${reason ?? ''}');
    return request(id, status: approve ? 'approved' : 'rejected');
  }

  @override
  Future<SupplyRequest> giveSupplyMoney(String id,
      {required String clientId, required int amount}) async {
    calls.add('give $id $amount');
    return request(id,
        status: 'funded', advance: SupplyAdvance(amount: amount));
  }

  @override
  Future<SupplyRequest> confirmSupply(String id,
      {required String clientId, required bool acceptOverspend}) async {
    _maybeFail();
    calls.add('confirm $id $acceptOverspend');
    return request(id, status: 'closed');
  }
}

Future<TestApp> open(WidgetTester tester, SupplyOffice office, String route,
    {StaffProfile? as}) async {
  office.signedIn = true;
  final app = await pumpApp(tester, startAs: StartAs.signedOut, office: office);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(as ?? office.owner);
  await tester.pumpAndSettle();
  app.router.push(route);
  await tester.pumpAndSettle();
  return app;
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

const finance = StaffProfile(
    id: 'f1', name: 'Neema', phone: '+255700000001', roles: ['finance']);
const supervisor = StaffProfile(
    id: 'p1', name: 'Juma', phone: '+255700000002', roles: ['supervisor']);

void main() {
  linkTests();
  testWidgets('owner funds a request approved by someone else after restart',
      (tester) async {
    // Nothing is waiting any more and the app starts fresh: the request is
    // found by its status and opened by its id.
    final office = SupplyOffice()
      ..all['a1'] = request('a1', status: 'approved');
    final app = await open(tester, office, MNRoutes.officeSupplyRequests);
    expect(find.text('Imeidhinishwa — inasubiri fedha'), findsOneWidget);
    await tester.tap(find.textContaining('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeSupplyRequest('a1'));
    await tester.tap(find.text('Toa fedha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toa fedha').last);
    await tester.pumpAndSettle();
    expect(office.calls, contains('give a1 18000'));
    // A pull to refresh does not lose it either.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Ombi halionekani kwenye orodha yako'), findsNothing);
  });

  testWidgets('confirm page shows requested vs received', (tester) async {
    final office = SupplyOffice()
      ..all['p'] = request('p',
          status: 'purchased',
          advance: const SupplyAdvance(amount: 18000, holderId: 'v9'),
          settlement: const SupplySettlement(
              spent: 17000, changeReturned: 1000, supplier: 'Soko'),
          received: 1,
          deliveries: const [
            SupplyDelivery(
                id: 'm1',
                reference: 'DN-1A2B',
                sender: 'Soko',
                status: 'accepted')
          ],
          decided: true);
    await open(tester, office, MNRoutes.officeSupplyRequest('p'), as: finance);
    expect(find.text('Imeombwa: 2 pc · TSh 9,000'), findsOneWidget);
    expect(find.text('Imepokelewa: 1 pc · Tofauti: -1'), findsOneWidget);
    expect(find.textContaining('DN-1A2B'), findsOneWidget);
    expect(find.textContaining('Juma amekubali'), findsOneWidget);
    expect(find.text('Thibitisha matumizi'), findsOneWidget);
  });

  testWidgets('owner sees Toa fedha only when approved', (tester) async {
    final office = SupplyOffice()
      ..open.add(const OutstandingAdvance(
          requestId: 'funded', status: 'funded', amount: 10000))
      ..waiting.add(request('pending', kind: 'final', step: 1))
      ..own.addAll([request('approved', status: 'approved')]);
    // Pending (waiting at the final step): decide, but no money.
    await open(tester, office, MNRoutes.officeSupplyRequest('pending'));
    expect(find.text('Kubali'), findsOneWidget);
    expect(find.text('Toa fedha'), findsNothing);
  });

  testWidgets('owner gives money for an approved request and then not again',
      (tester) async {
    final office = SupplyOffice()
      ..waiting.add(request('r1', kind: 'final', step: 1));
    await open(tester, office, MNRoutes.officeSupplyRequest('r1'));
    expect(find.text('Toa fedha'), findsNothing);
    await tester.tap(find.text('Kubali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kubali').last);
    await tester.pumpAndSettle();
    expect(office.calls, ['decide r1 1 true ']);
    // The server's answer says approved: money can be given now.
    await reveal(tester, find.text('Toa fedha'));
    await tester.tap(find.text('Toa fedha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '12000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toa fedha').last);
    await tester.pumpAndSettle();
    expect(office.calls.last, 'give r1 12000');
    expect(find.text('Fedha zimetolewa'), findsWidgets);
    expect(find.text('Toa fedha'), findsNothing);
  });

  testWidgets('money can only be given to a request that is approved',
      (tester) async {
    final office = SupplyOffice()
      ..all['f'] = request('f',
          status: 'funded', advance: const SupplyAdvance(amount: 5000));
    await open(tester, office, MNRoutes.officeSupplyRequest('f'));
    expect(find.text('Toa fedha'), findsNothing);
    expect(find.text('Thibitisha matumizi'), findsNothing);
  });

  testWidgets('approver does not see own request as decidable', (tester) async {
    final office = SupplyOffice()
      ..own.add(request('mine', kind: 'final', step: 1));
    await open(tester, office, MNRoutes.officeSupplyRequest('mine'));
    expect(find.text('Inasubiri Mmiliki au Fedha'), findsOneWidget);
    expect(find.text('Kubali'), findsNothing);
    expect(find.text('Kataa'), findsNothing);
    expect(find.text('Huwezi kuamua ombi hili'), findsOneWidget);
  });

  testWidgets('a refused decision is explained in Swahili', (tester) async {
    final office = SupplyOffice()
      ..waiting.add(request('r1'))
      ..failNext = const SupplyError('already_decided_other_step', 403);
    await open(tester, office, MNRoutes.officeSupplyRequest('r1'),
        as: supervisor);
    await tester.tap(find.text('Kubali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kubali').last);
    await tester.pumpAndSettle();
    expect(find.text('Umeshaamua hatua nyingine ya ombi hili'), findsOneWidget);
  });

  testWidgets('confirming an overspend needs an explicit acceptance',
      (tester) async {
    final office = SupplyOffice()
      ..all['p'] = request('p',
          status: 'purchased',
          advance: const SupplyAdvance(amount: 10000, holderId: 'v9'),
          settlement: const SupplySettlement(
              spent: 12000, changeReturned: 0, overspend: 2000));
    await open(tester, office, MNRoutes.officeSupplyRequest('p'), as: finance);
    await tester.tap(find.text('Thibitisha matumizi'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(ElevatedButton, 'Thibitisha matumizi');
    expect(find.textContaining('TSh 2,000'), findsWidgets);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thibitisha matumizi').last);
    await tester.pumpAndSettle();
    expect(office.calls, ['confirm p true']);
    expect(confirm, findsNothing);
  });

  testWidgets('outstanding advances with age are on the Fedha page',
      (tester) async {
    final office = SupplyOffice()
      ..open.add(const OutstandingAdvance(
          requestId: 'a',
          status: 'funded',
          amount: 20000,
          ageDays: 3,
          holderName: 'Asha',
          stationName: 'Kariakoo'));
    await open(tester, office, MNRoutes.officeMoney);
    expect(find.text('Fedha za manunuzi zisizofungwa'), findsOneWidget);
    expect(find.textContaining('siku 3'), findsOneWidget);
    expect(find.textContaining('Haijaelezwa'), findsOneWidget);
  });

  testWidgets('waiting requests are listed for the approver', (tester) async {
    final office = SupplyOffice()..waiting.add(request('w1'));
    final app = await open(tester, office, MNRoutes.officeSupplyRequests,
        as: supervisor);
    expect(find.textContaining('Kuku mzima'), findsOneWidget);
    await tester.tap(find.textContaining('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeSupplyRequest('w1'));
  });

  testWidgets('the lead reaches Maombi ya mzigo from Kituo', (tester) async {
    final app = await pumpApp(tester,
        api: LeadApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maombi ya mzigo'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeSupplyRequests);
    expect(
        MNRoutes.isLeadOfficePath(MNRoutes.officeSupplyRequest('x')), isTrue);
  });
}

/// A delivery form whose station can also list supply requests by status.
class LinkOffice extends ReceivingOffice implements OfficeSupplyRepository {
  final byStatus = <String>[];
  final stationAsked = <String?>[];
  final found = <SupplyRequest>[];

  @override
  Future<List<SupplyRequest>> waitingSupplyRequests() async => [];
  @override
  Future<List<SupplyRequest>> ownSupplyRequests() async => [];
  @override
  Future<List<OutstandingAdvance>> officeSupplyOutstanding() async => [];
  @override
  Future<SupplyRequest> supplyRequestById(String id) async =>
      throw const SupplyError('not_found', 404);
  @override
  Future<List<SupplyRequest>> supplyRequestsByStatus(String status,
      {String? stationId}) async {
    byStatus.add(status);
    stationAsked.add(stationId);
    return [
      for (final r in found)
        if (r.status == status) r // the server scopes by station
    ];
  }

  @override
  Future<SupplyRequest> decideSupplyRequest(String id,
          {required String clientId,
          required int step,
          required bool approve,
          String? reason}) async =>
      throw UnimplementedError();
  @override
  Future<SupplyRequest> giveSupplyMoney(String id,
          {required String clientId, required int amount}) async =>
      throw UnimplementedError();
  @override
  Future<SupplyRequest> confirmSupply(String id,
          {required String clientId, required bool acceptOverspend}) async =>
      throw UnimplementedError();
}

void linkTests() {
  testWidgets("lead links delivery to a seller's funded request",
      (tester) async {
    final office = LinkOffice()
      ..found.addAll([
        request('f1',
            status: 'funded', advance: const SupplyAdvance(amount: 18000)),
        request('c1', status: 'closed'),
        request('p1', status: 'purchased'),
      ]);
    final app =
        await pumpApp(tester, office: office, startAs: StartAs.signedOut);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(supervisor);
    app.router.go(MNRoutes.officeStock('s1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ongeza').last);
    await tester.tap(find.text('Ongeza').last);
    await tester.pumpAndSettle();
    await choose(tester, 0, 'Manunuzi kutoka kwa msambazaji');
    await tester.enterText(find.byType(TextField).at(1), 'Msambazaji');
    await tester.enterText(find.byType(TextField).at(2), 'AGR-22');
    await choose(tester, 1, 'Baada ya kuthibitisha kupokea');
    // The picker lists this station's funded, bought and closed requests.
    expect(office.byStatus.toSet(), {'funded', 'purchased', 'closed'});
    expect(office.stationAsked.toSet(), {'s1'});
    final picker = find.byType(MNSelectField<String>).at(2);
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.textContaining('Fedha zimetolewa'), findsOneWidget);
    expect(find.textContaining('Imenunuliwa'), findsOneWidget);
    expect(find.textContaining('Imekamilika'), findsOneWidget);
    await tester.tap(find.textContaining('Fedha zimetolewa'));
    await tester.pumpAndSettle();
    await addProduct(tester, 'Kuku mzima', 4);
    await tester.enterText(find.byType(TextField).at(3), '6000');
    await save(tester);
    expect(office.requests.single['supply_request_id'], 'f1');
  });
}
