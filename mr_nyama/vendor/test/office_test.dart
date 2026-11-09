import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/routing/router.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/office_sign_in.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart';

import 'helpers.dart';

/// In-memory office API: one owner (+255746484666, PIN 4826).
class FakeOfficeRepository implements OfficeRepository {
  @override
  Future<OfficeProduct> createProduct(
      {required String code,
      required String name,
      required String category,
      required String unit}) async {
    final product = OfficeProduct(
        code: code,
        name: name,
        category: category,
        unit: unit,
        available: true);
    productsList.add(product);
    return product;
  }

  // Keep the shared in-memory fixture aligned with the office API contract.
  @override
  Future<OfficeCategory> createCategory(
      {required String code, required String name}) async {
    final category = OfficeCategory(code, name);
    categoryList.add(category);
    return category;
  }

  @override
  Future<OfficeUnit> createUnit(
      {required String code,
      required String name,
      required bool allowsDecimal}) async {
    final unit = OfficeUnit(code, name, allowsDecimal: allowsDecimal);
    unitList.add(unit);
    return unit;
  }

  OfficeVendor _vendor(String id,
      {String? name, String? phone, StatusChange? change, String? reason}) {
    final index = vendorsList.indexWhere((v) => v.id == id);
    final old = vendorsList[index];
    return vendorsList[index] = OfficeVendor(
        id: old.id,
        name: name ?? old.name,
        phone: phone ?? old.phone,
        activated: old.activated,
        code: old.code,
        stationId: old.stationId,
        stationName: old.stationName,
        stationCode: old.stationCode,
        stationSince: old.stationSince,
        suspended:
            change == null ? old.suspended : change == StatusChange.suspend,
        left: change == null ? old.left : change == StatusChange.leave,
        statusReason: reason ?? old.statusReason);
  }

  OfficeStaff _staff(String id,
      {String? name,
      String? phone,
      StatusChange? change,
      String? reason,
      String? revokeGrant}) {
    final index = staffList.indexWhere((s) => s.id == id);
    final old = staffList[index];
    final grants = old.roleGrants.where((g) => g.id != revokeGrant).toList();
    return staffList[index] = OfficeStaff(
        id: old.id,
        name: name ?? old.name,
        phone: phone ?? old.phone,
        activated: old.activated,
        code: old.code,
        stationIds: old.stationIds,
        roles: revokeGrant == null
            ? old.roles
            : grants.map((g) => g.role).toList(),
        roleGrants: grants,
        suspended:
            change == null ? old.suspended : change == StatusChange.suspend,
        left: change == null ? old.left : change == StatusChange.leave,
        statusReason: reason ?? old.statusReason);
  }

  @override
  Future<OfficeVendor> updateVendor(String vendorId,
          {String? name, String? phone, required String reason}) async =>
      _vendor(vendorId, name: name, phone: phone);
  @override
  Future<OfficeStaff> updateStaff(String staffId,
          {String? name, String? phone, required String reason}) async =>
      _staff(staffId, name: name, phone: phone);
  @override
  Future<void> changeVendorStatus(String vendorId, StatusChange change,
      {required String reason}) async {
    if (change == StatusChange.delete) {
      vendorsList.removeWhere((v) => v.id == vendorId);
      return;
    }
    _vendor(vendorId, change: change, reason: reason);
  }

  @override
  Future<void> changeStaffStatus(String staffId, StatusChange change,
      {required String reason}) async {
    if (change == StatusChange.delete) {
      staffList.removeWhere((s) => s.id == staffId);
      return;
    }
    _staff(staffId, change: change, reason: reason);
  }

  @override
  Future<void> revokeRole(
      {required String staffId,
      required String roleGrantId,
      required String reason}) async {
    _staff(staffId, revokeGrant: roleGrantId);
  }

