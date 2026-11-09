import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';

import 'auth_test.dart' show typeKeys, path;
import 'helpers.dart';

/// Every state of the owner-approved Badilisha PIN reference (30 October
/// 2026). `--dart-define=REFERENCE_CAPTURES=true` also writes each to
/// output/change-pin-reference for comparing against the supplied image.
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('REFERENCE_CAPTURES')) return;
  await tester.runAsync(() => precacheImage(
      const AssetImage('assets/brand/logo.png'),
      tester.element(find.byType(Scaffold).first)));
  await tester.pump();
  RenderObject? node = tester.renderObject(find.byType(Scaffold).first);
  RenderRepaintBoundary? root;
  while (node != null) {
    if (node is RenderRepaintBoundary) root = node;
    node = node.parent;
  }
  final image = (await tester.runAsync(() => root!.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/change-pin-reference');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

Future<TestApp> open(WidgetTester tester, {FakeVendorRepository? api}) async {
  final app = await pumpApp(tester,
      initial: MNRoutes.profile, api: api, size: const Size(390, 863));
  tester.view
    ..padding = const FakeViewPadding(top: 47, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  app.router.push(MNRoutes.changePin);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('three steps, wrong PIN, mismatch: each state of the reference',
      (tester) async {
    final app = await open(tester);
    expect(find.text('PIN ya sasa'), findsOneWidget);
    expect(find.text('Hatua ya 1 kati ya 3'), findsOneWidget);
    expect(find.text('Umesahau PIN?'), findsOneWidget);
    await capture(tester, '1-pin-ya-sasa');

    await typeKeys(tester, '13');
    await capture(tester, '2-inaingizwa');
    await typeKeys(tester, '57');

    expect(find.text('PIN mpya'), findsOneWidget);
    expect(find.text('Hatua ya 2 kati ya 3'), findsOneWidget);
    expect(find.text('Umesahau PIN?'), findsNothing);
    await capture(tester, '4-pin-mpya');
    await typeKeys(tester, '4071');

    expect(find.text('Thibitisha PIN mpya'), findsOneWidget);
    expect(find.text('Hatua ya 3 kati ya 3'), findsOneWidget);
    await typeKeys(tester, '4072');
    // A mismatch stays on step 3 with the dots empty.
    expect(find.text('Thibitisha PIN mpya'), findsOneWidget);
    expect(find.text('PIN hazifanani. Jaribu tena.'), findsOneWidget);
    expect(tester.widget<MNPinDots>(find.byType(MNPinDots)).filled, 0);
    await capture(tester, '5-pin-hazifanani');

    await typeKeys(tester, '4071');
    // The wrong current PIN comes back on step 1.
    expect(find.text('PIN ya sasa'), findsOneWidget);
    expect(find.text('Hatua ya 1 kati ya 3'), findsOneWidget);
    expect(find.text('PIN si sahihi. Jaribu tena.'), findsOneWidget);
    await capture(tester, '3-pin-si-sahihi');

    await typeKeys(tester, '2');
    expect(find.text('PIN si sahihi. Jaribu tena.'), findsNothing);
    await typeKeys(tester, '580');
    await typeKeys(tester, '4071');
    await typeKeys(tester, '4071');
    expect(app.api.pin, '4071');
    expect(path(app), MNRoutes.profile);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back returns one step, then leaves', (tester) async {
    final app = await open(tester);
    await typeKeys(tester, '2580');
    await typeKeys(tester, '4071');
    expect(find.text('Thibitisha PIN mpya'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Rudi'));
    await tester.pumpAndSettle();
    expect(find.text('PIN mpya'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Rudi'));
    await tester.pumpAndSettle();
    expect(find.text('PIN ya sasa'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Rudi'));
    await tester.pumpAndSettle();
    expect(path(app), MNRoutes.profile);
  });

  testWidgets('too many tries grey the pad and count down', (tester) async {
    final api = FakeVendorRepository()
      ..changePinFailure = AuthFailure(AuthFailureKind.locked,
          retryAfter: DateTime.now().add(const Duration(seconds: 299)));
    await open(tester, api: api);
    await typeKeys(tester, '2580');
    await typeKeys(tester, '4071');
    await typeKeys(tester, '4071');
    await tester.pump();
    expect(find.text('Subiri kidogo'), findsOneWidget);
    expect(find.text('Jaribio limezuiwa kwa muda'), findsOneWidget);
    expect(
        find.text('PIN na biometrics vimesitishwa kwa muda.'), findsOneWidget);
    expect(find.textContaining('Jaribu tena baada ya 4:5'), findsOneWidget);
    expect(find.text('Umesahau PIN?'), findsNothing);
    final filled = api.calls.length;
    await tester.tap(
        find.descendant(of: find.byType(MNPinKeypad), matching: find.text('1')),
        warnIfMissed: false);
    await tester.pump();
    expect(api.calls.length, filled);
    await capture(tester, '6-imefungwa-kwa-muda');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('forgot PIN explains who helps', (tester) async {
    await open(tester);
    await tester.tap(find.text('Umesahau PIN?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mwombe msimamizi'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(360, 640)]) {
    testWidgets('fits $size with large text', (tester) async {
      final app = await pumpApp(tester,
          initial: MNRoutes.profile, size: size, textScale: 1.6);
      app.router.push(MNRoutes.changePin);
      await tester.pumpAndSettle();
      expect(find.text('PIN ya sasa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
