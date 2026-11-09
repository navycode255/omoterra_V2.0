import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/biometrics.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'auth_test.dart' show typeKeys;
import 'biometrics_test.dart' show FakeBiometrics, enable;
import 'fingerprint_sign_in_test.dart' show KeyedOffice;
import 'helpers.dart';
import 'lock_product_reference_test.dart' show iconFont;

const s = Strings('sw');

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('REFERENCE_CAPTURES')) return;
  await tester.runAsync(() => precacheImage(
      const AssetImage('assets/brand/icon.png'),
      tester.element(find.byType(Scaffold).first)));
  await tester.pumpAndSettle();
  RenderObject? node = tester.renderObject(find.byType(Scaffold).first);
  RenderRepaintBoundary? root;
  while (node != null) {
    if (node is RenderRepaintBoundary) root = node;
    node = node.parent;
  }
  root!.markNeedsPaint();
  await tester.pump();
  final image = (await tester.runAsync(() => root!.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../reviews/2026-10-30/lock-showcase');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  testWidgets(
      'explicit PIN choice stays on PIN; fingerprint retries and lockout disables it',
      (tester) async {
    await iconFont(tester);
    final bio = FakeBiometrics()..answer = false;
    final api = FakeVendorRepository();
    final app = await pumpApp(tester, api: api, overrides: [
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    await enable(app, tester, biometricAccount('vendor', testProfile.id));
    await capture(tester, 'locked');
    await tester.tap(find.text(s.biometricUnlock));
    await tester.pumpAndSettle();
    expect(find.text(s.lockFailedTitle), findsOneWidget);
    await capture(tester, 'biometric-failed');
    await tester.tap(find.text(s.biometricUsePin));
    await tester.pumpAndSettle();
    expect(bio.prompts, 1); // Choosing PIN does not reopen the OS prompt.
    expect(find.text(s.pinTitle), findsOneWidget);
    expect(tester.widget<MNPinKeypad>(find.byType(MNPinKeypad)).tiles, isTrue);
    await capture(tester, 'pin-empty');
    await typeKeys(tester, '13');
    await capture(tester, 'pin-partial');
    await typeKeys(tester, '57');
    expect(find.text(s.pinWrong), findsOneWidget);
    await capture(tester, 'pin-wrong');
    bio.pending = Completer<bool>();
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pump();
    expect(
        tester.widget<MNPinKeypad>(find.byType(MNPinKeypad)).enabled, isFalse);
    bio.pending!.complete(false);
    await tester.pumpAndSettle();
    api.signInFailure = AuthFailure(AuthFailureKind.locked,
        retryAfter: DateTime.now().add(const Duration(minutes: 5)));
    await typeKeys(tester, '2580');
    expect(find.text(s.pinWait), findsOneWidget);
    expect(find.text(s.biometricPaused), findsOneWidget);
    final prompts = bio.prompts;
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pump();
    expect(bio.prompts, prompts);
    expect(app.container.read(sessionProvider).valueOrNull, isA<Locked>());
    await capture(tester, 'pin-locked-out');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('office PIN fallback retains its enrolled fingerprint action',
      (tester) async {
    final bio = FakeBiometrics();
    final office = KeyedOffice()..signedIn = true;
    final app = await pumpApp(tester,
        startAs: StartAs.signedOut,
        office: office,
        overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)]);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await app.container.read(officeSessionProvider.notifier).rememberDevice();
    await enable(app, tester, biometricAccount('staff', office.owner.id));
    await tester.tap(find.text(s.biometricUsePin));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(bio.prompts, 0);
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(bio.prompts, 1);
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedIn>());
  });
}