  final productsList = <OfficeProduct>[];
  final categoryList = <OfficeCategory>[const OfficeCategory('kuku', 'Kuku')];
  final pricesList = <OfficeStationPrice>[];
  final placements = <String, List<String>>{};
  final priceWrites = <Map<String, Object?>>[];
  @override
  Future<List<OfficeProduct>> products() async => productsList;
  @override
  Future<List<OfficeCategory>> categories() async => categoryList;
  final unitList = <OfficeUnit>[];
  @override
  Future<List<OfficeUnit>> units() async => unitList;
  @override
  Future<List<OfficeStationPrice>> productPrices(String code) async =>
      pricesList;
  @override
  Future<void> updateProduct(String code,
      {required String name,
      required String category,
      required String unit,
      required bool available,
      required String status,
      required String? imageKey,
      required String reason}) async {
    final i = productsList.indexWhere((p) => p.code == code);
    productsList[i] = OfficeProduct(
        code: code,
        name: name,
        category: category,
        unit: unit,
        imageKey: imageKey,
        price: productsList[i].price,
        available: available,
        status: status);
  }

  @override
  Future<void> setProductPrice(String code,
      {required int amount, String? stationId, required String reason}) async {
    priceWrites.add({
      'code': code,
      'amount': amount,
      'station': stationId,
      'reason': reason
    });
  }

  @override
  Future<String> uploadProductImage(Uint8List bytes) async =>
      'uploads/${'a' * 32}/${'b' * 64}.jpg';
  @override
  Future<void> placeStaff(String staffId,
      {required List<String> stationIds, required String reason}) async {
    placements[staffId] = stationIds;
  }

  final vendorsList = <OfficeVendor>[];
  final staffList = <OfficeStaff>[];
  final stationsList = <OfficeStation>[
    const OfficeStation(
        id: 's1', code: 'KA01', name: 'Kariakoo', hasVendor: false),
  ];
  final assigned = <String, String>{};
  final roles = <String, String>{};
  StaffProfile owner = const StaffProfile(
      id: 'o1',
      name: 'Maternus Joshua',
      phone: '+255746484666',
      roles: ['business_owner']);
  bool signedIn = false;

  @override
  Future<bool> hasSession() async => signedIn;
  @override
  Future<SignInStep> startSignIn(String phone) async =>
      phone == owner.phone ? SignInStep.pin : SignInStep.activation;
  @override
  Future<StaffProfile> signIn(
      {required String phone, required String pin}) async {
    if (phone != owner.phone || pin != '4826') {
      throw const AuthFailure(AuthFailureKind.wrongPin);
    }
    signedIn = true;
    return owner;
  }

  @override
  Future<String> verifyCode(
          {required String phone,
          required String code,
          bool reset = false}) async =>
      throw const AuthFailure(AuthFailureKind.invalidCode);
  @override
  Future<StaffProfile> setPin(
          {required String setupToken, required String pin}) async =>
      owner;
  @override
  Future<void> signOut() async => signedIn = false;
  String pin = '4826';
  @override
  Future<void> changePin(
      {required String currentPin, required String newPin}) async {
    if (currentPin != pin) throw const AuthFailure(AuthFailureKind.wrongPin);
    pin = newPin;
  }

  @override
  Future<List<OfficeVendor>> vendors() async => vendorsList;
  @override
  Future<List<OfficeStaff>> staff() async => staffList;
  @override
  Future<List<OfficeStation>> stations() async => stationsList;
  @override
  Future<String> addVendor(
      {required String name, required String phone}) async {
    if (vendorsList.any((v) => v.phone == phone)) {
      throw const OfficeError(OfficeErrorKind.duplicate);
    }
    final id = 'v${vendorsList.length + 1}';
    vendorsList.add(OfficeVendor(
        id: id, name: name, phone: phone, activated: false, suspended: false));
    return id;
  }

  @override
  Future<void> assignVendor(
          {required String vendorId,
          required String stationId,
          required String reason}) async =>
      assigned[vendorId] = stationId;
  @override
  Future<IssuedCode> vendorCode(String vendorId, {bool reset = false}) async =>
      const IssuedCode('520588', 24);
  @override
  Future<String> addStaff({required String name, required String phone}) async {
    final id = 'st${staffList.length + 1}';
    staffList.add(OfficeStaff(
        id: id,
        name: name,
        phone: phone,
        roles: const [],
        activated: false,
        suspended: false));
    return id;
  }

  @override
  Future<void> grantRole(
          {required String staffId,
          required String role,
          required String reason}) async =>
      roles[staffId] = role;
  @override
  Future<void> assignSupervisor(
      {required String stationId,
      required String staffId,
      required String reason}) async {}
  @override
  Future<IssuedCode> staffCode(String staffId, {bool reset = false}) async =>
      const IssuedCode('731904', 24);
  @override
  Future<OfficeStation> addStation(
      {required String code, required String name}) async {
    final s = OfficeStation(
        id: 's${stationsList.length + 1}',
        code: code,
        name: name,
        hasVendor: false);
    stationsList.add(s);
    return s;
  }

