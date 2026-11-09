import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/person_screens.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart'
    show OwnerMenuRow;
import 'package:mr_nyama_vendor/features/office/product_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

/// The shared fake, recording the owner-control calls and able to refuse one.
class RecordingOffice extends FakeOfficeRepository {
  final log = <String>[];
  final codes = <String>[];

  /// Thrown by the next status change, then cleared.
  OfficeError? refuseStatus;

  @override
  Future<OfficeVendor> updateVendor(String vendorId,
      {String? name, String? phone, required String reason}) {
    log.add('updateVendor $vendorId name=$name phone=$phone reason=$reason');
    return super
        .updateVendor(vendorId, name: name, phone: phone, reason: reason);
  }

  @override
  Future<void> changeVendorStatus(String vendorId, StatusChange change,
      {required String reason}) {
    log.add('vendor ${change.name} $vendorId reason=$reason');
    if (refuseStatus case final e?) {
      refuseStatus = null;
      throw e;
    }
    return super.changeVendorStatus(vendorId, change, reason: reason);
  }

  @override
  Future<void> changeStaffStatus(String staffId, StatusChange change,
      {required String reason}) {
    log.add('staff ${change.name} $staffId reason=$reason');
    if (refuseStatus case final e?) {
      refuseStatus = null;
      throw e;
    }
    return super.changeStaffStatus(staffId, change, reason: reason);
  }

  @override
  Future<void> revokeRole(
      {required String staffId,
      required String roleGrantId,
      required String reason}) {
    log.add('revoke $staffId $roleGrantId reason=$reason');
    return super
        .revokeRole(staffId: staffId, roleGrantId: roleGrantId, reason: reason);
  }

  @override
  Future<void> grantRole(
      {required String staffId, required String role, required String reason}) {
    log.add('grant $staffId $role reason=$reason');
    return super.grantRole(staffId: staffId, role: role, reason: reason);
  }

  @override
  Future<IssuedCode> vendorCode(String vendorId, {bool reset = false}) {
    codes.add('vendor $vendorId reset=$reset');
    return super.vendorCode(vendorId, reset: reset);
  }
}

RecordingOffice peopleOffice() => RecordingOffice()
  ..signedIn = true
  ..vendorsList.add(const OfficeVendor(
      id: 'v1',
      name: 'Asha Juma',
      phone: '+255712345678',
      code: 'V-001',
      stationId: 's1',
      stationName: 'Kariakoo',
      activated: true,
      suspended: false))
  ..staffList.addAll([
    const OfficeStaff(
        id: 'st1',
        name: 'Neema Said',
        phone: '+255713000111',
        code: 'S-002',
        roles: ['supervisor'],
        roleGrants: [OfficeRoleGrant('g1', 'supervisor')],
        stationIds: ['s1'],
        activated: true,
        suspended: false),
    const OfficeStaff(
        id: 'o2',
        name: 'Mmiliki Pekee',
        phone: '+255746000222',
        roles: ['business_owner'],
        roleGrants: [OfficeRoleGrant('g9', 'business_owner')],
        activated: true,
        suspended: false),
  ]);

Future<TestApp> openOffice(WidgetTester tester, RecordingOffice office,
    {Size size = const Size(390, 844), double textScale = 1}) async {
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut,
      office: office,
      size: size,
      textScale: textScale);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  await tester.pumpAndSettle();
  return app;
}

/// Scrolls the page until [finder] is on screen, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder inSheet(Finder finder) =>
    find.descendant(of: find.byType(MNSheet), matching: finder);

