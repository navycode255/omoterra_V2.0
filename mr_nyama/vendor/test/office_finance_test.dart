import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/workflow_help.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/pressable.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart' show TestApp;
import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible;

const sw = Strings('sw');

/// The verification fake plus the finance books, in memory.
class FinanceOffice extends VerificationOffice
    implements OfficeFinanceRepository {
  final postCalls = <String>[];
  final created = <Map<String, String>>[];
  final updated = <String>[];
  final ruleCalls = <String>[];
  final lockCalls = <String>[];
  final journalCalls = <String>[];
  FinanceStatus status = const FinanceStatus(
      unposted: {'sale_cash': 3, 'handover_confirmed': 1},
      unconfigured: ['sale_mpesa']);
  List<FinanceAccount> accounts = const [
    FinanceAccount(
        id: 'a1', code: '1100', name: 'Sanduku la fedha', balance: 1500.5),
    FinanceAccount(id: 'a2', code: '4000', name: 'Mauzo', kind: 'income'),
  ];
  List<PostingRule> rules = [
    for (final e in financeEvents)
      e == 'sale_cash'
          ? const PostingRule(
              event: 'sale_cash',
              configured: true,
              debit:
                  FinanceRef(id: 'a1', name: 'Sanduku la fedha', code: '1100'),
              credit: FinanceRef(id: 'a2', name: 'Mauzo', code: '4000'))
          : PostingRule(event: e),
  ];
  List<FinancePeriod> periods = const [
    FinancePeriod(month: '2026-10'),
    FinancePeriod(month: '2026-09'),
    FinancePeriod(month: '2026-08'),
    FinancePeriod(month: '2026-07', locked: true),
  ];
  List<JournalEntry> entries = [
    for (var i = 0; i < 12; i++)
      JournalEntry(
          id: 'e$i',
          event: 'sale_cash',
          entryDate: DateTime.utc(2026, 10, 1 + i),
          lines: const [
            JournalLine(
                account: FinanceRef(
                    id: 'a1', name: 'Sanduku la fedha', code: '1100'),
                debit: 9000),
            JournalLine(
                account: FinanceRef(id: 'a2', name: 'Mauzo', code: '4000'),
                credit: 9000),
          ])
  ];
  OperatingResult result = const OperatingResult(
      income: [
        AccountAmount(
            account: FinanceRef(id: 'a2', name: 'Mauzo', code: '4000'),
            amount: 108000)
      ],
      totalIncome: 108000,
      totalExpenses: 0,
      result: 108000,
      provisional: true,
      unposted: 4);

  @override
  Future<List<FinanceAccount>> financeAccounts() async => accounts;
  @override
  Future<FinanceAccount> createFinanceAccount(
      {required String code,
      required String name,
      required String kind,
      required String reason}) async {
    created.add({'code': code, 'name': name, 'kind': kind, 'reason': reason});
    final account =
        FinanceAccount(id: 'new', code: code, name: name, kind: kind);
    accounts = [...accounts, account];
    return account;
  }

  @override
  Future<FinanceAccount> updateFinanceAccount(String id,
      {String? name, bool? active, required String reason}) async {
    updated.add('$id name=$name active=$active reason=$reason');
    return accounts.firstWhere((a) => a.id == id);
  }

  @override
  Future<List<PostingRule>> postingMap() async => rules;
  @override
  Future<PostingRule> setPostingRule(String event,
      {required String debitAccountId,
      required String creditAccountId,
      required String reason}) async {
    ruleCalls.add('$event $debitAccountId $creditAccountId $reason');
    return PostingRule(event: event, configured: true);
  }

  @override
  Future<FinanceStatus> financeStatus() async => status;
  @override
  Future<PostResult> postToBooks({required String until}) async {
    postCalls.add(until);
    status = const FinanceStatus(unconfigured: ['sale_mpesa']);
    return const PostResult(
        posted: {'sale_cash': 3, 'handover_confirmed': 1}, entries: 4);
  }

  @override
  Future<List<FinancePeriod>> financePeriods() async => periods;
  @override
  Future<FinancePeriod> lockFinancePeriod(String month,
      {required String reason}) async {
    lockCalls.add('$month $reason');
    return FinancePeriod(month: month, locked: true);
  }

  @override
  Future<List<JournalEntry>> journal(
      {String? from, String? to, String? accountId}) async {
    journalCalls.add('$from $to $accountId');
    return entries;
  }

  @override
  Future<TrialBalance> trialBalance({String? asOf}) async =>
      const TrialBalance(rows: [
        TrialBalanceRow(
            account:
                FinanceRef(id: 'a1', name: 'Sanduku la fedha', code: '1100'),
            kind: 'asset',
            debit: 9000,
            balance: 9000)
      ], totalDebit: 9000, totalCredit: 9000);
  @override
  Future<OperatingResult> operatingResult({String? from, String? to}) async =>
      result;
  @override
  Future<CashPosition> cashPosition({String? asOf}) async =>
      const CashPosition(rows: [
        AccountAmount(
            account:
                FinanceRef(id: 'a1', name: 'Sanduku la fedha', code: '1100'),
            amount: 9000)
      ]);
}

