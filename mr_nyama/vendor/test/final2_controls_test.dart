import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/office_sale_cancel.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/office/setup_screens.dart'
    show kitchenKindName;
import 'package:mr_nyama_vendor/features/sales/checkout.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

import 'credit_test.dart' show openWithCustomers, rehema;
import 'helpers.dart';
import 'history_flow_test.dart' show now, openHistory, openSale, record;
import 'office_setup_test.dart'
    show SetupOffice, choose, entry, office, typeInto;
import 'office_verification_test.dart' show openAs, tapVisible;
import 'sale_cancel_test.dart' as cancel show CancelOffice, office, request;
import 'sales_flow_test.dart' as flow show choose, openCart, tapProduct;

const sw = Strings('sw');
const en = Strings('en');

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

/// Remembers the id of every draft sent, and can fail the first send.
class RetryOffice extends SetupOffice {
  final clientIds = <String>[];
  bool failNext = false;
  @override
  Future<OfficeOpeningEntry> draftOpening(
      {required String clientId,
      required String locationId,
      required String product,
      required int quantity,
      int? unitCost,
      required String asOf,
      required String reference}) async {
    clientIds.add(clientId);
    if (failNext) {
      failNext = false;
      throw const SocketFailure();
    }
    return OfficeOpeningEntry(id: 'n1', quantity: quantity);
  }
}

class SocketFailure implements Exception {
  const SocketFailure();
}

SetupOffice _withProduct(SetupOffice o) {
  final base = office();
  o.productsList.addAll(base.productsList);
  return o;
}

