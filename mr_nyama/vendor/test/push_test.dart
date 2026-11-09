import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/push.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/push/push_client.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/notifications/notifications_state.dart';

import 'helpers.dart';
import 'notifications_test.dart' show NotifyingOffice, note;

class FakePush implements PushClient {
  String? current = 'token-1';
  int deleted = 0;
  PushTap? initial;
  final refresh = StreamController<String>.broadcast();
  final arrive = StreamController<void>.broadcast();
  final tap = StreamController<PushTap>.broadcast();
  @override
  Future<String?> token() async => current;
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<void> get received => arrive.stream;
  @override
  Stream<PushTap> get tapped => tap.stream;
  @override
  Future<PushTap?> initialTap() async => initial;
  @override
  Future<void> deleteToken() async => deleted++;
}

class PushVendor extends FakeVendorRepository implements VendorPushRepository {
  final registered = <String>[];
  bool down = false;
  @override
  Future<void> registerPushToken(String token, {required String lang}) async {
    if (down) throw StateError('offline');
    registered.add('$token/$lang');
  }
}

class PushOffice extends NotifyingOffice implements OfficePushRepository {
  final registered = <String>[];
  @override
  Future<void> registerPushToken(String token, {required String lang}) async =>
      registered.add('$token/$lang');
}

Future<TestApp> vendorApp(WidgetTester tester, FakePush push, PushVendor api,
        {StartAs startAs = StartAs.signedIn}) =>
    pumpApp(tester,
        api: api,
        startAs: startAs,
        overrides: [pushClientProvider.overrideWithValue(push)]);

void main() {
  testWidgets('a signed-in vendor registers once, in the app language',
      (tester) async {
    final api = PushVendor();
    final app = await vendorApp(tester, FakePush(), api);
    expect(api.registered, ['token-1/sw']);
    app.container.read(languageProvider.notifier).state = 'en';
    await tester.pumpAndSettle();
    expect(api.registered, ['token-1/sw', 'token-1/en']);
  });

  testWidgets('a new token from Firebase is registered', (tester) async {
    final api = PushVendor();
    final push = FakePush();
    await vendorApp(tester, push, api);
    push.current = 'token-2';
    push.refresh.add('token-2');
    await tester.pumpAndSettle();
    expect(api.registered.last, 'token-2/sw');
  });

  testWidgets('signing out ends the token; signing in registers again',
      (tester) async {
    final api = PushVendor();
    final push = FakePush();
    final app = await vendorApp(tester, push, api);
    await app.container.read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(push.deleted, 1);
    await app.container
        .read(sessionProvider.notifier)
        .signIn(testProfile.phone, api.pin);
    await tester.pumpAndSettle();
    expect(api.registered, ['token-1/sw', 'token-1/sw']);
  });

  testWidgets('a phone locked for inactivity keeps its token', (tester) async {
    final api = PushVendor();
    final push = FakePush();
    final app = await vendorApp(tester, push, api);
    await app.container.read(sessionProvider.notifier).lockForPin();
    await tester.pumpAndSettle();
    expect(push.deleted, 0);
  });

  testWidgets('no permission or no server changes nothing for the app',
      (tester) async {
    final api = PushVendor()..down = true;
    final push = FakePush();
    final app = await vendorApp(tester, push, api);
    expect(api.registered, isEmpty);
    expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
    // Tried again when the app returns.
    api.down = false;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(api.registered, ['token-1/sw']);
  });

  testWidgets('tapping a push opens its screen and marks it read',
      (tester) async {
    final api = PushVendor()..notificationList.add(note('n1'));
    final push = FakePush();
    final app = await vendorApp(tester, push, api);
    push.tap.add(
        const PushTap(notificationId: 'n1', target: 'receive', side: 'vendor'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.receive);
    expect(api.notificationList.single.read, isTrue);
  });

  testWidgets('a push that opened the app waits for the PIN', (tester) async {
    final api = PushVendor();
    final push = FakePush()
      ..initial = const PushTap(
          notificationId: 'n1', target: 'receive', side: 'vendor');
    final app = await vendorApp(tester, push, api, startAs: StartAs.locked);
    expect(app.router.state.uri.path, MNRoutes.pin);
    await app.container
        .read(sessionProvider.notifier)
        .signIn(testProfile.phone, api.pin);
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.receive);
  });

  testWidgets('a push arriving in the open app lights the bell',
      (tester) async {
    final api = PushVendor();
    final push = FakePush();
    final app = await vendorApp(tester, push, api);
    expect(app.container.read(notificationsUnreadProvider), isFalse);
    api.notificationList.add(note('n1'));
    push.arrive.add(null);
    await tester.pumpAndSettle();
    expect(app.container.read(notificationsUnreadProvider), isTrue);
  });

  testWidgets('office staff register their own side', (tester) async {
    final office = PushOffice()..signedIn = true;
    final push = FakePush();
    final app = await pumpApp(tester,
        startAs: StartAs.signedOut,
        office: office,
        overrides: [pushClientProvider.overrideWithValue(push)]);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    expect(office.registered, ['token-1/sw']);
    push.tap.add(const PushTap(target: 'office_reviews', side: 'staff'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeSyncConflicts);
  });
}
