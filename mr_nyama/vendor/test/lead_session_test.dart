import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/lead_session.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';

import 'package:mr_nyama_vendor/core/api/push.dart';
import 'package:mr_nyama_vendor/core/push/push_client.dart';
import 'package:mr_nyama_vendor/features/notifications/notifications_state.dart';

import 'helpers.dart';
import 'notifications_test.dart' show NotifyingOffice, note;
import 'push_test.dart' show FakePush, PushVendor;
import 'office_test.dart' show FakeOfficeRepository;

const _leadProfile = VendorProfile(
    id: 'v1',
    name: 'Asha Mussa',
    phone: '+255712345678',
    station: 'Kariakoo',
    stationKey: 'S1',
    outletLead: OutletLeadLink(stationId: 'st1', staffId: 's1'));

class LeadApi extends FakeVendorRepository implements VendorLeadRepository {
  AuthFailure? leadFailure;
  int leadCalls = 0;

  @override
  Future<LeadSession> leadSession(String token) async {
    leadCalls++;
    if (leadFailure case final failure?) throw failure;
    return const LeadSession(
        tokens: {'access_token': 'lead-a', 'refresh_token': 'lead-r'},
        profile: StaffProfile(
            id: 's1', name: 'Asha (ofisi)', phone: '', roles: ['cashier']));
  }
}

class LeadOffice extends FakeOfficeRepository implements OfficeLeadRepository {
  final adopted = <Map<String, dynamic>>[];
  int signOuts = 0;
  int deviceKeys = 0;

  @override
  Future<void> keepLeadTokens(Map<String, dynamic> tokens) async {
    adopted.add(tokens);
    signedIn = true;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    signedIn = false;
  }
}

class FeedLeadApi extends PushVendor implements VendorLeadRepository {
  @override
  Future<LeadSession> leadSession(String token) async => const LeadSession(
      tokens: {'access_token': 'lead-a', 'refresh_token': 'lead-r'},
      profile: StaffProfile(id: 's1', name: 'Asha', phone: '', roles: []));
}

class FeedLeadOffice extends NotifyingOffice
    implements OfficeLeadRepository, OfficePushRepository {
  final pushed = <String>[];
  @override
  Future<void> keepLeadTokens(Map<String, dynamic> tokens) async =>
      signedIn = true;
  @override
  Future<void> registerPushToken(String token, {required String lang}) async =>
      pushed.add(token);
}

void seedLead(InMemoryStore store) {
  store.values['session_profile'] = jsonEncode(_leadProfile.toJson());
}

void main() {
  testWidgets('a seller who is an Outlet Lead gets the lead office session',
      (tester) async {
    final api = LeadApi();
    final office = LeadOffice();
    final app = await pumpApp(tester,
        api: api, office: office, seed: seedLead);
    await tester.pumpAndSettle();
    expect(api.leadCalls, 1);
    final state = app.container.read(officeSessionProvider).valueOrNull;
    expect(state, isA<OfficeSignedIn>());
    expect((state as OfficeSignedIn).viaLead, isTrue);
    expect(office.adopted.single['access_token'], 'lead-a');
    // Never a fingerprint key, never the "last side".
    expect(app.store.values.keys.where((k) => k.contains('device_sign_in')),
        isNot(contains('device_sign_in_staff')));
    expect(app.store.values['device_sign_in_last_side'] ?? 'vendor',
        isNot('staff'));
    expect(app.router.state.uri.path, MNRoutes.home);
  });

  testWidgets('a seller who is not a lead never asks for one', (tester) async {
    final api = LeadApi();
    final office = LeadOffice();
    final app = await pumpApp(tester, api: api, office: office);
    expect(api.leadCalls, 0);
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedOut>());
  });

  testWidgets('lead session failure keeps seller home usable', (tester) async {
    final api = LeadApi()
      ..leadFailure = const AuthFailure(AuthFailureKind.offline);
    final office = LeadOffice();
    final app = await pumpApp(tester,
        api: api, office: office, seed: seedLead);
    await tester.pumpAndSettle();
    expect(api.leadCalls, 1);
    expect(app.router.state.uri.path, MNRoutes.home);
    expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedOut>());
    expect(find.textContaining('Imeshindwa'), findsNothing);
    expect(find.textContaining('Hitilafu'), findsNothing);
  });

  testWidgets('a refused lead session (not a lead) is also silent',
      (tester) async {
    final api = LeadApi()
      ..leadFailure = const AuthFailure(AuthFailureKind.suspended);
    final app = await pumpApp(tester,
        api: api, office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
  });

  testWidgets('vendor sign-out clears lead office session', (tester) async {
    final api = LeadApi();
    final office = LeadOffice();
    final app = await pumpApp(tester,
        api: api, office: office, seed: seedLead);
    await tester.pumpAndSettle();
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedIn>());
    await app.container.read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedOut>());
    expect(office.signOuts, 1);
    expect(app.router.state.uri.path, MNRoutes.login);
  });

  testWidgets('a lead session survives the lock but opens no page while locked',
      (tester) async {
    final api = LeadApi();
    final app = await pumpApp(tester,
        api: api, office: LeadOffice(), seed: seedLead);
    await tester.pumpAndSettle();
    await app.container.read(sessionProvider.notifier).lockForPin();
    await tester.pumpAndSettle();
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedIn>());
    app.router.go(MNRoutes.officeStock('st1'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.pin);
  });

  testWidgets('lead session keeps seller bell and seller push registration',
      (tester) async {
    final api = FeedLeadApi()..notificationList.add(note('v1'));
    final office = FeedLeadOffice()..list.add(note('s1', title: 'Ofisi'));
    final app = await pumpApp(tester,
        api: api,
        office: office,
        seed: seedLead,
        overrides: [pushClientProvider.overrideWithValue(FakePush())]);
    await tester.pumpAndSettle();
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedIn>());
    final page = await app.container.read(notificationsProvider.future);
    expect([for (final n in page.items) n.id], ['v1']);
    expect(api.registered, ['token-1/sw']);
    expect(office.pushed, isEmpty);
  });
}
