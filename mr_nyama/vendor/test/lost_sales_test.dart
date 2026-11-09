import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_lost_sales.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_history.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/history/history_recovery.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart'
    show databaseProvider;
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';
import 'history_flow_test.dart' show now, openHistory, record;
import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible, verificationOffice;

const sw = Strings('sw');
const en = Strings('en');

const asha = OfficeVendor(
    id: 'v1',
    name: 'Asha Juma',
    phone: '+255712000111',
    activated: true,
    suspended: false,
    stationName: 'Kariakoo');

LostSaleEntry entry(
        {String status = 'open',
        bool mine = false,
        String payment = 'cash',
        DateTime? requestedAt,
        bool saleCancelled = false,
        bool dayCounted = true}) =>
    LostSaleEntry.fromJson({
      'id': 'e1',
      'vendor_id': 'v1',
      'vendor_name': 'Asha Juma',
      'station_id': 's1',
      'station_name': 'Kariakoo',
      'business_date': '2026-10-20',
      'payment_method': payment,
      'lines': [
        {'product_code': 'KUKU', 'name': 'Kuku mzima', 'quantity': 2, 'unit_price': 7000, 'amount': 14000}
      ],
      'total': 14000,
      'reason': 'Simu ilipotea; daftari linaonyesha.',
      'status': status,
      'requested_by': {'id': 'u9', 'name': 'Juma'},
      'requested_by_me': mine,
      'requested_at': requestedAt?.toIso8601String(),
      'sale_cancelled': saleCancelled,
      'day_counted': dayCounted,
      'decided_by': status == 'approved' ? {'id': 'u8', 'name': 'Neema'} : null,
    });

class LostOffice extends VerificationOffice implements OfficeLostSalesRepository {
  final entries = <LostSaleEntry>[];
  final asked = <Map<String, Object?>>[];
  final decided = <String>[];
  final withdrawn = <String>[];
  final ended = <String>[];
  OfficeError? refuseAsk;
  OfficeError? refuseDay;
  bool otherDecider = true;

  @override
  Future<List<LostSaleEntry>> lostSaleEntries(
          {String? stationId, String? vendorId, String? status}) async =>
      entries.where((e) => status == null || e.status == status).toList();

  @override
  Future<LostSaleDay> lostSaleDay(String vendorId, String businessDate) async {
    if (refuseDay case final e?) throw e;
    return LostSaleDay(
        businessDate: businessDate,
        stationId: 's1',
        stationName: 'Kariakoo',
        otherDecider: otherDecider,
        products: const [
          LostSaleProduct(code: 'KUKU', name: 'Kuku mzima', unitPrice: 7000),
          LostSaleProduct(code: 'PAJA', name: 'Paja', unitPrice: 2000),
        ]);
  }

  @override
  Future<LostSaleEntry> askLostSale(
      {required String clientId,
      required String vendorId,
      required String stationId,
      required String businessDate,
      required String paymentMethod,
      String? customerId,
      required Map<String, int> quantities,
      required String reason}) async {
    asked.add({
      'client': clientId,
      'vendor': vendorId,
      'station': stationId,
      'date': businessDate,
      'payment': paymentMethod,
      'customer': customerId,
      'lines': quantities,
      'reason': reason,
    });
    if (refuseAsk case final e?) {
      refuseAsk = null;
      throw e;
    }
    return entry(mine: true);
  }

  @override
  Future<LostSaleEntry> decideLostSale(String id,
      {required bool approve, required String reason}) async {
    decided.add('$id approve=$approve reason=$reason');
    entries.removeWhere((e) => e.id == id);
    return entry(status: approve ? 'approved' : 'rejected');
  }

  @override
  Future<LostSaleEntry> withdrawLostSale(String id) async {
    withdrawn.add(id);
    entries.removeWhere((e) => e.id == id);
    return entry(status: 'withdrawn', mine: true);
  }

