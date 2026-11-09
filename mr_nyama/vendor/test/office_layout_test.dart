import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository, enterPin;

void main() {
  for (final size in [const Size(320, 568), const Size(768, 1024)]) {
    testWidgets('office pages fit $size at enlarged text', (tester) async {
      final office = FakeOfficeRepository()
        ..signedIn = true
        ..productsList.add(const OfficeProduct(
            code: 'KUKU',
            name: 'Kuku wa kuchoma',
            category: 'kuku',
            unit: 'bird',
            price: 100000000))
        ..staffList.add(const OfficeStaff(
            id: 'worker',
            name: 'Asha',
            phone: '+255712345678',
            roles: ['kitchen_staff'],
            activated: true,
            suspended: false));
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut, office: office, size: size, textScale: 2);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(office.owner);
      await tester.pumpAndSettle();
      for (final route in [
        MNRoutes.office,
        MNRoutes.officeVendors,
        MNRoutes.officeStaff,
        MNRoutes.officeStations,
        MNRoutes.officeNewVendor,
        MNRoutes.officeNewStaff,
        MNRoutes.officeProducts,
        MNRoutes.officeProduct("KUKU"),
        MNRoutes.officeStaffStations("worker"),
      ]) {
        app.router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }

  testWidgets('capture owner login and home previews', (tester) async {
    final office = FakeOfficeRepository();
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary));
      final image =
          (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
      final bytes = await tester
          .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      await tester.runAsync(() async {
        final dir = Directory('../../output/vendor-screen-previews');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    await capture('owner-entry');
    app.router.push(MNRoutes.officeSignIn);
    await capture('owner-login');
    await tester.enterText(find.byType(TextField), '746484666');
    await tester.pump();
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    await capture('owner-pin');
    await enterPin(tester, '4826');
    await capture('owner-home');
    office.productsList.add(const OfficeProduct(
        code: 'KUKU',
        name: 'Kuku wa kuchoma',
        category: 'kuku',
        unit: 'bird',
        price: 9000,
        available: true,
        imageKey: 'kidali'));
    office.pricesList.addAll([
      const OfficeStationPrice('a', 'Kariakoo', 9000, false),
      const OfficeStationPrice('b', 'Sinza', 10000, true),
    ]);
    office.staffList.add(const OfficeStaff(
        id: 'worker',
        name: 'Asha Juma',
        phone: '+255712345678',
        roles: ['kitchen_staff'],
        stationIds: ['s1'],
        activated: true,
        suspended: false));
    app.router.push(MNRoutes.officeProducts);
    await capture('owner-products');
    app.router.push(MNRoutes.officeProduct('KUKU'));
    await capture('owner-product-editor');
    app.router.go(MNRoutes.officeStaffStations('worker'));
    await capture('owner-staff-stations');
  });
}
