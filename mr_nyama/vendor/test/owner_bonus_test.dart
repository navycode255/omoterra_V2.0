import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/vendor_pay_pages.dart'
    show VendorPaymentStatementScreen;
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible;

const sw = Strings('sw');

/// 26 October 2026, noon in Dar es Salaam.
final _clock =
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 26, 9));

/// The verification fake plus owner bonuses and settings, in memory.
class BonusOffice extends VerificationOffice implements OwnerBonusesRepository {
  final bonusCalls = <String>[];
  final corrections = <String>[];
  OwnerBonusPeriod period = const OwnerBonusPeriod();
  OwnerVendorBonus? vendor;
  OwnerPerformanceSettings performance = const OwnerPerformanceSettings();

  @override
  Future<OwnerBonusPeriod> bonuses(
      {required String period, String? date}) async {
    bonusCalls.add('$period $date');
    return this.period;
  }

  @override
  Future<OwnerVendorBonus> vendorBonus(String vendorId,
          {required String period, String? date}) async =>
      vendor!;

  @override
  Future<void> correctSale(String saleId, {required String reason}) async {
    corrections.add('$saleId $reason');
  }

  @override
  Future<OwnerPerformanceSettings> performanceSettings() async => performance;
}

const juma = MoneyParty(id: 'v1', name: 'Juma Ali', code: 'V-0001');
const kariakoo = MoneyParty(id: 's1', name: 'Kariakoo', code: 'KRK');

BonusOffice office() => BonusOffice()
  ..period = OwnerBonusPeriod(
      period: 'week',
      from: DateTime.utc(2026, 10, 26),
      to: DateTime.utc(2026, 11, 1),
      earned: 3250,
      estimated: 1000,
      adjustments: -600,
      vendors: const [
        OwnerVendorBonus(
            vendor: juma, earned: 3250, estimated: 1000, chickens: 31)
      ])
  ..vendor = OwnerVendorBonus(vendor: juma, earned: 3250, days: [
    OwnerBonusDay(
        vendorDayId: 'd1',
        businessDate: DateTime.utc(2026, 10, 26),
        station: kariakoo,
        locked: true,
        chickens: 15,
        chickenBonus: 1000,
        profitBonus: 2250,
        vendorsSharing: 2,
        profit: 60000),
    OwnerBonusDay(
        vendorDayId: 'd0',
        businessDate: DateTime.utc(2026, 10, 25),
        station: kariakoo,
        chickens: 16,
        chickenBonus: 1000,
        profitKnown: false),
  ]);

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

