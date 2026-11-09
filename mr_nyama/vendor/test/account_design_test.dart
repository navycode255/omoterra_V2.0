import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/shared/widgets/account.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

Future<TestApp> openAccount(WidgetTester tester,
    {required bool office,
    String language = 'sw',
    Size size = const Size(390, 844),
    double scale = 1}) async {
  final repo = FakeOfficeRepository()..signedIn = true;
  final app = await pumpApp(tester,
      startAs: office ? StartAs.signedOut : StartAs.signedIn,
      initial: office ? null : MNRoutes.profile,
      office: repo,
      size: size,
      textScale: scale,
      overrides: [languageProvider.overrideWith((ref) => language)]);
  if (office) {
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings(language).ownerAccount).last);
    await tester.pumpAndSettle();
  }
  return app;
}

Future<void> openSignOut(WidgetTester tester, Strings s) async {
  final action = find.descendant(
      of: find.byType(MNAccountSignOut), matching: find.text(s.logout));
  if (action.evaluate().isEmpty) {
    await tester.scrollUntilVisible(action, 200,
        scrollable: find.byType(Scrollable).first);
  } else {
    await tester.ensureVisible(action);
  }
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Finder sheetText(String text) => find.descendant(
    of: find.byType(MNAccountSignOutSheet), matching: find.text(text));
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('ACCOUNT_CAPTURES')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../reviews/2026-10-28/account');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  for (final office in [false, true]) {
    for (final language in ['sw', 'en']) {
      testWidgets(
          '${office ? 'office' : 'vendor'} account confirms/cancels sign-out in $language',
          (tester) async {
        final app = await openAccount(tester,
            office: office, language: language, size: const Size(390, 1152));
        final s = Strings(language);
        final name = tester.widget<Text>(
            find.text(office ? 'Maternus Joshua' : 'Asha Mussa').first);
        expect(name.style?.fontFamily, office ? 'Inter' : 'Manrope');
        if (!office) {
          expect(find.text(s.vendorPayTitle), findsNothing);
          expect(find.text(s.financeBooks), findsNothing);
          expect(find.text(s.vendorSignIn), findsNothing);
        }
        await capture(tester, '${office ? 'office' : 'vendor'}-$language');
        await openSignOut(tester, s);
        expect(find.byType(MNAccountSignOutSheet), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(sheetText(s.logoutConfirm), findsOneWidget);
        expect(sheetText(s.accountSignOutBody), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await capture(
            tester, '${office ? 'office' : 'vendor'}-sign-out-$language');
        await tester.tap(sheetText(s.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(MNAccountSignOutSheet), findsNothing);
        expect(
            office
                ? app.container.read(officeSessionProvider).valueOrNull
                    is OfficeSignedIn
                : app.container.read(sessionProvider).valueOrNull is SignedIn,
            isTrue);
        await openSignOut(tester, s);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MNAccountSignOutSheet), findsNothing);
        expect(
            office
                ? app.container.read(officeSessionProvider).valueOrNull
                    is OfficeSignedIn
                : app.container.read(sessionProvider).valueOrNull is SignedIn,
            isTrue);
        await openSignOut(tester, s);
        await tester.tap(sheetText(s.logout));
        await tester.pumpAndSettle();
        expect(
            office
                ? app.container.read(officeSessionProvider).valueOrNull
                    is OfficeSignedOut
                : app.container.read(sessionProvider).valueOrNull is SignedOut,
            isTrue);
        expect(find.byType(MNAccountSignOutSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
        '${office ? 'office' : 'vendor'} account/sheet fits 320px at double text',
        (tester) async {
      await openAccount(tester,
          office: office, size: const Size(320, 568), scale: 2);
      expect(tester.takeException(), isNull);
      await openSignOut(tester, const Strings('sw'));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(sheetText('Ghairi'));
      await tester.tap(sheetText('Ghairi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'sign-out failure stays open and repeated confirmation submits once',
      (tester) async {
    setScreen(tester);
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: mrNyamaTheme(),
            home: Scaffold(body: MNAccountSignOut(onSignOut: () async {
              calls++;
              if (calls == 1) await pending.future;
            })))));
    const s = Strings('sw');
    await openSignOut(tester, s);
    final button = tester.widget<MNTextButton>(find.descendant(
        of: find.byType(MNAccountSignOutSheet),
        matching: find.byType(MNTextButton)));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls, 1);
    pending.completeError(StateError('fixture refusal'));
    await tester.pumpAndSettle();
    expect(sheetText(s.accountSignOutFailed), findsOneWidget);
    expect(find.byType(MNAccountSignOutSheet), findsOneWidget);
    await tester.tap(sheetText(s.logout));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(MNAccountSignOutSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
