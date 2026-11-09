import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/production_screens.dart';
import 'package:mr_nyama_vendor/features/office/sync_review_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

import 'helpers.dart';
import 'office_stock_production_test.dart' show stockOffice;
import 'office_verification_test.dart' show openAs, verificationOffice;
import 'receiving_flow_test.dart' show openReceiving;

/// The screens with their own empty illustration: one picture and one title.
/// `--dart-define=REFERENCE_CAPTURES=true` writes each to
/// output/empty-states-reference.
const _captures = bool.fromEnvironment('REFERENCE_CAPTURES');
const sw = Strings('sw');

Future<void> capture(WidgetTester tester, String name) async {
  if (!_captures) return;
  final image = tester.widget<Image>(find.descendant(
      of: find.byType(MNEmptyState), matching: find.byType(Image)));
  await tester.runAsync(() =>
      precacheImage(image.image, tester.element(find.byType(MNEmptyState))));
  await tester.pump(const Duration(milliseconds: 400));
  RenderObject? node = tester.renderObject(find.byType(MNEmptyState));
  RenderRepaintBoundary? root;
  while (node != null) {
    if (node is RenderRepaintBoundary) root = node;
    node = node.parent;
  }
  final shot = (await tester.runAsync(() => root!.toImage(pixelRatio: 1)))!;
  final bytes = await tester
      .runAsync(() => shot.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/empty-states-reference');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  shot.dispose();
}

void expectOnlyTitle(WidgetTester tester, String image, String title) {
  final state = tester.widget<MNEmptyState>(find.byType(MNEmptyState));
  expect(state.image, 'assets/errors/$image');
  expect(state.title, title);
  expect(state.message, isNull);
  expect(state.action, isNull);
}

void main() {
  testWidgets('production: the picture, and the button at the bottom',
      (tester) async {
    await openAs(tester, stockOffice(),
        roles: const ['business_owner'],
        route: MNRoutes.officeProduction,
        size: const Size(390, 800),
        overrides: [productionRunsProvider.overrideWith((ref) async => [])]);
    expectOnlyTitle(tester, 'production_state.png', sw.productionNone);
    final button =
        tester.getTopLeft(find.widgetWithText(MNButton, sw.productionRecord));
    expect(button.dy,
        greaterThan(tester.getBottomLeft(find.text(sw.productionNone)).dy));
    expect(button.dy, greaterThan(640));
    await capture(tester, 'production');
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone records', (tester) async {
    await openAs(tester, verificationOffice(),
        roles: const ['business_owner'],
        route: MNRoutes.officeSyncConflicts,
        size: const Size(390, 800),
        overrides: [syncConflictsProvider.overrideWith((ref) async => [])]);
    expectOnlyTitle(tester, 'phone_records_state.png', sw.syncConflictsEmpty);
    await capture(tester, 'phone-records');
  });

  testWidgets('sales waiting for verification', (tester) async {
    await openAs(tester, verificationOffice()..salesList.clear(),
        roles: const ['supervisor'],
        route: MNRoutes.officeVerificationStation('s1'),
        size: const Size(390, 900));
    expectOnlyTitle(
        tester, 'sales_verification_state.png', sw.noUnverifiedSales);
    await capture(tester, 'sales');
  });

  testWidgets('damage reports', (tester) async {
    await pumpApp(tester, initial: MNRoutes.damaged);
    await tester.pumpAndSettle();
    expectOnlyTitle(tester, 'damage_state.png', sw.noDamageReports);
    expect(find.widgetWithText(MNButton, sw.reportDamage), findsOneWidget);
    await capture(tester, 'damage');
  });

  testWidgets('deliveries waiting', (tester) async {
    await openReceiving(tester, deliveries: []);
    expectOnlyTitle(tester, 'delivery_state.png', sw.noDeliveries);
    await capture(tester, 'delivery');
  });
}
