import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/shared/widgets/workflow_header.dart';
import 'package:mr_nyama_vendor/shared/widgets/app_header.dart';
import 'helpers.dart';
import 'damage_closing_flow_test.dart' show reportDamage, tapText;
import 'receiving_flow_test.dart' show delivery;

const sw = Strings('sw');
final now = DateTime.utc(2026, 10, 26, 10);

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['MN_DAMAGE_PREVIEWS'] != '1') return;
  await tester.pumpAndSettle();
  final boundary = tester
      .firstRenderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final picture =
      (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => picture.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final folder = Directory('build/damage-clean-validation/previews');
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  picture.dispose();
}

void main() {
  testWidgets(
      'damage screens are light; explanations and record details open on request',
      (tester) async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final app = await pumpApp(tester,
        now: now, api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    app.router.push(MNRoutes.damaged);
    await tester.pumpAndSettle();
    expect(find.byType(MNWorkflowHeader), findsOneWidget);
    expect(find.byType(MNAppHeader), findsNothing);
    expect(find.text(sw.reportNotLoss), findsNothing);
    await capture(tester, 'empty');
    await tapText(tester, sw.reportDamage);
    await capture(tester, 'products');
    await tapText(tester, 'Kuku mzima');
    await capture(tester, 'quantity');
    await tapText(tester, sw.continueAction);
    await capture(tester, 'reason');
    await tapText(tester, 'Imeungua');
    await tapText(tester, sw.continueAction);
    expect(find.text(sw.reportNotLoss), findsNothing);
    await capture(tester, 'review');
    await tapText(tester, sw.submitReport);
    expect(find.text(sw.savedOnPhone), findsOneWidget);
    expect(find.text('Inasubiri kutumwa'), findsOneWidget);
    await capture(tester, 'saved');
    await tapText(tester, sw.back);
    expect(find.text('Imeungua'), findsNothing);
    expect(find.text('Kuku mzima × 1'), findsOneWidget);
    await capture(tester, 'history');
    await tapText(tester, 'Kuku mzima × 1');
    expect(find.text('Imeungua'), findsOneWidget);
    expect(find.text(sw.reportNotLoss), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'routine guidance stays behind Help on expense, receipt and closing screens',
      (tester) async {
    final app = await pumpApp(tester,
        now: now,
        api: FakeVendorRepository()
          ..catalogSnapshot = testCatalog
          ..deliveryList = [delivery()]);
    for (final (route, text) in [
      (MNRoutes.expenses, sw.vendorExpenseApprovalNote),
      (MNRoutes.receive, sw.receiveTransferHelp),
      (MNRoutes.closeDay, sw.closingOnlyCount),
      (MNRoutes.sync, sw.correctionsByOffice),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(find.text(text), findsNothing, reason: route);
      await tester.tap(find.byTooltip(sw.help));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget, reason: route);
      await tester.tapAt(const Offset(20, 100));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('full damage workflow fits 320px with double text',
      (tester) async {
    final app = await pumpApp(tester,
        now: now,
        size: const Size(320, 568),
        textScale: 2,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    app.router.push(MNRoutes.damaged);
    await tester.pumpAndSettle();
    await reportDamage(tester);
    expect(tester.takeException(), isNull);
    await tapText(tester, sw.submitReport);
    expect(tester.takeException(), isNull);
    await tapText(tester, sw.back);
    expect(tester.takeException(), isNull);
  });
}
