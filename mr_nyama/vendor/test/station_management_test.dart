import 'dart:typed_data';

import 'office_design_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/station_screen.dart';
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

class StationOffice extends FakeOfficeRepository
    implements StationManagementRepository {
  final amendments = <List<Map<String, dynamic>>>[];
  final cancellations = <String>[];
  int? expectedVersion;
  bool refuse = false;
  final deliveries = <Map<String, dynamic>>[
    {
      'id': 'delivery',
      'reference': 'DN-01',
      'sender': 'Mtoa bidhaa',
      'status': 'open',
      'version': 1,
      'arrangement': 'A',
      'receipt': null,
      'expected_date': '2026-10-22',
      'lines': [
        {
          'product': 'KUKU',
          'quantity': 10,
          'agreed_unit_price': 6000,
          'accepted': null
        }
      ]
    },
    {
      'id': 'received',
      'reference': 'DN-OLD',
      'sender': 'Mtoa bidhaa',
      'status': 'received',
      'version': 1,
      'arrangement': 'A',
      'receipt': {'id': 'r1'},
      'expected_date': '2026-10-21',
      'lines': [
        {
          'product': 'KUKU',
          'quantity': 8,
          'agreed_unit_price': 6000,
          'accepted': 8
        }
      ]
    },
  ];
  StationOffice() {
    signedIn = true;
    stationsList.clear();
    stationsList.add(const OfficeStation(
        id: 's1',
        code: 'MR01',
        name: 'Bunju B',
        area: 'Bunju',
        address: 'Barabara kuu',
        stockLocationId: 'loc1',
        hasVendor: false));
    vendorsList.add(const OfficeVendor(
        id: 'v1',
        name: 'Juma Ali',
        phone: '+255712345678',
        activated: true,
        suspended: false));
    staffList.add(const OfficeStaff(
        id: 'worker',
        name: 'Asha Juma',
        phone: '+255713345678',
        roles: ['kitchen_staff'],
        stationIds: ['other'],
        activated: true,
        suspended: false));
  }
  @override
  Future<void> updateStation(String id,
      {required String name,
      required String area,
      required String address,
      required String reason}) async {
    if (refuse) throw const OfficeError(OfficeErrorKind.forbidden);
    final old = stationsList.first;
    stationsList[0] = OfficeStation(
        id: id,
        code: old.code,
        name: name,
        area: area,
        address: address,
        stockLocationId: old.stockLocationId,
        hasVendor: old.hasVendor);
  }

  final photoUploads = <Uint8List>[];
  bool photoRemoved = false;

  void _setPhoto(String? url) {
    final old = stationsList.first;
    stationsList[0] = OfficeStation(
        id: old.id,
        code: old.code,
        name: old.name,
        area: old.area,
        address: old.address,
        stockLocationId: old.stockLocationId,
        hasVendor: old.hasVendor,
        imageUrl: url);
  }

  @override
  Future<void> uploadStationPhoto(String id, Uint8List bytes) async {
    if (refuse) throw const OfficeError(OfficeErrorKind.forbidden);
    photoUploads.add(bytes);
    _setPhoto('https://storage.test/stations/${photoUploads.length}.jpg');
  }

  @override
  Future<void> removeStationPhoto(String id) async {
    photoRemoved = true;
    _setPhoto(null);
  }

  @override
  Future<List<Map<String, dynamic>>> stationStock(String id) async => [
        {
          'product': 'KUKU',
          'name': 'Kuku mzima',
          'unit': 'piece',
          'quantity': 8
        }
      ];
  @override
  Future<List<Map<String, dynamic>>> stationManifests(String id) async =>
      deliveries;
  @override
  Future<void> amendManifest(String id, List<Map<String, dynamic>> lines,
      String reason, int version) async {
    amendments.add(lines);
    expectedVersion = version;
    deliveries[0] = {...deliveries[0], 'lines': lines, 'version': version + 1};
  }

  @override
  Future<void> cancelManifest(String id, String reason, int version) async {
    cancellations.add(id);
    expectedVersion = version;
    deliveries[0] = {...deliveries[0], 'status': 'cancelled'};
  }

  @override
  Future<void> endVendorStation(String id, String reason) async {}
}

