import 'office_design_helpers.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/business_day.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/stock_screens.dart'
    show transitDeliveredLater, transitLoss, transitReturned;
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/pressable.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible, verificationOffice;

const sw = Strings('sw');

/// The verification fake plus stock, recipes and production, in memory.
class StockOffice extends VerificationOffice
    implements OfficeStockRepository, OfficeProductionRepository {
  final returnCalls = <Map<String, Object?>>[];
  final resolveCalls = <String>[];
  final lateWrites = <int?>[];
  final draftCalls = <Map<String, Object?>>[];
  final decideCalls = <String>[];
  final runCalls = <Map<String, Object?>>[];

  /// Thrown (then cleared) by the next return; an [Exception] that is not
  /// an [OfficeError] stands for no answer from the server.
  Object? failNextReturn;
  bool locationsForbidden = false;
  List<Map<String, dynamic>> stockDayRows = const [];
  List<OfficeRecipe> recipeList = const [];
  List<OfficeProductionRun> runList = const [];
  List<StaffKitchen> meKitchens = const [];

  @override
  Future<StaffProfile> staffMe() async => StaffProfile(
      id: owner.id,
      name: owner.name,
      phone: '',
      roles: owner.roles,
      kitchens: meKitchens);

  @override
  Future<List<OfficeStockLocation>> stockLocations() async {
    if (locationsForbidden) throw const OfficeError(OfficeErrorKind.forbidden);
    return const [
      OfficeStockLocation(
          id: 'k1', code: 'JK1', name: 'Jiko Kuu', kind: 'kitchen'),
      OfficeStockLocation(
          id: 'r1', code: 'GH1', name: 'Ghala Kuu', kind: 'receiving'),
      OfficeStockLocation(
          id: 'v1', code: 'VC1', name: 'Mkononi', kind: 'vendor_custody'),
    ];
  }

  @override
  Future<OfficeStockReturn> recordReturn(
      {required String clientId,
      required String stationId,
      required String businessDate,
      required String destinationLocationId,
      required String reason,
      required List<ReturnLineDraft> lines}) async {
    returnCalls.add({
      'client_id': clientId,
      'station_id': stationId,
      'business_date': businessDate,
      'destination': destinationLocationId,
      'reason': reason,
      'lines': [for (final l in lines) l.toJson()],
    });
    if (failNextReturn case final e?) {
      failNextReturn = null;
      throw e;
    }
    return OfficeStockReturn.fromJson({
      'id': 'ret-1',
      'client_id': clientId,
      'station_id': stationId,
      'business_date': businessDate,
      'destination_location_id': destinationLocationId,
      'destination_name': 'Jiko Kuu',
      'reason': reason,
      'cost_amount': 18000,
      'lines': [
        for (final l in lines)
          {
            'product': l.product,
            'name': 'Kuku mzima',
            'unit': 'bird',
            'quantity': l.quantity,
            'cost_amount': 18000,
          }
      ],
    });
  }

  @override
  Future<List<OfficeStockReturn>> stockReturns(
          {String? stationId, String? from, String? to}) async =>
      const [];

  @override
  Future<OfficeStockDays> stockDays(
          {required String stationId, String? from, String? to}) async =>
      OfficeStockDays.fromJson({
        'station_id': stationId,
        'from': from,
        'to': to,
        'days': stockDayRows
      });

  @override
  Future<ResolvedProblem> resolveTransit(String exceptionId,
      {required String resolution,
      required String reason,
      String? destinationLocationId}) async {
    resolveCalls.add('$exceptionId|$resolution|$reason|$destinationLocationId');
    exceptionList.removeWhere((e) => e.id == exceptionId);
    return ResolvedProblem(id: exceptionId, status: 'resolved');
  }

  @override
  Future<void> saveLateEntryHours(int? hours, {required String reason}) async {
    lateWrites.add(hours);
    moneySettingsValue = OfficeMoneySettings(lateEntryHours: hours);
  }

  @override
  Future<List<OfficeRecipe>> recipes() async => recipeList;
  @override
  Future<OfficeRecipe> recipe(String id) async =>
      recipeList.firstWhere((r) => r.id == id);
  @override
  Future<OfficeRecipe> createRecipe(
          {required String name,
          required String product,
          required String reason}) async =>
      OfficeRecipe(id: 'r-new', name: name, product: product);

  @override
  Future<RecipeVersion> draftVersion(String recipeId,
      {required List<RecipeLineDraft> inputs,
      required List<RecipeLineDraft> outputs,
      required AllocationMethod method,
      required String wasteKind,
      required String wasteValue,
      required String maxOutputRatio,
      required String reason}) async {
    draftCalls.add({
      'inputs': [for (final l in inputs) '${l.product}:${l.quantity}'],
      'outputs': [
        for (final l in outputs) '${l.product}:${l.quantity}:${l.basis}'
      ],
      'method': method.wire,
      'waste': '$wasteKind:$wasteValue',
      'ratio': maxOutputRatio,
      'reason': reason,
    });
    return RecipeVersion(id: 'ver-new', version: 3);
  }

  @override
  Future<RecipeVersion> decideVersion(String versionId,
      {required bool approve, required String reason}) async {
    decideCalls.add('$versionId approve=$approve reason=$reason');
    return RecipeVersion(id: versionId, version: 1, status: 'approved');
  }

  @override
  Future<OfficeProductionRun> recordRun(
      {required String clientId,
      required String kitchenId,
      required String versionId,
      required List<RecipeLineDraft> inputs,
      required List<RecipeLineDraft> outputs,
      required Object wasteQuantity,
      DateTime? occurredAt,
      String? note}) async {
    runCalls.add({
      if (occurredAt != null)
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      'client_id': clientId,
      'kitchen': kitchenId,
      'version': versionId,
      'inputs': [for (final l in inputs) '${l.product}:${l.quantity}'],
      'outputs': [for (final l in outputs) '${l.product}:${l.quantity}'],
      'waste': wasteQuantity,
    });
    return OfficeProductionRun.fromJson({
      'id': 'run-9',
      'client_id': clientId,
      'kitchen_location_id': kitchenId,
      'recipe_name': 'Kuku wa kukata',
      'recipe_version_id': versionId,
      'version': 1,
      'batches': '1',
      'cost_state': 'unknown',
      'input_cost': null,
      'abnormal_loss_cost': null,
      'waste': {'quantity': '0', 'allowed': '0.5', 'abnormal_quantity': '0'},
      'variance': true,
      'exception_id': 'x-var',
      'inputs': [
        {
          'kind': 'input',
          'product': 'KUKU',
          'name': 'Kuku mzima',
          'unit': 'bird',
          'quantity': '1',
          'cost': null
        }
      ],
      'outputs': [
        {
          'line': 1,
          'product': 'PAJA',
          'name': 'Paja',
          'unit': 'piece',
          'quantity': '1',
          'expected_quantity': '4',
          'allocated_cost': null,
          'lots': [],
        }
      ],
    });
  }

  @override
  Future<List<OfficeProductionRun>> productionRuns(
          {String? kitchenId, String? from, String? to}) async =>
      runList;
  @override
  Future<OfficeProductionRun> productionRun(String id) async =>
      runList.firstWhere((r) => r.id == id);
}

