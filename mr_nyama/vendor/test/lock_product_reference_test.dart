import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/biometrics.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'helpers.dart';
import 'auth_test.dart' show typePhone, typeKeys;
import 'biometrics_test.dart' show FakeBiometrics, enable;
import 'owner_catalogue_test.dart' as catalogue;
import 'office_design_helpers.dart';
import 'station_management_test.dart' show StationOffice;

Future<void> iconFont(WidgetTester tester) async {
  if (!const bool.fromEnvironment('REFERENCE_CAPTURES')) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await tester.runAsync(loader.load);
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('REFERENCE_CAPTURES')) return;
  // Capture the full view, including sheets, rather than an image's internal
  // repaint boundary after its asynchronous decode has completed.
  RenderObject? node = tester.renderObject(find.byType(Scaffold).first);
  RenderRepaintBoundary? rootBoundary;
  while (node != null) {
    if (node is RenderRepaintBoundary) rootBoundary = node;
    node = node.parent;
  }
  final boundary = rootBoundary!;
  boundary.markNeedsPaint();
  await tester.pump();
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../reviews/2026-10-29/lock-product-reference');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  for (final language in ['sw', 'en']) {
    testWidgets(
        'product reference preserves pristine, changed and confirmation states in $language',
        (tester) async {
      await iconFont(tester);
      final repo = catalogue.office();
      final app =
          await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(repo.owner);
      app.container.read(languageProvider.notifier).state = language;
      await tester.pumpAndSettle();
      app.router.push(MNRoutes.officeProduct('KUKU'));
      await tester.pumpAndSettle();
      final s = Strings(language);
      if (const bool.fromEnvironment('REFERENCE_CAPTURES')) {
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/owner/mzima.png'),
            tester.element(find.byType(Scaffold).last)));
        await tester.pumpAndSettle();
      }
      expect(
          tester
              .widget<MNButton>(find.widgetWithText(MNButton, s.saveChanges))
              .onPressed,
          isNull);
      await capture(tester, 'product-pristine-$language');
      await catalogue.reveal(tester, find.text(s.defaultPrice));
      await tester.tap(find.text(s.defaultPrice));
      await tester.pumpAndSettle();
      await tester.enterText(catalogue.sheetFields().first, '10000');
      await tester.tap(find.text(s.productApplyDraft).last);
      await tester.pumpAndSettle();
      await catalogue.reveal(tester, find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first,
          language == 'sw' ? 'Marekebisho ya bei' : 'Price update');
      await tester.pumpAndSettle();
      expect(repo.priceWrites, isEmpty);
      expect(
          tester
              .widget<MNButton>(find.widgetWithText(MNButton, s.saveChanges))
              .onPressed,
          isNotNull);
      await capture(tester, 'product-changed-$language');
      await catalogue.reveal(tester, find.text(s.productDisable));
      await tester.tap(find.text(s.productDisable));
      await tester.pumpAndSettle();
      expect(find.text(s.productDisableTitle('Kuku mzima')), findsOneWidget);
      await capture(tester, 'product-confirm-$language');
      expect(repo.productsList.single.status, 'active');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'branded lock, prompt and failure retain secure local authorization in $language',
        (tester) async {
      await iconFont(tester);
      final bio = FakeBiometrics()..pending = Completer<bool>();
      final app = await pumpApp(tester,
          overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)]);
      app.container.read(languageProvider.notifier).state = language;
      await enable(app, tester, biometricAccount('vendor', testProfile.id));
      final s = Strings(language);
      await capture(tester, 'locked-$language');
      await tester.tap(find.text(s.biometricUnlock));
      await tester.pump(const Duration(milliseconds: 250));
      await capture(tester, 'biometric-prompt-$language');
      bio.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(find.text(s.lockFailedTitle), findsOneWidget);
      await capture(tester, 'biometric-failed-$language');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('light login, round PIN keypad and a real retry deadline',
      (tester) async {
    await iconFont(tester);
    final api = FakeVendorRepository();
    await pumpApp(tester, startAs: StartAs.signedOut, api: api);
    await capture(tester, 'login-phone');
    await typePhone(tester, '712345678');
    await capture(tester, 'login-pin');
    await typeKeys(tester, '1357');
    await capture(tester, 'incorrect-pin');
    api.signInFailure = AuthFailure(AuthFailureKind.locked,
        retryAfter: DateTime.now().add(const Duration(minutes: 5)));
    await typeKeys(tester, '2580');
    expect(find.text(const Strings('sw').pinWait), findsOneWidget);
    await capture(tester, 'pin-lockout');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'expected deliveries show summaries before quantities and actions',
      (tester) async {
    final repo = StationOffice();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    app.router.go(MNRoutes.officeStock('s1'));
    await tester.pumpAndSettle();
    const s = Strings('sw');
    await tester.ensureVisible(find.text(s.stationExpectedLoads));
    await tester.tap(find.text(s.stationExpectedLoads));
    await tester.pumpAndSettle();
    expect(find.text('DN-01'), findsOneWidget);
    expect(find.text(s.stationEditDelivery), findsNothing);
    await capture(tester, 'expected-deliveries');
    await expandOfficeDetails(tester, s.recordDetails);
    expect(find.text(s.stationEditDelivery), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
