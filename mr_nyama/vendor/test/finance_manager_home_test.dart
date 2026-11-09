import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/features/office/finance_manager_home.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';

import 'office_money_test.dart' show moneyOffice, openMoney, tapVisible;

void main() {
  testWidgets('finance staff enter the finance-only workspace', (tester) async {
    final app = await openMoney(tester, moneyOffice(),
        roles: const [StaffRole.finance]);
    app.container.read(languageProvider.notifier).state = 'en';
    await tester.pumpAndSettle();

    final strings = Strings('en');
    expect(find.byType(FinanceManagerHomeScreen), findsOneWidget);
    expect(find.text(strings.financeTasks), findsNWidgets(2));
    expect(find.text(strings.roleName(StaffRole.finance)), findsOneWidget);
    expect(find.text(strings.ownerSummary), findsNothing);
    expect(find.text(strings.manageProducts), findsNothing);

    final cashShort = tester
        .widgetList<OwnerMenuRow>(find.byType(OwnerMenuRow))
        .firstWhere((row) => row.label == strings.opCashShortTitle);
    expect(cashShort.onTap, isNull);
    expect(cashShort.showChevron, isFalse);

    await tapVisible(tester, find.text(strings.financePaymentsTab).last);
    expect(find.text(strings.vendorPayTitle), findsOneWidget);

    await tapVisible(tester, find.text(strings.financeBooksTab).last);
    expect(find.text(strings.financeBooks), findsOneWidget);

    await tapVisible(tester, find.text(strings.ownerAccount).last);
    expect(find.text('Neema Said'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('finance navigation fits a small phone with large text',
      (tester) async {
    final app = await openMoney(tester, moneyOffice(),
        roles: const [StaffRole.finance],
        size: const Size(320, 568),
        textScale: 2);
    app.container.read(languageProvider.notifier).state = 'en';
    await tester.pumpAndSettle();

    expect(find.text(const Strings('en').financeTasks), findsNWidgets(2));
    await tapVisible(
        tester, find.text(const Strings('en').financePaymentsTab).last);
    expect(find.text(const Strings('en').vendorPayTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
