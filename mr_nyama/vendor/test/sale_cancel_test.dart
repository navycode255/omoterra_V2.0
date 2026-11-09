import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/office_sale_cancel.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/history/history_screen.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';
import 'office_verification_test.dart'
    show VerificationOffice, openAs, verificationOffice;

const sw = Strings('sw');
const en = Strings('en');

class CancelOffice extends VerificationOffice
    implements OfficeSaleCancelRepository {
  final requests = <SaleCancellation>[];
  final asked = <String>[];
  final decided = <String>[];

  @override
  Future<List<SaleCancellation>> saleCancellations(
          {String? stationId, String? status}) async =>
      requests.where((r) => status == null || r.status == status).toList();

  @override
  Future<SaleCancellation> askToCancelSale(
      {required String clientId,
      required String saleId,
      required String reason}) async {
    asked.add('$saleId|$reason');
    return requests.first;
  }

  @override
  Future<SaleCancellation> withdrawSaleCancellation(String id) async =>
      SaleCancellation(
          id: id,
          saleId: 'sale-1',
          stationId: 's1',
          businessDate: '',
          status: 'withdrawn',
          reason: '');

  @override
  Future<SaleCancellation> decideSaleCancellation(String id,
      {required bool approve, required String reason}) async {
    decided.add('$id approve=$approve reason=$reason');
    requests.removeWhere((r) => r.id == id);
    return SaleCancellation(
        id: id,
        saleId: 'sale-1',
        stationId: 's1',
        businessDate: '',
        status: 'approved',
        reason: '');
  }
}

SaleCancellation request({bool mine = false}) => SaleCancellation(
    id: 'k1',
    saleId: 'sale-1',
    stationId: 's1',
    businessDate: '2026-10-20',
    status: 'open',
    reason: 'Yaliandikwa kimakosa.',
    requestedBy: const CancelPerson(id: 'u9', name: 'Juma'),
    requestedByMe: mine,
    vendorName: 'Asha Juma',
    total: 9000,
    lines: const [CancelLine(name: 'Kuku mzima', quantity: 1, amount: 9000)]);

CancelOffice office() {
  final base = verificationOffice();
  return CancelOffice()
    ..signedIn = true
    ..verificationList.addAll(base.verificationList)
    ..salesList.addAll(base.salesList)
    ..damageList.addAll(base.damageList)
    ..closingList.addAll(base.closingList);
}

final now = DateTime.utc(2026, 10, 9, 12);

