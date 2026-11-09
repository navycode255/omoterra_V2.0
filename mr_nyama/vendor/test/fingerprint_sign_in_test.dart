import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/biometrics.dart';
import 'package:mr_nyama_vendor/core/auth/device_sign_in.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'biometrics_test.dart' show FakeBiometrics;
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository, enterPin;

const sw = Strings('sw');

/// Turns the fingerprint on from Wasifu, as a vendor would.
Future<TestApp> enrolled(WidgetTester tester, FakeBiometrics bio,
    {FakeVendorRepository? api}) async {
  final app =
      await pumpApp(tester, api: api, initial: MNRoutes.profile, overrides: [
    biometricAuthenticatorProvider.overrideWithValue(bio),
  ]);
  final title = find.text('Kufungua kwa alama za mwili');
  await tester.ensureVisible(title);
  await tester.tap(title);
  await tester.pumpAndSettle();
  return app;
}

Future<void> signOut(TestApp app, WidgetTester tester) async {
  await app.container.read(sessionProvider.notifier).signOut();
  await tester.pumpAndSettle();
}

/// Signs out with the fingerprint check declined, so the remembered
/// sign-in screen stays up instead of signing straight back in.
Future<void> signOutDeclining(
    TestApp app, WidgetTester tester, FakeBiometrics bio) async {
  bio.answer = false;
  await signOut(app, tester);
  bio.answer = true;
}

