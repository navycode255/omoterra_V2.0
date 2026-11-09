import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_overview.dart';
import 'helpers.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart';
import 'package:mr_nyama_vendor/features/office/person_screens.dart';
import 'package:mr_nyama_vendor/features/office/staff_stations_screen.dart';
import 'package:mr_nyama_vendor/features/office/product_screens.dart';
import 'office_test.dart' show FakeOfficeRepository;

FakeOfficeRepository approvedOffice() => FakeOfficeRepository()
  ..signedIn = true
  ..vendorsList.add(const OfficeVendor(
      id: 'v1',
      name: 'Maternus Joshua',
      phone: '+255746484666',
      activated: true,
      suspended: false))
  ..staffList.add(const OfficeStaff(
      id: 'worker',
      name: 'Maternus Joshua',
      phone: '+255746484666',
      roles: ['business_owner'],
      activated: true,
      suspended: false))
  ..productsList.addAll([
    for (final (i, item) in <(String, int?)>[
      ('Kuku mishkaki', null),
      ('Maini', null),
      ('Ndizi kaanga', null),
      ('Firigisi', 1000),
      ('Kidali', 2500),
      ('Kuku mzima', 9000),
      ('Nusu kuku', 4500),
      ('Paja', 2000),
      ('Shingo', 500),
    ].indexed)
      OfficeProduct(
          code: 'P$i',
          name: item.$1,
          category: 'kuku',
          unit: 'piece',
          price: item.$2,
          available: true),
  ]);

void main() {
  testWidgets('owner fonts use native iOS faces and bundled Inter elsewhere',
      (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      late TextStyle title, body, action;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(builder: (context) {
            title = OwnerStyle.text(context, 31, weight: 700);
            body = OwnerStyle.text(context, 14.5);
            action = OwnerStyle.text(context, 13, weight: 500);
            return const SizedBox();
          })));
      await tester.pumpAndSettle();
      expect(title.fontFamily,
          platform == TargetPlatform.iOS ? 'CupertinoSystemDisplay' : 'Inter');
      expect(body.fontFamily,
          platform == TargetPlatform.iOS ? 'CupertinoSystemText' : 'Inter');
      expect(title.fontWeight, FontWeight.w700);
      expect(body.fontWeight, FontWeight.w400);
      expect(action.fontWeight, FontWeight.w500);
    }
    expect(File('assets/fonts/Inter.ttf').lengthSync(), greaterThan(100000));
    expect(File('assets/fonts/Inter-OFL.txt').readAsStringSync(),
        contains('SIL OPEN FONT LICENSE'));
  });

  testWidgets('every reference icon renders from vectors at multiple sizes',
      (tester) async {
    final names = Directory('assets/owner/icons')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toList();
    expect(names.length, 19); // 14 traced from the references + 5 hand-drawn
    for (final size in [18.0, 27.0, 48.0]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Wrap(children: [
        for (final name in names) OwnerGlyph(name, size: size),
      ]))));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNWidgets(19));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'approved owner references render with live widgets at 863 by 1823',
      (tester) async {
    final repo = approvedOffice()
      ..stationsList.clear()
      ..stationsList.add(const OfficeStation(
          id: 's1', code: 'MR01', name: 'Bunju B', hasVendor: false));
    final app = await pumpApp(tester,
        startAs: StartAs.signedOut,
        office: repo,
        overrides: [
          ownerOverviewProvider.overrideWith((ref) => const AsyncData(
              OwnerOverview(
                  sales: 450000,
                  changePercent: 12,
                  supervisorFunds: 95000,
                  openStations: 8,
                  totalStations: 10)))
        ]);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    tester.view
      ..physicalSize = const Size(863, 1823)
      ..devicePixelRatio = 863 / 390
      ..padding = const FakeViewPadding(top: 80, bottom: 53)
      ..viewPadding = const FakeViewPadding(top: 80, bottom: 53);
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      for (final file in Directory('assets/owner')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))) {
        await precacheImage(AssetImage(file.path), context);
      }
    });
    for (final (name, route) in [
      ('muhtasari', MNRoutes.office),
      ('wauzaji', MNRoutes.officeVendors),
      ('wafanyakazi', MNRoutes.officeStaff),
      ('usimamizi', MNRoutes.officeManagement),
      ('vituo', MNRoutes.officeStations),
      ('bidhaa-na-bei', MNRoutes.officeProducts),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary));
      final rendered = (await tester
          .runAsync(() => boundary.toImage(pixelRatio: 863 / 390)))!;
      final bytes = await tester
          .runAsync(() => rendered.toByteData(format: ui.ImageByteFormat.png));
      await tester.runAsync(() async {
        final dir = Directory('../../output/owner-approved-previews');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      rendered.dispose();
    }
  });

  testWidgets('staff use the approved people layout and keep working actions',
      (tester) async {
    final repo = approvedOffice()
      ..staffList.clear()
      ..staffList.add(const OfficeStaff(
          id: 'worker',
          name: 'Asha Juma',
          phone: '+255712345678',
          roles: ['kitchen_staff'],
          activated: true,
          suspended: false));
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    app.router.go(MNRoutes.officeStaff);
    await tester.pumpAndSettle();
    expect(find.text('Jumla: 1'), findsNothing);
    expect(find.text('Gusa + kusajili mfanyakazi'), findsOneWidget);
    expect(find.text('Jikoni'), findsOneWidget);
    expect(find.text('Hai'), findsOneWidget);
    expect(
        tester.widget<OwnerPage>(find.byType(OwnerPage)).vendorSpacing, isTrue);
    await tester.tap(find.byTooltip('Sajili mfanyakazi'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeNewStaffScreen), findsOneWidget);
    app.router.go(MNRoutes.officeStaff);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asha Juma'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeStaffMemberScreen), findsOneWidget);
    app.router.go(MNRoutes.officeStaff);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Asha Juma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vituo vya kazi'));
    await tester.pumpAndSettle();
    expect(find.byType(StaffStationsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'approved plus buttons and owner navigation open working controls',
      (tester) async {
    final repo = approvedOffice();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    expect(find.text('450,000'),
        findsNothing); // Fixture money never leaks into production.
    // Below the Muhtasari rows (Utendaji, Bonasi) on a phone screen.
    await tester.ensureVisible(find.text('Usimamizi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usimamizi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wauzaji'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeVendorsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Sajili muuzaji'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeNewVendorScreen), findsOneWidget);
    app.router.go(MNRoutes.officeProducts);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ongeza bidhaa'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeNewProductScreen), findsOneWidget);
    expect(find.text('Nambari ya bidhaa'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'Bidhaa mpya');
    await tester.tap(find.byType(MNSelectField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuku').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.productsList.last.code, matches(RegExp(r'^PR-[0-9A-F]{10}$')));
    expect(repo.productsList.last.name, 'Bidhaa mpya');
    expect(find.byType(OfficeProductScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