  @override
  Future<void> endPhoneAccess(String vendorId, {required String reason}) async {
    ended.add('$vendorId reason=$reason');
  }
}

LostOffice office() {
  final base = verificationOffice();
  return LostOffice()
    ..signedIn = true
    ..vendorsList.add(asha)
    ..verificationList.addAll(base.verificationList)
    ..salesList.addAll(base.salesList)
    ..damageList.addAll(base.damageList)
    ..closingList.addAll(base.closingList);
}

const reason = 'Simu ilipotea; daftari linaonyesha mauzo.';

void main() {
  group('the vendor page', () {
    testWidgets('a supervisor gets lost sales and not ending access', (tester) async {
      await openAs(tester, office(), route: MNRoutes.officeVendor('v1'));
      expect(find.text(sw.lostSalesTitle), findsOneWidget);
      expect(find.text(sw.endPhoneAccess), findsNothing);
    });

    testWidgets('finance gets lost sales and not ending access', (tester) async {
      await openAs(tester, office(), roles: const ['finance'], route: MNRoutes.officeVendor('v1'));
      expect(find.text(sw.lostSalesTitle), findsOneWidget);
      expect(find.text(sw.endPhoneAccess), findsNothing);
    });

    testWidgets('operations gets ending access and not lost sales', (tester) async {
      await openAs(tester, office(), roles: const ['operations_admin'], route: MNRoutes.officeVendor('v1'));
      expect(find.text(sw.endPhoneAccess), findsOneWidget);
      expect(find.text(sw.lostSalesTitle), findsNothing);
    });

    testWidgets('ending access asks a reason, then confirms in the agreed words', (tester) async {
      final o = office();
      await openAs(tester, o, roles: const ['business_owner'], route: MNRoutes.officeVendor('v1'));
      await tapVisible(tester, find.text(sw.endPhoneAccess));
      expect(find.byType(MNSheet), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'Simu imepotea');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(MNButton, sw.endPhoneAccess).last);
      expect(
          find.text('Atahitaji kuingia tena. Kumbukumbu zisizotumwa zinabaki kwenye simu hiyo.'),
          findsOneWidget);
      expect(o.ended, isEmpty);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.endPhoneYes).last);
      expect(o.ended, ['v1 reason=Simu imepotea']);
      expect(find.text(sw.endPhoneDone), findsOneWidget);
    });

    testWidgets('a suspended vendor has no sessions left to end', (tester) async {
      final o = office();
      o.vendorsList
        ..clear()
        ..add(const OfficeVendor(
            id: 'v1', name: 'Asha Juma', phone: '+255712000111', activated: true, suspended: true));
      await openAs(tester, o, roles: const ['business_owner'], route: MNRoutes.officeVendor('v1'));
      expect(find.text(sw.endPhoneAccess), findsNothing);
    });
  });

  group('the form', () {
    Future<void> pickDay(WidgetTester tester) async {
      await tapVisible(tester, find.text(sw.lostSaleChooseDate));
      await tester.tap(find.text(sw.useThisDate));
      await tester.pumpAndSettle();
    }

    Future<LostOffice> start(WidgetTester tester, [LostOffice? given]) async {
      final o = given ?? office();
      await openAs(tester, o, route: MNRoutes.officeLostSaleNew('v1'));
      await pickDay(tester);
      return o;
    }

    Future<void> plus(WidgetTester tester, int row) async {
      final button = find.byType(MNQuantitySelector).at(row);
      final add = find.descendant(of: button, matching: find.byType(MNQuantityButton)).last;
      await tapVisible(tester, add);
    }

    Future<void> writeReason(WidgetTester tester, String text) async {
      final field = find.byType(EditableText).last;
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
    }

    testWidgets('shows that day\'s prices, totals them and sends no price', (tester) async {
      final o = await start(tester);
      expect(find.text('Kuku mzima'), findsOneWidget);
      expect(find.textContaining('7,000'), findsOneWidget);
      expect(find.widgetWithText(MNButton, sw.lostSaleSend), findsOneWidget);
      await plus(tester, 0);
      await plus(tester, 0);
      await plus(tester, 1);
      expect(find.text('TSh 16,000'), findsOneWidget);
      // Nothing to send until the reason says enough.
      await writeReason(tester, 'Fupi');
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleSend));
      expect(o.asked, isEmpty);
      await writeReason(tester, reason);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleSend));
      expect(o.asked.single['lines'], {'KUKU': 2, 'PAJA': 1});
      expect(o.asked.single['payment'], 'cash');
      expect(o.asked.single['station'], 's1');
      expect(o.asked.single['reason'], reason);
    });

    testWidgets('a retry keeps the client id; changed details get a new one', (tester) async {
      final o = office()..refuseAsk = const OfficeError(OfficeErrorKind.invalid);
      await start(tester, o);
      await plus(tester, 0);
      await writeReason(tester, reason);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleSend));
      expect(o.asked, hasLength(1));
      // The failed save keeps its retry.
      o.refuseAsk = const OfficeError(OfficeErrorKind.invalid);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleSend));
      expect(o.asked[1]['client'], o.asked[0]['client']);
      o.refuseAsk = const OfficeError(OfficeErrorKind.invalid);
      await plus(tester, 0);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleSend));
      expect(o.asked[2]['client'], isNot(o.asked[0]['client']));
    });

    testWidgets('a refused date says why inline', (tester) async {
      final o = office()
        ..refuseDay = const OfficeError(OfficeErrorKind.refused, 'Muuzaji hakupangiwa kituo hiki siku hiyo.');
      await start(tester, o);
      expect(find.textContaining('hakupangiwa'), findsOneWidget);
      expect(find.widgetWithText(MNButton, sw.lostSaleSend), findsNothing);
    });

    testWidgets('warns when nobody else could decide', (tester) async {
      await start(tester, office()..otherDecider = false);
      expect(find.text(sw.lostSaleNoDecider), findsOneWidget);
    });

    testWidgets('offers cash and credit, never M-Pesa', (tester) async {
      await start(tester);
      await tapVisible(tester, find.text(sw.cash));
      expect(find.text(sw.credit), findsOneWidget);
      expect(find.textContaining('M-Pesa'), findsNothing);
    });
  });

  group('deciding', () {
    testWidgets('finance sees the section; approving warns about cash due', (tester) async {
      final o = office()..entries.add(entry());
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text(sw.lostSalesTitle), findsOneWidget);
      expect(find.textContaining('Kuku mzima'), findsWidgets);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleApprove));
      expect(find.text(sw.lostSaleCashWarning('TSh 14,000')), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'Nimekagua daftari');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleApprove).last);
      expect(o.decided, ['e1 approve=true reason=Nimekagua daftari']);
    });

    testWidgets('credit does not claim to change cash due', (tester) async {
      final o = office()..entries.add(entry(payment: 'credit'));
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeVerificationStation('s1'));
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleApprove));
      expect(find.text(sw.lostSaleCashWarning('TSh 14,000')), findsNothing);
    });

    testWidgets('the decider\'s card shows how old the request is', (tester) async {
      final o = office()
        ..entries.add(entry(requestedAt: DateTime.now().subtract(const Duration(days: 40))));
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text(sw.lostSaleAge(40)), findsOneWidget);
      expect(sw.lostSaleAge(0), isNot(sw.lostSaleAge(1)));
    });

    testWidgets('approving warns when the day has no count', (tester) async {
      final o = office()..entries.add(entry(dayCounted: false));
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeVerificationStation('s1'));
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleApprove));
      expect(find.text('Siku hii itaonekana kama siku bila hesabu.'), findsOneWidget);
    });

    testWidgets('a counted day has no such warning, and refusing never does', (tester) async {
      final o = office()..entries.add(entry());
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeVerificationStation('s1'));
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleApprove));
      expect(find.text('Siku hii itaonekana kama siku bila hesabu.'), findsNothing);
    });

    testWidgets('a supervisor does not get the section', (tester) async {
      final o = office()..entries.add(entry());
      await openAs(tester, o, route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text(sw.lostSalesTitle), findsNothing);
    });

    testWidgets('the asker withdraws from the vendor page and cannot decide', (tester) async {
      final o = office()..entries.add(entry(mine: true));
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeLostSales('v1'));
      expect(find.widgetWithText(MNButton, sw.lostSaleApprove), findsNothing);
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleWithdraw));
      await tapVisible(tester, find.widgetWithText(MNButton, sw.lostSaleWithdrawYes).last);
      expect(o.withdrawn, ['e1']);
    });
  });

  group('labels', () {
    testWidgets('an entry whose sale was cancelled does not read Approved', (tester) async {
      final o = office()..entries.add(entry(status: 'approved', saleCancelled: true));
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeLostSales('v1'));
      expect(find.text(sw.lostSaleCancelled), findsOneWidget);
      expect(find.text(sw.lostSaleStatus('approved')), findsNothing);
    });

    testWidgets('an approved entry still reads Approved', (tester) async {
      final o = office()..entries.add(entry(status: 'approved'));
      await openAs(tester, o, roles: const ['finance'], route: MNRoutes.officeLostSales('v1'));
      expect(find.text(sw.lostSaleCancelled), findsNothing);
      expect(find.text(sw.lostSaleStatus('approved')), findsOneWidget);
    });

    testWidgets('the one who asked cannot select the sale, and is told why', (tester) async {
      Map<String, Object?> sale(String id, bool mine) => {
            'sale_id': id,
            'id': 'c$id',
            'vendor_id': 'v1',
            'vendor_name': 'Asha Juma',
            'business_date': '2026-10-20',
            'recorded_at': '2026-10-20T09:00:00Z',
            'payment': 'cash',
            'amount': 14000,
            'status': 'reported',
            'lines': const [],
            'product': 'Kuku mzima',
            'quantity': 2,
            'office_entry': {
              'id': 'e$id',
              'requested_by': 'Juma',
              'decided_by': 'Neema',
              'requested_by_me': mine
            },
          };
      final o = office();
      o.salesList
        ..clear()
        ..add(OfficeSale.fromJson(sale('mine', true)));
      await openAs(tester, o, route: MNRoutes.officeVerificationStation('s1'));
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(sw.lostSaleAskerCannotVerify), findsOneWidget);
    });

    testWidgets('the decider or anyone else can select it', (tester) async {
      final o = office();
      o.salesList
        ..clear()
        ..add(OfficeSale.fromJson({
          'sale_id': 'other',
          'id': 'c',
          'vendor_id': 'v1',
          'vendor_name': 'Asha Juma',
          'business_date': '2026-10-20',
          'recorded_at': '2026-10-20T09:00:00Z',
          'payment': 'cash',
          'amount': 14000,
          'status': 'reported',
          'lines': const [],
          'office_entry': {'id': 'e', 'requested_by': 'Juma', 'decided_by': 'Neema', 'requested_by_me': false},
        }));
      await openAs(tester, o, route: MNRoutes.officeVerificationStation('s1'));
      expect(find.byType(Checkbox), findsWidgets);
      expect(find.text(sw.lostSaleAskerCannotVerify), findsNothing);
    });

    testWidgets('a back-dated shortfall and a possible double entry say what is true', (tester) async {
      final o = office()
        ..exceptionList.addAll([
          const OfficeException(id: 'x1', kind: 'oversold', detail: {'sold': 2, 'not_in_stock': 1, 'backdated': true}),
          const OfficeException(id: 'x2', kind: 'possible_duplicate_entry', detail: {'sale_id': 's'}),
        ]);
      await openAs(tester, o, route: MNRoutes.officeVerificationProblems('s1'));
      await tapVisible(tester, find.text(sw.problemKind('oversold')));
      expect(find.text(sw.oversoldBackdatedLine), findsOneWidget);
      await tester.tap(find.byTooltip(sw.back));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Huenda mauzo yameingizwa mara mbili'));
      expect(find.text(sw.duplicateEntryLine), findsOneWidget);
    });

    testWidgets('a plain oversold has no back-dated line', (tester) async {
      final o = office()
        ..exceptionList.add(const OfficeException(id: 'x1', kind: 'oversold', detail: {'sold': 2, 'not_in_stock': 1}));
      await openAs(tester, o, route: MNRoutes.officeVerificationProblems('s1'));
      await tapVisible(tester, find.text(sw.problemKind('oversold')));
      expect(find.text(sw.oversoldBackdatedLine), findsNothing);
    });

    testWidgets('the sale row names who asked and who allowed', (tester) async {
      final o = office();
      o.salesList
        ..clear()
        ..add(OfficeSale.fromJson({
          'sale_id': 'sale-9',
          'id': 'c9',
          'vendor_id': 'v1',
          'vendor_name': 'Asha Juma',
          'business_date': '2026-10-20',
          'recorded_at': '2026-10-20T09:00:00Z',
          'payment': 'cash',
          'amount': 14000,
          'status': 'reported',
          'office_entry': {'id': 'e1', 'requested_by': 'Juma', 'decided_by': 'Neema'},
        }));
      await openAs(tester, o, route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text(sw.lostEnteredByOffice), findsOneWidget);
      expect(find.text(sw.lostEnteredNames('Juma', 'Neema')), findsOneWidget);
    });

    test('the hold reason is true in both languages', () {
      expect(sw.autoHoldReason('office_entered'), contains('ofisi'));
      expect(en.autoHoldReason('office_entered'), contains('office'));
    });

    test('statuses read plainly', () {
      expect(sw.lostSaleStatus('open'), 'Inasubiri uamuzi');
      expect(sw.lostSaleStatus('approved'), 'Imekubaliwa');
      expect(sw.lostSaleStatus('rejected'), 'Imekataliwa');
      expect(sw.lostSaleStatus('withdrawn'), 'Imeondolewa');
    });

    testWidgets('the vendor\'s history says the office entered it', (tester) async {
      final app = await openHistory(tester, seed: (app) async {
        await record(app, 'aaaa-0009', now.subtract(const Duration(hours: 2)));
        await HistoryRecoveryStore(app.container.read(databaseProvider)).apply(
            'v1',
            VendorHistory(sales: [
              RecoveredSale.fromJson(const {
                'client_id': 'aaaa-0009',
                'recorded_at': '2026-10-08T09:00:00Z',
                'office_entered': true,
              })
            ]));
      });
      expect(app, isNotNull);
      expect(find.textContaining(sw.lostEnteredByOffice), findsOneWidget);
    });

    test('recovery remembers which sales the office entered', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final store = HistoryRecoveryStore(db);
      final sale = RecoveredSale.fromJson({
        'client_id': 'c9',
        'recorded_at': '2026-10-20T09:00:00Z',
        'payment_method': 'cash',
        'total': 14000,
        'status': 'reported',
        'lines': const [],
        'office_entered': true,
      });
      expect(sale.officeEntered, isTrue);
      await store.apply('v1', VendorHistory(sales: [sale]));
      expect(await store.watchOfficeEntered('v1').first, {'c9'});
      // A second recovery leaves it as it was.
      await store.apply('v1', VendorHistory(sales: [sale]));
      expect(await store.watchOfficeEntered('v1').first, {'c9'});
    });
  });

  test('entries read from the server', () {
    final e = entry(status: 'approved');
    expect(e.total, 14000);
    expect(e.lines.single.name, 'Kuku mzima');
    expect(e.decidedBy, 'Neema');
    expect(e.isOpen, isFalse);
  });
}