Future<void> fromMenu(WidgetTester tester, String item) async {
  await tester.tap(find.bySemanticsLabel(sw.moreOptions));
  await tester.pumpAndSettle();
  await tapText(tester, item);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A server without the fingerprint sign-in step (before MN024 is deployed).
class NoKeyServer extends FakeVendorRepository {
  int asked = 0;
  @override
  Future<String> issueDeviceKey() async {
    asked++;
    throw const AuthFailure(AuthFailureKind.offline);
  }
}

/// The office fake with fingerprint sign-in keys (MN024).
class KeyedOffice extends FakeOfficeRepository
    implements OfficeDeviceKeyRepository {
  final liveKeys = <String>{};
  int issued = 0;
  @override
  Future<String> issueDeviceKey() async {
    final key = 'staff-key-${++issued}';
    liveKeys
      ..clear()
      ..add(key);
    return key;
  }

  @override
  Future<void> forgetDeviceKey() async => liveKeys.clear();
  @override
  Future<StaffProfile> deviceSignIn(String key) async {
    if (!liveKeys.contains(key)) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    signedIn = true;
    return owner;
  }
}

void main() {
  group('a remembered phone', () {
    testWidgets('asks for the fingerprint by itself after signing out',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      expect(app.api.deviceKeysIssued, 1);
      final before = bio.prompts;
      await signOut(app, tester);
      expect(bio.prompts, before + 1);
      expect(app.api.calls, contains('deviceSignIn'));
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
    });

    testWidgets('greets the vendor, with the PIN and Si wewe one tap away',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      await signOutDeclining(app, tester, bio);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedOut>());
      expect(find.text(sw.welcomeBack('Asha')), findsOneWidget);
      expect(find.text(sw.biometricFailed), findsOneWidget);
      expect(find.text(sw.biometricUsePin), findsOneWidget);
      // One greeting line, the circle with its hint, and the PIN as the only
      // button (owner review, 30 October 2026).
      expect(find.text(sw.fingerprintTapHint), findsOneWidget);
      expect(find.widgetWithText(MNButton, sw.fingerprintSignIn), findsNothing);
      expect(find.widgetWithText(MNButton, sw.biometricUsePin), findsOneWidget);
      expect(find.text(sw.notYou), findsOneWidget);
      expect(find.text(sw.continueLabel), findsNothing);
      // Asking again from the button signs in.
      // The circle is the fingerprint button.
      await tester.tap(find.bySemanticsLabel(sw.fingerprintSignIn));
      await tester.pumpAndSettle();
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
    });

    testWidgets('Tumia PIN opens the PIN pad with the phone already known',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      await signOutDeclining(app, tester, bio);
      await tapText(tester, sw.biometricUsePin);
      expect(app.api.calls, contains('start ${testProfile.phone}'));
      expect(find.text(sw.pinTitle), findsOneWidget);
      await enterPin(tester, app.api.pin);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
      // The fingerprint stays on and gets a fresh key.
      expect(app.api.deviceKeysIssued, 2);
    });

    testWidgets('the PIN pad fingerprint key signs in with the saved key',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      await signOutDeclining(app, tester, bio);
      await tapText(tester, sw.biometricUsePin);
      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pumpAndSettle();
      expect(app.api.calls, contains('deviceSignIn'));
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
    });

    testWidgets('Si wewe shows the phone form, from either screen',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      await signOutDeclining(app, tester, bio);
      await tapText(tester, sw.biometricUsePin);
      await tapText(tester, sw.notYou);
      expect(find.text(sw.continueLabel), findsOneWidget);
      expect(find.text(sw.welcomeBack('Asha')), findsNothing);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedOut>());
    });

    testWidgets('a key the server ended falls back to the phone form',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      app.api.liveDeviceKeys.clear(); // e.g. a PIN reset at the office
      await signOut(app, tester);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedOut>());
      expect(find.text(sw.fingerprintKeyEnded), findsOneWidget);
      expect(find.text(sw.continueLabel), findsOneWidget);
      expect(find.text(sw.welcomeBack('Asha')), findsNothing);
    });

    testWidgets('Wasifu says so when the server gives no sign-in key',
        (tester) async {
      final server = NoKeyServer();
      await enrolled(tester, FakeBiometrics(), api: server);
      expect(find.text(sw.biometricOn), findsOneWidget);
      expect(find.text(sw.fingerprintSignInPending), findsOneWidget);
      // Asked when turned on, and once more when the setting is shown.
      expect(server.asked, 2);
    });

    testWidgets('turning the fingerprint off forgets it on both sides',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await enrolled(tester, bio);
      final title = find.text('Kufungua kwa alama za mwili');
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(app.api.liveDeviceKeys, isEmpty);
      expect(await app.container.read(deviceSignInStoreProvider).read('vendor'),
          isNull);
      final before = bio.prompts;
      await signOut(app, tester);
      expect(bio.prompts, before);
      expect(find.text(sw.continueLabel), findsOneWidget);
    });
  });

  group('Nikumbuke', () {
    testWidgets('after the PIN, turns the fingerprint on for this phone',
        (tester) async {
      final bio = FakeBiometrics();
      final app = await pumpApp(tester, startAs: StartAs.signedOut, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tapText(tester, sw.rememberNumber);
      await tapText(tester, sw.continueLabel);
      await enterPin(tester, app.api.pin);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
      expect(app.api.deviceKeysIssued, 1);
      final account = biometricAccount('vendor', testProfile.id);
      expect(
          await app.container
              .read(biometricPreferencesProvider)
              .enabled(account),
          isTrue);
      await signOutDeclining(app, tester, bio);
      expect(find.text(sw.welcomeBack('Asha')), findsOneWidget);
    });

    testWidgets('left unticked, nothing is remembered', (tester) async {
      final bio = FakeBiometrics();
      final app = await pumpApp(tester, startAs: StartAs.signedOut, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tapText(tester, sw.continueLabel);
      await enterPin(tester, app.api.pin);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
      expect(app.api.deviceKeysIssued, 0);
      await signOut(app, tester);
      expect(bio.prompts, 0);
      expect(find.text(sw.continueLabel), findsOneWidget);
    });

    testWidgets('without a fingerprint reader, keeps only the number',
        (tester) async {
      final bio = FakeBiometrics()..supported = false;
      final app = await pumpApp(tester, startAs: StartAs.signedOut, overrides: [
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ]);
      await tester.enterText(find.byType(TextField), '0712345678');
      await tester.pump();
      await tapText(tester, sw.rememberNumber);
      await tapText(tester, sw.continueLabel);
      await enterPin(tester, app.api.pin);
      expect(app.container.read(sessionProvider).valueOrNull, isA<SignedIn>());
      expect(app.api.deviceKeysIssued, 0);
      await signOut(app, tester);
      expect(bio.prompts, 0);
      expect(find.text('712 345 678'), findsOneWidget);
    });
  });

  group('office', () {
    testWidgets('Nikumbuke, then the office opens first on the next start',
        (tester) async {
      final bio = FakeBiometrics();
      final office = KeyedOffice();
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut,
          office: office,
          overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)]);
      await fromMenu(tester, sw.officeSignIn);
      await tester.enterText(find.byType(TextField), '746484666');
      await tester.pump();
      await tapText(tester, sw.rememberNumber);
      await tapText(tester, sw.continueLabel);
      await enterPin(tester, '4826');
      expect(app.container.read(officeSessionProvider).valueOrNull,
          isA<OfficeSignedIn>());
      expect(office.issued, 1);
      expect(await app.container.read(deviceSignInStoreProvider).lastSide(),
          'staff');
      // Signing out lands on the office sign-in, which asks by itself.
      final before = bio.prompts;
      await app.container.read(officeSessionProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(bio.prompts, before + 1);
      expect(app.container.read(officeSessionProvider).valueOrNull,
          isA<OfficeSignedIn>());
    });

    testWidgets('a fresh start opens the office side when it was used last',
        (tester) async {
      final bio = FakeBiometrics()..answer = false;
      final office = KeyedOffice()..liveKeys.add('staff-key-1');
      final account = biometricAccount('staff', office.owner.id);
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut,
          office: office,
          overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)],
          seed: (store) {
        store.values['biometric_enabled_$account'] = '1';
        store.values['sign_in_last_side'] = 'staff';
        store.values['device_sign_in_staff'] =
            '{"account":"$account","key":"staff-key-1",'
            '"name":"${office.owner.name}","phone":"${office.owner.phone}"}';
      });
      expect(find.text(sw.welcomeBack('Maternus')), findsOneWidget);
      expect(bio.prompts, 1);
      // The vendor side is in the menu and asks for nothing.
      await fromMenu(tester, sw.vendorSignIn);
      expect(find.text(sw.continueLabel), findsOneWidget);
      expect(bio.prompts, 1);
      expect(app.container.read(officeSessionProvider).valueOrNull,
          isA<OfficeSignedOut>());
    });
  });
}
