import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';
import 'package:mr_nyama_vendor/shared/widgets/workflow_help.dart';
import 'office_money_test.dart' show MoneyOffice, openMoney, tapVisible;

class ManagementOffice extends MoneyOffice
    implements OfficeSyncReviewRepository {
  @override
  Future<OfficeConflictOutcome> retryConflict(String opId,
          {required String reason}) async =>
      const OfficeConflictOutcome('accepted', null);
  @override
  Future<OfficeConflictOutcome> rejectConflict(String opId,
          {required String reason}) async =>
      const OfficeConflictOutcome('rejected', null);
  @override
  Future<void> assignVendorPastDay(
      {required String vendorId,
      required String stationId,
      required String businessDate,
      required String reason}) async {}
  @override
  Future<List<OfficeSyncConflict>> syncConflicts() async => [
        for (var i = 0; i < 3; i++)
          OfficeSyncConflict(
              opId: 'conflict-$i',
              opType: 'sale',
              reason: 'not_assigned',
              vendorId: 'v1',
              vendorCode: 'V1',
              vendorName: 'Test vendor'),
      ];
}

ManagementOffice fixture() {
  final office = ManagementOffice()..signedIn = true;
  office.stationsList
    ..clear()
    ..add(const OfficeStation(
        id: 's1', code: 'S1', name: 'Bunju B', hasVendor: true));
  for (var i = 0; i < 2; i++) {
    office.vendorsList.add(OfficeVendor(
        id: 'v$i',
        name: 'Vendor $i',
        phone: '',
        activated: true,
        suspended: false));
    office.staffList.add(OfficeStaff(
        id: 'st$i',
        name: 'Staff $i',
        phone: '',
        roles: const ['supervisor'],
        activated: true,
        suspended: false));
  }
  for (var i = 0; i < 3; i++) {
    office.productsList.add(OfficeProduct(
        code: 'P$i',
        name: 'Product $i',
        category: 'kuku',
        unit: 'piece',
        available: true));
  }
  office.moneySettingsValue = const OfficeMoneySettings(expenseCategories: [
    'Usafi',
    'Maji'
  ], expenseItems: {
    'Usafi': ['Sabuni']
  }, handoverDeadline: '19:30', lateEntryHours: 48);
  return office;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('MANAGEMENT_CAPTURES')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  boundary.markNeedsPaint();
  await tester.pump();
  await tester.pumpAndSettle();
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../reviews/2026-10-29/management');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  for (final language in ['sw', 'en']) {
    testWidgets('management follows the reference groups in $language',
        (tester) async {
      final s = Strings(language);
      final app = await openMoney(tester, fixture(),
          roles: const ['business_owner'],
          route: MNRoutes.officeManagement,
          size: const Size(390, 1000));
      app.container.read(languageProvider.notifier).state = language;
      await tester.pumpAndSettle();
      for (final title in [
        s.managementSetup,
        s.money,
        s.managementKitchen,
        s.managementAdministration,
        s.ownerAccount
      ]) {
        expect(find.text(title.toUpperCase()), findsOneWidget);
      }
      expect(tester.getTopLeft(find.text(s.stations)).dy,
          lessThan(tester.getTopLeft(find.text(s.vendors)).dy));
      expect(find.text(s.managementAllHaveVendors), findsOneWidget);
      final rows = tester.widgetList<OwnerMenuRow>(find.byType(OwnerMenuRow));
      expect(rows.firstWhere((r) => r.label == s.stations).valueColor,
          OwnerStyle.muted);
      expect(rows.firstWhere((r) => r.label == s.manageProducts).valueColor,
          OwnerStyle.assignAction);
      expect(find.text(s.ownerMissingPrices(3)), findsOneWidget);
      await capture(tester, 'management-$language');
      await tapVisible(tester, find.text(s.moneySettings));
      expect(app.router.state.uri.path, MNRoutes.officeMoneySettings);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'money settings keep forms and explanations behind a deliberate action in $language',
        (tester) async {
      final s = Strings(language);
      final app = await openMoney(tester, fixture(),
          roles: const ['business_owner'], route: MNRoutes.officeMoneySettings);
      app.container.read(languageProvider.notifier).state = language;
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text(s.offlineSettingsHelp), findsNothing);
      expect(find.text(s.lateEntryHelp), findsNothing);
      expect(find.text('19:30'), findsOneWidget);
      await capture(tester, 'money-settings-$language');
      await tester.tap(find.byType(MNWorkflowHelp));
      await tester.pumpAndSettle();
      expect(find.text(s.lateEntryHelp), findsOneWidget);
      Navigator.of(tester.element(find.text(s.lateEntryHelp))).pop();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(s.offlineSettingsTitle));
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text(s.offlineSettingsHelp), findsNothing);
      await tester.tap(find.byType(MNWorkflowHelp).last);
      await tester.pumpAndSettle();
      expect(find.text(s.offlineSettingsHelp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings fit a small phone at large text size', (tester) async {
    await openMoney(tester, fixture(),
        roles: const ['business_owner'],
        route: MNRoutes.officeMoneySettings,
        size: const Size(320, 568),
        textScale: 2);
    await tapVisible(
        tester, find.text(const Strings('sw').offlineSettingsTitle));
    expect(find.byType(TextField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('management fits small phones with large text', (tester) async {
    await openMoney(tester, fixture(),
        roles: const ['business_owner'],
        route: MNRoutes.officeManagement,
        size: const Size(320, 568),
        textScale: 2);
    await tapVisible(tester, find.text(const Strings('sw').ownerAccount));
    expect(tester.takeException(), isNull);
  });
}
