import 'office_design_helpers.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart'
    show AuthFailure, AuthFailureKind;
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/money_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

/// The shared fake with money fixtures; records what is sent.
class MoneyOffice extends FakeOfficeRepository {
  final recorded = <Map<String, Object?>>[];
  final handoverIds = <String?>[];
  final handoverTimes = <DateTime?>[];
  final handoverNotes = <String?>[];
  bool loseNextAnswer = false;
  final confirmed = <String>[];
  final reversed = <String>[];
  final decided = <String>[];

  @override
  Future<OfficeHandover> recordHandover(
      {required String vendorId,
      required String businessDate,
      required int amount,
      DateTime? receivedAt,
      String? note,
      String? clientId}) {
    recorded.add({
      'vendor_id': vendorId,
      'business_date': businessDate,
      'amount': amount,
    });
    handoverIds.add(clientId);
    handoverTimes.add(receivedAt);
    handoverNotes.add(note);
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const AuthFailure(AuthFailureKind.offline);
    }
    return super.recordHandover(
        vendorId: vendorId,
        businessDate: businessDate,
        amount: amount,
        receivedAt: receivedAt,
        note: note);
  }

  @override
  Future<OfficeHandover> confirmHandover(String handoverId) {
    confirmed.add(handoverId);
    return super.confirmHandover(handoverId);
  }

  @override
  Future<OfficeHandover> reverseHandover(String handoverId,
      {required String reason}) {
    reversed.add('$handoverId reason=$reason');
    return super.reverseHandover(handoverId, reason: reason);
  }

  @override
  Future<OfficeExpense> decideExpense(String expenseId,
      {required bool approve, required String reason}) {
    decided.add('$expenseId approve=$approve reason=$reason');
    return super.decideExpense(expenseId, approve: approve, reason: reason);
  }
}

/// The business day the tests run on (09:00 EAT, 21 October 2026).
final _now = DateTime.utc(2026, 10, 21, 6);
final _day = DateTime.utc(2026, 10, 21);
const _date = '2026-10-21';

OfficeMoneyDay _row(String id, String name, MoneyDayState state,
        {int due = 10000,
        int handed = 0,
        int remaining = 0,
        int unverified = 0,
        bool? late}) =>
    OfficeMoneyDay(
        vendorDayId: 'vd-$id',
        vendor: MoneyParty(id: id, name: name, code: 'V-$id'),
        businessDate: _day,
        verifiedCashSales: due,
        unverifiedCashSales: unverified,
        cashDue: due,
        handedOver: handed,
        remaining: remaining,
        state: state,
        late: late);

MoneyOffice moneyOffice() => MoneyOffice()
  ..signedIn = true
  ..verificationList.addAll(const [
    OfficeVerificationStation(id: 's1', code: 'KA01', name: 'Kariakoo'),
    OfficeVerificationStation(id: 's2', code: 'SI01', name: 'Sinza'),
  ])
  ..moneyDayList.addAll([
    _row('v1', 'Asha Juma', MoneyDayState.nothingDue, due: 0),
    _row('v2', 'Baraka Ally', MoneyDayState.short,
        handed: 8000, remaining: 2000, unverified: 4000, late: true),
    _row('v3', 'Chausiku Ali', MoneyDayState.full, handed: 10000, late: false),
    _row('v4', 'Daudi Musa', MoneyDayState.over,
        handed: 10500, remaining: -500),
    _row('v5', 'Eliya John', MoneyDayState.notHanded, remaining: 10000),
  ]);

Future<TestApp> openMoney(WidgetTester tester, MoneyOffice office,
    {List<String> roles = const ['supervisor'],
    String id = 'st1',
    String? route,
    Size size = const Size(390, 844),
    double textScale = 1}) async {
  office.owner = StaffProfile(
      id: id, name: 'Neema Said', phone: '+255713000111', roles: roles);
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut,
      office: office,
      now: _now,
      size: size,
      textScale: textScale);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  await tester.pumpAndSettle();
  if (route != null) {
    app.router.push(route);
    await tester.pumpAndSettle();
  }
  return app;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

OfficeHandover _handover(String id, String recorderId,
        {int amount = 5000, String status = 'recorded'}) =>
    OfficeHandover(
        id: id,
        vendor: const MoneyParty(id: 'v2', name: 'Baraka Ally'),
        businessDate: _day,
        amount: amount,
        receivedAt: DateTime.utc(2026, 10, 21, 15),
        recordedBy: MoneyParty(id: recorderId, name: 'Mtu $recorderId'),
        status: status);