void main() {
  testWidgets('a vendor row opens the vendor detail screen', (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeVendors);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asha Juma'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeVendorScreen), findsOneWidget);
    expect(app.router.routerDelegate.currentConfiguration.last.matchedLocation,
        MNRoutes.officeVendor('v1'));
    expect(find.text('+255 712 345 678'), findsOneWidget);
    expect(find.text('V-001'), findsOneWidget);
    expect(find.text('Kariakoo'), findsOneWidget);
    expect(find.text('Anatumia'), findsOneWidget);
    expect(find.text('Simamisha akaunti'), findsOneWidget);
  });

  testWidgets(
      'changing the phone warns, saves through updateVendor, then offers the code',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeVendor('v1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Badilisha jina au simu'));
    final fields = inSheet(find.byType(TextField));
    expect(find.textContaining('namba mpya ya kuingia'), findsNothing);
    await tester.enterText(fields.at(1), '713999888');
    await tester.pumpAndSettle();
    // The warning shows as soon as the number differs.
    expect(find.textContaining('ataondolewa kwenye app'), findsOneWidget);
    await tester.enterText(fields.at(2), 'Simu mpya');
    await tester.tap(inSheet(find.text('Hifadhi mabadiliko')));
    await tester.pumpAndSettle();
    expect(find.text('Badilisha namba ya simu?'), findsOneWidget);
    expect(office.log, isEmpty, reason: 'nothing is sent before confirming');
    await tester.tap(find.text('Ndiyo, badilisha'));
    await tester.pumpAndSettle();
    expect(office.log,
        ['updateVendor v1 name=null phone=+255713999888 reason=Simu mpya']);
    expect(find.text('Toa namba mpya ya kuingia sasa?'), findsOneWidget);
    await tester.tap(find.text('Ndiyo, toa namba'));
    await tester.pumpAndSettle();
    expect(office.codes, ['vendor v1 reset=false']);
    expect(find.text('Mpe Asha Juma namba hii'), findsOneWidget);
  });

  testWidgets('marking a vendor as left needs a reason and a confirmation',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeVendor('v1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Ameondoka kazini'));
    // The final-step warning, then no reason → nothing sent.
    expect(find.textContaining('Akaunti inafungwa'), findsOneWidget);
    await tester.tap(inSheet(find.text('Ameondoka kazini')).last);
    await tester.pumpAndSettle();
    expect(find.text('Andika sababu (angalau herufi 3).'), findsOneWidget);
    await tester.enterText(
        inSheet(find.byType(TextField)), 'Amehamia mkoa mwingine');
    await tester.tap(inSheet(find.text('Ameondoka kazini')).last);
    await tester.pumpAndSettle();
    expect(find.text('Thibitisha Asha Juma ameondoka?'), findsOneWidget);
    // Cancelling the confirmation sends nothing.
    await tester.tap(find.text('Ghairi'));
    await tester.pumpAndSettle();
    expect(office.log, isEmpty);
    await tester.tap(inSheet(find.text('Ameondoka kazini')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, ameondoka'));
    await tester.pumpAndSettle();
    expect(office.log, ['vendor leave v1 reason=Amehamia mkoa mwingine']);
    // Read-only afterwards, with the reason on the status line.
    expect(find.text('Ameondoka: Amehamia mkoa mwingine'), findsOneWidget);
    expect(find.textContaining('Rudisha kazini'), findsWidgets);
    expect(find.text('Badilisha jina au simu'), findsNothing);
    expect(find.text('Simamisha akaunti'), findsNothing);
    // A mistake is undone: back to active.
    await tapVisible(
        tester, find.widgetWithText(OwnerMenuRow, 'Rudisha kazini'));
    await tester.enterText(inSheet(find.byType(TextField)), 'Ilikuwa makosa');
    await tester.tap(inSheet(find.text('Rudisha kazini')).last);
    await tester.pumpAndSettle();
    expect(office.log.last, 'vendor returned v1 reason=Ilikuwa makosa');
    expect(find.text('Simamisha akaunti'), findsOneWidget);
  });

  testWidgets('a server refusal (409) is translated into Swahili',
      (tester) async {
    final office = peopleOffice()
      ..refuseStatus = const OfficeError(
          OfficeErrorKind.refused, 'The last business owner cannot leave.');
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeStaffMember('o2'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Ameondoka kazini'));
    await tester.enterText(inSheet(find.byType(TextField)), 'Anaondoka');
    await tester.tap(inSheet(find.text('Ameondoka kazini')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, ameondoka'));
    await tester.pumpAndSettle();
    expect(office.log.single, 'staff leave o2 reason=Anaondoka');
    expect(find.text('Mmiliki wa mwisho wa biashara hawezi kuondoka.'),
        findsOneWidget);
    expect(office.staffList.last.left, isFalse);
  });

  testWidgets('staff roles: revoke names the role grant, grant adds a role',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeStaff);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neema Said'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeStaffMemberScreen), findsOneWidget);
    expect(find.text('S-002'), findsOneWidget);

    await tapVisible(tester, find.text('Ondoa kazi: Msimamizi'));
    await tester.enterText(
        inSheet(find.byType(TextField)), 'Amehamishiwa jikoni');
    await tester.tap(inSheet(find.text('Ondoa kazi: Msimamizi')).last);
    await tester.pumpAndSettle();
    expect(office.log, ['revoke st1 g1 reason=Amehamishiwa jikoni']);
    // Let the "saved" message go before reaching for the next row.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Ongeza kazi'));
    // The owner may give manager roles too; held roles are not offered.
    // Kitchen staff are placed at a kitchen, which has its own test
    // (office_setup_test.dart).
    expect(inSheet(find.text('Meneja wa fedha')), findsOneWidget);
    await tester.tap(inSheet(find.text('Meneja wa fedha')));
    await tester.pumpAndSettle();
    await tester.enterText(inSheet(find.byType(TextField)), 'Kazi ya jikoni');
    await tester.tap(inSheet(find.text('Ongeza kazi')).last);
    await tester.pumpAndSettle();
    expect(office.log.last, 'grant st1 finance reason=Kazi ya jikoni');
  });

  testWidgets('the signed-in owner sees no actions on their own account',
      (tester) async {
    final office = peopleOffice()
      ..staffList.add(const OfficeStaff(
          id: 'o1',
          name: 'Maternus Joshua',
          phone: '+255746484666',
          roles: ['business_owner'],
          activated: true,
          suspended: false));
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeStaffMember('o1'));
    await tester.pumpAndSettle();
    expect(find.text('Mmiliki'), findsOneWidget);
    expect(find.text('Simamisha akaunti'), findsNothing);
    expect(find.text('Ameondoka kazini'), findsNothing);
  });

  testWidgets('a category created from the product form becomes selected',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeNewProduct);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Soda baridi');
    await tester.tap(find.byType(MNSelectField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Kundi jipya').last);
    await tester.pumpAndSettle();
    final fields = inSheet(find.byType(TextField));
    await tester.enterText(fields.at(0), 'Vinywaji Baridi');
    await tester.pumpAndSettle();
    // The code follows the name in the server's format.
    expect(tester.widget<TextField>(fields.at(1)).controller!.text,
        'vinywaji_baridi');
    await tester.tap(inSheet(find.text('Ongeza kundi')));
    await tester.pumpAndSettle();
    expect(find.byType(MNSheet), findsNothing);
    expect(office.categoryList.last.code, 'vinywaji_baridi');
    expect(find.text('Vinywaji Baridi'), findsOneWidget);
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(office.productsList.last.category, 'vinywaji_baridi');
    expect(find.byType(OfficeProductScreen), findsOneWidget);
  });

  testWidgets('a unit added from the product form becomes selected',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeNewProduct);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Supu ya kuku');
    await tester.tap(find.byType(MNSelectField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuku').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Kipimo kipya').last);
    await tester.pumpAndSettle();
    await tester.enterText(inSheet(find.byType(TextField)), 'Bakuli Kubwa');
    await tester.tap(inSheet(find.byType(MNSelectField<bool>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desimali zinaruhusiwa (kama kg)').last);
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Ongeza kipimo')));
    await tester.pumpAndSettle();
    expect(find.byType(MNSheet), findsNothing);
    final unit = office.unitList.single;
    expect((unit.code, unit.name, unit.allowsDecimal),
        ('bakuli_kubwa', 'Bakuli Kubwa', true));
    expect(find.text('Bakuli Kubwa'), findsOneWidget);
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(office.productsList.last.unit, 'bakuli_kubwa');
  });

  testWidgets('a built-in unit name is not added again', (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeNewProduct);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Kipimo kipya').last);
    await tester.pumpAndSettle();
    await tester.enterText(inSheet(find.byType(TextField)), 'Kipande');
    await tester.tap(inSheet(find.text('Ongeza kipimo')));
    await tester.pumpAndSettle();
    expect(find.text('Kipimo hiki tayari kipo'), findsOneWidget);
    expect(office.unitList, isEmpty);
  });

  testWidgets('a bad category code is explained before anything is sent',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeNewProduct);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MNSelectField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Kundi jipya').last);
    await tester.pumpAndSettle();
    final fields = inSheet(find.byType(TextField));
    await tester.enterText(fields.at(0), 'Vinywaji');
    await tester.enterText(fields.at(1), '9x');
    await tester.tap(inSheet(find.text('Ongeza kundi')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Herufi ndogo'), findsOneWidget);
    expect(office.categoryList.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('person screens and sheets fit 320 px at 2× text',
      (tester) async {
    final office = peopleOffice();
    final app = await openOffice(tester, office,
        size: const Size(320, 568), textScale: 2);
    for (final route in [
      MNRoutes.officeVendor('v1'),
      MNRoutes.officeStaffMember('st1'),
      MNRoutes.officeStaffMember('missing'),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    app.router.go(MNRoutes.officeVendor('v1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Badilisha jina au simu'));
    await tester.enterText(inSheet(find.byType(TextField)).at(1), '713999888');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(MNSheet))).pop();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Ameondoka kazini'));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(MNSheet))).pop();
    await tester.pumpAndSettle();

    app.router.go(MNRoutes.officeNewProduct);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(OfficeNewProductScreen));
    showNewCategorySheet(context);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('person screens meet tap-target and label guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    final office = peopleOffice();
    final app = await openOffice(tester, office);
    for (final route in [
      MNRoutes.officeVendor('v1'),
      MNRoutes.officeStaffMember('st1'),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }
    handle.dispose();
  });

  group('HTTP', () {
    test('owner-control calls send the contract payloads and parse rows',
        () async {
      final requests = <RequestOptions>[];
      final store = InMemoryStore();
      await store.write('office_access_token', 'staff-token');
      final dio = Dio()
        ..httpClientAdapter = _Adapter((o) {
          requests.add(o);
          return switch ('${o.method} ${o.uri.path}') {
            'PATCH /api/v1/admin/vendors/v1' => (
                200,
                {
                  'id': 'v1',
                  'vendor_code': 'V-001',
                  'name': 'Asha',
                  'phone': '+255713999888',
                  'station': null,
                  'status': 'active',
                  'activation_state': 'pending',
                  'status_reason': null,
                }
              ),
            'PATCH /api/v1/admin/staff/st1' => (
                200,
                {
                  'id': 'st1',
                  'staff_code': 'S-002',
                  'name': 'Neema',
                  'phone': '+255713000111',
                  'status': 'suspended',
                  'status_reason': 'Uchunguzi',
                  'activation_state': 'activated',
                  'roles': ['supervisor'],
                  'role_grants': [
                    {'id': 'g1', 'role': 'supervisor'}
                  ],
                  'stations': [],
                  'work_stations': ['s1'],
                }
              ),
            'POST /api/v1/admin/categories' => (
                201,
                {'id': 'c', 'code': 'vinywaji', 'name': 'Vinywaji'}
              ),
            'POST /api/v1/admin/staff/o2/leave' => (
                409,
                {
                  'error': 'refused',
                  'detail': 'The last business owner cannot leave.'
                }
              ),
            'POST /api/v1/admin/vendors/v2/suspend' => (
                403,
                {'error': 'forbidden'}
              ),
            'GET /api/v1/admin/vendors' => (
                200,
                [
                  {
                    'id': 'v9',
                    'name': 'Zamani',
                    'phone': '+255712000000',
                    'station': {'id': 's1', 'code': 'KA01', 'name': 'Kariakoo'},
                    'status': 'left',
                    'activation_state': 'activated',
                  }
                ]
              ),
            _ => (200, <String, Object?>{}),
          };
        });
      final repo =
          HttpOfficeRepository(baseUrl: 'https://x', store: store, dio: dio);

      final vendor = await repo.updateVendor('v1',
          phone: '+255713999888', reason: 'Simu mpya');
      expect(requests.last.data,
          {'phone': '+255713999888', 'reason': 'Simu mpya'});
      expect(vendor.activated, isFalse);
      expect(vendor.code, 'V-001');

      final staff =
          await repo.updateStaff('st1', name: 'Neema', reason: 'Jina sahihi');
      expect(requests.last.data, {'name': 'Neema', 'reason': 'Jina sahihi'});
      expect(staff.roleGrants.single.id, 'g1');
      expect(staff.suspended, isTrue);
      expect(staff.statusReason, 'Uchunguzi');
      expect(staff.stationIds, ['s1']);

      await repo.changeVendorStatus('v1', StatusChange.leave,
          reason: 'Ameondoka');
      expect(requests.last.uri.path, '/api/v1/admin/vendors/v1/leave');
      await repo.changeStaffStatus('st1', StatusChange.reinstate,
          reason: 'Amerudi');
      expect(requests.last.uri.path, '/api/v1/admin/staff/st1/reinstate');
      expect(requests.last.data, {'reason': 'Amerudi'});
      await repo.revokeRole(
          staffId: 'st1', roleGrantId: 'g1', reason: 'Kazi imeisha');
      expect(requests.last.uri.path, '/api/v1/admin/staff/st1/roles/g1/revoke');
      expect(requests.last.data, {'reason': 'Kazi imeisha'});

      final category =
          await repo.createCategory(code: 'vinywaji', name: 'Vinywaji');
      expect(requests.last.data, {'code': 'vinywaji', 'name': 'Vinywaji'});
      expect(category.code, 'vinywaji');

      await expectLater(
          repo.changeStaffStatus('o2', StatusChange.leave, reason: 'Anaondoka'),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.refused)
              .having((e) => e.detail, 'detail',
                  'The last business owner cannot leave.')));
      await expectLater(
          repo.changeVendorStatus('v2', StatusChange.suspend,
              reason: 'Uchunguzi'),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.forbidden)));

      // A row from a server without the new fields still parses.
      final old = (await repo.vendors()).single;
      expect(old.left, isTrue);
      expect(old.statusReason, isNull);
      expect(old.stationId, 's1');
      expect(
          requests
              .every((r) => r.headers['Authorization'] == 'Bearer staff-token'),
          isTrue);
    });

    test('staff rows without role grants or reasons still parse', () {
      final staff = OfficeStaff.fromJson({
        'id': 'x',
        'name': 'X',
        'phone': '+255712000000',
        'status': 'active',
        'activation_state': 'pending',
        'roles': ['kitchen_staff'],
      });
      expect(staff.roleGrants, isEmpty);
      expect(staff.statusReason, isNull);
      expect(staff.left, isFalse);
      expect(staff.roles, ['kitchen_staff']);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  final (int, Object?) Function(RequestOptions) answer;
  _Adapter(this.answer);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    final (status, data) = answer(options);
    return ResponseBody.fromString(jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}
