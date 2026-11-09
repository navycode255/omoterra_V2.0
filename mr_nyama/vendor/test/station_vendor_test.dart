import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart'
    show OfficeIssuedCodeScreen;
import 'package:mr_nyama_vendor/features/office/person_screens.dart';
import 'helpers.dart';
import 'station_management_test.dart' show StationOffice;

/// A station with Amiri selling there and Ramadhani supervising it.
class PeopleStation extends StationOffice {
  final ended = <String, String>{};
  PeopleStation() {
    vendorsList.add(OfficeVendor(
        id: 'amiri',
        name: 'Amiri',
        phone: '+255712345678',
        activated: true,
        suspended: false,
        stationId: 's1',
        stationName: 'Bunju B',
        stationCode: 'MR01',
        stationSince: DateTime(2026, 10, 12, 9)));
    staffList.add(const OfficeStaff(
        id: 'ramadhani',
        name: 'Ramadhani',
        phone: '+255713000111',
        roles: [StaffRole.supervisor],
        stationIds: ['s1'],
        activated: true,
        suspended: false));
  }

  @override
  Future<void> endVendorStation(String id, String reason) async {
    ended[id] = reason;
    final i = vendorsList.indexWhere((v) => v.id == id);
    final old = vendorsList[i];
    vendorsList[i] = OfficeVendor(
        id: old.id,
        name: old.name,
        phone: old.phone,
        activated: old.activated,
        suspended: old.suspended);
  }
}

Future<TestApp> station(WidgetTester tester, PeopleStation repo,
    {Size size = const Size(390, 844), double scale = 1}) async {
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut, office: repo, size: size, textScale: scale);
  await app.container.read(officeSessionProvider.notifier).signedIn(repo.owner);
  app.router.go(MNRoutes.officeStation('s1'));
  await tester.pumpAndSettle();
  return app;
}

Future<void> shoot(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/station-people-previews');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  testWidgets('station lists its people without repeating the station code',
      (tester) async {
    await station(tester, PeopleStation());
    expect(find.text('Maelezo ya kituo'), findsOneWidget);
    expect(find.text('Kituo MR01'), findsOneWidget);
    expect(find.text('Namba ya kituo'), findsNothing);
    expect(find.text('Amiri'), findsOneWidget);
    expect(find.text('Ramadhani'), findsOneWidget);
    expect(find.text('Msimamizi'), findsOneWidget);
    await shoot(tester, '1-station');
    await tester.ensureVisible(find.text('Ongeza').first);
    await tester.tap(find.text('Ongeza').first);
    await tester.pumpAndSettle();
    expect(find.text('Panga mtu kituoni'), findsOneWidget);
    expect(find.text('Anauza kituoni'), findsOneWidget);
    expect(find.text('Anasimamia kituo'), findsOneWidget);
    await shoot(tester, '2-assign-sheet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a vendor opened from the station shows the basic details',
      (tester) async {
    await station(tester, PeopleStation());
    await tester.tap(find.text('Amiri'));
    await tester.pumpAndSettle();
    expect(find.byType(StationVendorScreen), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('Maelezo ya msingi'), findsOneWidget);
    expect(find.text('Namba ya simu'), findsOneWidget);
    expect(find.text('+255 712 345 678'), findsOneWidget);
    expect(find.text('Jukumu'), findsOneWidget);
    expect(find.text('Bunju B (MR01)'), findsOneWidget);
    expect(find.text('Alianza'), findsOneWidget);
    expect(find.text('12 Okt 2026'), findsOneWidget);
    expect(find.text('Ondoa kwenye kituo'), findsOneWidget);
    await shoot(tester, '3-person');
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing ends only the placement and returns to the station',
      (tester) async {
    final repo = PeopleStation();
    await station(tester, repo);
    await tester.tap(find.text('Amiri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ondoa kwenye kituo'));
    await tester.pumpAndSettle();
    expect(find.text('Ondoa Amiri kwenye Bunju B?'), findsOneWidget);
    expect(
        find.text('Atatolewa kwenye kituo hiki tu. Akaunti yake na historia '
            'ya mauzo itabaki salama.'),
        findsOneWidget);
    await shoot(tester, '4-remove-sheet');
    // Ghairi keeps the vendor in place.
    await tester.tap(find.text('Ghairi'));
    await tester.pumpAndSettle();
    expect(repo.ended, isEmpty);
    expect(find.byType(StationVendorScreen), findsOneWidget);
    await tester.tap(find.text('Ondoa kwenye kituo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ondoa kwenye kituo').last);
    await tester.pumpAndSettle();
    expect(repo.ended.keys, ['amiri']);
    expect(find.byType(StationVendorScreen), findsNothing);
    expect(find.text('Maelezo ya kituo'), findsOneWidget);
    expect(find.text('Amiri'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more options give a sign-in code once', (tester) async {
    await station(tester, PeopleStation());
    await tester.tap(find.text('Amiri'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Chaguo zaidi'));
    await tester.pumpAndSettle();
    expect(find.text('Wasifu kamili'), findsOneWidget);
    await tester.tap(find.text('Toa namba ya kubadili PIN'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeIssuedCodeScreen), findsOneWidget);
    expect(find.text('Mpe Amiri namba hii'), findsOneWidget);
    await tester.tap(find.text('Nimemaliza'));
    await tester.pumpAndSettle();
    expect(find.byType(StationVendorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(768, 1024)]) {
    testWidgets('person page and remove sheet fit $size at large text',
        (tester) async {
      await station(tester, PeopleStation(), size: size, scale: 2);
      await tester.ensureVisible(find.text('Amiri'));
      await tester.tap(find.text('Amiri'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ondoa kwenye kituo'));
      await tester.tap(find.text('Ondoa kwenye kituo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