/// 27 October 2026, noon in Dar es Salaam.
final _clock =
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 27, 9));

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

Future<TestApp> _open(WidgetTester tester, FinanceOffice office, String route,
        {List<String> roles = const ['finance'],
        Size size = const Size(390, 844),
        double textScale = 1}) =>
    openAs(tester, office,
        roles: roles,
        route: route,
        size: size,
        textScale: textScale,
        overrides: [_clock]);

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
  await tester.ensureVisible(field.first);
  await tester.enterText(field.first, text);
  await tester.pump();
}

void main() {
  for (final language in ['sw', 'en']) {
    testWidgets(
        'books landing stays concise and help remains available in $language',
        (tester) async {
      final app = await _open(tester, FinanceOffice(), MNRoutes.officeFinance);
      app.container.read(languageProvider.notifier).state = language;
      await tester.pumpAndSettle();
      final s = Strings(language);
      expect(find.text(s.financeConfirmNote), findsNothing);
      expect(find.text(s.financeNeverPosted), findsNothing);
      expect(find.text(s.financeEventCount(s.financeEventName('sale_cash'), 3)),
          findsNothing);
      expect(find.text(s.financeMapCaption), findsNothing);
      expect(find.text(s.financeWaitingSummary(4)), findsOneWidget);
      if (const bool.fromEnvironment('FINANCE_CAPTURES')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        boundary.markNeedsPaint();
        await tester.pump();
        final image =
            (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
        final bytes = await tester
            .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        await tester.runAsync(() async {
          final dir = Directory('../reviews/2026-10-29/finance-books');
          await dir.create(recursive: true);
          await File('${dir.path}/books-$language.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
      await tester.tap(find.byType(MNWorkflowHelp));
      await tester.pumpAndSettle();
      expect(find.text(s.financeConfirmNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('status shows what waits, and posting sends the date',
      (tester) async {
    final office = FinanceOffice();
    await _open(tester, office, MNRoutes.officeFinance);
    expect(find.text(sw.financeWaitingSummary(4)), findsOneWidget);
    expect(find.text(sw.financeConfirmNote), findsNothing);
    expect(find.text(sw.financeNeverPosted), findsNothing);
    await tapVisible(tester, find.text(sw.financeStatusTitle));
    expect(find.text(sw.financeEventCount(sw.financeEventName('sale_cash'), 3)),
        findsOneWidget);
    expect(_inSheet(find.text(sw.financeUnconfigured(1))), findsOneWidget);
    expect(find.text(sw.financeNeverPosted), findsOneWidget);
    Navigator.of(tester.element(find.text(sw.financeNeverPosted))).pop();
    await tester.pumpAndSettle();
    await tapVisible(tester, _button(sw.financePost));
    await tester.tap(find.text(sw.useThisDate));
    await tester.pumpAndSettle();
    expect(find.text(sw.financePostConfirmBody), findsOneWidget);
    await tester.tap(find.text(sw.financePost).last);
    await tester.pumpAndSettle();
    expect(office.postCalls, ['2026-10-27']);
    expect(find.text(sw.financePosted(4)), findsOneWidget);
    expect(find.text(sw.financeAllPosted), findsOneWidget);
  });

  testWidgets('finance adds an account with its kind', (tester) async {
    final office = FinanceOffice();
    await _open(tester, office, MNRoutes.officeFinanceAccounts);
    expect(find.text('1100 · Sanduku la fedha'), findsOneWidget);
    expect(find.text(sw.financeBalance('TSh 1,500.50')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(sw.financeAddAccount));
    await tester.pumpAndSettle();
    await type(tester, sw.financeAccountCode, '5100');
    await type(tester, sw.financeAccountName, 'Gharama za mkaa');
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(find.text(sw.financeAccountKindMissing), findsOneWidget);
    await choose(tester, sw.financeAccountKind, sw.financeKindName('expense'));
    await tester.tap(_inSheet(_button(sw.saveChanges)));
    await tester.pumpAndSettle();
    expect(office.created.single, {
      'code': '5100',
      'name': 'Gharama za mkaa',
      'kind': 'expense',
      'reason': sw.financeReasonNewAccount('5100'),
    });
    expect(find.text(sw.financeAccountSaved), findsOneWidget);
  });

  testWidgets('only the owner edits the posting map', (tester) async {
    final office = FinanceOffice();
    await _open(tester, office, MNRoutes.officeFinanceMap);
    expect(find.text(sw.financeOwnerOnly), findsNothing);
    await tester.tap(find.byType(MNWorkflowHelp));
    await tester.pumpAndSettle();
    expect(find.text(sw.financeOwnerOnly), findsOneWidget);
    Navigator.of(tester.element(find.text(sw.financeOwnerOnly))).pop();
    await tester.pumpAndSettle();
    expect(_button(sw.financeMap), findsNothing);
    expect(find.text('${sw.financeDebit}: 1100 · Sanduku la fedha'),
        findsOneWidget);
  });

  testWidgets('the owner sets a rule with two different accounts',
      (tester) async {
    final office = FinanceOffice();
    await _open(tester, office, MNRoutes.officeFinanceMap,
        roles: const ['business_owner']);
    // The second event (credit sales) is not set yet.
    await tapVisible(tester, _button(sw.financeMap).at(1));
    await choose(tester, sw.financeDebit, '1100 · Sanduku la fedha');
    await choose(tester, sw.financeCredit, '1100 · Sanduku la fedha');
    await type(tester, sw.moneyReason, 'Kwa ushauri wa mhasibu');
    await tester.tap(_inSheet(_button(sw.financeSaveRule)));
    await tester.pumpAndSettle();
    expect(find.text(sw.financeRuleSameAccount), findsOneWidget);
    await choose(tester, sw.financeCredit, '4000 · Mauzo');
    await tester.tap(_inSheet(_button(sw.financeSaveRule)));
    await tester.pumpAndSettle();
    expect(office.ruleCalls, ['sale_credit a1 a2 Kwa ushauri wa mhasibu']);
    expect(find.text(sw.financeRuleSaved), findsOneWidget);
  });

  testWidgets('months lock in order, oldest open first, by the owner',
      (tester) async {
    final office = FinanceOffice();
    await _open(tester, office, MNRoutes.officeFinancePeriods,
        roles: const ['business_owner']);
    expect(find.text(sw.financeLockRule), findsNothing);
    await tester.tap(find.byType(MNWorkflowHelp));
    await tester.pumpAndSettle();
    expect(find.text(sw.financeLockRule), findsOneWidget);
    Navigator.of(tester.element(find.text(sw.financeLockRule))).pop();
    await tester.pumpAndSettle();
    // August is the oldest open month before October: only it can lock.
    expect(_button(sw.financeLockMonth), findsOneWidget);
    await tapVisible(tester, _button(sw.financeLockMonth));
    expect(find.text(sw.financeLockTitle(sw.monthYear(DateTime.utc(2026, 8)))),
        findsOneWidget);
    expect(_inSheet(find.text(sw.financeLockRule)), findsOneWidget);
    await tester.enterText(
        _inSheet(find.byType(TextField)), 'Hesabu zimekamilika');
    await tester.tap(_inSheet(_button(sw.financeLockMonth)));
    await tester.pumpAndSettle();
    expect(office.lockCalls, ['2026-08 Hesabu zimekamilika']);
  });

  testWidgets('finance sees periods but cannot lock', (tester) async {
    await _open(tester, FinanceOffice(), MNRoutes.officeFinancePeriods);
    expect(find.text(sw.financeMonthLocked), findsOneWidget);
    expect(_button(sw.financeLockMonth), findsNothing);
  });

  testWidgets('the journal shows ten entries, then Zaidi', (tester) async {
    final office = FinanceOffice();
    await _open(tester, office, MNRoutes.officeFinanceJournal);
    expect(office.journalCalls.first, '2026-10-01 2026-10-27 null');
    expect(find.text(sw.financeEventName('sale_cash')), findsNWidgets(10));
    await tapVisible(tester, _button(sw.moreRows));
    expect(find.text(sw.financeEventName('sale_cash')), findsNWidgets(12));
  });

  testWidgets('reports: trial balance, a provisional result, cash',
      (tester) async {
    await _open(tester, FinanceOffice(), MNRoutes.officeFinanceReports);
    expect(
        find.text(sw.financeTotals('TSh 9,000', 'TSh 9,000')), findsOneWidget);
    await tester.tap(find.text(sw.financeOperatingResult));
    await tester.pumpAndSettle();
    expect(find.text(sw.financeProvisional), findsOneWidget);
    expect(find.text(sw.financeProvisionalNote(4)), findsOneWidget);
    expect(find.text('${sw.financeResult}: TSh 108,000'), findsOneWidget);
    await tapVisible(tester, find.text(sw.financeCashPosition));
    expect(find.text('1100 · Sanduku la fedha'), findsOneWidget);
    expect(find.text('TSh 9,000'), findsOneWidget);
  });

  testWidgets('supervisors are not allowed into the books', (tester) async {
    await _open(tester, FinanceOffice(), MNRoutes.officeFinance,
        roles: const ['supervisor']);
    expect(find.text(sw.notAllowed), findsOneWidget);
    expect(_button(sw.financePost), findsNothing);
  });

  testWidgets('finance screens fit 320 px at 2× text', (tester) async {
    final app = await _open(tester, FinanceOffice(), MNRoutes.officeFinance,
        roles: const ['business_owner'],
        size: const Size(320, 640),
        textScale: 2);
    expect(tester.takeException(), isNull);
    for (final route in [
      MNRoutes.officeFinanceAccounts,
      MNRoutes.officeFinanceMap,
      MNRoutes.officeFinancePeriods,
      MNRoutes.officeFinanceJournal,
      MNRoutes.officeFinanceReports,
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });
}