void main() {
  test('the requests name the id and the withdraw route', () async {
    final store = InMemoryStore();
    await store.write('office_access_token', 'staff-token');
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _Adapter((o) {
        requests.add(o);
        return switch ('${o.method} ${o.uri.path}') {
          'POST /api/v1/staff/opening-entries' => (
              201,
              {'id': 'e1', 'quantity': 6}
            ),
          'POST /api/v1/staff/sale-cancellations/k1/withdraw' => (
              200,
              {'id': 'k1', 'status': 'withdrawn'}
            ),
          _ => (404, {'error': 'not_found'}),
        };
      });
    final repo =
        HttpOfficeRepository(baseUrl: 'https://x', store: store, dio: dio);
    await repo.draftOpening(
        clientId: 'c-1',
        locationId: 'l1',
        product: 'KUKU',
        quantity: 6,
        asOf: '2026-10-20',
        reference: 'Karatasi');
    expect((requests.last.data as Map)['client_id'], 'c-1');
    final row = await repo.withdrawSaleCancellation('k1');
    expect(row.status, 'withdrawn');
  });

  group('opening stock: closing is a lock', () {
    testWidgets('closed: Idhinisha is hidden, Kataa stays and it says why',
        (tester) async {
      final o = office()
        ..settings =
            const OfficeOpeningSettings(date: '2026-10-20', closed: true)
        ..entries.add(entry('e', 'finance-1'));
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingApprove), findsNothing);
      expect(find.text(sw.openingReject), findsOneWidget);
      expect(find.text(sw.openingClosedRejectOnly), findsOneWidget);
    });

    testWidgets('an entry of an earlier date: Idhinisha is hidden',
        (tester) async {
      final o = office()
        ..settings = const OfficeOpeningSettings(date: '2026-10-21')
        ..entries.add(entry('e', 'finance-1'));
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingApprove), findsNothing);
      expect(find.text(sw.openingReject), findsOneWidget);
      expect(find.text(sw.openingOldDate), findsOneWidget);
    });

    testWidgets('closing names how many drafts are still open', (tester) async {
      final o = office()
        ..entries.addAll([
          entry('a', 'finance-1'),
          entry('b', 'finance-1'),
          entry('c', 'finance-1', status: 'rejected')
        ]);
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      await tapVisible(tester, find.text(sw.openingClose));
      expect(find.textContaining(sw.openingCloseDrafts(2)), findsOneWidget);
    });

    testWidgets('closing with no drafts carries no warning', (tester) async {
      final o = office();
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      await tapVisible(tester, find.text(sw.openingClose));
      expect(find.text(sw.openingCloseBody), findsOneWidget);
      expect(find.textContaining(sw.openingCloseDrafts(1)), findsNothing);
    });
  });

  group('opening stock: the drafter', () {
    testWidgets('an owner who drafted sees Kataa, not Idhinisha, and the truth',
        (tester) async {
      final o = office()..entries.add(entry('mine', 'st1'));
      await openAs(tester, o,
          roles: const ['business_owner'], route: MNRoutes.officeOpening);
      expect(find.text('Mtu mwingine ataamua'), findsNothing);
      expect(find.text(sw.openingOwnDraftOwner), findsOneWidget);
      expect(find.text(sw.openingApprove), findsNothing);
      await tapVisible(tester, find.text(sw.openingReject));
      await tester.enterText(
          _inSheet(find.byType(TextField)), 'Niliandika vibaya');
      await tester.tap(_inSheet(find.text(sw.openingReject)).last);
      await tester.pumpAndSettle();
      expect(o.calls, ['decide mine approve=false reason=Niliandika vibaya']);
    });

    testWidgets('finance sees Kataa on their own draft, nothing on another',
        (tester) async {
      final o = office()
        ..entries.addAll([entry('mine', 'st1'), entry('theirs', 'finance-2')]);
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpening);
      expect(find.text(sw.openingOwnDraftFinance), findsOneWidget);
      expect(find.text(sw.openingOwnerDecides), findsOneWidget);
      expect(find.text(sw.openingReject), findsOneWidget);
      expect(find.text(sw.openingApprove), findsNothing);
    });
  });

  group('opening stock: a repeated send', () {
    Future<void> fill(WidgetTester tester, String reference) async {
      await choose(tester, sw.openingLocation, 'Ghala Kuu');
      await choose(tester, sw.openingProduct, 'Kuku mzima');
      await typeInto(tester, sw.openingRefRequired, reference);
    }

    testWidgets('a retry keeps the id; changed details get a new one',
        (tester) async {
      final o = _withProduct(RetryOffice()..failNext = true) as RetryOffice;
      await openAs(tester, o,
          roles: const ['finance'], route: MNRoutes.officeOpeningNew);
      await fill(tester, 'Karatasi A');
      await tester.tap(_button(sw.openingSave));
      await tester.pumpAndSettle();
      expect(o.clientIds, hasLength(1));
      expect(find.textContaining('Angalia orodha'), findsNothing);
      o.failNext = true;
      await tester.tap(_button(sw.openingSave));
      await tester.pumpAndSettle();
      expect(o.clientIds, hasLength(2));
      expect(o.clientIds[1], o.clientIds[0]);
      await typeInto(tester, sw.openingRefRequired, 'Karatasi B');
      await tester.tap(_button(sw.openingSave));
      await tester.pumpAndSettle();
      expect(o.clientIds, hasLength(3));
      expect(o.clientIds[2], isNot(o.clientIds[0]));
    });
  });

  group('kitchens', () {
    testWidgets('a new kitchen grant leaves out kitchens the person holds',
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
      await tapVisible(tester, find.text(sw.grantRole));
      await tester.tap(_inSheet(find.text('Jikoni')));
      await tester.pumpAndSettle();
      await tester.tap(_inSheet(find.text(sw.selectPlaceholder)).first);
      await tester.pumpAndSettle();
      final sheet = find.byType(MNSheet).last;
      expect(find.descendant(of: sheet, matching: find.text('Jiko la Pili')),
          findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Jiko Kuu')),
          findsNothing);
    });

    testWidgets('someone at every kitchen is told so, with nothing to pick',
        (tester) async {
      final o = office()
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
      await tapVisible(tester, find.text(sw.grantRole));
      await tester.tap(_inSheet(find.text('Jikoni')));
      await tester.pumpAndSettle();
      expect(_inSheet(find.text(sw.kitchenAllHeld)), findsOneWidget);
    });

    testWidgets('each kitchen grant has a revoke row naming its kitchen',
        (tester) async {
      final o = office()
        ..locations.add(const OfficeStockLocation(
            id: 'k2', code: 'JK2', name: 'Jiko la Pili', kind: 'kitchen'))
        ..staffList.add(const OfficeStaff(
            id: 'st9',
            name: 'Juma Pishi',
            phone: '+255713000999',
            roles: ['kitchen_staff'],
            roleGrants: [
              OfficeRoleGrant('g1', 'kitchen_staff', 'k1'),
              OfficeRoleGrant('g2', 'kitchen_staff', 'k2')
            ],
            activated: true,
            suspended: false));
      await openAs(tester, o,
          roles: const ['business_owner'],
          route: MNRoutes.officeStaffMember('st9'));
      final first = sw.revokeRole('${sw.roleName('kitchen_staff')}: Jiko Kuu');
      final second =
          sw.revokeRole('${sw.roleName('kitchen_staff')}: Jiko la Pili');
      expect(find.text(first), findsOneWidget);
      expect(find.text(second), findsOneWidget);
    });

    test('a raw location kind is never shown', () {
      for (final kind in ['station', 'vendor_custody', 'in_transit', 'other']) {
        expect(kitchenKindName(sw, kind), isNot(kind));
        expect(kitchenKindName(en, kind), isNot(kind));
      }
      expect(kitchenKindName(sw, 'station'), 'Kituo');
    });
  });

  group('sale cancellation: withdrawing', () {
    testWidgets('the asker sees Ondoa ombi, asked first, and it is sent',
        (tester) async {
      final o = WithdrawOffice.from(cancel.office())
        ..requests.add(cancel.request(mine: true));
      await openAs(tester, o,
          roles: const ['supervisor'],
          route: MNRoutes.officeVerificationStation('s1'));
      await tapVisible(tester, find.text(sw.cancelWithdraw));
      expect(o.withdrawn, isEmpty);
      await tester.tap(_button(sw.cancelWithdrawYes));
      await tester.pumpAndSettle();
      expect(o.withdrawn, ['k1']);
      expect(find.text(sw.cancelWithdraw), findsNothing);
    });

    testWidgets('another person has no Ondoa ombi', (tester) async {
      final o = WithdrawOffice.from(cancel.office())
        ..requests.add(cancel.request());
      await openAs(tester, o,
          roles: const ['finance'],
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text(sw.cancelWithdraw), findsNothing);
    });

    testWidgets('a failed load shows the load error, not nothing',
        (tester) async {
      final o = WithdrawOffice.from(cancel.office())..failList = true;
      await openAs(tester, o,
          roles: const ['supervisor'],
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.byType(MNErrorState), findsOneWidget);
    });
  });

  group('sale cancellation: nobody else to decide', () {
    Future<void> openAsk(
        WidgetTester tester, WithdrawOffice o, List<String> roles) async {
      await openAs(tester, o,
          roles: roles, route: MNRoutes.officeVerificationStation('s1'));
      await tapVisible(tester, find.text(sw.cancelAsk).first);
    }

    const finance = OfficeStaff(
        id: 'f1',
        name: 'Rehema',
        phone: '+255713000222',
        roles: ['finance'],
        activated: true,
        suspended: false);
    const me = OfficeStaff(
        id: 'st1',
        name: 'Neema Said',
        phone: '+255713000111',
        roles: ['business_owner'],
        activated: true,
        suspended: false);

    testWidgets('the only owner is warned', (tester) async {
      final o = WithdrawOffice.from(cancel.office())..staffList.add(me);
      await openAsk(tester, o, const ['business_owner']);
      expect(_inSheet(find.text(sw.cancelNoDecider)), findsOneWidget);
    });

    testWidgets('someone who left or was suspended cannot decide',
        (tester) async {
      final o = WithdrawOffice.from(cancel.office())
        ..staffList.addAll([
          me,
          const OfficeStaff(
              id: 'f2',
              name: 'Ali',
              phone: '+255713000333',
              roles: ['finance'],
              activated: true,
              suspended: true)
        ]);
      await openAsk(tester, o, const ['business_owner']);
      expect(_inSheet(find.text(sw.cancelNoDecider)), findsOneWidget);
    });

    testWidgets('with a finance person there is no warning', (tester) async {
      final o = WithdrawOffice.from(cancel.office())
        ..staffList.addAll([me, finance]);
      await openAsk(tester, o, const ['business_owner']);
      expect(_inSheet(find.text(sw.cancelNoDecider)), findsNothing);
    });

    testWidgets('a supervisor is not warned', (tester) async {
      final o = WithdrawOffice.from(cancel.office())..staffList.add(me);
      await openAsk(tester, o, const ['supervisor']);
      expect(_inSheet(find.text(sw.cancelNoDecider)), findsNothing);
    });
  });

  group('M-Pesa number taken away', () {
    testWidgets('the cart resets the choice and Save is disabled',
        (tester) async {
      final app = await pumpApp(tester,
          api: FakeVendorRepository()..catalogSnapshot = testCatalog,
          initial: MNRoutes.sales);
      await tester.pumpAndSettle();
      await flow.tapProduct(tester, 'Paja (Robo)');
      await flow.openCart(tester);
      await flow.choose(tester, sw.mpesa);
      final save = find.widgetWithText(MNButton, sw.saveSale);
      expect(tester.widget<MNButton>(save).onPressed, isNotNull);
      expect(app.container.read(checkoutProvider).payment, PaymentMethod.mpesa);

      await app.container.read(salesStoreProvider).replaceCatalog(
          CatalogSnapshot(
              mpesaRecipient: null, products: testCatalog.products));
      await tester.pumpAndSettle();
      expect(app.container.read(checkoutProvider).payment, isNull);
      expect(tester.widget<MNButton>(save).onPressed, isNull);
    });

    testWidgets('a controller holding M-Pesa with no number refuses to save',
        (tester) async {
      final app = await pumpApp(tester,
          api: FakeVendorRepository()..catalogSnapshot = testCatalog,
          initial: MNRoutes.sales);
      await tester.pumpAndSettle();
      final notifier = app.container.read(checkoutProvider.notifier);
      await app.container.read(salesStoreProvider).replaceCatalog(
          CatalogSnapshot(
              mpesaRecipient: null, products: testCatalog.products));
      await tester.pumpAndSettle();
      notifier.choosePayment(PaymentMethod.mpesa);
      await expectLater(notifier.confirm(), throwsA(isA<CheckoutBlocked>()));
      expect(app.container.read(checkoutProvider).payment, isNull);
    });

    testWidgets('a repayment choice falls back to cash', (tester) async {
      final app = await openWithCustomers(tester, customers: const [rehema]);
      app.router.push(MNRoutes.credit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mama Rehema'));
      await tester.pumpAndSettle();
      await tester.tap(_inSheet(find.text(sw.cash)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sw.mpesa).last);
      await tester.pumpAndSettle();
      expect(_inSheet(find.text(sw.creditRepaymentCashNote)), findsNothing);
      await app.container.read(salesStoreProvider).replaceCatalog(
          CatalogSnapshot(
              mpesaRecipient: null, products: testCatalog.products));
      await tester.pumpAndSettle();
      // Cash again, and the sheet says what a cash repayment means.
      expect(_inSheet(find.text(sw.creditRepaymentCashNote)), findsOneWidget);
    });
  });

  group('a sale the office cancelled', () {
    testWidgets(
        'the details say Yamebatilishwa na ofisi, not "Sababu nyingine"',
        (tester) async {
      final app = await openHistory(tester, seed: (app) async {
        await record(app, 'aaaa-0001', now.subtract(const Duration(hours: 2)));
      });
      await openSale(tester, 'Kuku mzima');
      await app.container
          .read(historyStoreProvider)
          .markCancelledByOffice('aaaa-0001', 'void-o', now);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sababu nyingine'), findsNothing);
      expect(find.textContaining('· ${sw.statusCancelledByOffice}'),
          findsOneWidget);
    });
  });
}

class WithdrawOffice extends cancel.CancelOffice {
  final withdrawn = <String>[];
  bool failList = false;

  factory WithdrawOffice.from(cancel.CancelOffice base) => WithdrawOffice._()
    ..signedIn = true
    ..verificationList.addAll(base.verificationList)
    ..salesList.addAll(base.salesList)
    ..damageList.addAll(base.damageList)
    ..closingList.addAll(base.closingList);
  WithdrawOffice._();

  @override
  Future<List<SaleCancellation>> saleCancellations(
      {String? stationId, String? status}) {
    if (failList) {
      return Future.error(const OfficeError(OfficeErrorKind.refused));
    }
    return super.saleCancellations(stationId: stationId, status: status);
  }

  @override
  Future<SaleCancellation> withdrawSaleCancellation(String id) async {
    withdrawn.add(id);
    requests.removeWhere((r) => r.id == id);
    return SaleCancellation(
        id: id,
        saleId: 'sale-1',
        stationId: 's1',
        businessDate: '',
        status: 'withdrawn',
        reason: '');
  }
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