StockOffice stockOffice() {
  final office = StockOffice()
    ..signedIn = true
    ..verificationList.addAll(verificationOffice().verificationList)
    ..productsList.addAll(const [
      OfficeProduct(
          code: 'KUKU', name: 'Kuku mzima', category: 'kuku', unit: 'bird'),
      OfficeProduct(
          code: 'PAJA', name: 'Paja', category: 'kuku', unit: 'piece'),
      OfficeProduct(
          code: 'KIDALI', name: 'Kidali', category: 'kuku', unit: 'piece'),
    ]);
  return office;
}

const _version1 = {
  'id': 'ver-1',
  'recipe_id': 'rec-1',
  'version': 1,
  'status': 'approved',
  'in_force': true,
  'allocation_method': 'weight',
  'waste_allowance': {'kind': 'percent', 'value': '5'},
  'max_output_ratio': '1.2',
  'drafted_by': 'ops-1',
  'inputs': [
    {
      'line': 1,
      'product': 'KUKU',
      'name': 'Kuku mzima',
      'unit': 'bird',
      'quantity': '1'
    }
  ],
  'outputs': [
    {
      'line': 1,
      'product': 'PAJA',
      'name': 'Paja',
      'unit': 'piece',
      'quantity': '4',
      'unit_weight': '0.25'
    },
  ],
};