void main() {
  testWidgets('each vendor-day shows its cash and a plain status word',
      (tester) async {
    await openMoney(tester, moneyOffice(),
        route: MNRoutes.officeMoneyStation('s1'));
    expect(find.text('Kariakoo'), findsOneWidget);
    expect(find.text('Siku: 21 Okt 2026'), findsOneWidget);
    expect(find.textContaining('Deni = mauzo ya taslimu yaliyothibitishwa'),
        findsNothing);
    await openOfficeHelp(tester);
    expect(find.textContaining('Deni = mauzo ya taslimu yaliyothibitishwa'),
        findsOneWidget);
    Navigator.of(tester.element(find.byType(MNSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Hakuna deni'), findsOneWidget);
    expect(find.text('Pungufu TSh 2,000'), findsOneWidget);
    expect(find.text('Kamili'), findsOneWidget);
    expect(find.text('Ziada TSh 500'), findsOneWidget);
    expect(find.text('Hajakabidhi'), findsOneWidget);
    // Only the vendor the server marked late; nothing when late is null.
    expect(find.text('Amechelewa'), findsOneWidget);
    expect(find.text('TSh 4,000 bado haijathibitishwa'), findsOneWidget);
    expect(find.text('Amekabidhi: TSh 8,000'), findsOneWidget);
    expect(find.text('Imebaki: TSh 2,000'), findsOneWidget);
  });

  testWidgets('the day switch asks the server for that business date',
      (tester) async {
    await openMoney(tester, moneyOffice(),
        route: MNRoutes.officeMoneyStation('s1'));
    await tester.tap(find.text('Jana'));
    await tester.pumpAndSettle();
    expect(find.text('Siku: 20 Okt 2026'), findsOneWidget);
    expect(find.text('Hakuna fedha za wauzaji siku hii'), findsOneWidget);
  });

  testWidgets('recording a handover sends the vendor, day and amount',
      (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office, route: MNRoutes.officeMoneyStation('s1'));
    await tapVisible(tester, find.text('Baraka Ally · V-v2'));
    expect(find.byType(OfficeMoneyVendorDayScreen), findsOneWidget);
    expect(find.text('Deni: TSh 10,000'), findsOneWidget);
    await tapVisible(tester, _button('Pokea fedha'));
    final amount = _inSheet(find.byType(TextField)).first;
    // Never prefilled from sales, even when money is still owed.
    expect(tester.widget<TextField>(amount).controller!.text, isEmpty);
    await tester.enterText(amount, '1500');
    await tester.tap(_inSheet(_button('Pokea fedha')));
    await tester.pumpAndSettle();
    expect(
        find.text('Pokea TSh 1,500 kutoka kwa Baraka Ally?'), findsOneWidget);
    expect(office.recorded, isEmpty); // Nothing sent before confirming.
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    expect(office.recorded, [
      {'vendor_id': 'v2', 'business_date': _date, 'amount': 1500}
    ]);
    expect(find.text('Makabidhiano yamehifadhiwa ofisini.'), findsOneWidget);
    expect(find.text('TSh 1,500'), findsOneWidget);
    expect(find.text('Inasubiri uthibitisho wa fedha'), findsOneWidget);
    // A supervisor neither confirms nor reverses.
    expect(_button('Thibitisha makabidhiano'), findsNothing);
    expect(_button('Rekebisha'), findsNothing);
  });

  testWidgets('the amount field is never prefilled from sales', (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    expect(find.text('Deni: TSh 10,000'), findsOneWidget);
    await tapVisible(tester, _button('Pokea fedha'));
    expect(
        tester
            .widget<TextField>(_inSheet(find.byType(TextField)).first)
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('the form sends the chosen time and note', (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tapVisible(tester, _button('Pokea fedha'));
    // Empty means now: nothing is sent for the time.
    expect(find.text('Ilipokelewa saa'), findsOneWidget);
    expect(find.text('Maelezo (si lazima)'), findsOneWidget);
    await tester.tap(_inSheet(find.text('Sasa')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Punguza Saa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tumia muda huu'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsWidgets);
    final fields = _inSheet(find.byType(TextField));
    await tester.enterText(fields.at(0), '1500');
    await tester.enterText(fields.at(1), 'Amekabidhi kwa Asha');
    tester.testTextInput.hide();
    await tester.tap(_inSheet(_button('Pokea fedha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    // 08:00 East Africa time is 05:00 UTC.
    expect(office.handoverTimes.single, DateTime.utc(2026, 10, 21, 5));
    expect(office.handoverNotes.single, 'Amekabidhi kwa Asha');
  });

  testWidgets('a handover without a time or note sends neither',
      (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tapVisible(tester, _button('Pokea fedha'));
    await tester.enterText(_inSheet(find.byType(TextField)).first, '700');
    await tester.tap(_inSheet(_button('Pokea fedha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    expect(office.handoverTimes.single, isNull);
    expect(office.handoverNotes.single, isNull);
  });

  testWidgets('a future time is refused on the form', (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tapVisible(tester, _button('Pokea fedha'));
    await tester.tap(_inSheet(find.text('Sasa')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Ongeza Saa')); // 10:00, after now
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tumia muda huu'));
    await tester.pumpAndSettle();
    expect(find.text('Saa hii bado haijafika. Chagua saa iliyopita.'),
        findsOneWidget);
    expect(office.handoverTimes, isEmpty);
    expect(office.recorded, isEmpty);
  });

  testWidgets('the day shows the cash on hand as an estimate', (tester) async {
    final office = moneyOffice()
      ..moneyDayList.add(OfficeMoneyDay(
          vendorDayId: 'vd-v7',
          vendor: const MoneyParty(id: 'v7', name: 'Gaudensia', code: 'V-v7'),
          businessDate: _day,
          cashOnHandEstimate: 42000,
          state: MoneyDayState.notHanded));
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v7'));
    expect(find.text('Makadirio ya fedha mkononi sasa'), findsOneWidget);
    expect(find.text('TSh 42,000'), findsWidgets);
  });

  testWidgets('a past day shows no cash-on-hand estimate', (tester) async {
    final office = moneyOffice(); // the server sends no estimate for a past day
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', '2026-10-20', 'v2'));
    expect(find.text('Makadirio ya fedha mkononi sasa'), findsNothing);
  });

  testWidgets('sending a handover again after a lost answer keeps its id',
      (tester) async {
    final office = moneyOffice()..loseNextAnswer = true;
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tapVisible(tester, _button('Pokea fedha'));

    Future<void> send(String amount) async {
      await tester.enterText(_inSheet(find.byType(TextField)).first, amount);
      await tester.tap(_inSheet(_button('Pokea fedha')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ndiyo, thibitisha'));
      await tester.pumpAndSettle();
    }

    await send('1500');
    expect(office.handoverIds.single, isNotNull);
    // The sheet is still open: the same amount is the same handover.
    await send('1500');
    expect(office.handoverIds, hasLength(2));
    expect(office.handoverIds.last, office.handoverIds.first);
  });

  testWidgets('an amount of zero is refused before sending', (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v3'));
    await tapVisible(tester, _button('Pokea fedha'));
    expect(
        tester
            .widget<TextField>(_inSheet(find.byType(TextField)).first)
            .controller!
            .text,
        isEmpty);
    await tester.tap(_inSheet(_button('Pokea fedha')));
    await tester.pumpAndSettle();
    expect(find.text('Andika kiasi kikubwa kuliko sifuri.'), findsOneWidget);
    expect(office.recorded, isEmpty);
  });

  testWidgets('a negative cash due is not prefilled', (tester) async {
    final office = moneyOffice()
      ..moneyDayList.add(_row('v6', 'Fatma Ali', MoneyDayState.over,
          due: -2000, handed: 1000, remaining: -3000));
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v6'));
    expect(find.text('Ziada TSh 3,000'), findsOneWidget);
    await tapVisible(tester, _button('Pokea fedha'));
    expect(
        tester
            .widget<TextField>(_inSheet(find.byType(TextField)).first)
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('finance confirms only handovers someone else recorded',
      (tester) async {
    final office = moneyOffice()
      ..handoverList.addAll([
        _handover('h1', 'st1', amount: 3000),
        _handover('h2', 'st9', amount: 5000),
      ]);
    await openMoney(tester, office,
        roles: const ['finance'],
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    expect(_button('Thibitisha makabidhiano'), findsOneWidget);
    expect(find.text('Uliyarekodi wewe; mtu mwingine atayathibitisha.'),
        findsOneWidget);
    await tapVisible(tester, _button('Thibitisha makabidhiano'));
    expect(
        find.text('Thibitisha TSh 5,000 zimepokelewa kutoka kwa Baraka Ally?'),
        findsOneWidget);
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    expect(office.confirmed, ['h2']);
    expect(find.text('Imethibitishwa na Neema Said'), findsOneWidget);
    expect(_button('Thibitisha makabidhiano'), findsNothing);
  });

  testWidgets('a supervisor is not offered confirmation', (tester) async {
    final office = moneyOffice()..handoverList.add(_handover('h2', 'st9'));
    await openMoney(tester, office,
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    expect(find.text('Inasubiri uthibitisho wa fedha'), findsOneWidget);
    expect(_button('Thibitisha makabidhiano'), findsNothing);
  });

  testWidgets('reversing needs a reason and adds a correcting record',
      (tester) async {
    final office = moneyOffice()
      ..handoverList.add(_handover('h2', 'st9', status: 'confirmed'));
    await openMoney(tester, office,
        roles: const ['finance'],
        route: MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tapVisible(tester, _button('Rekebisha'));
    expect(find.textContaining('Rekodi ya awali haifutwi'), findsOneWidget);
    await tester.tap(_inSheet(_button('Rekebisha')));
    await tester.pumpAndSettle();
    expect(find.text('Andika sababu ya herufi 3 hadi 500.'), findsOneWidget);
    expect(office.reversed, isEmpty);
    await tester.enterText(
        _inSheet(find.byType(TextField)), 'Hesabu mara mbili');
    await tester.tap(_inSheet(_button('Rekebisha')));
    await tester.pumpAndSettle();
    expect(office.reversed, ['h2 reason=Hesabu mara mbili']);
    expect(find.text('Rekodi ya kurekebisha imehifadhiwa ofisini.'),
        findsOneWidget);
    expect(find.text('Imerekebishwa'), findsOneWidget);
    expect(find.text('Rekodi ya kurekebisha'), findsOneWidget);
    expect(_button('Rekebisha'), findsNothing);
  });

  group('expenses', () {
    testWidgets('without categories, Mengineyo needs what was bought',
        (tester) async {
      final office = moneyOffice();
      await openMoney(tester, office, route: MNRoutes.officeMoneyStation('s1'));
      await tester.tap(find.text('Gharama'));
      await tester.pumpAndSettle();
      await tapVisible(tester, _button('Ongeza gharama'));
      await tester.tap(find.byType(MNSelectField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mengineyo').last);
      await tester.pumpAndSettle();
      await tester.enterText(_inSheet(find.byType(TextField)).at(1), '1500');
      await tester.tap(_inSheet(_button('Ongeza gharama')));
      await tester.pumpAndSettle();
      expect(
          find.text('Chagua au andika kitu kilichonunuliwa.'), findsOneWidget);
      await tester.enterText(
          _inSheet(find.byType(TextField)).at(0), 'Kiberiti');
      await tester.tap(_inSheet(_button('Ongeza gharama')));
      await tester.pumpAndSettle();
      expect(find.text('Rekodi gharama ya Mengineyo · Kiberiti, TSh 1,500?'),
          findsOneWidget);
      await tester.tap(find.text('Ndiyo, thibitisha'));
      await tester.pumpAndSettle();
      final row = office.expenseList.single;
      expect((row.category, row.item, row.amount),
          ('Mengineyo', 'Kiberiti', 1500));
      expect(find.text('Mengineyo · Kiberiti'), findsOneWidget);
    });

    testWidgets('a category with items needs one of them', (tester) async {
      final office = moneyOffice()
        ..moneySettingsValue = const OfficeMoneySettings(expenseCategories: [
          'Usafi'
        ], expenseItems: {
          'Usafi': ['Sabuni', 'Dawa ya vyombo']
        });
      await openMoney(tester, office, route: MNRoutes.officeMoneyStation('s1'));
      await tester.tap(find.text('Gharama'));
      await tester.pumpAndSettle();
      await tapVisible(tester, _button('Ongeza gharama'));
      await tester.tap(find.byType(MNSelectField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usafi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MNSelectField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sabuni').last);
      await tester.pumpAndSettle();
      await tester.enterText(_inSheet(find.byType(TextField)).first, '3000');
      await tester.tap(_inSheet(_button('Ongeza gharama')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ndiyo, thibitisha'));
      await tester.pumpAndSettle();
      final row = office.expenseList.single;
      expect((row.category, row.item, row.amount), ('Usafi', 'Sabuni', 3000));
    });

    testWidgets('an office expense is recorded for the screen date',
        (tester) async {
      final office = moneyOffice()
        ..moneySettingsValue =
            const OfficeMoneySettings(expenseCategories: ['Mkaa', 'Maji']);
      await openMoney(tester, office, route: MNRoutes.officeMoneyStation('s1'));
      await tester.tap(find.text('Gharama'));
      await tester.pumpAndSettle();
      expect(find.text('Hakuna gharama siku hii'), findsOneWidget);
      await tapVisible(tester, _button('Ongeza gharama'));
      await tester.tap(_inSheet(_button('Ongeza gharama')));
      await tester.pumpAndSettle();
      expect(find.text('Chagua aina ya gharama.'), findsOneWidget);
      await tester.tap(find.byType(MNSelectField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mkaa').last);
      await tester.pumpAndSettle();
      await tester.enterText(_inSheet(find.byType(TextField)).first, '7000');
      await tester.tap(_inSheet(_button('Ongeza gharama')));
      await tester.pumpAndSettle();
      expect(find.text('Rekodi gharama ya Mkaa, TSh 7,000?'), findsOneWidget);
      await tester.tap(find.text('Ndiyo, thibitisha'));
      await tester.pumpAndSettle();
      final row = office.expenseList.single;
      expect((row.category, row.amount, moneyDateKey(row.businessDate!)),
          ('Mkaa', 7000, _date));
      expect(find.text('Gharama imehifadhiwa ofisini.'), findsOneWidget);
      expect(find.text('Imelipwa na ofisi'), findsOneWidget);
    });

    testWidgets('a reversal shows as a correction under its original',
        (tester) async {
      final office = moneyOffice()
        ..expenseList.addAll([
          OfficeExpense(
              id: 'e1',
              businessDate: _day,
              category: 'Mkaa',
              amount: 4000,
              decidedBy: const MoneyParty(id: 'st1', name: 'Neema Said'),
              reversedById: 'e3'),
          OfficeExpense(
              id: 'e2', businessDate: _day, category: 'Maji', amount: 1000),
          OfficeExpense(
              id: 'e3',
              businessDate: _day,
              category: 'Mkaa',
              amount: 4000,
              reversesId: 'e1',
              decidedBy: const MoneyParty(id: 'st9', name: 'Fedha Juma'),
              decisionReason: 'Imerudiwa'),
        ]);
      await openMoney(tester, office,
          roles: const ['finance'], route: MNRoutes.officeMoneyStation('s1'));
      await tester.tap(find.text('Gharama'));
      await tester.pumpAndSettle();
      final correction = find.text('Inarekebisha gharama ya Mkaa, TSh 4,000');
      expect(correction, findsOneWidget);
      expect(find.text('Imerekebishwa na Fedha Juma'), findsOneWidget);
      expect(find.text('Sababu: Imerudiwa'), findsOneWidget);
      // Placed right after the original, before the next expense.
      expect(tester.getTopLeft(correction).dy,
          lessThan(tester.getTopLeft(find.text('Maji')).dy));
      // An office expense does not show who "decided" it.
      expect(find.textContaining('Imeamuliwa na'), findsNothing);
      // Only the untouched approved expense can still be reversed.
      expect(_button('Rekebisha'), findsOneWidget);
    });

    testWidgets('vendor claims come first and are decided with a reason',
        (tester) async {
      final office = moneyOffice()
        ..expenseList.addAll([
          OfficeExpense(
              id: 'e1',
              businessDate: _day,
              category: 'Mkaa',
              amount: 4000,
              paidBy: 'office'),
          OfficeExpense(
              id: 'e2',
              businessDate: _day,
              category: 'Maji',
              amount: 1000,
              paidBy: 'vendor',
              vendor: const MoneyParty(id: 'v2', name: 'Baraka Ally'),
              status: 'pending'),
        ]);
      await openMoney(tester, office, route: MNRoutes.officeMoneyStation('s1'));
      await tester.tap(find.text('Gharama'));
      await tester.pumpAndSettle();
      expect(find.text('Madai ya wauzaji yanayosubiri'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Maji')).dy,
          lessThan(tester.getTopLeft(find.text('Mkaa')).dy));
      expect(find.text('Imelipwa na Baraka Ally'), findsOneWidget);
      // Reversal is for finance and the owner.
      expect(_button('Rekebisha'), findsNothing);
      await tapVisible(tester, _button('Kubali'));
      expect(
          find.text(
              'Ukikubali, TSh 1,000 itaondolewa kwenye deni la Baraka Ally.'),
          findsOneWidget);
      await tester.tap(_inSheet(_button('Kubali')));
      await tester.pumpAndSettle();
      expect(office.decided, isEmpty);
      await tester.enterText(_inSheet(find.byType(TextField)), 'Risiti ipo');
      await tester.tap(_inSheet(_button('Kubali')));
      await tester.pumpAndSettle();
      expect(office.decided, ['e2 approve=true reason=Risiti ipo']);
      expect(find.text('Madai ya wauzaji yanayosubiri'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('categories, their items and Mengineyo in quiet rows',
        (tester) async {
      final office = moneyOffice()
        ..moneySettingsValue = const OfficeMoneySettings(expenseCategories: [
          'Usafi'
        ], expenseItems: {
          'Usafi': ['Sabuni']
        }, handoverDeadline: '19:30');
      await openMoney(tester, office,
          roles: const ['business_owner'], route: MNRoutes.officeMoneySettings);
      expect(find.text('19:30'), findsOneWidget);
      expect(find.text('Usafi'), findsNothing);
      await tapVisible(tester, find.text('Aina za gharama'));
      expect(find.text('Usafi'), findsOneWidget);
      expect(find.text('Kitu 1'), findsOneWidget);
      expect(find.text('Mengineyo'), findsOneWidget);

      // A new category: one name and Save, the reason is written for you.
      await tapVisible(tester, find.text('Ongeza').first);
      await tester.tap(_inSheet(_button('Hifadhi mabadiliko')));
      await tester.pumpAndSettle();
      expect(find.text('Andika jina la herufi 1 hadi 40.'), findsOneWidget);
      await tester.enterText(_inSheet(find.byType(TextField)), 'mengineyo');
      await tester.tap(_inSheet(_button('Hifadhi mabadiliko')));
      await tester.pumpAndSettle();
      expect(find.text('Mengineyo ipo tayari kwa vitu visivyo na aina.'),
          findsOneWidget);
      await tester.enterText(_inSheet(find.byType(TextField)), ' usafi ');
      await tester.tap(_inSheet(_button('Hifadhi mabadiliko')));
      await tester.pumpAndSettle();
      expect(find.text('Jina hili lipo tayari.'), findsOneWidget);
      expect(office.settingWrites, isEmpty);
      await tester.enterText(_inSheet(find.byType(TextField)), 'Mkaa');
      await tester.tap(_inSheet(_button('Hifadhi mabadiliko')));
      await tester.pumpAndSettle();
      expect(office.settingWrites.single, {
        'key': 'expense.categories',
        'value': ['Usafi', 'Mkaa'],
        'reason': 'Imeongezwa aina: Mkaa'
      });
      expect(find.text('Hakuna vitu'), findsOneWidget);

      // Its page lists the items; adding one keeps the other categories'.
      await tapVisible(tester, find.text('Usafi'));
      expect(find.text('Sabuni'), findsOneWidget);
      await tapVisible(tester, find.text('Ongeza').first);
      await tester.enterText(
          _inSheet(find.byType(TextField)), 'Dawa ya vyombo');
      await tester.tap(_inSheet(_button('Hifadhi mabadiliko')));
      await tester.pumpAndSettle();
      expect(office.settingWrites.last, {
        'key': 'expense.items',
        'value': {
          'Usafi': ['Sabuni', 'Dawa ya vyombo']
        },
        'reason': 'Imeongezwa: Dawa ya vyombo (Usafi)'
      });
      expect(find.text('Dawa ya vyombo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the owner sets the cash limit, off until then',
        (tester) async {
      final office = moneyOffice();
      await openMoney(tester, office,
          roles: const ['business_owner'], route: MNRoutes.officeMoneySettings);
      expect(find.text('Kikomo cha fedha mkononi'), findsOneWidget);
      expect(find.text('Haijawekwa'), findsWidgets);
      await tapVisible(tester, find.text('Kikomo cha fedha mkononi'));
      await tester.enterText(_inSheet(find.byType(TextField)).first, '300000');
      tester.testTextInput.hide();
      await tester.tap(_inSheet(_button('Weka kikomo')));
      await tester.pumpAndSettle();
      expect(office.settingWrites.single['key'], 'money.cash_on_hand_limit');
      expect(office.settingWrites.single['value'], 300000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only the owner edits the settings', (tester) async {
      await openMoney(tester, moneyOffice(),
          roles: const ['finance'], route: MNRoutes.officeMoneySettings);
      expect(
          find.text('Akaunti yako hairuhusiwi kufanya hili'), findsOneWidget);
      expect(_button('Hifadhi aina za gharama'), findsNothing);
    });
  });

  group('entries', () {
    testWidgets('the owner Muhtasari money row opens Fedha', (tester) async {
      await openMoney(tester, moneyOffice(), roles: const ['business_owner']);
      await tapVisible(tester, find.text('Fedha'));
      expect(find.byType(OfficeMoneyScreen), findsOneWidget);
      expect(find.text('Mipangilio ya fedha'), findsOneWidget);
      await tester.tap(find.text('Kariakoo'));
      await tester.pumpAndSettle();
      expect(find.byType(OfficeMoneyStationScreen), findsOneWidget);
    });

    testWidgets('the owner reaches the settings from Usimamizi',
        (tester) async {
      final app = await openMoney(tester, moneyOffice(),
          roles: const ['business_owner']);
      app.router.push(MNRoutes.officeManagement);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Mipangilio ya fedha'));
      expect(find.byType(OfficeMoneySettingsScreen), findsOneWidget);
    });

    for (final role in ['supervisor', 'finance']) {
      testWidgets('$role sees Fedha next to Uthibitisho', (tester) async {
        await openMoney(tester, moneyOffice(), roles: [role]);
        expect(find.text('Uthibitisho'), findsOneWidget);
        await tapVisible(tester, find.text('Fedha'));
        expect(find.byType(OfficeMoneyScreen), findsOneWidget);
        expect(find.text('Mipangilio ya fedha'), findsNothing);
      });
    }

    for (final role in ['kitchen_staff', 'operations_admin']) {
      testWidgets('$role does not see Fedha', (tester) async {
        await openMoney(tester, moneyOffice(), roles: [role]);
        expect(find.text('Fedha'), findsNothing);
      });
    }
  });

  testWidgets('money screens fit 320 px at 2× text', (tester) async {
    final office = moneyOffice()
      ..handoverList.add(_handover('h2', 'st9'))
      ..moneySettingsValue =
          const OfficeMoneySettings(expenseCategories: ['Mkaa'])
      ..expenseList.add(OfficeExpense(
          id: 'e2',
          businessDate: _day,
          category: 'Maji',
          amount: 1000,
          paidBy: 'vendor',
          vendor: const MoneyParty(id: 'v2', name: 'Baraka Ally'),
          status: 'pending'));
    final app = await openMoney(tester, office,
        roles: const ['business_owner'],
        size: const Size(320, 568),
        textScale: 2);
    for (final route in [
      MNRoutes.officeMoney,
      MNRoutes.officeMoneyStation('s1'),
      MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'),
      MNRoutes.officeMoneySettings,
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    app.router.go(MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tester.pumpAndSettle();
    await tapVisible(tester, _button('Pokea fedha'));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(MNSheet))).pop();
    await tester.pumpAndSettle();
    app.router.go(MNRoutes.officeMoneyStation('s1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Gharama'));
    expect(tester.takeException(), isNull);
    await tapVisible(tester, _button('Ongeza gharama'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the money screens meet the tap-target guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    final app = await openMoney(tester, moneyOffice(),
        roles: const ['finance'], route: MNRoutes.officeMoneyStation('s1'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    app.router.push(MNRoutes.officeMoneyVendorDay('s1', _date, 'v2'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  group('HTTP', () {
    test('money calls use the contract paths, bodies and refusals', () async {
      final requests = <RequestOptions>[];
      final store = InMemoryStore();
      await store.write('office_access_token', 'staff-token');
      final dio = Dio()
        ..httpClientAdapter = _Adapter((o) {
          requests.add(o);
          return switch ('${o.method} ${o.uri.path}') {
            'GET /api/v1/staff/money/days' => (
                200,
                [
                  {
                    'vendor_day_id': 'vd1',
                    'vendor': {'id': 'v1', 'name': 'Asha', 'code': 'V-1'},
                    'business_date': '2026-10-21',
                    'verified_cash_sales': 12000,
                    'unverified_cash_sales': 3000,
                    'approved_vendor_expenses': 2000,
                    'pending_vendor_expenses': 0,
                    'cash_due': 10000,
                    'handed_over': 8000,
                    'confirmed': 0,
                    'remaining': 2000,
                    'last_received_at': null,
                    'state': 'short',
                    'late': null
                  },
                  {'vendor': null},
                ]
              ),
            'POST /api/v1/staff/handovers' => (
                201,
                {
                  'id': 'h1',
                  'vendor': {'id': 'v1', 'name': 'Asha', 'code': 'V-1'},
                  'station': {'id': 's1', 'code': 'KA01', 'name': 'Kariakoo'},
                  'business_date': '2026-10-21',
                  'amount': 2000,
                  'received_at': '2026-10-21T15:00:00+00:00',
                  'recorded_by': {'id': 'st1', 'name': 'Neema'},
                  'status': 'recorded',
                  'confirmed_by': null,
                  'reverses_id': null,
                  'reversed_by_id': null,
                }
              ),
            'POST /api/v1/staff/handovers/h1/confirm' => (
                409,
                {'error': 'refused', 'detail': 'You recorded this handover.'}
              ),
            'POST /api/v1/staff/expenses' => (
                409,
                {
                  'error': 'refused',
                  'detail': 'Expense categories are not configured.'
                }
              ),
            'GET /api/v1/staff/expenses' => (200, []),
            'GET /api/v1/admin/settings' => (
                200,
                {
                  'expense.categories': ['Mkaa'],
                  'money.handover_deadline': '19:30'
                }
              ),
            'PUT /api/v1/admin/settings/money.handover_deadline' => (
                403,
                {'error': 'forbidden'}
              ),
            _ => (404, {'error': 'not_found'}),
          };
        });
      final repo =
          HttpOfficeRepository(baseUrl: 'https://x', store: store, dio: dio);

      final days = await repo.moneyDays(stationId: 's1', businessDate: _date);
      expect(requests.last.uri.queryParameters,
          {'station_id': 's1', 'business_date': _date});
      expect(days.first.state, MoneyDayState.short);
      expect(days.first.cashDue, 10000);
      expect(days.first.late, isNull);
      expect(days.last.vendor.id, ''); // A malformed row still parses.

      await repo.recordHandover(
          vendorId: 'v1', businessDate: _date, amount: 2000, clientId: 'c-1');
      expect((requests.last.data as Map)['client_id'], 'c-1');
      final h = await repo.recordHandover(
          vendorId: 'v1', businessDate: _date, amount: 2000);
      expect(requests.last.data,
          {'vendor_id': 'v1', 'business_date': _date, 'amount': 2000});
      expect((h.id, h.recordedBy.id, h.confirmed), ('h1', 'st1', false));

      await expectLater(
          repo.confirmHandover('h1'),
          throwsA(isA<OfficeError>().having(
              (e) => e.detail, 'detail', 'You recorded this handover.')));
      await expectLater(
          repo.recordExpense(
              stationId: 's1',
              businessDate: _date,
              category: 'Mkaa',
              amount: 500),
          throwsA(isA<OfficeError>().having((e) => e.detail, 'detail',
              'Expense categories are not configured.')));
      expect(requests.last.data, {
        'station_id': 's1',
        'business_date': _date,
        'category': 'Mkaa',
        'amount': 500
      });

      expect(await repo.expenses(stationId: 's1', from: _date, to: _date),
          isEmpty);
      expect(requests.last.uri.queryParameters,
          {'station_id': 's1', 'from': _date, 'to': _date});

      final settings = await repo.moneySettings();
      expect(settings.expenseCategories, ['Mkaa']);
      expect(settings.handoverDeadline, '19:30');

      await expectLater(
          repo.saveSetting(OfficeMoneySettings.deadlineKey,
              value: '20:00', reason: 'Mapema'),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.forbidden)));
      expect(requests.last.data, {'value': '20:00', 'reason': 'Mapema'});
    });

    test('category lists are checked like the server', () {
      expect(checkExpenseCategories([]), CategoryListProblem.empty);
      expect(checkExpenseCategories(['Mkaa', '']), CategoryListProblem.blank);
      expect(checkExpenseCategories(['Mkaa', 'MKAA']),
          CategoryListProblem.duplicate);
      expect(checkExpenseCategories(['x' * 41]), CategoryListProblem.tooLong);
      expect(checkExpenseCategories([for (var i = 0; i < 31; i++) 'c$i']),
          CategoryListProblem.tooMany);
      expect(checkExpenseCategories(['Mkaa', 'Maji']), isNull);
      expect(validHandoverDeadline('23:59'), isTrue);
      expect(validHandoverDeadline('24:00'), isFalse);
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
