import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/pressable.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible;

const sw = Strings('sw');

/// Opening stock and kitchens in memory; records every write.
class SetupOffice extends VerificationOffice implements OfficeSetupRepository {
  final calls = <String>[];
  OfficeOpeningSettings settings =
      const OfficeOpeningSettings(date: '2026-10-20');
  final entries = <OfficeOpeningEntry>[];
  final locations = <OfficeStockLocation>[
    const OfficeStockLocation(
        id: 'k1', code: 'JK1', name: 'Jiko Kuu', kind: 'kitchen'),
    const OfficeStockLocation(
        id: 'r1', code: 'GH1', name: 'Ghala Kuu', kind: 'receiving'),
    const OfficeStockLocation(
        id: 'v1',
        code: 'VC1',
        name: 'Mkononi Kariakoo',
        kind: 'vendor_custody'),
  ];

  @override
  Future<List<OfficeOpeningEntry>> openingEntries() async => entries;
  @override
  Future<OfficeOpeningSettings> openingSettings() async => settings;
  @override
  Future<OfficeOpeningEntry> draftOpening(
      {required String clientId,
      required String locationId,
      required String product,
      required int quantity,
      int? unitCost,
      required String asOf,
      required String reference}) async {
    calls.add('draft $locationId $product $quantity cost=$unitCost '
        'asOf=$asOf ref=$reference');
    return OfficeOpeningEntry(id: 'n1', quantity: quantity);
  }

  @override
  Future<OfficeOpeningEntry> decideOpening(String id,
      {required bool approve, required String reason}) async {
    calls.add('decide $id approve=$approve reason=$reason');
    return OfficeOpeningEntry(id: id, quantity: 1);
  }

  @override
  Future<void> setOpeningDate(String date, {required String reason}) async =>
      calls.add('date $date');
  @override
  Future<void> closeOpening({required String reason}) async {
    calls.add('close');
    settings = OfficeOpeningSettings(date: settings.date, closed: true);
  }

  @override
  Future<List<OfficeStockLocation>> setupLocations() async => locations;
  @override
  Future<OfficeStockLocation> createLocation(
      {required String code,
      required String name,
      required String kind}) async {
    calls.add('location $code $name $kind');
    final row =
        OfficeStockLocation(id: 'new', code: code, name: name, kind: kind);
    locations.add(row);
    return row;
  }

  @override
  Future<void> grantKitchenRole(
          {required String staffId,
          required String kitchenLocationId,
          required String reason}) async =>
      calls.add('kitchen $staffId $kitchenLocationId $reason');
}

OfficeOpeningEntry entry(String id, String by, {String status = 'draft'}) =>
    OfficeOpeningEntry(
        id: id,
        productName: 'Kuku mzima',
        locationName: 'Ghala Kuu',
        quantity: 12,
        reference: 'Karatasi A',
        enteredBy: by,
        enteredByName: 'Neema Said',
        asOf: '2026-10-20',
        status: status);

SetupOffice office() => SetupOffice()
  ..productsList.add(const OfficeProduct(
      code: 'KUKU',
      name: 'Kuku mzima',
      category: 'c',
      unit: 'bird',
      price: 18000,
      available: true));

final _addButton = find.byWidgetPredicate(
    (w) => w is OwnerIconButton && w.label == sw.kitchensAdd);
Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

