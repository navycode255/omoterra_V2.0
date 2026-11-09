import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/balance_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/pressable.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible;

const sw = Strings('sw');

/// The verification fake plus vendor balances, in memory.
class BalancesOffice extends VerificationOffice
    implements OfficeBalancesRepository {
  final requests = <Map<String, Object?>>[];
  final decisionCalls = <String>[];
  final exportCalls = <String>[];
  List<OfficeVendorBalance> balanceRows = [];
  OfficeVendorMoney? money;

  @override
  Future<List<OfficeVendorBalance>> vendorBalances({String? stationId}) async =>
      balanceRows;

  @override
  Future<OfficeVendorMoney> vendorMoney(String vendorId) async => money!;

  @override
  Future<List<OfficeAdjustment>> adjustments(
          {String? status, String? vendorId}) async =>
      money?.adjustments ?? const [];

  @override
  Future<OfficeAdjustment> requestAdjustment(
      {required String clientId,
      required String vendorId,
      required String businessDate,
      required AdjustmentKind kind,
      required String direction,
      required int amount,
      required String reason,
      required String basisRef,
      String? correctsId}) async {
    requests.add({
      'vendor': vendorId,
      'date': businessDate,
      'kind': kind.wire,
      'direction': direction,
      'amount': amount,
      'reason': reason,
      'basis': basisRef,
      'corrects': correctsId,
    });
    return OfficeAdjustment(id: 'new', kind: kind, amount: amount);
  }

  @override
  Future<OfficeAdjustment> decideAdjustment(String id,
      {required bool approve, required String reason}) async {
    decisionCalls.add('$id approve=$approve reason=$reason');
    return OfficeAdjustment(id: id, status: approve ? 'approved' : 'rejected');
  }

  @override
  Future<MoneyExport> moneyExport(MoneyExportKind kind,
      {required String from, required String to, String? stationId}) async {
    exportCalls.add('${kind.wire} $from $to $stationId');
    return MoneyExport(
        filename: 'mr_nyama_siku.csv',
        bytes: Uint8List.fromList(utf8.encode('a,b\r\n1,2\r\n')),
        rows: 1);
  }
}

const juma = MoneyParty(id: 'v1', name: 'Juma Ali', code: 'V-0001');
const neema = MoneyParty(id: 'st1', name: 'Neema Said');
const asha = MoneyParty(id: 'st2', name: 'Asha Bakari');

BalancesOffice office() => BalancesOffice()
  ..verificationList.add(
      const OfficeVerificationStation(id: 's1', code: 'KRK', name: 'Kariakoo'))
  ..balanceRows = [
    OfficeVendorBalance(
        vendor: juma,
        owed: 7000,
        oldestOutstanding: DateTime.utc(2026, 10, 24),
        ageDays: 2,
        unconfirmedHandovers: 3000,
        pendingAdjustments: 1),
    const OfficeVendorBalance(
        vendor: MoneyParty(id: 'v2', name: 'Rehema', code: 'V-0002'),
        credit: 500),
  ]
  ..money = OfficeVendorMoney(
      balance: OfficeVendorBalance(
          vendor: juma,
          owed: 7000,
          oldestOutstanding: DateTime.utc(2026, 10, 24),
          ageDays: 2,
          unverifiedCashSales: 2500),
      days: [
        OfficeBalanceDay(
            businessDate: DateTime.utc(2026, 10, 25),
            due: 5000,
            applied: 3000,
            remaining: 2000,
            status: MoneyStatus.partReceived),
        OfficeBalanceDay(
            businessDate: DateTime.utc(2026, 10, 24),
            due: 5000,
            remaining: 5000,
            status: MoneyStatus.outstanding),
      ],
      adjustments: [
        OfficeAdjustment(
            id: 'a1',
            kind: AdjustmentKind.stockCharge,
            direction: 'debit',
            amount: 1000,
            reason: 'Kuku mmoja hakuonekana',
            basisRef: 'Mkataba §4',
            requestedBy: asha,
            businessDate: DateTime.utc(2026, 10, 25)),
        OfficeAdjustment(
            id: 'a0',
            kind: AdjustmentKind.priceShortfall,
            direction: 'debit',
            amount: 500,
            reason: 'Aliuza chini ya bei',
            basisRef: 'Barua 12',
            requestedBy: neema,
            decidedBy: asha,
            status: 'approved',
            businessDate: DateTime.utc(2026, 10, 24)),
      ]);

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

Future<void> choose(WidgetTester tester, String label, String option) async {
  await tapVisible(
      tester,
      find
          .descendant(
              of: find.widgetWithText(MNFieldButton, label),
              matching: find.byType(MNPressable))
          .first);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
      of: find.widgetWithText(MNTextField, label),
      matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// 26 October 2026, noon in Dar es Salaam.
final _clock =
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 26, 9));

