import 'package:mr_nyama_vendor/shared/widgets/account.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/vendor_reference.dart';
import 'package:mr_nyama_vendor/shared/widgets/workflow_header.dart';

import 'helpers.dart';
import 'history_flow_test.dart' as history;
import 'receiving_flow_test.dart' as receiving;

// In-memory fixtures only. Captures are optional development artifacts.
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('VENDOR_DESIGN_CAPTURES')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final data = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('build/vendor-design-2026-10-27/previews');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in ['profile', 'sync', 'sale', 'delivery']) {
        testWidgets('$page at ${size.width} and text scale $scale',
            (tester) async {
          final api = FakeVendorRepository()
            ..deliveryList = [receiving.delivery()];
          final app = await pumpApp(tester,
              api: api, now: history.now, size: size, textScale: scale);
          if (page == 'sale') {
            await history.record(app, 'design-sale', history.now);
          }
          app.router.push(switch (page) {
            'profile' => MNRoutes.profile,
            'sync' => MNRoutes.sync,
            'sale' => MNRoutes.saleDetail('design-sale'),
            _ => MNRoutes.delivery('c1'),
          });
          await tester.pumpAndSettle();
          expect(find.byType(MNWorkflowHeader), findsOneWidget);
          expect(
              find.byType(
                  page == 'profile' ? MNAccountGroup : MNReferenceSurface),
              findsWidgets);
          expect(tester.takeException(), isNull);
          if (size.width == 390 && scale == 1) {
            await capture(tester, page);
          }
          // Check the remainder of the scrollable content as well.
          await tester.drag(find.byType(ListView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
