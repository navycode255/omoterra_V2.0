import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'office_delivery_entry_test.dart' show openForm, choose;

// Development-only fixtures: no operational records are submitted.
void main() {
  testWidgets('receiving form and selection sheet preview', (tester) async {
    await openForm(tester, lots: const [], locations: const []);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      final image =
          (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
      final bytes = await tester
          .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      await tester.runAsync(() async {
        final dir = Directory('../../output/receiving-refinement');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    await choose(tester, 0, 'Vimeandaliwa na timu yetu');
    await capture('prepared-form');
    final field = find.byType(MNSelectField<String>).first;
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await capture('source-options');
    expect(tester.takeException(), isNull);
  });
}