  // Verification: in memory, all or nothing like the server.
  final verificationList = <OfficeVerificationStation>[];
  final salesList = <OfficeSale>[];
  final damageList = <OfficeDamageReport>[];
  final closingList = <OfficeClosingCount>[];
  final exceptionList = <OfficeException>[];

  /// The results the server fixes when a count is confirmed, by closing id.
  final confirmedLines = <String, List<OfficeClosingLine>>{};

  @override
  Future<List<OfficeVerificationStation>> verificationQueue() async =>
      verificationList;
  @override
  Future<List<OfficeSale>> stationSales(String stationId,
          {String? businessDate, String? status}) async =>
      salesList.where((s) => status == null || s.status == status).toList();
  @override
  Future<List<String>> verifySales(List<String> saleIds) async {
    final rows = [
      for (final id in saleIds) salesList.firstWhere((s) => s.saleId == id)
    ];
    if (rows.any((s) => s.voided)) {
      throw const OfficeError(
          OfficeErrorKind.refused, 'A voided sale cannot be verified');
    }
    for (final row in rows) {
      salesList[salesList.indexOf(row)] = OfficeSale(
          saleId: row.saleId,
          vendorId: row.vendorId,
          vendorName: row.vendorName,
          businessDate: row.businessDate,
          recordedAt: row.recordedAt,
          amount: row.amount,
          lines: row.lines,
          status: 'verified');
    }
    return saleIds;
  }

  @override
  Future<List<OfficeDamageReport>> damageReports(
          {required String stationId, String status = 'reported'}) async =>
      damageList.where((d) => d.status == status).toList();
  @override
  Future<OfficeDamageReport> decideDamage(String reportId,
      {required bool approve, required String reason}) async {
    final i = damageList.indexWhere((d) => d.id == reportId);
    final old = damageList[i];
    return damageList[i] = OfficeDamageReport(
        id: old.id,
        vendorName: old.vendorName,
        productName: old.productName,
        quantity: old.quantity,
        status: approve ? 'verified' : 'rejected',
        decisionReason: reason);
  }

  @override
  Future<List<OfficeClosingCount>> closingCounts(
          {required String stationId, String status = 'recorded'}) async =>
      closingList.where((c) => c.status == status).toList();
  @override
  Future<OfficeClosingCount> confirmClosing(String closingId) async {
    final i = closingList.indexWhere((c) => c.id == closingId);
    final old = closingList[i];
    if (old.blocked) {
      throw const OfficeError(
          OfficeErrorKind.refused, 'Sales or damage reports are waiting');
    }
    return closingList[i] = OfficeClosingCount(
        id: old.id,
        vendorName: old.vendorName,
        businessDate: old.businessDate,
        countedLines: old.countedLines,
        lines: confirmedLines[closingId] ?? const [],
        status: 'confirmed');
  }

  @override
  Future<List<OfficeException>> exceptions(
          {required String stationId, String status = 'open'}) async =>
      exceptionList.where((e) => e.status == status).toList();

  // Money: in memory, refusing like the server.
  final moneyDayList = <OfficeMoneyDay>[];
  final handoverList = <OfficeHandover>[];
  final expenseList = <OfficeExpense>[];
  OfficeMoneySettings moneySettingsValue = const OfficeMoneySettings();
  final settingWrites = <Map<String, Object?>>[];

  MoneyParty get _me => MoneyParty(id: owner.id, name: owner.name);

  @override
  Future<List<OfficeMoneyDay>> moneyDays(
          {required String stationId, required String businessDate}) async =>
      moneyDayList
          .where((d) =>
              d.businessDate == null ||
              moneyDateKey(d.businessDate!) == businessDate)
          .toList();
  @override
  Future<OfficeHandover> recordHandover(
      {required String vendorId,
      required String businessDate,
      required int amount,
      DateTime? receivedAt,
      String? note,
      String? clientId}) async {
    final vendor = moneyDayList
            .where((d) => d.vendor.id == vendorId)
            .firstOrNull
            ?.vendor ??
        MoneyParty(id: vendorId, name: '');
    final row = OfficeHandover(
        id: 'h${handoverList.length + 1}',
        vendor: vendor,
        businessDate: DateTime.parse(businessDate),
        amount: amount,
        receivedAt: receivedAt,
        recordedBy: _me,
        note: note);
    handoverList.add(row);
    return row;
  }

