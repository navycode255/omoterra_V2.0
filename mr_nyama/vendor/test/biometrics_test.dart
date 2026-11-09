import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/biometrics.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

class FakeBiometrics implements BiometricAuthenticator {
  bool supported = true, answer = true, throws = false;
  int prompts = 0;
  Completer<bool>? pending;
  @override
  Future<bool> available() async => supported;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    if (throws) throw StateError('test failure');
    return pending == null ? answer : pending!.future;
  }
}

Future<void> enable(TestApp app, WidgetTester tester, String account) async {
  await app.container.read(biometricPreferencesProvider).enable(account);
  app.container.invalidate(biometricEnabledProvider(account));
  await tester.pumpAndSettle();
}

void main() {
  test('preferences contain only opt-in, scoped by audience and account',
      () async {
    final store = InMemoryStore();
    final prefs = BiometricPreferences(store);
    final vendor = biometricAccount('vendor', 'same-id');
    final staff = biometricAccount('staff', 'same-id');
    expect(vendor, isNot(staff));
    await prefs.enable(vendor);
    expect(await prefs.enabled(vendor), isTrue);
    expect(await prefs.enabled(staff), isFalse);
    expect(store.values.values, ['1']);
    await prefs.clear(vendor);
    expect(store.values, isEmpty);
  });

  testWidgets('vendor stays locked on cancellation/error; success unlocks',
      (tester) async {
    final bio = FakeBiometrics()..answer = false;
    final app = await pumpApp(tester, overrides: [
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    await enable(app, tester, biometricAccount('vendor', testProfile.id));
    expect(find.text('Imefungwa'), findsOneWidget);
    await tester.tap(find.text('Fungua kwa biometrics'));
    await tester.pumpAndSettle();
    expect(find.text('Haikuweza kufunguka'), findsOneWidget);
    bio.throws = true;
    await tester.tap(find.text('Jaribu tena'));
    await tester.pumpAndSettle();
    expect(find.text('Haikuweza kufunguka'), findsOneWidget);
    bio
      ..throws = false
      ..answer = true;
    await tester.tap(find.text('Jaribu tena'));
    await tester.pumpAndSettle();
    expect(find.text('Imefungwa'), findsNothing);
    expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
  });

  group('the five-minute wait', () {
    late DateTime now;
    late FakeBiometrics bio;

    Future<TestApp> unlocked(WidgetTester tester) async {
      now = DateTime(2026, 10, 31, 9);
      bio = FakeBiometrics()..answer = true;
      final app = await pumpApp(tester, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
        clockProvider.overrideWithValue(() => now),
      ]);
      await enable(app, tester, biometricAccount('vendor', testProfile.id));
      await tester.tap(find.text('Fungua kwa biometrics'));
      await tester.pumpAndSettle();
      expect(find.text('Imefungwa'), findsNothing);
      return app;
    }

    Future<void> away(WidgetTester tester, Duration time) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      now = now.add(time);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
    }

    testWidgets('leaving to choose a photo does not lock', (tester) async {
      await unlocked(tester);
      await away(tester, const Duration(minutes: 4, seconds: 59));
      expect(find.text('Imefungwa'), findsNothing);
      expect(bio.prompts, 1);
    });

    testWidgets('five minutes away locks on return', (tester) async {
      await unlocked(tester);
      await away(tester, biometricIdleLock);
      expect(find.text('Imefungwa'), findsOneWidget);
    });

    testWidgets('a call-style interruption alone does not lock',
        (tester) async {
      await unlocked(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Imefungwa'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Imefungwa'), findsNothing);
    });

    testWidgets('five untouched minutes on screen lock; a touch restarts them',
        (tester) async {
      await unlocked(tester);
      await tester.pump(const Duration(minutes: 4));
      await tester.tapAt(const Offset(195, 400));
      await tester.pump(const Duration(minutes: 4));
      expect(find.text('Imefungwa'), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Imefungwa'), findsOneWidget);
    });

    testWidgets('the wait starts again after a short time away',
        (tester) async {
      await unlocked(tester);
      await tester.pump(const Duration(minutes: 4));
      await away(tester, const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 4));
      expect(find.text('Imefungwa'), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Imefungwa'), findsOneWidget);
    });
  });

  testWidgets(
      'duplicate taps prompt once; account change invalidates an outstanding result',
      (tester) async {
    final bio = FakeBiometrics()..pending = Completer<bool>();
    final app = await pumpApp(tester, overrides: [
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    await enable(app, tester, biometricAccount('vendor', testProfile.id));
    await tester.tap(find.text('Fungua kwa biometrics'));
    await tester.pump();
    await tester.tap(find.text('Fungua kwa biometrics'));
    await tester.pump();
    expect(bio.prompts, 1);
    await app.container.read(sessionProvider.notifier).lockForPin();
    await tester.pumpAndSettle();
    bio.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
    expect(app.router.state.uri.path, MNRoutes.pin);
  });

  testWidgets('PIN fallback and sign-out preserve records and keep the opt-in',
      (tester) async {
    final app = await pumpApp(tester, connectivity: Stream.value(false));
    await app.container.read(salesStoreProvider).saveSale(SaleDraft(
          clientId: 'biometric-unsent-sale',
          vendorId: testProfile.id,
          stationKey: testProfile.stationKey,
          recordedAt: DateTime.now(),
          payment: PaymentMethod.cash,
          lines: const [
            DraftLine(
                productId: 'sample',
                productName: 'Test item',
                quantity: 1,
                unitPrice: 1000,
                priceVersion: 'test-price')
          ],
        ));
    final account = biometricAccount('vendor', testProfile.id);
    await enable(app, tester, account);
    await tester.tap(find.text('Tumia PIN'));
    await tester.pumpAndSettle();
    expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
    expect(app.store.values['session_token'], isNotNull);
    expect(app.router.state.uri.path, MNRoutes.pin);
    await app.container.read(sessionProvider.notifier).signOut();
    expect((await app.db.select(app.db.sales).get()).single.clientId,
        'biometric-unsent-sale');
    expect((await app.db.select(app.db.outbox).get()).single.opId,
        'biometric-unsent-sale');
    // Signing in again on this phone keeps the fingerprint on.
    expect(
        await app.container.read(biometricPreferencesProvider).enabled(account),
        isTrue);
  });

  group('the PIN screen after a lock', () {
    testWidgets('a vendor locked for inactivity opens with the fingerprint',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await pumpApp(tester, startAs: StartAs.locked, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
      await enable(app, tester, biometricAccount('vendor', testProfile.id));
      // The prompt opens by itself once; the server confirms the session.
      expect(bio.prompts, 1);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
      expect(app.api.calls.where((c) => c.startsWith('dashboard')), isNotEmpty);
      expect(app.router.state.uri.path, isNot(MNRoutes.pin));
    });

    testWidgets('a cancelled prompt leaves the PIN and the fingerprint key',
        (tester) async {
      final bio = FakeBiometrics()..answer = false;
      final app = await pumpApp(tester, startAs: StartAs.locked, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      await enable(app, tester, biometricAccount('vendor', testProfile.id));
      expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
      expect(find.text('Jaribu tena au tumia PIN.'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      bio.answer = true;
      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pumpAndSettle();
      expect(bio.prompts, 2);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
    });

    testWidgets(
        'without the opt-in, or when the server ended the session, only the PIN',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await pumpApp(tester, startAs: StartAs.locked, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      expect(find.byIcon(Icons.fingerprint), findsNothing); // not turned on
      await app.container.read(sessionProvider.notifier).expire();
      await enable(app, tester, biometricAccount('vendor', testProfile.id));
      expect(find.byIcon(Icons.fingerprint), findsNothing); // server ended it
      expect(bio.prompts, 0);
    });

    testWidgets('offline without a valid grant the fingerprint does not open',
        (tester) async {
      final bio = FakeBiometrics();
      final api = FakeVendorRepository()
        ..dashboardFailure = const AuthFailure(AuthFailureKind.offline);
      final app =
          await pumpApp(tester, startAs: StartAs.locked, api: api, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      await enable(app, tester, biometricAccount('vendor', testProfile.id));
      expect(bio.prompts, 1);
      expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });
  });

  testWidgets(
      'enrollment requires enrolled biometrics and a successful OS prompt',
      (tester) async {
    final bio = FakeBiometrics()..supported = false;
    final app = await pumpApp(tester, initial: MNRoutes.profile, overrides: [
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    final title = find.text('Kufungua kwa alama za mwili');
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(bio.prompts, 0);
    final account = biometricAccount('vendor', testProfile.id);
    expect(
        await app.container.read(biometricPreferencesProvider).enabled(account),
        isFalse);
    bio
      ..supported = true
      ..answer = false;
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(
        await app.container.read(biometricPreferencesProvider).enabled(account),
        isFalse);
    bio.answer = true;
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(
        await app.container.read(biometricPreferencesProvider).enabled(account),
        isTrue);
    expect(find.text('Imefungwa'), findsNothing);
    expect(
        app.store.values.keys.where((k) => k.startsWith('biometric_enabled_')),
        hasLength(1));
  });

  testWidgets('office lock has its own scope and PIN fallback survives restart',
      (tester) async {
    final repo = FakeOfficeRepository()..signedIn = true;
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    final account = biometricAccount('staff', repo.owner.id);
    await enable(app, tester, account);
    expect(find.text('Imefungwa'), findsOneWidget);
    await tester.tap(find.text('Tumia PIN'));
    await tester.pumpAndSettle();
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedOut>());
    expect(app.store.values['office_profile'], isNull);
    app.container.invalidate(officeSessionProvider);
    expect(await app.container.read(officeSessionProvider.future),
        isA<OfficeSignedOut>());
  });
  for (final officeMode in [false, true]) {
    testWidgets(
        '${officeMode ? 'office' : 'vendor'} biometric success before resume unlocks on resume',
        (tester) async {
      final bio = FakeBiometrics()..pending = Completer<bool>();
      final repo = FakeOfficeRepository()..signedIn = true;
      final app = await pumpApp(tester,
          startAs: officeMode ? StartAs.signedOut : StartAs.signedIn,
          office: repo,
          overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)]);
      if (officeMode) {
        await app.container
            .read(officeSessionProvider.notifier)
            .signedIn(repo.owner);
        await tester.pumpAndSettle();
      }
      await enable(
          app,
          tester,
          biometricAccount(officeMode ? 'staff' : 'vendor',
              officeMode ? repo.owner.id : testProfile.id));
      await tester.tap(find.text('Fungua kwa biometrics'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      bio.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Imefungwa'), findsOneWidget);
      expect(find.text('Haikuweza kufunguka'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Imefungwa'), findsNothing);
      expect(bio.prompts, 1);
    });
  }

  testWidgets('backgrounding after success but before resume discards it',
      (tester) async {
    final bio = FakeBiometrics()..pending = Completer<bool>();
    final app = await pumpApp(tester, overrides: [
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    await enable(app, tester, biometricAccount('vendor', testProfile.id));
    await tester.tap(find.text('Fungua kwa biometrics'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    bio.pending!.complete(true);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Imefungwa'), findsOneWidget);
  });

  testWidgets('backgrounding cancels a pending biometric result',
      (tester) async {
    final bio = FakeBiometrics()..pending = Completer<bool>();
    final app = await pumpApp(tester, overrides: [
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    await enable(app, tester, biometricAccount('vendor', testProfile.id));
    await tester.tap(find.text('Fungua kwa biometrics'));
    await tester.pump();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    bio.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Haikuweza kufunguka'), findsOneWidget);
  });
}
