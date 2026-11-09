import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart';
import 'helpers.dart';
import 'office_people_test.dart' show peopleOffice;

// Local fixtures exercise loaded or explicitly unavailable/empty states.
// No production records or operations are submitted.
final officeRoutes = <String>[
  "/ofisi",
  "/ofisi/usimamizi",
  "/ofisi/akaunti",
  "/ofisi/bidhaa/mpya",
  "/ofisi/wauzaji",
  "/ofisi/wauzaji/mpya",
  "/ofisi/wafanyakazi",
  "/ofisi/wafanyakazi/mpya",
  "/ofisi/wauzaji/v1",
  "/ofisi/wafanyakazi/st1",
  "/ofisi/menyu/excel",
  "/ofisi/vituo/s1/menyu",
  "/ofisi/bidhaa",
  "/ofisi/bidhaa/KUKU",
  "/ofisi/wafanyakazi/st1/vituo",
  "/ofisi/vituo/s1",
  "/ofisi/vituo/s1/wauzaji/v1",
  "/ofisi/vituo",
  "/ofisi/uthibitisho",
  "/ofisi/uthibitisho/s1",
  "/ofisi/uthibitisho/s1/matatizo",
  "/ofisi/kumbukumbu-za-simu",
  "/ofisi/kumbukumbu-za-simu/s1",
  "/ofisi/vitabu",
  "/ofisi/vitabu/akaunti",
  "/ofisi/vitabu/mpangilio",
  "/ofisi/vitabu/vipindi",
  "/ofisi/vitabu/daftari",
  "/ofisi/vitabu/ripoti",
  "/ofisi/malipo-wauzaji",
  "/ofisi/malipo-wauzaji/s1",
  "/ofisi/bonasi",
  "/ofisi/bonasi/muuzaji/v1",
  "/ofisi/bonasi/mauzo/s1",
  "/ofisi/mipangilio/utendaji",
  "/ofisi/utendaji",
  "/ofisi/utendaji/muuzaji/s1",
  "/ofisi/utendaji/mfanyakazi/s1",
  "/ofisi/utendaji/kituo/s1",
  "/ofisi/ripoti",
  "/ofisi/fedha",
  "/ofisi/fedha/mipangilio",
  "/ofisi/fedha/s1",
  "/ofisi/fedha/muuzaji/v1",
  "/ofisi/fedha/s1/2026-10-26/v1",
  "/ofisi/mkopo/kituo/s1",
  "/ofisi/mkopo/mteja/s1",
  "/ofisi/stoo/s1",
  "/ofisi/stoo/s1/rudisha",
  "/ofisi/mapishi",
  "/ofisi/mapishi/s1",
  "/ofisi/mapishi/s1/toleo-jipya",
  "/ofisi/uzalishaji",
  "/ofisi/uzalishaji/mpya",
  "/ofisi/uzalishaji/s1",
  "/ofisi/namba-ya-kuingia",
];

Future<TestApp> openOffice(WidgetTester tester,
    {Size size = const Size(390, 844), double scale = 1}) async {
  final repo = peopleOffice()
    ..productsList.add(const OfficeProduct(
        code: 'KUKU',
        name: 'Kuku mzima',
        category: 'kuku',
        unit: 'bird',
        price: 9000,
        available: true));
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut, office: repo, size: size, textScale: scale);
  await app.container.read(officeSessionProvider.notifier).signedIn(repo.owner);
  await tester.pumpAndSettle();
  return app;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('OFFICE_DESIGN_CAPTURES')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('build/office-design-2026-10-27/previews');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  testWidgets('office sign-in uses Inter while vendor sign-in retains Manrope',
      (tester) async {
    final app = await pumpApp(tester, startAs: StartAs.signedOut);
    expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .style
            ?.fontFamily,
        'Manrope');
    app.router.push(MNRoutes.officeSignIn);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .style
            ?.fontFamily,
        'Inter');
    expect(tester.takeException(), isNull);
  });

  testWidgets('all 56 signed-in office routes render a safe page state',
      (tester) async {
    final app = await openOffice(tester);
    for (final route in officeRoutes) {
      app.router.go(route,
          extra: route == MNRoutes.officeIssuedCode
              ? IssuedCodeArgs(
                  name: 'Asha Juma',
                  code: IssuedCode('520588', 24),
                  staff: false)
              : null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      expect(find.byType(Scaffold), findsWidgets, reason: route);
    }
  });
  for (final size in [const Size(320, 568), const Size(768, 1024)]) {
    testWidgets('office editors fit $size with double text', (tester) async {
      final app = await openOffice(tester, size: size, scale: 2);
      for (final route in [
        MNRoutes.officeNewVendor,
        MNRoutes.officeNewStaff,
        MNRoutes.officeNewProduct,
        MNRoutes.officeProduct('KUKU'),
        MNRoutes.officeStaffStations('st1'),
        MNRoutes.officeMenuImport
      ]) {
        app.router.go(route);
        await tester.pumpAndSettle();
        expect(find.byType(OwnerPage), findsOneWidget, reason: route);
        expect(tester.takeException(), isNull, reason: route);
        final fields = find.byType(TextField);
        if (fields.evaluate().isNotEmpty) {
          expect(
              tester.widget<TextField>(fields.first).style?.fontFamily, 'Inter',
              reason: route);
        }
      }
    });
  }
  testWidgets('office form previews and on-route typography', (tester) async {
    final app = await openOffice(tester);
    for (final entry in {
      'new-vendor': MNRoutes.officeNewVendor,
      'new-staff': MNRoutes.officeNewStaff,
      'product-editor': MNRoutes.officeProduct('KUKU'),
      'staff-stations': MNRoutes.officeStaffStations('st1'),
      'excel-import': MNRoutes.officeMenuImport,
    }.entries) {
      app.router.go(entry.value);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, entry.key);
    }
  });
}
