import 'package:mr_nyama_vendor/shared/widgets/account.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/providers.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/auth_flow.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'helpers.dart';

Future<void> typePhone(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextField), phone);
  await tester.pump();
  await tester.tap(find.text('Endelea'));
  await tester.pumpAndSettle();
}

Future<void> typeKeys(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(
        find.descendant(of: find.byType(MNPinKeypad), matching: find.text(d)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

String path(TestApp app) => app.router.state.uri.path;

void main() {
  group('production fails closed', () {
    test('the default vendor API is the unavailable one', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vendorRepositoryProvider),
          isA<UnavailableVendorRepository>());
    });

    testWidgets('without the API, sign-in says so and goes nowhere',
        (tester) async {
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut,
          repository: const UnavailableVendorRepository());
      await typePhone(tester, '712345678');
      expect(find.text('Huduma ya kuingia bado haipatikani.'), findsOneWidget);
      expect(path(app), MNRoutes.login);
      expect(app.store.values['session_token'], isNull);
    });
  });

  group('phone number', () {
    testWidgets('signed out opens the photographic login', (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      expect(path(app), MNRoutes.login);
      expect(find.text('+255'), findsOneWidget);
      expect(find.widgetWithText(MNButton, 'Endelea'), findsOneWidget);
    });

    testWidgets('an invalid number is caught before calling the server',
        (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      // Endelea waits for nine digits; leaving the field says why.
      expect(
          tester
              .widget<MNButton>(find.widgetWithText(MNButton, 'Endelea'))
              .onPressed,
          isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Ingiza tarakimu 9 baada ya +255.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '812345678');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Namba si sahihi'), findsOneWidget);
      expect(app.api.calls, isEmpty);
    });

    test('Tanzanian numbers are normalised', () {
      expect(normaliseTanzanianPhone('0712 345 678'), '+255712345678');
      expect(normaliseTanzanianPhone('712345678'), '+255712345678');
      expect(normaliseTanzanianPhone('+255 612 345 678'), '+255612345678');
      expect(normaliseTanzanianPhone('812345678'), isNull);
      expect(normaliseTanzanianPhone('71234567'), isNull);
      expect(displayPhone('+255712345678'), '+255 712 345 678');
    });

    for (final (kind, message) in [
      (
        AuthFailureKind.offline,
        'Hakuna intaneti. Unganisha simu kisha ujaribu tena.'
      ),
      (AuthFailureKind.unknownPhone, 'Namba hii haijasajiliwa kama muuzaji.'),
    ]) {
      testWidgets('$kind is explained on the login', (tester) async {
        final api = FakeVendorRepository()..startFailure = AuthFailure(kind);
        final app = await pumpApp(tester, startAs: StartAs.signedOut, api: api);
        await typePhone(tester, '712345678');
        expect(find.text(message), findsOneWidget);
        expect(path(app), MNRoutes.login);
      });
    }
  });

  group('PIN', () {
    testWidgets(
        'correct PIN signs in and opens Nyumbani; the PIN is never '
        'stored', (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      await typePhone(tester, '0712 345 678');
      expect(path(app), MNRoutes.pin);
      expect(find.text('Weka PIN'), findsOneWidget);
      await typeKeys(tester, '2580');
      expect(path(app), MNRoutes.home);
      expect(app.store.values['session_token'], 'token-2');
      expect(app.store.values.values.join(' '), isNot(contains('2580')));
    });

    testWidgets('wrong PIN: red dots, attempts left, next key starts over',
        (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      await typePhone(tester, '712345678');
      await typeKeys(tester, '1357');
      expect(find.text('PIN si sahihi.'), findsOneWidget);
      expect(find.text('Majaribio 2 yamebaki.'), findsOneWidget);
      expect(tester.widget<MNPinDots>(find.byType(MNPinDots)).error, isTrue);
      expect(path(app), MNRoutes.pin);
      await typeKeys(tester, '2');
      expect(find.text('PIN si sahihi.'), findsNothing);
      expect(tester.widget<MNPinDots>(find.byType(MNPinDots)).filled, 1);
    });

    testWidgets('delete removes the last digit', (tester) async {
      await pumpApp(tester, startAs: StartAs.signedOut);
      await typePhone(tester, '712345678');
      await typeKeys(tester, '25');
      await tester.tap(find.bySemanticsLabel('Futa'));
      await tester.pump();
      expect(tester.widget<MNPinDots>(find.byType(MNPinDots)).filled, 1);
    });

    testWidgets('too many attempts explains the pause', (tester) async {
      final api = FakeVendorRepository()
        ..signInFailure = AuthFailure(AuthFailureKind.locked,
            retryAfter: DateTime.now().add(const Duration(minutes: 5)));
      await pumpApp(tester, startAs: StartAs.signedOut, api: api);
      await typePhone(tester, '712345678');
      await typeKeys(tester, '2580');
      expect(find.text('Subiri kidogo'), findsOneWidget);
      expect(find.textContaining('Jaribu tena baada ya'), findsWidgets);
      // The pad stays, greyed, while the wait counts down.
      expect(tester.widget<MNPinKeypad>(find.byType(MNPinKeypad)).enabled,
          isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('while checking: spinner, and the keypad ignores keys',
        (tester) async {
      final api = FakeVendorRepository();
      await pumpApp(tester, startAs: StartAs.signedOut, api: api);
      await typePhone(tester, '712345678');
      api.gate = Completer();
      await typeKeys(tester, '258');
      await tester.tap(find.descendant(
          of: find.byType(MNPinKeypad), matching: find.text('0')));
      await tester.pump();
      expect(find.byType(MNSpinner), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(MNPinKeypad), matching: find.text('9')));
      await tester.pump();
      expect(tester.widget<MNPinDots>(find.byType(MNPinDots)).filled, 4);
      api.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: login to PIN without transition',
        (tester) async {
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut, reducedMotion: true);
      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tester.tap(find.text('Endelea'));
      await tester.pump();
      await tester.pump();
      expect(path(app), MNRoutes.pin);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('first activation', () {
    testWidgets('code, choose PIN, confirm (with a mismatch), signed in',
        (tester) async {
      final api = FakeVendorRepository()..step = SignInStep.activation;
      final app = await pumpApp(tester, startAs: StartAs.signedOut, api: api);
      await typePhone(tester, '712345678');
      expect(path(app), MNRoutes.activate);

      await typeKeys(tester, '000000');
      expect(find.text('Namba ya uthibitisho si sahihi.'), findsOneWidget);
      await typeKeys(tester, '123456');
      expect(path(app), MNRoutes.createPin);

      await typeKeys(tester, '1111');
      expect(find.text('Chagua PIN isiyo rahisi kukisia.'), findsOneWidget);
      await typeKeys(tester, '4071');
      expect(path(app), MNRoutes.confirmPin);

      await typeKeys(tester, '4072');
      expect(path(app), MNRoutes.createPin);
      expect(find.text('PIN hazilingani. Anza upya.'), findsOneWidget);

      await typeKeys(tester, '4071');
      await typeKeys(tester, '4071');
      expect(path(app), MNRoutes.home);
      expect(api.calls, contains('setPin setup-1'));
      expect(app.container.read(authFlowProvider).newPin, isNull);
    });

    testWidgets('forgot PIN goes to the code screen as a reset',
        (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      await typePhone(tester, '712345678');
      await tester.tap(find.text('Umesahau PIN?'));
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.forgotPin);
      await tester.tap(find.text('Nina namba ya uthibitisho'));
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.activate);
      await typeKeys(tester, '123456');
      expect(app.api.calls, contains('verify reset=true'));
    });
  });

  group('session protection', () {
    testWidgets('signed out cannot open app screens', (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.signedOut);
      for (final route in [
        MNRoutes.home,
        MNRoutes.sales,
        MNRoutes.profile,
        MNRoutes.closeDay
      ]) {
        app.router.go(route);
        await tester.pumpAndSettle();
        expect(path(app), MNRoutes.login, reason: route);
      }
    });

    testWidgets('after 12 hours away the PIN is asked again, without back',
        (tester) async {
      final app = await pumpApp(tester, startAs: StartAs.locked);
      expect(path(app), MNRoutes.pin);
      expect(find.text('Weka PIN'), findsOneWidget);
      expect(find.bySemanticsLabel('Rudi'), findsNothing);
      app.router.go(MNRoutes.sales);
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.pin);
      await typeKeys(tester, '2580');
      expect(path(app), MNRoutes.home);
    });

    testWidgets('returning to the app after 12 hours locks it', (tester) async {
      final app = await pumpApp(tester);
      app.store.values['last_active'] =
          DateTime.now().subtract(const Duration(hours: 13)).toIso8601String();
      await app.container.read(sessionProvider.notifier).checkLock();
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.pin);
    });

    testWidgets('a session the server rejects returns to PIN with a note',
        (tester) async {
      final api = FakeVendorRepository()
        ..dashboardFailure = const AuthFailure(AuthFailureKind.sessionExpired);
      final app = await pumpApp(tester, api: api);
      expect(path(app), MNRoutes.pin);
      expect(find.text('Muda wa kuingia umeisha. Ingiza PIN tena.'),
          findsOneWidget);
      expect(app.store.values['session_token'], isNull);
    });

    testWidgets('a suspended account sees only the suspended screen',
        (tester) async {
      final api = FakeVendorRepository()
        ..startFailure = const AuthFailure(AuthFailureKind.suspended);
      final app = await pumpApp(tester, startAs: StartAs.signedOut, api: api);
      await typePhone(tester, '712345678');
      expect(path(app), MNRoutes.suspended);
      expect(find.text('Akaunti imesimamishwa'), findsOneWidget);
      app.router.go(MNRoutes.home);
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.suspended);
      await tester.tap(find.text('Rudi mwanzo'));
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.login);
    });
  });

  group('profile', () {
    testWidgets('logout asks first, then ends the session', (tester) async {
      final app = await pumpApp(tester, initial: MNRoutes.profile);
      await tester.tap(find.text('Toka kwenye akaunti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghairi'));
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.profile);

      await tester.tap(find.text('Toka kwenye akaunti'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(MNAccountSignOutSheet),
          matching: find.text('Toka kwenye akaunti')));
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.login);
      expect(app.store.values['session_token'], isNull);
      expect(app.api.calls, contains('signOut'));
    });

    testWidgets('change PIN: a wrong current PIN starts over; then success',
        (tester) async {
      final app = await pumpApp(tester, initial: MNRoutes.profile);
      await tester.tap(find.text('Badilisha PIN'));
      await tester.pumpAndSettle();
      expect(path(app), MNRoutes.changePin);
      await typeKeys(tester, '1357'); // wrong current
      await typeKeys(tester, '4071');
      await typeKeys(tester, '4071');
      expect(find.text('PIN ya sasa'), findsOneWidget);
      expect(find.text('PIN si sahihi. Jaribu tena.'), findsOneWidget);

      await typeKeys(tester, '2580');
      await typeKeys(tester, '4071');
      await typeKeys(tester, '4071');
      expect(find.text('PIN imebadilishwa'), findsOneWidget);
      expect(path(app), MNRoutes.profile);
      expect(app.api.pin, '4071');
    });
  });
}