OfficeRecipe recipeWithDrafts() => OfficeRecipe.fromJson({
      'id': 'rec-1',
      'name': 'Kuku wa kukata',
      'product': 'KUKU',
      'product_name': 'Kuku mzima',
      'active_version_id': 'ver-1',
      'versions': [
        _version1,
        {
          ..._version1,
          'id': 'ver-2',
          'version': 2,
          'status': 'draft',
          'in_force': false,
          'drafted_by': 'ops-1'
        },
        {
          ..._version1,
          'id': 'ver-3',
          'version': 3,
          'status': 'draft',
          'in_force': false,
          'drafted_by': 'st1'
        },
      ],
    });

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

/// Opens the choice field labelled [label] and picks [option].
Future<void> choose(WidgetTester tester, String label, String option) async {
  final field = find.descendant(
      of: find.widgetWithText(MNFieldButton, label),
      matching: find.byType(MNPressable));
  await tapVisible(tester, field.first);
  await tester.tap(_inSheet(find.text(option)).last);
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, String label, String text,
    {int at = 0}) async {
  final field = find.descendant(
      of: find.widgetWithText(MNTextField, label).at(at),
      matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Taps the + of the [index]th kikapu stepper on the page.
Future<void> plus(WidgetTester tester, int index) async {
  final button = find
      .descendant(
          of: find.byType(MNQuantitySelector).at(index),
          matching: find.byType(MNQuantityButton))
      .last;
  await tapVisible(tester, button);
}

void main() {
  final today = businessDateKey(DateTime.now());

  group('returns', () {
    testWidgets('the form sends exact lines and the same client id on retry',
        (tester) async {
      final office = stockOffice()..failNextReturn = Exception('offline');
      await openAs(tester, office, route: MNRoutes.officeStockReturn('s1'));
      // Only kitchens and receiving stores take returns.
      final field = find.descendant(
          of: find.widgetWithText(MNFieldButton, sw.returnDestination),
          matching: find.byType(MNPressable));
      await tapVisible(tester, field);
      expect(_inSheet(find.text('Mkononi')), findsNothing);
      await tester.tap(_inSheet(find.text('Jiko Kuu')));
      await tester.pumpAndSettle();
      await tapVisible(tester, _button(sw.addMore));
      await tester.tap(_inSheet(find.text('Kuku mzima')));
      await tester.pumpAndSettle();
      await plus(tester, 0); // 1 → 2
      await typeInto(tester, sw.returnReason, 'Zimebaki jioni');
      await tapVisible(tester, _button(sw.returnSend));
      expect(_inSheet(find.text('2 Kuku × Kuku mzima')), findsOneWidget);
      expect(office.returnCalls, isEmpty); // Nothing sent before the summary.
      await tester.tap(_inSheet(_button(sw.returnSend)));
      await tester.pumpAndSettle();
      expect(find.textContaining(sw.sendRetryNote), findsOneWidget);
      await tapVisible(tester, _button(sw.retry));
      expect(office.returnCalls, hasLength(2));
      final first = office.returnCalls[0], second = office.returnCalls[1];
      expect(second, first);
      expect(first['client_id'], isNotEmpty);
      expect(first['station_id'], 's1');
      expect(first['destination'], 'k1');
      expect(first['business_date'], today);
      expect(first['lines'], [
        {'product': 'KUKU', 'quantity': 2}
      ]);
      expect(find.text(sw.returnSaved), findsOneWidget);
      expect(find.text(sw.costText('TSh 18,000')), findsWidgets);
    });

    testWidgets('a stock refusal is localized', (tester) async {
      final office = stockOffice()
        ..failNextReturn = const OfficeError(
            OfficeErrorKind.refused, 'The station held only 3 of KUKU.');
      await openAs(tester, office, route: MNRoutes.officeStockReturn('s1'));
      await choose(tester, sw.returnDestination, 'Ghala Kuu');
      await tapVisible(tester, _button(sw.addMore));
      await tester.tap(_inSheet(find.text('Kuku mzima')));
      await tester.pumpAndSettle();
      await typeInto(tester, sw.returnReason, 'Zimebaki jioni');
      await tapVisible(tester, _button(sw.returnSend));
      await tester.tap(_inSheet(_button(sw.returnSend)));
      await tester.pumpAndSettle();
      expect(find.text('Kiasi kilichopo kituoni hakitoshi kwa ombi hili.'),
          findsOneWidget);
      // The form opens again with a new id for the next attempt.
      expect(_button(sw.returnSend), findsOneWidget);
    });
  });

  group('stock days', () {
    testWidgets('empty Stoo keeps the period and disables returns',
        (tester) async {
      await openAs(tester, stockOffice(), route: MNRoutes.officeStock('s1'));
      expect(find.text(sw.stockNoRecords), findsOneWidget);
      expect(find.text(sw.stockRecordsHint), findsOneWidget);
      expect(find.text(sw.stockChoosePeriod), findsOneWidget);
      expect(find.text(sw.stockDailyCounts), findsNothing);
      expect(
          tester.widget<MNButton>(_button(sw.returnGoods)).onPressed, isNull);
      await tapVisible(tester, find.text(sw.stockChoosePeriod));
      expect(find.text(sw.stockChoosePeriod), findsWidgets);
    });

    testWidgets('blockers in words, the previous day, and a reopened day',
        (tester) async {
      final office = stockOffice()
        ..closingList.add(const OfficeClosingCount(
            id: 'c9', vendorName: 'Asha Juma', status: 'confirmed'))
        ..stockDayRows = [
          {
            'vendor_day_id': 'vd-20',
            'vendor_name': 'Asha Juma',
            'business_date': '2026-10-20',
            'stock_status': 'needs_reconciliation',
            'closing_id': 'c9',
            'closing_status': 'confirmed',
            'revision': 2,
            'blockers': null,
            'reopened_by': [
              {
                'movement_id': 'm1',
                'movement_type': 'return',
                'occurred_at': '2026-10-22T08:00:00Z',
                'business_date': '2026-10-20',
                'previous_status': 'reconciled',
                'by': 'Neema',
                'at': '2026-10-22T08:00:00Z'
              }
            ],
            'products': [
              {
                'product_id': 'p1',
                'product_code': 'KUKU',
                'name': 'Kuku mzima',
                'unit': 'bird',
                'opening': 4,
                'received': 10,
                'sold': 8,
                'returned': 1,
                'lost': 0,
                'moved_out': 0,
                'expected_closing': 5,
                'counted_closing': 4,
                'difference': -1
              }
            ],
          },
          {
            'vendor_day_id': 'vd-22',
            'vendor_name': 'Baraka Ally',
            'business_date': '2026-10-22',
            'stock_status': 'open',
            'closing_id': 'c10',
            'previous_business_date': '2026-10-21',
            'previous_stock_status': 'open',
            'blockers': {
              'unverified_sales': 2,
              'pending_damage': 0,
              'previous_day_unreconciled': 1
            },
            'reopened_by': [],
            'products': [],
          },
        ];
      await openAs(tester, office, route: MNRoutes.officeStock('s1'));
      await tapVisible(tester, find.text('Iko wazi'));
      expect(find.text('Iko wazi'), findsOneWidget);
      expect(
          find.text('Huwezi kuthibitisha bado: mauzo 2 hayajathibitishwa, '
              'siku iliyotangulia (21 Okt 2026) haijasawazishwa'),
          findsOneWidget);
      await tester.tap(find.byTooltip(sw.back));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Inahitaji kusawazishwa tena'));
      expect(find.text('Inahitaji kusawazishwa tena'), findsOneWidget);
      expect(
          find.textContaining(
              'Imefunguliwa tena na urejeshaji ya siku 20 Okt 2026'),
          findsOneWidget);
      // The day's products open as rows; a row opens its equation.
      await tapVisible(tester, find.text(sw.stockShowProducts));
      expect(find.text('Inayotarajiwa 5 · Tofauti −1'), findsOneWidget);
      await tapVisible(tester, find.text('Kuku mzima'));
      expect(find.text(sw.stockSold), findsOneWidget);
      // A reopened day's closing can be confirmed again.
      await tapVisible(tester, _button(sw.stockConfirmAgain));
      expect(office.confirms, ['c9']);
    });

    testWidgets('Funga Siku names the previous-day blocker', (tester) async {
      final office = stockOffice()
        ..closingList.add(OfficeClosingCount(
            id: 'c3',
            vendorName: 'Asha Juma',
            businessDate: DateTime.utc(2026, 10, 22),
            previousDayUnreconciled: 1));
      await openAs(tester, office,
          route: MNRoutes.officeVerificationStation('s1'));
      await tapVisible(tester, find.text(sw.closeDay));
      expect(find.text('${sw.closingBlocked} ${sw.closingBlockedPreviousDay}'),
          findsOneWidget);
      expect(
          tester.widget<MNButton>(_button(sw.confirmCount)).onPressed, isNull);
      expect(find.text(sw.stockTitle), findsOneWidget); // The Stoo entry.
    });
  });

  testWidgets('a receipt mismatch goes back to central with a reason',
      (tester) async {
    final office = stockOffice()
      ..exceptionList.addAll([
        OfficeException(
            id: 'x2',
            kind: 'receipt_mismatch',
            openedAt: DateTime.utc(2026, 10, 22, 9)),
        OfficeException(
            id: 'x3',
            kind: 'production_variance',
            detail: const {
              'reasons': ['above_max_ratio'],
              'abnormal_loss_cost': '12500.00',
              'batches': '2'
            },
            openedAt: DateTime.utc(2026, 10, 22, 10)),
      ]);
    await openAs(tester, office,
        route: MNRoutes.officeVerificationProblems('s1'));
    expect(find.text('Tofauti ya uzalishaji'), findsOneWidget);
    expect(find.text(sw.abnormalLossText('TSh 12,500')), findsOneWidget);
    expect(_button(sw.mismatchResolve), findsOneWidget);
    await tapVisible(tester, _button(sw.mismatchResolve));
    // Nothing is chosen for the supervisor, and a loss is not theirs.
    final outcome = find.descendant(
        of: find.widgetWithText(MNFieldButton, sw.mismatchOutcome),
        matching: find.byType(MNPressable));
    await tester.tap(outcome);
    await tester.pumpAndSettle();
    expect(find.text(sw.transitResolutionName(transitLoss)), findsNothing);
    expect(find.text(sw.transitResolutionName(transitDeliveredLater)),
        findsOneWidget);
    await tester.tap(find.text(sw.transitResolutionName(transitReturned)).last);
    await tester.pumpAndSettle();
    await tester.enterText(_inSheet(find.byType(TextField)), 'Hazikufika');
    await tester
        .tap(_inSheet(_button(sw.transitResolutionName(transitReturned))));
    await tester.pumpAndSettle();
    expect(office.resolveCalls, ['x2|returned_to_central|Hazikufika|null']);
    expect(find.text(sw.mismatchResolved(transitReturned)), findsOneWidget);
  });

  testWidgets('units delivered later go into the station stock',
      (tester) async {
    final office = stockOffice()
      ..exceptionList
          .add(const OfficeException(id: 'x2', kind: 'receipt_mismatch'));
    await openAs(tester, office,
        route: MNRoutes.officeVerificationProblems('s1'));
    await tapVisible(tester, _button(sw.mismatchResolve));
    await choose(tester, sw.mismatchOutcome,
        sw.transitResolutionName(transitDeliveredLater));
    // Only a return names a store.
    expect(find.text(sw.mismatchDestination), findsNothing);
    await tester.enterText(_inSheet(find.byType(TextField)), 'Zimefika jioni');
    await tester.tap(
        _inSheet(_button(sw.transitResolutionName(transitDeliveredLater))));
    await tester.pumpAndSettle();
    expect(office.resolveCalls, ['x2|delivered_later|Zimefika jioni|null']);
    expect(
        find.text(sw.mismatchResolved(transitDeliveredLater)), findsOneWidget);
  });

  testWidgets('finance records a transit loss and nothing else',
      (tester) async {
    final office = stockOffice()
      ..exceptionList
          .add(const OfficeException(id: 'x2', kind: 'receipt_mismatch'));
    await openAs(tester, office,
        roles: const ['finance'],
        route: MNRoutes.officeVerificationProblems('s1'));
    await tapVisible(tester, _button(sw.mismatchResolve));
    // Their one choice is already chosen.
    expect(_inSheet(find.text(sw.transitResolutionName(transitLoss))),
        findsWidgets);
    await tester.enterText(_inSheet(find.byType(TextField)), 'Zimepotea');
    await tester.tap(_inSheet(_button(sw.transitResolutionName(transitLoss))));
    await tester.pumpAndSettle();
    expect(office.resolveCalls, ['x2|transit_loss|Zimepotea|null']);
    expect(find.text(sw.mismatchResolved(transitLoss)), findsOneWidget);
  });

  testWidgets('operations sees no resolve button', (tester) async {
    final office = stockOffice()
      ..exceptionList
          .add(const OfficeException(id: 'x2', kind: 'receipt_mismatch'));
    await openAs(tester, office,
        roles: const ['operations_admin'],
        route: MNRoutes.officeVerificationProblems('s1'));
    expect(_button(sw.mismatchResolve), findsNothing);
  });

  testWidgets('the late-entry window takes 0 to 720 hours or none',
      (tester) async {
    final office = stockOffice();
    await openAs(tester, office,
        roles: const ['business_owner'], route: MNRoutes.officeMoneySettings);
    expect(find.text(sw.lateEntryTitle), findsOneWidget);
    expect(find.text(sw.lateEntryNotSet), findsOneWidget);
    await tapVisible(tester, find.text(sw.lateEntryTitle));
    await typeInto(tester, sw.lateEntryHours, '721');
    await tapVisible(tester, _button(sw.lateEntrySave));
    expect(find.text(sw.lateEntryInvalid), findsOneWidget);
    expect(office.lateWrites, isEmpty);
    await typeInto(tester, sw.lateEntryHours, '48');
    await tapVisible(tester, _button(sw.lateEntrySave));
    await tester.enterText(_inSheet(find.byType(TextField)), 'Siku mbili');
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(office.lateWrites, [48]);
    expect(find.text(sw.lateEntryValue(48)), findsOneWidget);
    await tapVisible(tester, _button(sw.lateEntryClear));
    await tester.enterText(_inSheet(find.byType(TextField)), 'Bila dirisha');
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(office.lateWrites, [48, null]);
    expect(parseLateEntryHours('0'), 0);
    expect(parseLateEntryHours('720'), 720);
    expect(parseLateEntryHours('-1'), isNull);
  });

  group('recipes', () {
    testWidgets('fixed shares must total 100% before sending', (tester) async {
      final office = stockOffice()..recipeList = [recipeWithDrafts()];
      await openAs(tester, office,
          roles: const ['operations_admin'],
          route: MNRoutes.officeRecipeNewVersion('rec-1'));
      await tapVisible(tester, _button(sw.recipeAddInput));
      await tester.tap(_inSheet(find.text('Kuku mzima')));
      await tester.pumpAndSettle();
      await choose(tester, sw.recipeMethod, sw.methodName('fixed_shares'));
      for (final name in ['Paja', 'Kidali']) {
        await tapVisible(tester, _button(sw.recipeAddOutput));
        await tester.tap(_inSheet(find.text(name)));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 3; i++) {
        await plus(tester, i);
      }
      final share = sw.basisLabel('fixed_shares');
      await typeInto(tester, share, '50');
      await typeInto(tester, share, '40', at: 1);
      await typeInto(tester, sw.wasteValue, '5');
      await typeInto(tester, sw.recipeMaxRatio, '1.2');
      await typeInto(tester, sw.moneyReason, 'Toleo jipya la kukata');
      expect(find.text(sw.sharesTotal('90')), findsOneWidget);
      await tapVisible(tester, _button(sw.saveWorkflow));
      expect(find.text(sw.sharesMustTotal), findsOneWidget);
      expect(office.draftCalls, isEmpty);
      await typeInto(tester, share, '50', at: 1);
      await tapVisible(tester, _button(sw.saveWorkflow));
      expect(office.draftCalls, [
        {
          'inputs': ['KUKU:1'],
          'outputs': ['PAJA:1:5000', 'KIDALI:1:5000'],
          'method': 'fixed_shares',
          'waste': 'quantity:5',
          'ratio': '1.2',
          'reason': 'Toleo jipya la kukata',
        }
      ]);
      expect(percentToBps('62.5'), 6250);
      expect(percentToBps('101'), isNull);
    });

    testWidgets('the owner approves others\' drafts, never their own',
        (tester) async {
      final office = stockOffice()..recipeList = [recipeWithDrafts()];
      await openAs(tester, office,
          roles: const ['business_owner'],
          route: MNRoutes.officeRecipe('rec-1'));
      expect(find.text(sw.recipeInForce(1)), findsWidgets);
      // Version 3 is the owner's own draft (drafted_by st1): no approve.
      expect(find.text(sw.recipeYourDraft), findsOneWidget);
      expect(_button(sw.recipeApprove), findsOneWidget);
      await tapVisible(tester, _button(sw.recipeApprove));
      await tester.enterText(_inSheet(find.byType(TextField)), 'Imekaguliwa');
      await tester.tap(_inSheet(_button(sw.recipeApprove)));
      await tester.pumpAndSettle();
      expect(office.decideCalls, ['ver-2 approve=true reason=Imekaguliwa']);
    });

    testWidgets('operations drafts but never sees approve', (tester) async {
      final office = stockOffice()..recipeList = [recipeWithDrafts()];
      await openAs(tester, office,
          roles: const ['operations_admin'],
          route: MNRoutes.officeRecipe('rec-1'));
      expect(_button(sw.recipeApprove), findsNothing);
      expect(_button(sw.recipeNewVersion), findsOneWidget);
    });
  });

  testWidgets('a production run shows a summary, then the server answer',
      (tester) async {
    // A new kitchen-staff member: no runs yet, one kitchen grant.
    final office = stockOffice()
      ..locationsForbidden = true
      ..recipeList = [recipeWithDrafts()]
      ..meKitchens = const [
        StaffKitchen(id: 'k1', code: 'JK1', name: 'Jiko Kuu')
      ];
    await openAs(tester, office,
        roles: const ['kitchen_staff'], route: MNRoutes.officeProductionNew);
    // Their kitchen comes from /staff/me and is chosen for them.
    expect(find.text('Jiko Kuu'), findsOneWidget);
    await choose(tester, sw.productionRecipe, 'Kuku wa kukata');
    // Nothing is prefilled: the steppers start at 0.
    expect(
        tester
            .widgetList<MNQuantitySelector>(find.byType(MNQuantitySelector))
            .map((q) => q.value),
        everyElement(0));
    await plus(tester, 0); // Kuku mzima input
    await plus(tester, 1); // Paja output
    await tapVisible(tester, _button(sw.productionSend));
    expect(_inSheet(find.text('1 Kuku × Kuku mzima')), findsOneWidget);
    expect(_inSheet(find.text('1 Kipande × Paja')), findsOneWidget);
    expect(office.runCalls, isEmpty);
    await tester.tap(_inSheet(_button(sw.productionSend)));
    await tester.pumpAndSettle();
    expect(office.runCalls, hasLength(1));
    expect(office.runCalls.single['kitchen'], 'k1');
    expect(office.runCalls.single['version'], 'ver-1');
    expect(office.runCalls.single['inputs'], ['KUKU:1']);
    expect(office.runCalls.single['outputs'], ['PAJA:1']);
    expect(office.runCalls.single['waste'], 0);
    expect(find.text(sw.productionSaved), findsOneWidget);
    expect(find.text(sw.batchesText('1')), findsOneWidget);
    expect(find.text(sw.productionCostUnknown), findsOneWidget);
    expect(find.text(sw.productionVariance), findsOneWidget);
    expect(find.text(sw.productionOutputText('1 Kipande', '4 Kipande')),
        findsNothing);
    await expandOfficeDetails(tester, sw.recordDetails);
    expect(find.text(sw.productionOutputText('1 Kipande', '4 Kipande')),
        findsOneWidget);
  });

  testWidgets('a production run done earlier is sent with its time',
      (tester) async {
    final office = stockOffice()
      ..locationsForbidden = true
      ..recipeList = [recipeWithDrafts()]
      ..meKitchens = const [
        StaffKitchen(id: 'k1', code: 'JK1', name: 'Jiko Kuu')
      ];
    // 24 October 2026, noon in Dar es Salaam.
    await openAs(tester, office,
        roles: const ['kitchen_staff'],
        route: MNRoutes.officeProductionNew,
        overrides: [
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 24, 9))
        ]);
    await choose(tester, sw.productionRecipe, 'Kuku wa kukata');
    await plus(tester, 0);
    await plus(tester, 1);
    // Empty means now.
    expect(find.text(sw.productionNow), findsOneWidget);
    await tapVisible(
        tester,
        find.descendant(
            of: find.widgetWithText(MNFieldButton, sw.productionWhen),
            matching: find.byType(MNPressable)));
    await tester.tap(find.byKey(const ValueKey('mn-date-2026-10-22')));
    await tester.pump();
    await tester.tap(find.text(sw.useThisDate));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(sw.useThisTime));
    await tester.pumpAndSettle();
    expect(find.text(sw.productionNow), findsNothing);
    await tapVisible(tester, _button(sw.productionSend));
    await tester.tap(_inSheet(_button(sw.productionSend)));
    await tester.pumpAndSettle();
    // Noon in Dar es Salaam is 09:00 UTC.
    expect(office.runCalls.single['occurred_at'], '2026-10-22T09:00:00.000Z');
    // The answer names the inputs, not just their codes.
    expect(find.textContaining('1 Kuku Kuku mzima'), findsNothing);
    await expandOfficeDetails(tester, sw.recordDetails);
    expect(find.textContaining('1 Kuku Kuku mzima'), findsOneWidget);
  });

  testWidgets('kitchen staff without a kitchen grant are told so',
      (tester) async {
    final office = stockOffice()
      ..locationsForbidden = true
      ..recipeList = [recipeWithDrafts()];
    await openAs(tester, office,
        roles: const ['kitchen_staff'], route: MNRoutes.officeProductionNew);
    expect(find.text(sw.productionNoKitchens), findsOneWidget);
    expect(sw.productionNoKitchens, startsWith('Ofisi haijakuweka jikoni'));
  });

  test('a profile without kitchens parses to none', () {
    final bare = StaffProfile.fromJson(const {
      'id': 'a',
      'name': 'Juma',
      'roles': ['kitchen_staff']
    });
    expect(bare.kitchens, isEmpty);
    final full = StaffProfile.fromJson(const {
      'id': 'a',
      'name': 'Juma',
      'roles': ['kitchen_staff'],
      'kitchens': [
        {'id': 'k1', 'code': 'JK1', 'name': 'Jiko Kuu'},
        'not a kitchen',
      ]
    });
    expect(full.kitchens.single.name, 'Jiko Kuu');
    expect(StaffProfile.fromJson(full.toJson()).kitchens.single.code, 'JK1');
  });

  testWidgets(
      'entry points: Mapishi and Uzalishaji for managers, '
      'Uzalishaji for kitchen staff', (tester) async {
    await openAs(tester, stockOffice(),
        roles: const ['operations_admin'], route: MNRoutes.officeManagement);
    expect(find.text(sw.recipes), findsOneWidget);
    expect(find.text(sw.production), findsOneWidget);
  });

  testWidgets('kitchen staff reach Uzalishaji from their home', (tester) async {
    await openAs(tester, stockOffice(), roles: const ['kitchen_staff']);
    expect(find.text(sw.production), findsOneWidget);
    expect(find.text(sw.recipes), findsNothing);
  });

  test('new files use no platform dropdowns or date/time pickers', () {
    for (final path in [
      'lib/features/office/stock_screens.dart',
      'lib/features/office/production_screens.dart',
      'lib/core/api/office_stock.dart',
      'lib/core/api/office_production.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final banned in [
        'DropdownButton',
        'DropdownMenu',
        'showDatePicker',
        'showTimePicker',
        'PopupMenuButton',
      ]) {
        expect(source.contains(banned), isFalse, reason: '$path: $banned');
      }
    }
  });

  testWidgets('stock, recipe and production screens fit 320 px at 2× text',
      (tester) async {
    final office = stockOffice()
      ..recipeList = [recipeWithDrafts()]
      ..stockDayRows = [
        {
          'vendor_day_id': 'vd-1',
          'vendor_name': 'Asha Juma',
          'business_date': '2026-10-22',
          'stock_status': 'needs_reconciliation',
          'closing_id': 'c9',
          'previous_business_date': '2026-10-21',
          'blockers': {
            'unverified_sales': 1,
            'pending_damage': 1,
            'previous_day_unreconciled': 1
          },
          'reopened_by': [
            {'movement_type': 'return', 'business_date': '2026-10-22'}
          ],
          'products': [
            {
              'name': 'Kuku mzima',
              'unit': 'bird',
              'expected_closing': 5,
              'counted_closing': 4,
              'difference': -1
            }
          ],
        }
      ];
    final app = await openAs(tester, office,
        roles: const ['business_owner'],
        size: const Size(320, 568),
        textScale: 2);
    for (final route in [
      MNRoutes.officeStock('s1'),
      MNRoutes.officeStockReturn('s1'),
      MNRoutes.officeRecipes,
      MNRoutes.officeRecipe('rec-1'),
      MNRoutes.officeRecipeNewVersion('rec-1'),
      MNRoutes.officeProduction,
      MNRoutes.officeProductionNew,
      MNRoutes.officeMoneySettings,
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    app.router.go(MNRoutes.officeStock('s1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Inahitaji kusawazishwa tena'));
    await tapVisible(tester, find.text(sw.stockShowProducts));
    await tapVisible(tester, find.text('Kuku mzima'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip(sw.back));
    await tester.pumpAndSettle();
    app.router.go(MNRoutes.officeProductionNew);
    await tester.pumpAndSettle();
    await choose(tester, sw.productionRecipe, 'Kuku wa kukata');
    expect(tester.takeException(), isNull);
  });
}