  @override
  Future<List<OfficeHandover>> handovers(
          {String? stationId,
          String? vendorId,
          String? from,
          String? to,
          String? status}) async =>
      handoverList
          .where((h) =>
              (vendorId == null || h.vendor.id == vendorId) &&
              (status == null || h.status == status))
          .toList();

  OfficeHandover _handover(OfficeHandover h,
          {String? status, MoneyParty? confirmedBy, String? reversedById}) =>
      OfficeHandover(
          id: h.id,
          vendor: h.vendor,
          businessDate: h.businessDate,
          amount: h.amount,
          receivedAt: h.receivedAt,
          recordedBy: h.recordedBy,
          status: status ?? h.status,
          confirmedBy: confirmedBy ?? h.confirmedBy,
          reversesId: h.reversesId,
          reversedById: reversedById ?? h.reversedById,
          reason: h.reason,
          note: h.note);

  @override
  Future<OfficeHandover> confirmHandover(String handoverId) async {
    final i = handoverList.indexWhere((h) => h.id == handoverId);
    if (handoverList[i].recordedBy.id == owner.id) {
      throw const OfficeError(OfficeErrorKind.refused,
          'You recorded this handover; someone else confirms it.');
    }
    return handoverList[i] =
        _handover(handoverList[i], status: 'confirmed', confirmedBy: _me);
  }

  @override
  Future<OfficeHandover> reverseHandover(String handoverId,
      {required String reason}) async {
    final i = handoverList.indexWhere((h) => h.id == handoverId);
    final old = handoverList[i];
    final row = OfficeHandover(
        id: 'h${handoverList.length + 1}',
        vendor: old.vendor,
        businessDate: old.businessDate,
        amount: -old.amount,
        receivedAt: old.receivedAt,
        recordedBy: _me,
        reversesId: old.id,
        reason: reason);
    handoverList[i] = _handover(old, reversedById: row.id);
    handoverList.add(row);
    return row;
  }

  OfficeExpense _expense(OfficeExpense e,
          {String? status, String? reason, String? reversedById}) =>
      OfficeExpense(
          id: e.id,
          businessDate: e.businessDate,
          category: e.category,
          amount: e.amount,
          note: e.note,
          paidBy: e.paidBy,
          vendor: e.vendor,
          status: status ?? e.status,
          decidedBy: status == null ? e.decidedBy : _me,
          decisionReason: reason ?? e.decisionReason,
          reversesId: e.reversesId,
          reversedById: reversedById ?? e.reversedById);

  @override
  Future<OfficeExpense> recordExpense(
      {required String stationId,
      required String businessDate,
      required String category,
      String? item,
      required int amount,
      String? note,
      String? clientId}) async {
    // As the server: Mengineyo needs a written item; other categories must
    // be configured.
    if (category == 'Mengineyo'
        ? item == null
        : !(moneySettingsValue.expenseCategories ?? const [])
            .contains(category)) {
      throw const OfficeError(OfficeErrorKind.refused,
          'This is not one of the expense categories.');
    }
    final row = OfficeExpense(
        id: 'e${expenseList.length + 1}',
        businessDate: DateTime.parse(businessDate),
        category: category,
        item: item,
        amount: amount,
        note: note,
        recordedBy: _me);
    expenseList.add(row);
    return row;
  }

  @override
  Future<List<OfficeExpense>> expenses(
          {String? stationId,
          String? from,
          String? to,
          String? status,
          String? paidBy}) async =>
      expenseList
          .where((e) =>
              (status == null || e.status == status) &&
              (paidBy == null || e.paidBy == paidBy))
          .toList();
  @override
  Future<OfficeExpense> decideExpense(String expenseId,
      {required bool approve, required String reason}) async {
    final i = expenseList.indexWhere((e) => e.id == expenseId);
    return expenseList[i] = _expense(expenseList[i],
        status: approve ? 'approved' : 'rejected', reason: reason);
  }

