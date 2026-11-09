import 'package:flutter/material.dart' show ListView;
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/lead_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';

import 'helpers.dart';
import 'lead_session_test.dart' show LeadApi, LeadOffice, seedLead;

const _rows = [
  'Pokea fedha ya muuzaji',
  'Pokea mzigo',
  'Stoo ya kituo',
  'Matumizi',
  'Uharibifu wa kuhakiki',
  'Hesabu za kufunga',
];

Future<void> _reveal(WidgetTester tester, String label) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -500));
  await tester.pumpAndSettle();
  expect(find.text(label), findsOneWidget);
}

void main() {
  testWidgets('plain seller sees no Kituo section', (tester) async {
    await pumpApp(tester, api: LeadApi(), office: LeadOffice());
    await tester.pumpAndSettle();
    expect(find.text('Kituo'), findsNothing);
    expect(find.text('Pokea fedha ya muuzaji'), findsNothing);
  });

  testWidgets('lead sees the rows in order', (tester) async {
    await pumpApp(tester,
        api: LeadApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    expect(find.text('Kituo'), findsOneWidget);
    var last = -1.0;
    for (final label in _rows) {
      final f = find.text(label, skipOffstage: false);
      expect(f, findsOneWidget, reason: label);
      final y = tester.getTopLeft(f).dy;
      expect(y, greaterThan(last), reason: label);
      last = y;
    }
  });

  testWidgets('tapping Pokea fedha opens the handovers page', (tester) async {
    final app = await pumpApp(tester,
        api: LeadApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    await _reveal(tester, 'Pokea fedha ya muuzaji');
    await tester.tap(find.text('Pokea fedha ya muuzaji'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeMoneyStation('st1'));
    expect(app.router.state.uri.queryParameters['section'], isNull);
  });

  testWidgets('Matumizi opens the expenses section of the same page',
      (tester) async {
    final app = await pumpApp(tester,
        api: LeadApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    await _reveal(tester, 'Matumizi');
    await tester.tap(find.text('Matumizi'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeMoneyStation('st1'));
    expect(app.router.state.uri.queryParameters['section'], 'expenses');
  });

  testWidgets('no verification row for the lead', (tester) async {
    await pumpApp(tester,
        api: LeadApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    expect(find.text('Kuhakiki mauzo', skipOffstage: false), findsNothing);
    expect(find.textContaining('Thibitisha mauzo', skipOffstage: false),
        findsNothing);
  });

  testWidgets('offline: rows shown, page shows load error', (tester) async {
    final office = _OfflineOffice();
    final app = await pumpApp(tester,
        api: _SupervisorApi(), office: office, seed: seedLead);
    await tester.pumpAndSettle();
    expect(find.text('Kituo'), findsOneWidget);
    await _reveal(tester, 'Pokea fedha ya muuzaji');
    await tester.tap(find.text('Pokea fedha ya muuzaji'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeMoneyStation('st1'));
    expect(find.text('Hakuna intaneti'), findsOneWidget);
  });
  const routes = [
    ('Pokea fedha ya muuzaji', '/ofisi/fedha/st1', null),
    ('Pokea mzigo', '/ofisi/stoo/st1', 'deliveries'),
    ('Stoo ya kituo', '/ofisi/stoo/st1', null),
    ('Matumizi', '/ofisi/fedha/st1', 'expenses'),
    ('Uharibifu wa kuhakiki', '/ofisi/uthibitisho/st1', 'damage'),
    ('Hesabu za kufunga', '/ofisi/uthibitisho/st1/siku-zisizofungwa', null),
    ('Mali za biashara', '/ofisi/mali', null),
  ];
  for (final (label, path, section) in routes) {
    testWidgets('row $label opens $path section $section', (tester) async {
      final app = await pumpApp(tester,
          api: _SupervisorApi(), office: LeadOffice(), seed: seedLead);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, path);
      expect(app.router.state.uri.queryParameters['section'], section);
      expect(MNRoutes.isLeadOfficePath(app.router.state.uri.path), isTrue);
    });
  }
  testWidgets('Mali row opens /ofisi/mali with his station', (tester) async {
    final app = await pumpApp(tester,
        api: _SupervisorApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mali za biashara'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeAssets);
    expect(app.router.state.uri.queryParameters['station'], 'st1');
  });
  testWidgets('Uharibifu opens with the Damage section selected',
      (tester) async {
    await pumpApp(tester,
        api: _SupervisorApi(), office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uharibifu wa kuhakiki'));
    await tester.pumpAndSettle();
    expect(find.text('Hakuna ripoti za uharibifu zinazosubiri'), findsOneWidget);
  });
}

class _OfflineOffice extends LeadOffice {
  @override
  Future<List<OfficeMoneyDay>> moneyDays(
          {required String stationId, required String businessDate}) async =>
      throw const AuthFailure(AuthFailureKind.offline);
}

/// The linked staff account of a real lead is a supervisor.
class _SupervisorApi extends LeadApi {
  @override
  Future<LeadSession> leadSession(String token) async => const LeadSession(
      tokens: {'access_token': 'lead-a', 'refresh_token': 'lead-r'},
      profile: StaffProfile(
          id: 's1', name: 'Asha (ofisi)', phone: '', roles: ['supervisor']));
}
