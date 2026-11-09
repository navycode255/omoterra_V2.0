import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart'
    show IssuedCodeArgs;
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

Future<void> issued(WidgetTester tester,
    {Size size = const Size(390, 844), double scale = 1}) async {
  final office = FakeOfficeRepository()..signedIn = true;
  final app = await pumpApp(tester,
      office: office, startAs: StartAs.signedOut, size: size, textScale: scale);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  app.router.push(MNRoutes.officeIssuedCode,
      extra: const IssuedCodeArgs(
          name: 'Amiri', code: IssuedCode('918705', 24), staff: false));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 585),
    const Size(390, 844)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('issued code fits $size at text scale $scale',
          (tester) async {
        await issued(tester, size: size, scale: scale);
        expect(find.text('Mpe Amiri namba hii'), findsOneWidget);
        expect(find.text('Nimemaliza'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('copy success appears inline only after clipboard accepts digits',
      (tester) async {
    await issued(tester);
    expect(find.text('Namba imenakiliwa.'), findsNothing);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await tester.tap(find.bySemanticsLabel('Nakili namba'));
    await tester.pumpAndSettle();
    expect(copied, '918705');
    expect(find.text('Namba imenakiliwa.'), findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    final image =
        (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    final bytes = await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    await tester.runAsync(() async {
      final dir = Directory('../../output/issued-code-refinement');
      await dir.create(recursive: true);
      await File('${dir.path}/issued-code.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
  });
  testWidgets('clipboard failure does not claim the code was copied',
      (tester) async {
    await issued(tester);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    await tester.tap(find.bySemanticsLabel('Nakili namba'));
    await tester.pumpAndSettle();
    expect(find.text('Namba imenakiliwa.'), findsNothing);
    expect(find.text('Imeshindikana kunakili. Jaribu tena.'), findsOneWidget);
  });
}
