import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'office_money_test.dart' show MoneyOffice, openMoney, tapVisible;

/// The shared fake plus credit customers, following the server's rules.
class CreditOffice extends MoneyOffice implements OfficeCreditRepository {
  final customers = <OfficeCreditCustomer>[
    const OfficeCreditCustomer(
        id: 'c1',
        name: 'Mama Rehema',
        stationId: 's1',
        stationName: 'Kariakoo',
        creditLimit: 50000,
        creditSales: 30000,
        repaid: 10000,
        owed: 20000),
  ];
  final calls = <String>[];

  OfficeCreditCustomer _find(String id) =>
      customers.firstWhere((c) => c.id == id);
  void _put(OfficeCreditCustomer c) =>
      customers[customers.indexWhere((x) => x.id == c.id)] = c;
  OfficeCreditCustomer _with(OfficeCreditCustomer c,
          {int? limit,
          bool clearLimit = false,
          String? status,
          int? owed,
          int? writtenOff}) =>
      OfficeCreditCustomer(
          id: c.id,
          name: c.name,
          stationId: c.stationId,
          stationName: c.stationName,
          status: status ?? c.status,
          creditLimit: clearLimit ? null : (limit ?? c.creditLimit),
          creditSales: c.creditSales,
          repaid: c.repaid,
          writtenOff: writtenOff ?? c.writtenOff,
          owed: owed ?? c.owed);

  @override
  Future<List<OfficeCreditCustomer>> creditCustomers(
          {String? stationId}) async =>
      customers.where((c) => c.stationId == stationId).toList();

  @override
  Future<OfficeCreditCustomer> createCreditCustomer(
      {required String stationId,
      required String name,
      String? phone,
      String? note}) async {
    calls.add('create $name');
    final c = OfficeCreditCustomer(
        id: 'c${customers.length + 1}', name: name, stationId: stationId);
    customers.add(c);
    return c;
  }

  @override
  Future<OfficeCreditStatement> creditStatement(String customerId) async =>
      OfficeCreditStatement(_find(customerId), const [
        OfficeCreditEntry(kind: 'sale', id: 'x1', amount: 30000),
        OfficeCreditEntry(
            kind: 'repayment', id: 'r1', amount: 10000, method: 'cash'),
      ]);

  @override
  Future<OfficeCreditCustomer> setCreditLimit(String customerId,
      {required int? limit, required String reason}) async {
    if (!owner.isOwner) throw const OfficeError(OfficeErrorKind.forbidden);
    calls.add('limit $limit $reason');
    final c = _with(_find(customerId), limit: limit, clearLimit: limit == null);
    _put(c);
    return c;
  }

  @override
  Future<OfficeCreditCustomer> setCreditStatus(String customerId,
      {required bool suspended, required String reason}) async {
    final c =
        _with(_find(customerId), status: suspended ? 'suspended' : 'active');
    _put(c);
    return c;
  }

  @override
  Future<OfficeCreditStatement> recordCreditRepayment(String customerId,
      {required int amount, required String method, String? note}) async {
    calls.add('repay $amount $method');
    final c = _with(_find(customerId), owed: _find(customerId).owed - amount);
    _put(c);
    return creditStatement(customerId);
  }

  @override
  Future<OfficeCreditStatement> reverseCreditRepayment(String repaymentId,
          {required String reason}) async =>
      creditStatement('c1');

  @override
  Future<OfficeCreditStatement> writeOffCredit(String customerId,
      {required int amount, required String reason}) async {
    calls.add('write-off $amount $reason');
    final c = _find(customerId);
    _put(_with(c, owed: c.owed - amount, writtenOff: c.writtenOff + amount));
    return creditStatement(customerId);
  }
}

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

void main() {
  testWidgets('a supervisor registers a customer; only the owner sets limits',
      (tester) async {
    final office = CreditOffice()..signedIn = true;
    await openMoney(tester, office,
        roles: const ['supervisor'], route: MNRoutes.officeCredit('s1'));
    expect(find.text('Mama Rehema'), findsOneWidget);
    expect(find.text('TSh 20,000'), findsWidgets);
    await tapVisible(tester, find.text('Ongeza'));
    await tester.enterText(_inSheet(find.byType(TextField)).first, 'Juma Ally');
    await tester
        .tap(_inSheet(find.widgetWithText(MNButton, 'Hifadhi mabadiliko')));
    await tester.pumpAndSettle();
    expect(office.calls, ['create Juma Ally']);
    expect(find.text('Juma Ally'), findsOneWidget);
    expect(find.text('Ofisi haijaweka kikomo: hawezi kukopa'), findsOneWidget);
    // A supervisor sees the limit but cannot change it, nor write off.
    await tapVisible(tester, find.text('Mama Rehema'));
    expect(find.text('Kikomo cha mkopo'), findsOneWidget);
    await tester.tap(find.text('TSh 50,000'));
    await tester.pumpAndSettle();
    expect(find.byType(MNSheet), findsNothing);
    expect(find.text('Futa deni (hasara)'), findsNothing);
    expect(find.text('Rekodi malipo ofisini'), findsOneWidget);
    await tapVisible(tester, find.text('Rekodi malipo ofisini'));
    expect(find.text('Amelipaje?'), findsNothing);
    expect(find.textContaining('M-Pesa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the owner sets the limit and writes off with a reason',
      (tester) async {
    final office = CreditOffice()..signedIn = true;
    await openMoney(tester, office,
        roles: const ['business_owner'],
        route: MNRoutes.officeCreditCustomer('c1'));
    await tapVisible(tester, find.text('TSh 50,000'));
    await tester.enterText(_inSheet(find.byType(TextField)).at(0), '80000');
    await tester.enterText(
        _inSheet(find.byType(TextField)).at(1), 'Analipa vizuri');
    await tester
        .tap(_inSheet(find.widgetWithText(MNButton, 'Hifadhi mabadiliko')));
    await tester.pumpAndSettle();
    expect(office.calls, ['limit 80000 Analipa vizuri']);
    expect(find.text('TSh 80,000'), findsOneWidget);

    await tapVisible(tester, find.text('Futa deni (hasara)'));
    await tester.enterText(_inSheet(find.byType(TextField)).at(0), '25000');
    await tester.enterText(_inSheet(find.byType(TextField)).at(1), 'Amehama');
    await tester
        .tap(_inSheet(find.widgetWithText(MNButton, 'Futa deni (hasara)')));
    await tester.pumpAndSettle();
    expect(
        find.text('Kiasi kisizidi anachodaiwa (TSh 20,000).'), findsOneWidget);
    await tester.enterText(_inSheet(find.byType(TextField)).at(0), '20000');
    await tester
        .tap(_inSheet(find.widgetWithText(MNButton, 'Futa deni (hasara)')));
    await tester.pumpAndSettle();
    expect(office.calls.last, 'write-off 20000 Amehama');
    expect(find.text('Deni lililofutwa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