void main() {
  testWidgets('a station lists what each vendor owes, oldest first',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        route: MNRoutes.officeMoneyStation('s1'), overrides: [_clock]);
    await tester.tap(find.text(sw.balancesTab));
    await tester.pumpAndSettle();
    expect(find.text(sw.balanceOwed('TSh 7,000')), findsOneWidget);
    expect(find.text(sw.balanceSince(sw.date(DateTime.utc(2026, 10, 24)), 2)),
        findsOneWidget);
    expect(find.text(sw.balanceUnconfirmed('TSh 3,000')), findsOneWidget);
    expect(find.text(sw.balanceCredit('TSh 500')), findsOneWidget);
    await tester.tap(find.text('Juma Ali · V-0001'));
    await tester.pumpAndSettle();
    expect(find.text(sw.balanceUnverified('TSh 2,500')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text(sw.moneyStatusName('outstanding')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(sw.moneyStatusName('part_received')), findsOneWidget);
    expect(find.text(sw.balanceDayRemaining('TSh 2,000')), findsOneWidget);
    // A supervisor neither asks for nor decides adjustments.
    expect(_button(sw.adjustmentNew), findsNothing);
    expect(_button(sw.adjustmentApprove), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance asks for an adjustment with its basis', (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: const ['finance'],
        route: MNRoutes.officeVendorMoney('v1'),
        overrides: [_clock]);
    await tapVisible(tester, _button(sw.adjustmentNew));
    await choose(
        tester, sw.adjustmentKind, sw.adjustmentKindName('stock_charge'));
    await type(tester, sw.moneyAmount, '1500');
    await type(tester, sw.moneyReason, 'Kuku hakuonekana');
    await tester.tap(_inSheet(_button(sw.adjustmentSend)));
    await tester.pumpAndSettle();
    // The basis is required before anything is sent.
    expect(find.text(sw.adjustmentBasisInvalid), findsOneWidget);
    expect(o.requests, isEmpty);
    await type(tester, sw.adjustmentBasis, 'Mkataba §4');
    await tester.tap(_inSheet(_button(sw.adjustmentSend)));
    await tester.pumpAndSettle();
    expect(o.requests.single, {
      'vendor': 'v1',
      'date': '2026-10-26',
      'kind': 'stock_charge',
      'direction': 'debit',
      'amount': 1500,
      'reason': 'Kuku hakuonekana',
      'basis': 'Mkataba §4',
      'corrects': null,
    });
    expect(find.text(sw.adjustmentSaved), findsOneWidget);
  });

  testWidgets('someone else approves; the asker cannot', (tester) async {
    final o = office();
    // Signed in as Asha (st1 in openAs is the signed-in id): a1 is by st2.
    await openAs(tester, o,
        roles: const ['business_owner'],
        route: MNRoutes.officeVendorMoney('v1'),
        overrides: [_clock]);
    await tapVisible(tester, _button(sw.adjustmentApprove));
    await tester.enterText(_inSheet(find.byType(TextField)), 'Nimeona mkataba');
    await tester.tap(_inSheet(_button(sw.adjustmentApprove)));
    await tester.pumpAndSettle();
    expect(o.decisionCalls, ['a1 approve=true reason=Nimeona mkataba']);
    expect(find.text(sw.adjustmentDecided), findsOneWidget);
  });

  testWidgets('an approved adjustment is corrected the other way',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: const ['finance'],
        route: MNRoutes.officeVendorMoney('v1'),
        overrides: [_clock]);
    await tapVisible(tester, _button(sw.adjustmentCorrect));
    // The amount starts at the original's; the kind and day are its own.
    expect(_inSheet(find.text('500')), findsOneWidget);
    await type(tester, sw.moneyReason, 'Bei ilikuwa sahihi');
    await type(tester, sw.adjustmentBasis, 'Orodha ya bei');
    await tester.tap(_inSheet(_button(sw.adjustmentSend)));
    await tester.pumpAndSettle();
    expect(o.requests.single['kind'], 'correction');
    expect(o.requests.single['direction'], 'credit');
    expect(o.requests.single['corrects'], 'a0');
    expect(o.requests.single['date'], '2026-10-24');
  });

  testWidgets('finance downloads a CSV report', (tester) async {
    final o = office();
    final saved = <String>[];
    await openAs(tester, o,
        roles: const ['finance'],
        route: MNRoutes.officeMoney,
        overrides: [
          _clock,
          saveMoneyExportProvider.overrideWithValue(
              (name, bytes) async => saved.add('$name ${utf8.decode(bytes)}'))
        ]);
    await tapVisible(tester, find.text(sw.moneyExport));
    await choose(
        tester, sw.moneyExportKind, sw.moneyExportKindName('handovers'));
    await tester.tap(_inSheet(_button(sw.moneyExportSave)));
    await tester.pumpAndSettle();
    expect(o.exportCalls.single, 'handovers 2026-09-27 2026-10-26 null');
    expect(saved.single, 'mr_nyama_siku.csv a,b\r\n1,2\r\n');
    expect(find.text(sw.moneyExportSaved(1)), findsOneWidget);
  });
}