void main() {
  group('the phone', () {
    late AppDatabase db;
    late SalesStore sales;
    late HistoryStore history;
    setUp(() async {
      db = testDatabase();
      sales = SalesStore(db);
      history = HistoryStore(db);
      await sales.replaceCatalog(testCatalog);
      await sales.saveSale(SaleDraft(
          clientId: 'sale-a',
          vendorId: 'v1',
          recordedAt: now.subtract(const Duration(days: 1)),
          payment: PaymentMethod.cash,
          lines: [
            DraftLine(
                productId: 'paja',
                productName: 'Paja (Robo)',
                quantity: 2,
                unitPrice: 2000)
          ]));
    });
    tearDown(() => db.close());

    test('a sale the office cancelled shows as cancelled by the office',
        () async {
      await history.markCancelledByOffice('sale-a', 'void-o', now);
      final sale = (await history.sale('sale-a'))!;
      expect(sale.entry.voidState, VoidState.accepted);
      expect(sale.entry.cancelledByOffice, isTrue);
      expect(saleStatus(sw, sale.entry).$1, 'Yamebatilishwa na ofisi');
      expect(saleStatus(en, sale.entry).$1, 'Cancelled by the office');
      // Told twice, still one void.
      await history.markCancelledByOffice('sale-a', 'void-o', now);
      expect(await db.select(db.saleVoids).get(), hasLength(1));
    });

    test('a sale this phone does not hold is left to history recovery',
        () async {
      await history.markCancelledByOffice('unknown', 'void-x', now);
      expect(await db.select(db.saleVoids).get(), isEmpty);
    });

    test('a vendor void still waiting becomes the office\'s and stays so',
        () async {
      await history.voidSale(
          voidId: 'void-v',
          saleClientId: 'sale-a',
          reason: VoidReason.wrongQuantity,
          actorId: 'v1',
          now: now.subtract(const Duration(days: 1)));
      await history.markCancelledByOffice('sale-a', 'void-o', now);
      // The server later answers the vendor's own void with "already voided".
      await history.applyVoidResult('void-v',
          accepted: false, rejectionReason: 'already_voided');
      final entry = (await history.sale('sale-a'))!.entry;
      expect(entry.voidState, VoidState.accepted);
      expect(entry.cancelledByOffice, isTrue);
    });

    test('a sale the vendor voided is not labelled as the office\'s', () async {
      await history.voidSale(
          voidId: 'void-v',
          saleClientId: 'sale-a',
          reason: VoidReason.wrongQuantity,
          actorId: 'v1',
          now: now.subtract(const Duration(days: 1)));
      final entry = (await history.sale('sale-a'))!.entry;
      expect(entry.cancelledByOffice, isFalse);
      expect(saleStatus(sw, entry).$1, isNot('Yamebatilishwa na ofisi'));
    });
  });

  test('the hold reason for an open request reads as its own', () {
    expect(sw.autoHoldReason('cancel_requested'),
        isNot(sw.autoHoldReason('new_code')));
    expect(en.autoHoldReason('cancel_requested'),
        isNot(en.autoHoldReason('new_code')));
  });

  group('the office', () {
    testWidgets('a sale row offers Omba kubatilisha and sends a reason',
        (tester) async {
      final o = office();
      await openAs(tester, o,
          roles: const ['supervisor'],
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text('Omba kubatilisha'), findsWidgets);
      await tester.ensureVisible(find.text('Omba kubatilisha').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Omba kubatilisha').first);
      await tester.pumpAndSettle();
      final send = find.widgetWithText(MNButton, 'Tuma ombi');
      expect(tester.widget<MNButton>(send).onPressed, isNull);
      await tester.enterText(
          find.descendant(
              of: find.byType(MNSheet), matching: find.byType(TextField)),
          'Imeandikwa kimakosa');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(o.asked, hasLength(1));
      expect(o.asked.first, endsWith('|Imeandikwa kimakosa'));
    });

    testWidgets('a sale with an open request says so and cannot be picked',
        (tester) async {
      final o = office();
      o.salesList[0] = OfficeSale(
          saleId: 'sale-1',
          vendorId: 'v1',
          vendorName: 'Asha Juma',
          businessDate: DateTime.utc(2026, 10, 20),
          recordedAt: DateTime.utc(2026, 10, 20, 7, 15),
          payment: 'cash',
          amount: 9000,
          cancelRequestId: 'k1');
      await openAs(tester, o, route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text('Ombi la kubatilisha linasubiri'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('finance sees Kubali and Kataa with the warning, then decides',
        (tester) async {
      final o = office()..requests.add(request());
      await openAs(tester, o,
          roles: const ['finance'],
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text('Maombi ya kubatilisha'), findsOneWidget);
      expect(find.text('Yaliandikwa kimakosa.'), findsOneWidget);
      expect(find.text('Mauzo yatabatilishwa; historia itabaki.'),
          findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(MNButton, 'Kubali'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MNButton, 'Kubali'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(MNSheet), matching: find.byType(TextField)),
          'Nimekagua, ni kosa');
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(MNSheet),
          matching: find.widgetWithText(MNButton, 'Kubali')));
      await tester.pumpAndSettle();
      expect(o.decided, ['k1 approve=true reason=Nimekagua, ni kosa']);
    });

    testWidgets('the one who asked is told someone else will decide',
        (tester) async {
      final o = office()..requests.add(request(mine: true));
      await openAs(tester, o,
          roles: const ['business_owner'],
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text('Mtu mwingine ataamua'), findsOneWidget);
      expect(find.widgetWithText(MNButton, 'Kubali'), findsNothing);
      expect(find.widgetWithText(MNButton, 'Kataa'), findsNothing);
    });

    testWidgets('a supervisor sees the request but no decision buttons',
        (tester) async {
      final o = office()..requests.add(request());
      await openAs(tester, o,
          roles: const ['supervisor'],
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text('Maombi ya kubatilisha'), findsOneWidget);
      expect(find.widgetWithText(MNButton, 'Kubali'), findsNothing);
    });
  });
}