Future<void> choose(WidgetTester tester, String label, String option) async {
  final field = find.descendant(
      of: find.widgetWithText(MNFieldButton, label),
      matching: find.byType(MNPressable));
  await tapVisible(tester, field.first);
  await tester.tap(_inSheet(find.text(option)).last);
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
      of: find.widgetWithText(MNTextField, label),
      matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  group('opening stock', () {
    testWidgets('empty opening stock shows the date, status and one action',
        (tester) async {
      await openAs(tester, office(),
          roles: const ['finance'], route: MNRoutes.officeOpening);

      expect(find.text(sw.openingDateCaption), findsOneWidget);
      expect(find.text(sw.openingStatus), findsOneWidget);
      expect(find.text(sw.openingStatusNotStarted), findsOneWidget);
      expect(find.text(sw.openingEmptyInstruction), findsOneWidget);
      expect(find.text(sw.openingApprovalRequired), findsOneWidget);
      expect(find.text(sw.openingAdd), findsOneWidget);
      expect(find.text(sw.openingClose), findsNothing);
    });

    testWidgets('approved opening entries show server-sourced totals',
        (tester) async {
      final o = office()
        ..entries.add(OfficeOpeningEntry(
            id: 'approved',
            productName: 'Kuku mzima',
            locationName: 'Ghala Kuu',
            quantity: 12,
            unitCost: 7000,
            enteredBy: 'finance-1',
            enteredByName: 'Neema Said',
            asOf: '2026-10-20',
            status: 'approved'));
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpening);

      expect(find.text(sw.openingApproved), findsWidgets);
      expect(find.text('TZS 84,000'), findsOneWidget);
      expect(find.text('Kuku mzima × 12'), findsOneWidget);
      expect(find.text(sw.openingApprove), findsNothing);
      expect(find.text(sw.openingAdd), findsOneWidget);
    });

    testWidgets('mixed entry decisions are not summarized as all rejected',
        (tester) async {
      final o = office()
        ..entries.addAll([
          entry('approved', 'finance-1', status: 'approved'),
          entry('rejected', 'finance-2', status: 'rejected'),
        ]);
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpening);

      expect(find.text(sw.openingStatusMixed), findsOneWidget);
    });

    testWidgets('closed opening stock is final and cannot accept entries',
        (tester) async {
      final o = office()
        ..settings =
            const OfficeOpeningSettings(date: '2026-10-20', closed: true);
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);

      expect(find.text(sw.openingStatusClosed), findsOneWidget);
      expect(find.text(sw.openingClosedNote), findsOneWidget);
      expect(find.text(sw.openingAdd), findsNothing);
      expect(find.text(sw.openingClose), findsNothing);
    });

    testWidgets('a blank cost stays unknown and the owner is warned first',
        (tester) async {
      final o = office();
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpeningNew);
      expect(find.textContaining('Mhasibu aandike, wewe uidhinishe.'),
          findsOneWidget);
      await choose(tester, sw.openingLocation, 'Ghala Kuu');
      await choose(tester, sw.openingProduct, 'Kuku mzima');
      await typeInto(tester, sw.openingRefRequired, 'Karatasi A');
      await tapVisible(tester, _button(sw.openingSave));
      expect(o.calls,
          ['draft r1 KUKU 1 cost=null asOf=2026-10-20 ref=Karatasi A']);
    });

    testWidgets('a typed cost and quantity are sent exactly', (tester) async {
      final o = office();
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpeningNew);
      // Finance is not warned: they are the ones who enter it.
      expect(find.textContaining('Mhasibu aandike'), findsNothing);
      await choose(tester, sw.openingLocation, 'Jiko Kuu');
      await choose(tester, sw.openingProduct, 'Kuku mzima');
      final plus = find.byTooltip('${sw.increase} ${sw.openingQuantity}');
      if (plus.evaluate().isNotEmpty) await tapVisible(tester, plus.first);
      await typeInto(tester, sw.openingUnitCost, '7000');
      await typeInto(tester, sw.openingRefRequired, 'Karatasi B');
      await tapVisible(tester, _button(sw.openingSave));
      expect(o.calls.single, startsWith('draft k1 KUKU '));
      expect(o.calls.single, contains('cost=7000'));
    });

    testWidgets('closed or undated hides the form and the add button',
        (tester) async {
      final o = office()
        ..settings =
            const OfficeOpeningSettings(date: '2026-10-20', closed: true);
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingClosedNote), findsOneWidget);
      expect(find.text(sw.openingAdd), findsNothing);
      expect(find.text(sw.openingClose), findsNothing);
    });

    testWidgets('undated: the owner must set a date and no form shows',
        (tester) async {
      final o = office()..settings = const OfficeOpeningSettings();
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingDateOwnerOnly), findsOneWidget);
      expect(find.text(sw.openingAdd), findsNothing);
      expect(find.text(sw.openingDateUnset), findsOneWidget);
    });

    testWidgets('the drafter cannot approve; another owner can decide',
        (tester) async {
      final o = office()
        ..entries.addAll([entry('mine', 'st1'), entry('theirs', 'finance-1')]);
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingOwnDraftOwner), findsOneWidget);
      expect(find.text(sw.openingApprove), findsOneWidget);
      // Each may be rejected: the drafter's own, then the other's.
      expect(find.text(sw.openingReject), findsNWidgets(2));
      expect(find.text(sw.openingCostUnknown), findsNWidgets(3));
      await tapVisible(tester, find.text(sw.openingReject).last);
      await tester.enterText(
          _inSheet(find.byType(TextField)), 'Hesabu si sahihi');
      await tester.tap(_inSheet(find.text(sw.openingReject)).last);
      await tester.pumpAndSettle();
      expect(o.calls, ['decide theirs approve=false reason=Hesabu si sahihi']);
    });

    testWidgets('finance sees who decides and no decision buttons',
        (tester) async {
      final o = office()..entries.add(entry('e', 'finance-1'));
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingOwnerDecides), findsOneWidget);
      expect(find.text(sw.openingApprove), findsNothing);
    });

    testWidgets('closing asks first and then writes', (tester) async {
      final o = office();
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      await tapVisible(tester, find.text(sw.openingClose));
      expect(o.calls, isEmpty);
      await tester.tap(_button(sw.openingCloseYes));
      await tester.pumpAndSettle();
      expect(o.calls, ['close']);
      expect(find.text(sw.openingClosedNote), findsOneWidget);
    });

    for (final (roles, route, shown) in [
      (['business_owner'], MNRoutes.officeManagement, true),
      (['finance'], MNRoutes.officeAccount, true),
      (['supervisor'], MNRoutes.officeAccount, false),
      (['operations_admin'], MNRoutes.officeManagement, false),
    ]) {
      testWidgets('the row for $roles on $route: $shown', (tester) async {
        await openAs(tester, office(), roles: roles, route: route);
        expect(
            find.text(sw.openingTitle), shown ? findsOneWidget : findsNothing);
      });
    }
  });

  group('kitchens and stores', () {
    testWidgets('lists kitchens and stores and adds one of the two kinds',
        (tester) async {
      final o = office();
      await openAs(tester, o,
          roles: const ['operations_admin'], route: MNRoutes.officeKitchens);
      expect(find.text('Jiko Kuu'), findsOneWidget);
      expect(find.text('Ghala Kuu'), findsOneWidget);
      expect(find.text('Mkononi Kariakoo'), findsNothing);
      await tapVisible(tester, _addButton);
      await tapVisible(tester, _inSheet(find.byType(MNFieldButton)).first);
      expect(find.text(sw.kitchenKindKitchen), findsWidgets);
      expect(find.text(sw.kitchenKindReceiving), findsWidgets);
      expect(find.text('Mkononi'), findsNothing);
      await tester.tap(_inSheet(find.text(sw.kitchenKindReceiving)).last);
      await tester.pumpAndSettle();
      await typeInto(tester, sw.kitchenName, 'Stoo Mpya');
      await typeInto(tester, sw.kitchenCode, 'st2');
      await tester.tap(_inSheet(_button(sw.kitchensAdd)));
      await tester.pumpAndSettle();
      expect(o.calls, ['location ST2 Stoo Mpya receiving']);
    });

    testWidgets('without stations.manage there is no add button',
        (tester) async {
      await openAs(tester, office(),
          roles: const ['supervisor'], route: MNRoutes.officeKitchens);
      expect(find.text('Jiko Kuu'), findsOneWidget);
      expect(_addButton, findsNothing);
    });

    testWidgets('granting kitchen staff needs a kitchen and sends it',
        (tester) async {
      final o = office()
        ..locations.add(const OfficeStockLocation(
            id: 'k2', code: 'JK2', name: 'Jiko la Pili', kind: 'kitchen'))
        ..staffList.add(const OfficeStaff(
            id: 'st9',
            name: 'Juma Pishi',
            phone: '+255713000999',
            roles: ['kitchen_staff'],
            roleGrants: [OfficeRoleGrant('g1', 'kitchen_staff', 'k1')],
            activated: true,
            suspended: false));
      await openAs(tester, o,
          roles: const ['business_owner'],
          route: MNRoutes.officeStaffMember('st9'));
      // The person's page shows the kitchen they work at.
      expect(find.text('Jiko Kuu'), findsOneWidget);
      // A second kitchen is a second grant of the same role.
      await tapVisible(tester, find.text(sw.grantRole));
      await tester.tap(_inSheet(find.text('Jikoni')));
      await tester.pumpAndSettle();
      await tester.enterText(
          _inSheet(find.byType(TextField)).last, 'Jiko la pili');
      await tester.tap(_inSheet(_button(sw.grantRole)));
      await tester.pumpAndSettle();
      expect(o.calls, isEmpty);
      expect(find.text(sw.kitchenRequired), findsOneWidget);
      await tester.tap(_inSheet(find.text(sw.selectPlaceholder)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jiko la Pili').last);
      await tester.pumpAndSettle();
      await tester.tap(_inSheet(_button(sw.grantRole)));
      await tester.pumpAndSettle();
      expect(o.calls, ['kitchen st9 k2 Jiko la pili']);
    });

    test('the empty kitchen note still tells the truth', () {
      expect(sw.productionNoKitchens,
          'Ofisi haijakuweka jikoni. Muombe meneja akuweke kwenye jiko.');
    });
  });
}