Future<void> revealStation(WidgetTester tester, String text) async {
  // Expected deliveries moved to the station's Stock page.
  if (find.text(text).evaluate().isEmpty &&
      find.text('Mizigo inayotarajiwa').evaluate().isEmpty &&
      find.text('Stoo').evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text('Stoo'));
    await tester.tap(find.text('Stoo'));
    await tester.pumpAndSettle();
  }
  if (find.text(text).evaluate().isEmpty &&
      find.text('Mizigo inayotarajiwa').evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text('Mizigo inayotarajiwa'));
    await tester.tap(find.text('Mizigo inayotarajiwa'));
    await tester.pumpAndSettle();
  }
  if (find.text(text).evaluate().isEmpty &&
      find.text('Maelezo zaidi').evaluate().isNotEmpty) {
    await expandOfficeDetails(tester, 'Maelezo zaidi');
  }
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(320, 568), const Size(768, 1024)]) {
    testWidgets('station details fit $size with large text and long address',
        (tester) async {
      final repo = StationOffice();
      await repo.updateStation('s1',
          name: 'Bunju B',
          area: 'Bunju',
          address: 'Barabara kuu karibu na soko la Bunju upande wa kaskazini',
          reason: 'Taarifa');
      final app = await pumpApp(tester,
          startAs: StartAs.signedOut, office: repo, size: size, textScale: 2);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(repo.owner);
      app.router.go(MNRoutes.officeStation('s1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await revealStation(tester, 'Badili orodha');
      await tester.tap(find.text('Badili orodha'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'station card opens details and a refused save preserves entered values',
      (tester) async {
    final repo = StationOffice();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    app.router.go(MNRoutes.officeStations);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bunju B'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeStationScreen), findsOneWidget);
    expect(find.text('Barabara kuu'), findsOneWidget);
    await tester.tap(find.text('Eneo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Bunju Mpya');
    await tester.enterText(find.byType(TextField).at(3), 'Sahihisha jina');
    repo.refuse = true;
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Bunju Mpya');
    expect(repo.stationsList.first.name, 'Bunju B');
    repo.refuse = false;
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.stationsList.first.name, 'Bunju Mpya');
    expect(repo.stationsList.first.code, 'MR01');
    expect(find.text('Bunju Mpya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'delivery amendments send versions and received deliveries stay locked',
      (tester) async {
    final repo = StationOffice();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    app.router.go(MNRoutes.officeStation('s1'));
    await tester.pumpAndSettle();
    await revealStation(tester, 'Badili orodha');
    expect(find.text('Badili orodha'), findsOneWidget);
    await tester.tap(find.text('Badili orodha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '12');
    await tester.enterText(find.byType(TextField).at(2), 'Ongeza idadi sahihi');
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.amendments.single.single['quantity'], 12);
    expect(repo.amendments.single.single['agreed_unit_price'], 6000);
    expect(repo.expectedVersion, 1);
    await revealStation(tester, 'Ghairi utumaji');
    await tester.tap(find.text('Ghairi utumaji'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Utumaji umerudi');
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.cancellations, ['delivery']);
    expect(repo.expectedVersion, 2);
    expect(find.text('Badili orodha'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'station assigns vendors and adds staff without dropping other placements',
      (tester) async {
    final repo = StationOffice();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    app.router.go(MNRoutes.officeStation('s1'));
    await tester.pumpAndSettle();
    for (final (label, person) in [
      ('Panga muuzaji', 'Juma Ali'),
      ('Panga mfanyakazi', 'Asha Juma')
    ]) {
      await tester.ensureVisible(find.text('Ongeza').first);
      await tester.tap(find.text('Ongeza').first);
      await tester.pumpAndSettle();
      await revealStation(tester, label);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MNSelectField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(person).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Panga kituo Bunju');
      await tester.tap(find.text('Hifadhi mabadiliko'));
      await tester.pumpAndSettle();
    }
    expect(repo.assigned['v1'], 's1');
    expect(repo.placements['worker'], ['other', 's1']);
    expect(tester.takeException(), isNull);
  });
}