  @override
  Future<OfficeExpense> reverseExpense(String expenseId,
      {required String reason}) async {
    final i = expenseList.indexWhere((e) => e.id == expenseId);
    final old = expenseList[i];
    final row = OfficeExpense(
        id: 'e${expenseList.length + 1}',
        businessDate: old.businessDate,
        category: old.category,
        amount: -old.amount,
        paidBy: old.paidBy,
        vendor: old.vendor,
        reversesId: old.id,
        decidedBy: _me,
        decisionReason: reason);
    expenseList[i] = _expense(old, reversedById: row.id);
    expenseList.add(row);
    return row;
  }

  @override
  Future<OfficeMoneySettings> moneySettings() async => moneySettingsValue;
  @override
  Future<void> saveSetting(String key,
      {required Object value, required String reason}) async {
    if (!owner.isOwner) throw const OfficeError(OfficeErrorKind.forbidden);
    settingWrites.add({'key': key, 'value': value, 'reason': reason});
    moneySettingsValue = OfficeMoneySettings(
        expenseCategories: key == OfficeMoneySettings.categoriesKey
            ? [for (final v in value as List) '$v']
            : moneySettingsValue.expenseCategories,
        expenseItems: key == OfficeMoneySettings.itemsKey
            ? {
                for (final MapEntry(:key, :value) in (value as Map).entries)
                  '$key': [for (final i in value as List) '$i']
              }
            : moneySettingsValue.expenseItems,
        handoverDeadline: key == OfficeMoneySettings.deadlineKey
            ? value as String
            : moneySettingsValue.handoverDeadline,
        lateEntryHours: moneySettingsValue.lateEntryHours);
  }
}

