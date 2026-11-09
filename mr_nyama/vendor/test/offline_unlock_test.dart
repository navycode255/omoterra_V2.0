import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/offline_unlock.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/sync/outbox.dart';
import 'package:mr_nyama_vendor/core/sync/sync_engine.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'helpers.dart';
import 'sales_flow_test.dart' show openCart, tapProduct;

const sw = Strings('sw');
const pin = '1357';

OfflineGrantAnswer grant({DateTime? expires, int attempts = 3}) =>
    OfflineGrantAnswer(
        enabled: true,
        grantId: 'g-1',
        expiresAt: expires ?? DateTime.now().add(const Duration(hours: 48)),
        validityHours: 48,
        relockMinutes: 30,
        pinAttempts: attempts);

/// The phone cannot reach the server: every call fails as offline.
void goOffline(FakeVendorRepository api) {
  const offline = AuthFailure(AuthFailureKind.offline);
  api
    ..signInFailure = offline
    ..dashboardFailure = offline
    ..catalogFailure = offline
    ..deliveriesFailure = offline
    ..progressFailure = offline
    ..notificationsFailure = offline
    ..creditFailure = offline
    ..syncFailure = offline;
}

void goOnline(FakeVendorRepository api) {
  api
    ..signInFailure = null
    ..dashboardFailure = null
    ..catalogFailure = null
    ..deliveriesFailure = null
    ..progressFailure = null
    ..creditFailure = null
    ..syncFailure = null;
}

/// A locked phone that signed in online before and kept a grant and verifier.
Future<TestApp> lockedWithGrant(WidgetTester tester, {int attempts = 3}) async {
  final api = FakeVendorRepository()..catalogSnapshot = testCatalog;
  final app = await pumpApp(tester, startAs: StartAs.locked, api: api);
  final offline = app.container.read(offlineUnlockProvider);
  await offline.rememberPin(pin);
  await offline.keepGrant(grant(attempts: attempts), DateTime.now());
  // The catalogue the phone already holds; then the server cannot be reached.
  await app.container.read(salesStoreProvider).replaceCatalog(testCatalog);
  goOffline(api);
  return app;
}

Future<void> signIn(WidgetTester tester, TestApp app, String value) async {
  await app.container
      .read(sessionProvider.notifier)
      .signIn(testProfile.phone, value);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => OfflineUnlock.markForNewOperations = null);

  testWidgets('the right PIN unlocks offline; the PIN itself is never stored',
      (tester) async {
    final app = await lockedWithGrant(tester);
    await signIn(tester, app, pin);
    final auth = app.container.read(sessionProvider).valueOrNull;
    expect(auth, isA<SignedIn>());
    expect((auth as SignedIn).session.offlineGrantId, 'g-1');
    expect(app.store.values.values.any((v) => v.contains(pin)), isFalse);
    expect(app.store.values.keys, contains('offline_pin_verifier'));

    // Work done now carries the grant; the payload itself stays clean.
    await enqueueOperation(app.db,
        opId: 'op-1',
        opType: 'damage_report',
        vendorId: 'v1',
        stationKey: 'S1',
        occurredAt: DateTime.now(),
        createdAt: DateTime.now(),
        payload: {'report_id': 'op-1'});
    goOnline(app.api);
    await app.container.read(syncEngineProvider.notifier).syncNow();
    await tester.pumpAndSettle();
    final sent = app.api.syncedBatches
        .expand((b) => b)
        .singleWhere((o) => o.opId == 'op-1');
    expect(sent.offlineGrantId, 'g-1');
    expect(sent.payload.containsKey(offlineMarkKey), isFalse);
    // The server answered: no longer offline, nothing new is marked.
    final after = app.container.read(sessionProvider).valueOrNull as SignedIn;
    expect(after.session.offline, isFalse);
    expect(OfflineUnlock.markForNewOperations, isNull);
  });

  testWidgets('wrong PINs count across restarts and the limit erases the grant',
      (tester) async {
    final app = await lockedWithGrant(tester, attempts: 2);
    await expectLater(
        signIn(tester, app, '0000'),
        throwsA(isA<OfflineUnlockFailure>()
            .having((f) => f.refusal, 'refusal', OfflineRefusal.wrongPin)
            .having((f) => f.attemptsLeft, 'left', 1)));
    expect(app.store.values['offline_pin_failures'], '1');
    // A fresh reader of the same store (the app was killed) keeps counting.
    await expectLater(
        OfflineUnlock(app.container.read(offlineUnlockProvider).ref)
            .unlock('0000', DateTime.now()),
        throwsA(isA<OfflineUnlockFailure>()
            .having((f) => f.refusal, 'refusal', OfflineRefusal.erased)));
    expect(
        app.store.values.keys.where(
            (k) => k.startsWith('offline_') && k != 'offline_last_online'),
        isEmpty);
    // Even the right PIN now needs the server.
    await expectLater(
        signIn(tester, app, pin),
        throwsA(isA<OfflineUnlockFailure>()
            .having((f) => f.refusal, 'refusal', OfflineRefusal.noGrant)));
    expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
  });

  testWidgets('past the validity the PIN no longer unlocks offline',
      (tester) async {
    final app = await lockedWithGrant(tester);
    app.store.values['offline_last_online'] = DateTime.now()
        .subtract(const Duration(hours: 49))
        .toUtc()
        .toIso8601String();
    await expectLater(
        signIn(tester, app, pin),
        throwsA(isA<OfflineUnlockFailure>()
            .having((f) => f.refusal, 'refusal', OfflineRefusal.expired)));
  });

  testWidgets('without a grant (limits unset) nothing works offline, as before',
      (tester) async {
    final api = FakeVendorRepository()
      ..signInFailure = const AuthFailure(AuthFailureKind.offline);
    final app = await pumpApp(tester, startAs: StartAs.locked, api: api);
    await expectLater(
        signIn(tester, app, pin),
        throwsA(isA<OfflineUnlockFailure>()
            .having((f) => f.refusal, 'refusal', OfflineRefusal.noGrant)));
  });

  testWidgets('an online sign-in keeps a verifier and asks for a grant',
      (tester) async {
    final api = FakeVendorRepository()
      ..offlineGrantValue = grant()
      ..pin = pin;
    final app = await pumpApp(tester, startAs: StartAs.locked, api: api);
    await signIn(tester, app, pin);
    expect(api.offlineGrantCalls, 1);
    expect(jsonDecode(app.store.values['offline_grant']!)['id'], 'g-1');
    expect(app.store.values.values.any((v) => v.contains(pin)), isFalse);
    // Signing out leaves nothing to unlock with.
    await app.container.read(sessionProvider.notifier).signOut();
    expect(
        app.store.values.keys.where(
            (k) => k.startsWith('offline_') && k != 'offline_last_online'),
        isEmpty);
  });

  testWidgets('when the offline time is over, the cart cannot save',
      (tester) async {
    final app = await lockedWithGrant(tester);
    await signIn(tester, app, pin);
    app.store.values['offline_last_online'] = DateTime.now()
        .subtract(const Duration(hours: 49))
        .toUtc()
        .toIso8601String();
    app.container.invalidate(offlineRecordingStoppedProvider);
    app.router.go(MNRoutes.sales);
    await tester.pumpAndSettle();
    await tapProduct(tester, 'Kuku mzima');
    await openCart(tester);
    expect(find.text(sw.offlineRecordingStopped), findsOneWidget);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi mauzo'))
            .onPressed,
        isNull);
  });
}