Future<void> type(WidgetTester tester, String label, String text,
    {int at = 0}) async {
  final field = find
      .descendant(
          of: find.widgetWithText(MNTextField, label),
          matching: find.byType(TextField))
      .at(at);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  testWidgets('the owner sees earned, estimated and adjustments per period',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: const ['business_owner'],
        route: MNRoutes.officeBonuses,
        overrides: [_clock]);
    expect(o.bonusCalls.first, 'week 2026-10-26');
    expect(find.text(sw.bonusEarned('TSh 3,250')), findsNWidgets(2));
    expect(find.text(sw.bonusEstimated('TSh 1,000')), findsNWidgets(2));
    expect(find.text(sw.bonusEstimatedNote), findsOneWidget);
    expect(find.text(sw.bonusAdjustments('−TSh 600')), findsOneWidget);
    await tester.tap(find.text(sw.bonusPeriodMonth));
    await tester.pumpAndSettle();
    expect(o.bonusCalls.last, 'month 2026-10-26');
    await tapVisible(tester, find.text('Juma Ali · V-0001'));
    expect(find.text(sw.bonusPayableEarned), findsOneWidget);
    expect(find.text(sw.bonusVerifiedChickens), findsOneWidget);
    expect(find.text(sw.bonusChickenPartShort), findsOneWidget);
    expect(find.text(sw.bonusProfitPartShort), findsOneWidget);
    expect(find.text(sw.bonusEstimatedStatus), findsOneWidget);
    await tapVisible(
        tester, find.byKey(const ValueKey('bonus-day-2026-10-25')));
    expect(find.text(sw.bonusDailyEarnings), findsOneWidget);
    expect(find.text(sw.bonusEstimatedNotPayable), findsOneWidget);
    expect(find.text(sw.bonusOverallStatus), findsOneWidget);
    expect(find.text(sw.bonusProfitCannotConfirm), findsOneWidget);
    expect(find.text(sw.bonusRecords), findsOneWidget);
    expect(find.text(sw.bonusVerifiedSales), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lipa opens the vendor\'s payments; there is no other payout',
      (tester) async {
    await openAs(tester, office(),
        roles: const ['business_owner'],
        route: MNRoutes.officeVendorBonus('v1', period: 'week'),
        overrides: [_clock]);
    await tapVisible(tester, find.text(sw.bonusPay));
    expect(find.byType(VendorPaymentStatementScreen), findsOneWidget);
  });

  testWidgets('only the owner corrects, only verified sales, with a reason',
      (tester) async {
    final o = office()
      ..salesList.addAll([
        OfficeSale(
            saleId: 'sale-1',
            vendorId: 'v1',
            vendorName: 'Juma Ali',
            amount: 36000,
            status: 'verified',
            recordedAt: DateTime.utc(2026, 10, 26, 7)),
        OfficeSale(
            saleId: 'sale-2',
            vendorId: 'v1',
            vendorName: 'Juma Ali',
            amount: 9000,
            status: 'verified',
            voided: true,
            recordedAt: DateTime.utc(2026, 10, 26, 8)),
        const OfficeSale(
            saleId: 'sale-3',
            vendorId: 'v1',
            vendorName: 'Juma Ali',
            amount: 1),
      ]);
    await openAs(tester, o,
        roles: const ['business_owner'],
        route: MNRoutes.officeVerifiedSales('s1', date: '2026-10-26'),
        overrides: [_clock]);
    // One button: the voided one is already corrected, the reported one
    // is not listed (the list asks for verified sales).
    expect(_button(sw.correctSale), findsOneWidget);
    expect(find.text(sw.correctedSale), findsOneWidget);
    await tapVisible(tester, _button(sw.correctSale));
    expect(_inSheet(find.text(sw.correctSaleWarning)), findsOneWidget);
    await tester.tap(_inSheet(_button(sw.correctSale)));
    await tester.pumpAndSettle();
    expect(o.corrections, isEmpty); // A reason is required.
    await tester.enterText(
        _inSheet(find.byType(TextField)), 'Iliandikwa mara mbili');
    await tester.tap(_inSheet(_button(sw.correctSale)));
    await tester.pumpAndSettle();
    expect(o.corrections, ['sale-1 Iliandikwa mara mbili']);
    expect(find.text(sw.correctSaleDone), findsOneWidget);
  });

  testWidgets('supervisors see neither bonuses nor corrections',
      (tester) async {
    await openAs(tester, office(),
        route: MNRoutes.officeBonuses, overrides: [_clock]);
    expect(find.text(sw.notAllowed), findsOneWidget);
  });

  testWidgets('unset settings show Haijawekwa; chicken steps save as JSON',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: const ['business_owner'],
        route: MNRoutes.officePerformanceSettings,
        overrides: [_clock]);
    expect(find.text(sw.perfNotSet), findsWidgets);
    await tapVisible(tester, find.text(sw.perfChicken));
    await type(tester, sw.perfTarget, '10');
    await tester.ensureVisible(_inSheet(_button(sw.perfAddStep)));
    await tester.tap(_inSheet(_button(sw.perfAddStep)));
    await tester.pump();
    await type(tester, sw.perfStepAt, '15');
    await type(tester, sw.perfStepAmount, '1000');
    await tester.tap(_inSheet(_button(sw.perfAddStep)));
    await tester.pump();
    await type(tester, sw.perfStepAt, '12', at: 1); // below the step before
    await type(tester, sw.perfStepAmount, '1500', at: 1);
    await type(tester, sw.perfPerExtra, '300');
    await tester.ensureVisible(_inSheet(_button(sw.saveChanges)));
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(find.text(sw.perfStepsInvalid), findsOneWidget);
    expect(o.settingWrites, isEmpty);
    await type(tester, sw.perfStepAt, '20', at: 1);
    await tester.ensureVisible(_inSheet(_button(sw.saveChanges)));
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(o.settingWrites.single['key'], 'bonus.chicken');
    expect(o.settingWrites.single['value'], {
      'target': 10,
      'steps': [
        {'at': 15, 'amount': 1000},
        {'at': 20, 'amount': 1500}
      ],
      'per_extra': 300,
    });
    expect(find.text(sw.perfSaved), findsOneWidget);
  });

  testWidgets('score weights save only when they total 100', (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: const ['business_owner'],
        route: MNRoutes.officePerformanceSettings,
        overrides: [_clock]);
    await tapVisible(
        tester, find.text(sw.perfWeightsFor('score.weights.manager')));
    await type(tester, sw.perfArea('on_time'), '50');
    await type(tester, sw.perfArea('open_items'), '30');
    await type(tester, sw.perfArea('rating'), '10');
    expect(find.text(sw.perfWeightsTotal(90)), findsOneWidget);
    expect(tester.widget<MNButton>(_inSheet(_button(sw.saveChanges))).onPressed,
        isNull);
    await type(tester, sw.perfArea('rating'), '20');
    await tester.ensureVisible(_inSheet(_button(sw.saveChanges)));
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(o.settingWrites.single, {
      'key': 'score.weights.manager',
      'value': {'on_time': 50, 'open_items': 30, 'rating': 20},
      'reason': sw.perfReason(
          '${sw.perfWeights}: ${sw.perfWeightsFor('score.weights.manager')}'),
    });
  });

  testWidgets('bonus and settings screens fit 320 px at 2× text',
      (tester) async {
    for (final route in [
      MNRoutes.officeBonuses,
      MNRoutes.officeVendorBonus('v1'),
      MNRoutes.officePerformanceSettings,
    ]) {
      await openAs(tester, office(),
          roles: const ['business_owner'],
          route: route,
          size: const Size(320, 640),
          textScale: 2,
          overrides: [_clock]);
      expect(tester.takeException(), isNull, reason: route);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