/// Opens the sign-in page's three-dot menu and picks [item].
Future<void> fromSignInMenu(WidgetTester tester, String item) async {
  await tester.tap(find.bySemanticsLabel('Chaguo zaidi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('redirects', () {
    const vendorOut = AsyncData<AuthState>(SignedOut());
    const owner = OfficeSignedIn(
        StaffProfile(id: 'o', name: 'O', phone: '', roles: ['business_owner']));

    test('the office sign-in is reachable while no vendor is signed in', () {
      expect(
          sessionRedirect(vendorOut, MNRoutes.officeSignIn,
              office: const OfficeSignedOut()),
          isNull);
      expect(
          sessionRedirect(vendorOut, MNRoutes.officeVendors,
              office: const OfficeSignedOut()),
          MNRoutes.officeSignIn);
    });

    test('a signed-in office account only sees office screens', () {
      expect(sessionRedirect(vendorOut, MNRoutes.home, office: owner),
          MNRoutes.office);
      expect(sessionRedirect(vendorOut, MNRoutes.officeSignIn, office: owner),
          MNRoutes.office);
      expect(sessionRedirect(vendorOut, MNRoutes.officeVendors, office: owner),
          isNull);
    });

    test('a signed-in vendor never reaches the office', () {
      final vendorIn =
          AsyncData<AuthState>(SignedIn(VendorSession('t', testProfile)));
      expect(
          sessionRedirect(vendorIn, MNRoutes.officeSignIn,
              office: const OfficeSignedOut()),
          MNRoutes.home);
      expect(
          sessionRedirect(vendorIn, MNRoutes.office,
              office: const OfficeSignedOut()),
          MNRoutes.home);
    });
  });

  testWidgets('the owner signs in and registers a vendor with a station',
      (tester) async {
    final office = FakeOfficeRepository();
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await fromSignInMenu(tester, 'Ingia ofisini');
    await tester.enterText(find.byType(TextField), '746484666');
    await tester.pump();
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    await enterPin(tester, '4826');
    expect(app.router.routerDelegate.currentConfiguration.uri.path,
        MNRoutes.office);
    expect(find.text('Muhtasari'), findsWidgets);
    // No vendor tabs in office mode.
    expect(find.text('Mauzo'), findsNothing);

    // Below the Muhtasari rows (Utendaji, Bonasi) on a phone screen.
    await tester.ensureVisible(find.text('Usimamizi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usimamizi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wauzaji'));
    await tester.pumpAndSettle();
    expect(find.text('Gusa + kuongeza muuzaji'), findsOneWidget);
    await tester.tap(find.byTooltip('Sajili muuzaji'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Asha Juma');
    await tester.enterText(find.byType(TextField).at(1), '712345678');
    await tester.tap(find.text('Chagua kituo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kariakoo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sajili'));
    await tester.pumpAndSettle();

    expect(office.vendorsList.single.phone, '+255712345678');
    expect(office.assigned['v1'], 's1');
    expect(find.text('Mpe Asha Juma namba hii'), findsOneWidget);
    for (final d in '520588'.split('')) {
      expect(find.text(d), findsWidgets);
    }
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await tester.tap(find.bySemanticsLabel('Nakili namba'));
    await tester.pump();
    expect(copied, '520588');
    expect(find.text('Namba imenakiliwa.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text('Nimemaliza'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Juma'), findsOneWidget);
  });

  testWidgets('a duplicate phone is explained, not hidden', (tester) async {
    final office = FakeOfficeRepository()
      ..signedIn = true
      ..vendorsList.add(const OfficeVendor(
          id: 'v1',
          name: 'Asha',
          phone: '+255712345678',
          activated: true,
          suspended: false));
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeNewVendor);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Mtu Mwingine');
    await tester.enterText(find.byType(TextField).at(1), '712345678');
    await tester.tap(find.text('Sajili'));
    await tester.pumpAndSettle();
    expect(find.text('Namba hii tayari imesajiliwa'), findsOneWidget);
  });

  testWidgets('only the owner may appoint managers, and they get their code',
      (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeNewStaff);
    await tester.pumpAndSettle();
    expect(find.text('Meneja wa fedha'), findsOneWidget);
    expect(find.text('Meneja wa shughuli'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Neema Said');
    await tester.enterText(find.byType(TextField).at(1), '713000111');
    await tester.tap(find.text('Meneja wa fedha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sajili'));
    await tester.pumpAndSettle();
    expect(office.roles['st1'], 'finance');
    expect(find.text('Mpe Neema Said namba hii'), findsOneWidget);
  });

  testWidgets('a supervisor account sees no registration menus',
      (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container.read(officeSessionProvider.notifier).signedIn(
        const StaffProfile(
            id: 's', name: 'Msimamizi', phone: '', roles: ['supervisor']));
    await tester.pumpAndSettle();
    expect(find.text('Wauzaji'), findsNothing);
    expect(find.text('Msimamizi'), findsWidgets);
    expect(find.text('Badilisha PIN'), findsOneWidget);
  });

  testWidgets('the office sign-in links back to the vendor sign-in',
      (tester) async {
    final office = FakeOfficeRepository();
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await fromSignInMenu(tester, 'Ingia ofisini');
    await fromSignInMenu(tester, 'Ingia kama muuzaji');
    expect(app.router.routerDelegate.currentConfiguration.uri.path,
        MNRoutes.login);
  });

  testWidgets(
      'from Ofisi the user switches to the vendor sign-in without restarting',
      (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    expect(app.router.routerDelegate.currentConfiguration.uri.path,
        MNRoutes.office);
    await tester.tap(find.text('Akaunti'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ingia kama muuzaji'), 200);
    await tester.tap(find.text('Ingia kama muuzaji'));
    await tester.pumpAndSettle();
    expect(app.router.routerDelegate.currentConfiguration.uri.path,
        MNRoutes.login);
    expect(app.container.read(officeSessionProvider).valueOrNull,
        isA<OfficeSignedOut>());
  });

  testWidgets('the copy button has a visible label and accessible action',
      (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeIssuedCode,
        extra: const IssuedCodeArgs(
            name: 'Asha', code: IssuedCode('520588', 24), staff: false));
    await tester.pumpAndSettle();
    expect(find.text('Nakili namba'), findsOneWidget);
    expect(find.bySemanticsLabel('Nakili namba'), findsOneWidget);
  });

  testWidgets('the office account changes its own PIN', (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akaunti'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Badilisha PIN'), 200);
    await tester.tap(find.text('Badilisha PIN'));
    await tester.pumpAndSettle();
    await enterPin(tester, '4826'); // current
    await enterPin(tester, '3917'); // new
    await enterPin(tester, '3917'); // again
    expect(office.pin, '3917');
    expect(app.router.routerDelegate.currentConfiguration.uri.path,
        MNRoutes.office);
  });

  testWidgets('a wrong current office PIN starts over and changes nothing',
      (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeChangePin);
    await tester.pumpAndSettle();
    await enterPin(tester, '1111');
    await enterPin(tester, '3917');
    await enterPin(tester, '3917');
    expect(office.pin, '4826');
    expect(find.text('PIN ya sasa'), findsOneWidget);
  });

  testWidgets('office forgot PIN explains who helps, then takes the code',
      (tester) async {
    final office = FakeOfficeRepository();
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await fromSignInMenu(tester, 'Ingia ofisini');
    await tester.enterText(find.byType(TextField), '746484666');
    await tester.pump();
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umesahau PIN?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kwenye seva'), findsOneWidget);
    await tester.tap(find.text('Nina namba ya uthibitisho'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeCodeScreen), findsOneWidget);
    expect(app.container.read(officeFlowProvider).reset, isTrue);
  });

  group('HTTP', () {
    test(
        'owner edits send authenticated image, station price and placement payloads',
        () async {
      final requests = <RequestOptions>[];
      final store = InMemoryStore();
      await store.write('office_access_token', 'staff-token');
      final dio = Dio()
        ..httpClientAdapter = _Adapter((o) {
          requests.add(o);
          return (
            200,
            o.uri.path.endsWith('/product-images')
                ? {'image_key': 'uploaded-photo'}
                : <String, Object?>{}
          );
        });
      final repo =
          HttpOfficeRepository(baseUrl: 'https://x', store: store, dio: dio);
      final bytes = Uint8List.fromList([255, 216, 255]);
      expect(await repo.uploadProductImage(bytes), 'uploaded-photo');
      await repo.setProductPrice('KUKU',
          amount: 3000, stationId: 'station-a', reason: 'Bei kituo A');
      await repo.placeStaff('worker',
          stationIds: ['station-b'], reason: 'Hamisha mfanyakazi');
      await repo.updateProduct('KUKU',
          name: 'Kuku mpya',
          category: 'kuku',
          unit: 'portion',
          available: true,
          status: 'active',
          imageKey: null,
          reason: 'Ondoa picha');
      expect(
          requests
              .every((r) => r.headers['Authorization'] == 'Bearer staff-token'),
          isTrue);
      expect(requests[0].contentType, 'application/octet-stream');
      expect(requests[0].data, bytes);
      expect(requests[1].data,
          {'amount': 3000, 'station_id': 'station-a', 'reason': 'Bei kituo A'});
      expect(requests[2].method, 'PUT');
      expect(requests[2].data, {
        'station_ids': ['station-b'],
        'reason': 'Hamisha mfanyakazi'
      });
      expect((requests[3].data as Map).containsKey('image_key'), isTrue);
      expect((requests[3].data as Map)['image_key'], isNull);
    });
    test('office calls use staff auth and map refusals', () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((o) {
          requests.add(o);
          return switch ('${o.method} ${o.uri.path}') {
            'POST /api/v1/staff/auth/start' => (200, {'next': 'pin'}),
            'POST /api/v1/staff/auth/sign-in' => (
                200,
                {
                  'access_token': 'a',
                  'refresh_token': 'r',
                  'profile': {
                    'id': 'o',
                    'name': 'O',
                    'phone': '+255746484666',
                    'roles': ['business_owner']
                  }
                }
              ),
            'POST /api/v1/admin/vendors' => (
                409,
                {'error': 'refused', 'detail': 'vendors_phone'}
              ),
            'GET /api/v1/admin/stations' => (
                200,
                [
                  {
                    'id': 's',
                    'code': 'KA01',
                    'name': 'Kariakoo',
                    'vendor_id': null
                  }
                ]
              ),
            _ => (404, {'error': 'not_found'}),
          };
        });
      final repo = HttpOfficeRepository(
          baseUrl: 'https://x', store: InMemoryStore(), dio: dio);
      expect(await repo.startSignIn('+255746484666'), SignInStep.pin);
      final profile = await repo.signIn(phone: '+255746484666', pin: '4826');
      expect(profile.canManagePeople, isTrue);
      await expectLater(
          repo.addVendor(name: 'A', phone: '+255712345678'),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.duplicate)));
      expect((await repo.stations()).single.code, 'KA01');
      expect(requests.where((r) => r.uri.path.contains('/vendor/')), isEmpty);
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
