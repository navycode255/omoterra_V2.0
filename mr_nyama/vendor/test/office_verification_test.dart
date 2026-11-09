import 'office_design_helpers.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/verification_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

/// The shared fake with verification fixtures; records calls and can refuse.
class VerificationOffice extends FakeOfficeRepository {
  final verifyCalls = <List<String>>[];
  final decisions = <String>[];
  final confirms = <String>[];

  /// Thrown by the next verify call, then cleared.
  OfficeError? refuseVerify;

  @override
  Future<List<String>> verifySales(List<String> saleIds) {
    verifyCalls.add(saleIds);
    if (refuseVerify case final e?) {
      refuseVerify = null;
      throw e;
    }
    return super.verifySales(saleIds);
  }

  @override
  Future<OfficeDamageReport> decideDamage(String reportId,
      {required bool approve, required String reason}) {
    decisions.add('$reportId approve=$approve reason=$reason');
    return super.decideDamage(reportId, approve: approve, reason: reason);
  }

  @override
  Future<OfficeClosingCount> confirmClosing(String closingId) {
    confirms.add(closingId);
    return super.confirmClosing(closingId);
  }
}

final _day20 = DateTime.utc(2026, 10, 20);
final _day21 = DateTime.utc(2026, 10, 21);

VerificationOffice verificationOffice() => VerificationOffice()
  ..signedIn = true
  ..verificationList.addAll([
    OfficeVerificationStation(
        id: 's1',
        code: 'KA01',
        name: 'Kariakoo',
        pendingSales: 3,
        pendingSalesAmount: 21000,
        reportedDamage: 1,
        recordedClosings: 2,
        openExceptions: 1,
        oldestPendingDate: _day20),
    const OfficeVerificationStation(id: 's2', code: 'SI01', name: 'Sinza'),
  ])
  ..salesList.addAll([
    OfficeSale(
        saleId: 'sale-1',
        vendorId: 'v1',
        vendorName: 'Asha Juma',
        businessDate: _day20,
        recordedAt: DateTime.utc(2026, 10, 20, 7, 15),
        payment: 'cash',
        amount: 9000,
        lines: const [
          OfficeSaleLine(
              productCode: 'KUKU',
              name: 'Kuku mzima',
              quantity: 1,
              unitPrice: 9000,
              amount: 9000)
        ]),
    OfficeSale(
        saleId: 'sale-2',
        vendorId: 'v1',
        vendorName: 'Asha Juma',
        businessDate: _day20,
        recordedAt: DateTime.utc(2026, 10, 20, 8),
        payment: 'mpesa',
        amount: 2500),
    OfficeSale(
        saleId: 'sale-3',
        vendorId: 'v1',
        vendorName: 'Asha Juma',
        businessDate: _day20,
        recordedAt: DateTime.utc(2026, 10, 20, 9),
        amount: 4500,
        voided: true),
    OfficeSale(
        saleId: 'sale-4',
        vendorId: 'v2',
        vendorName: 'Baraka Ally',
        businessDate: _day21,
        recordedAt: DateTime.utc(2026, 10, 21, 10),
        amount: 9500),
  ])
  ..damageList.add(OfficeDamageReport(
      id: 'd1',
      vendorName: 'Asha Juma',
      productName: 'Kuku mzima',
      unit: 'bird',
      quantity: 2,
      reason: 'burnt',
      note: 'Moto mkali',
      reportedAt: DateTime.utc(2026, 10, 20, 12)))
  ..closingList.addAll([
    OfficeClosingCount(
        id: 'c1',
        vendorName: 'Asha Juma',
        businessDate: _day20,
        countedLines: const [OfficeCountedLine(name: 'Kuku mzima', counted: 4)],
        unverifiedSales: 3,
        pendingDamage: 1),
    OfficeClosingCount(
        id: 'c2',
        vendorName: 'Baraka Ally',
        businessDate: _day21,
        countedLines: const [OfficeCountedLine(name: 'Kidali', counted: 8)]),
  ])
  ..confirmedLines['c2'] = const [
    OfficeClosingLine(name: 'Kidali', expected: 10, counted: 8, difference: -2)
  ]
  ..exceptionList.add(OfficeException(
      id: 'x1',
      kind: 'stock_difference',
      vendorName: 'Asha Juma',
      productName: 'Kidali',
      openedAt: DateTime.utc(2026, 10, 20, 18)));

Future<TestApp> openAs(WidgetTester tester, VerificationOffice office,
    {List<String> roles = const ['supervisor'],
    String? route,
    Size size = const Size(390, 844),
    double textScale = 1,
    List<Override> overrides = const []}) async {
  office.owner = StaffProfile(
      id: 'st1', name: 'Neema Said', phone: '+255713000111', roles: roles);
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut,
      office: office,
      size: size,
      textScale: textScale,
      overrides: overrides);
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

/// Scrolls the page until [finder] is on screen, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(MNButton, label);
Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

void main() {
  testWidgets('the queue lists each station and what waits there',
      (tester) async {
    final app = await openAs(tester, verificationOffice(),
        route: MNRoutes.officeVerification);
    expect(find.text('Uthibitisho'), findsWidgets);
    expect(find.text('Kariakoo'), findsOneWidget);
    expect(find.text('Mauzo 3 · TSh 21,000'), findsOneWidget);
    expect(find.text('Vimeharibika: 1'), findsOneWidget);
    expect(find.text('Funga Siku: 2'), findsOneWidget);
    expect(find.text('Matatizo: 1'), findsOneWidget);
    expect(find.text('Tangu 20 Okt 2026'), findsOneWidget);
    expect(find.text('Sinza'), findsOneWidget);
    expect(find.text('Hakuna kinachosubiri'), findsOneWidget);
    await tester.tap(find.text('Kariakoo'));
    await tester.pumpAndSettle();
    final station = tester.widget<OfficeVerificationStationScreen>(
        find.byType(OfficeVerificationStationScreen));
    expect(station.stationId, 's1');
    expect(find.text('Kariakoo'), findsOneWidget); // The page title.
    expect(app.router.canPop(), isTrue);
  });

  testWidgets('verifying sends exactly the selected server ids after a summary',
      (tester) async {
    final office = verificationOffice();
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    // The voided sale is shown but has no checkbox.
    expect(find.text('Yamebatilishwa · hayathibitishwi'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(tester.widget<MNButton>(_button('Thibitisha')).onPressed, isNull);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    // Each sale row now carries Omba kubatilisha (MN034), so the third may need scrolling to.
    await tester.ensureVisible(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Umechagua mauzo 2 · TSh 18,500'), findsOneWidget);
    await tapVisible(tester, _button('Thibitisha'));
    expect(find.text('Thibitisha mauzo 2 ya jumla ya TSh 18,500?'),
        findsOneWidget);
    expect(office.verifyCalls, isEmpty); // Nothing sent before confirming.
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    expect(office.verifyCalls, [
      ['sale-1', 'sale-4']
    ]);
    expect(find.text('Mauzo 2 yamethibitishwa na ofisi.'), findsOneWidget);
    expect(find.text('Baraka Ally'), findsNothing);
  });

  testWidgets('select all takes the vendor-day without the voided sale',
      (tester) async {
    final office = verificationOffice();
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.text('Chagua zote').first);
    await tester.pumpAndSettle();
    expect(find.text('Ondoa zote'), findsOneWidget);
    expect(find.text('Umechagua mauzo 2 · TSh 11,500'), findsOneWidget);
    await tapVisible(tester, _button('Thibitisha'));
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    expect(office.verifyCalls, [
      ['sale-1', 'sale-2']
    ]);
  });

  testWidgets('a sale expands to its lines', (tester) async {
    await openAs(tester, verificationOffice(),
        route: MNRoutes.officeVerificationStation('s1'));
    expect(find.text('1 × Kuku mzima · TSh 9,000'), findsNothing);
    await tester.tap(find.text('10:15 · Taslimu'));
    await tester.pumpAndSettle();
    expect(find.text('1 × Kuku mzima · TSh 9,000'), findsOneWidget);
  });

  testWidgets('a refusal is localized and nothing was verified',
      (tester) async {
    final office = verificationOffice()
      ..refuseVerify = const OfficeError(
          OfficeErrorKind.refused, 'A voided sale is not verified.');
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();
    await tapVisible(tester, _button('Thibitisha'));
    await tester.tap(find.text('Ndiyo, thibitisha'));
    await tester.pumpAndSettle();
    expect(office.verifyCalls, hasLength(1));
    expect(
        find.text('Mauzo yaliyobatilishwa hayawezi kuthibitishwa. '
            'Hakuna mauzo ya kundi hili yaliyothibitishwa.'),
        findsOneWidget);
    expect(find.textContaining('yamethibitishwa na ofisi'), findsNothing);
    expect(office.salesList.where((s) => s.verified), isEmpty);
    // The list was refreshed and the selection cleared.
    expect(find.text('Chagua mauzo ya kuthibitisha.'), findsOneWidget);
  });

  test('more than 500 sales go in batches and stop at the first refusal',
      () async {
    final ids = [for (var i = 0; i < 1200; i++) 'id$i'];
    final batches = <int>[];
    expect(
        await verifyInBatches((b) async {
          batches.add(b.length);
          return b;
        }, ids),
        1200);
    expect(batches, [500, 500, 200]);
    var calls = 0;
    await expectLater(
        verifyInBatches((b) async {
          if (++calls == 2) {
            throw const OfficeError(OfficeErrorKind.refused, 'no');
          }
          return b;
        }, ids),
        throwsA(isA<VerifyBatchRefused>()
            .having((e) => e.verifiedBefore, 'verified before', 500)));
    expect(calls, 2);
  });

  testWidgets('rejecting damage needs a reason; approving explains the loss',
      (tester) async {
    final office = verificationOffice();
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.text('Vimeharibika'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kama hasara iliyothibitishwa'), findsNothing);
    await openOfficeHelp(tester);
    expect(find.textContaining('kama hasara iliyothibitishwa'), findsOneWidget);
    Navigator.of(tester.element(find.byType(MNSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.text('2 Kuku'), findsOneWidget);
    expect(find.text('Sababu: Imeungua'), findsOneWidget);
    expect(find.text('Maelezo: Moto mkali'), findsOneWidget);

    await tapVisible(tester, _button('Kubali hasara'));
    expect(
        find.text('Ukikubali, Kuku mzima (2 Kuku) itaondolewa kwenye stock '
            'kama hasara iliyothibitishwa.'),
        findsOneWidget);
    Navigator.of(tester.element(find.byType(MNSheet))).pop();
    await tester.pumpAndSettle();

    await tapVisible(tester, _button('Kataa'));
    await tester.tap(_inSheet(_button('Kataa')));
    await tester.pumpAndSettle();
    expect(find.text('Andika sababu ya herufi 3 hadi 500.'), findsOneWidget);
    expect(office.decisions, isEmpty);
    await tester.enterText(_inSheet(find.byType(TextField)), 'Si hasara');
    await tester.tap(_inSheet(_button('Kataa')));
    await tester.pumpAndSettle();
    expect(office.decisions, ['d1 approve=false reason=Si hasara']);
    expect(find.text('Uamuzi umehifadhiwa ofisini.'), findsOneWidget);
    expect(
        find.text('Hakuna ripoti za uharibifu zinazosubiri'), findsOneWidget);
  });

  testWidgets('a closing count is confirmable only without blockers',
      (tester) async {
    final office = verificationOffice();
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.text('Funga Siku'));
    await tester.pumpAndSettle();
    expect(
        find.text('Huwezi kuthibitisha bado: mauzo 3 hayajathibitishwa, '
            'ripoti 1 ya uharibifu inasubiri'),
        findsOneWidget);
    // Before confirmation only the vendor's count exists.
    expect(find.text('Kuku mzima · 4'), findsOneWidget);
    final buttons = _button('Thibitisha hesabu');
    expect(buttons, findsNWidgets(2));
    expect(tester.widget<MNButton>(buttons.at(0)).onPressed, isNull);
    expect(tester.widget<MNButton>(buttons.at(1)).onPressed, isNotNull);
    expect(find.text('Imethibitishwa na ofisi.'), findsNothing);
    await tapVisible(tester, buttons.at(1));
    expect(office.confirms, ['c2']);
    expect(find.text('Imethibitishwa na ofisi.'), findsOneWidget);
    expect(find.textContaining('Tofauti −2'), findsOneWidget);
    expect(buttons, findsOneWidget);
  });

  testWidgets('a refused confirmation shows a localized reason',
      (tester) async {
    final office = verificationOffice();
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.text('Funga Siku'));
    await tester.pumpAndSettle();
    // The screen shows c2 as clear; meanwhile the server got a new sale.
    office.closingList[1] = OfficeClosingCount(
        id: 'c2',
        vendorName: 'Baraka Ally',
        businessDate: _day21,
        unverifiedSales: 2);
    await tapVisible(tester, _button('Thibitisha hesabu').at(1));
    expect(find.text('Kuna mauzo au ripoti za uharibifu zinazosubiri.'),
        findsOneWidget);
    expect(find.text('Imethibitishwa na ofisi.'), findsNothing);
    // Refreshed from the server: the new blocker is shown and the button off.
    expect(find.textContaining('mauzo 2 hayajathibitishwa'), findsOneWidget);
    expect(
        tester.widget<MNButton>(_button('Thibitisha hesabu').at(1)).onPressed,
        isNull);
  });

  testWidgets('finance verifies sales but is not offered stock decisions',
      (tester) async {
    await openAs(tester, verificationOffice(),
        roles: const ['finance'],
        route: MNRoutes.officeVerificationStation('s1'));
    expect(find.byType(Checkbox), findsNWidgets(3));
    for (final section in ['Vimeharibika', 'Funga Siku']) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(find.text('Kazi hii hufanywa na msimamizi au mmiliki.'),
          findsOneWidget);
      expect(_button('Kataa'), findsNothing);
      expect(_button('Thibitisha hesabu'), findsNothing);
    }
  });

  testWidgets('problems show open and resolved tabs with a detail view',
      (tester) async {
    await openAs(tester, verificationOffice(),
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.text('Matatizo'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeVerificationProblemsScreen), findsOneWidget);
    expect(find.text('Tofauti ya stock'), findsOneWidget);
    expect(find.text('Tahadhari'), findsOneWidget);
    expect(find.byType(MNButton), findsNothing);
    expect(find.text('Yaliyo wazi (1)'), findsOneWidget);
    expect(find.text('Yaliyotatuliwa'), findsOneWidget);

    await tester.tap(find.text('Tofauti ya stock'));
    await tester.pumpAndSettle();
    expect(find.text('Maelezo ya tatizo'), findsOneWidget);
    expect(find.text('Historia'), findsOneWidget);
  });

  testWidgets('a station difference with no vendor says who answers for it',
      (tester) async {
    final office = verificationOffice()
      ..exceptionList.add(OfficeException(
          id: 'x2',
          kind: 'stock_difference',
          stationName: 'Kituo cha Mikocheni',
          openedAt: DateTime.utc(2026, 10, 21, 18)));
    await openAs(tester, office,
        route: MNRoutes.officeVerificationStation('s1'));
    await tester.tap(find.text('Matatizo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tofauti ya stock').last);
    await tester.pumpAndSettle();
    const line =
        'Tofauti ya kituo: msimamizi anakagua. Hakuna muuzaji anayedaiwa moja kwa moja.';
    expect(find.text(line), findsOneWidget);
    expect(find.text('Kituo cha Mikocheni'), findsOneWidget);
  });

  testWidgets(
      'missing-price exceptions group by receipt and show cost guidance',
      (tester) async {
    final openedAt = DateTime.utc(2026, 10, 28, 12, 21);
    final office = verificationOffice()
      ..exceptionList.addAll([
        for (final (id, name) in [
          ('price-1', 'Vichwa na miguu'),
          ('price-2', 'Mshikaki wa Firigisi'),
          ('price-3', 'Kuku mzima'),
        ])
          OfficeException(
              id: id,
              kind: 'missing_agreed_price',
              stationId: 's1',
              vendorId: 'v1',
              vendorName: 'Maternus Joshua',
              productName: name,
              openedAt: openedAt),
      ]);
    await openAs(tester, office,
        roles: [StaffRole.owner],
        route: MNRoutes.officeVerificationProblems('s1'));

    expect(find.text('Bei ya makubaliano haipo · 3'), findsOneWidget);
    expect(find.text('Vichwa na miguu'), findsNothing);
    await tester.tap(find.text('Bei ya makubaliano haipo · 3'));
    await tester.pumpAndSettle();
    expect(find.text('Vichwa na miguu'), findsOneWidget);
    await tester.tap(find.text('Mshikaki wa Firigisi'));
    await tester.pumpAndSettle();
    expect(find.text('Hujitatua yenyewe'), findsOneWidget);
    expect(find.text('Weka gharama ya kawaida'), findsOneWidget);
    expect(find.text('Historia'), findsOneWidget);
  });

  testWidgets('resolved problems show the decision and history',
      (tester) async {
    final office = verificationOffice()
      ..exceptionList.add(OfficeException(
          id: 'price-resolved',
          kind: 'missing_agreed_price',
          status: 'resolved',
          vendorName: 'Maternus Joshua',
          productName: 'Kuku mzima',
          openedAt: DateTime.utc(2026, 10, 28, 12, 21),
          resolvedAt: DateTime.utc(2026, 10, 29, 9),
          resolution: 'standard_cost_set',
          resolutionReason:
              'Standard cost set for KUKU; missing agreed price closed automatically.'));
    await openAs(tester, office,
        route: MNRoutes.officeVerificationProblems('s1'));
    await tester.tap(find.text('Yaliyotatuliwa'));
    await tester.pumpAndSettle();
    expect(find.text('Bei ya makubaliano haipo'), findsOneWidget);
    await tester.tap(find.text('Bei ya makubaliano haipo'));
    await tester.pumpAndSettle();
    expect(find.text('Gharama ya kawaida imewekwa'), findsOneWidget);
    expect(find.text('Hujitatua yenyewe'), findsOneWidget);
    expect(
        find.text(
            'Standard cost set for KUKU; missing agreed price closed automatically.'),
        findsWidgets);
  });

  testWidgets('long lists show ten rows, then Zaidi', (tester) async {
    final office = verificationOffice()..verificationList.clear();
    for (var i = 0; i < 12; i++) {
      office.verificationList.add(OfficeVerificationStation(
          id: 'q$i', code: 'Q$i', name: 'Kituo $i', pendingSales: 1));
    }
    await openAs(tester, office, route: MNRoutes.officeVerification);
    expect(find.text('Kituo 11', skipOffstage: false), findsNothing);
    await tapVisible(tester, _button('Zaidi'));
    expect(find.text('Kituo 11', skipOffstage: false), findsOneWidget);
    expect(_button('Zaidi'), findsNothing);
  });

  group('home entry', () {
    testWidgets('a supervisor sees Uthibitisho and opens the queue',
        (tester) async {
      await openAs(tester, verificationOffice());
      await tapVisible(tester, find.text('Uthibitisho'));
      expect(find.byType(OfficeVerificationScreen), findsOneWidget);
      expect(find.text('Kariakoo'), findsOneWidget);
    });

    testWidgets('the owner sees it on Muhtasari', (tester) async {
      await openAs(tester, verificationOffice(),
          roles: const ['business_owner']);
      expect(find.text('Uthibitisho'), findsOneWidget);
    });

    testWidgets('an operations admin without a verifying role does not',
        (tester) async {
      await openAs(tester, verificationOffice(),
          roles: const ['operations_admin']);
      expect(find.text('Wauzaji'), findsOneWidget);
      expect(find.text('Uthibitisho'), findsNothing);
    });

    testWidgets('kitchen staff do not', (tester) async {
      await openAs(tester, verificationOffice(),
          roles: const ['kitchen_staff']);
      expect(find.text('Uthibitisho'), findsNothing);
    });
  });

  testWidgets('verification screens fit 320 px at 2× text', (tester) async {
    final app = await openAs(tester, verificationOffice(),
        size: const Size(320, 568), textScale: 2);
    for (final route in [
      MNRoutes.officeVerification,
      MNRoutes.officeVerificationStation('s1'),
      MNRoutes.officeVerificationProblems('s1'),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    app.router.go(MNRoutes.officeVerificationStation('s1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:15 · Taslimu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final section in ['Vimeharibika', 'Funga Siku']) {
      await tester.ensureVisible(find.text(section));
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: section);
    }
    await tester.tap(find.text('Vimeharibika'));
    await tester.pumpAndSettle();
    await tapVisible(tester, _button('Kataa'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the queue and station screens meet the tap-target guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    final app = await openAs(tester, verificationOffice(),
        route: MNRoutes.officeVerification);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    app.router.push(MNRoutes.officeVerificationStation('s1'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.bySemanticsLabel('Chagua mauzo ya 10:15, TSh 9,000'),
        findsOneWidget);
    handle.dispose();
  });

  group('HTTP', () {
    test('verification calls use the contract paths and map refusals',
        () async {
      final requests = <RequestOptions>[];
      final store = InMemoryStore();
      await store.write('office_access_token', 'staff-token');
      final dio = Dio()
        ..httpClientAdapter = _Adapter((o) {
          requests.add(o);
          return switch ('${o.method} ${o.uri.path}') {
            'GET /api/v1/staff/verification' => (
                200,
                [
                  {
                    'station': {'id': 's1', 'code': 'KA01', 'name': 'Kariakoo'},
                    'pending_sales': 2,
                    'pending_sales_amount': 11500,
                    'reported_damage': 0,
                    'recorded_closings': 1,
                    'open_exceptions': 0,
                    'oldest_pending_date': '2026-10-20'
                  },
                  {'station': null},
                ]
              ),
            'GET /api/v1/staff/sales' => (
                200,
                [
                  {
                    'sale_id': 'srv-1',
                    'id': 'client-1',
                    'vendor_id': 'v1',
                    'vendor_name': 'Asha',
                    'business_date': '2026-10-20',
                    'recorded_at': '2026-10-20T07:15:00+00:00',
                    'payment': 'cash',
                    'amount': 9000,
                    'status': 'reported',
                    'voided': false,
                    'lines': [
                      {
                        'product_code': 'KUKU',
                        'name': 'Kuku',
                        'quantity': 1,
                        'unit_price': 9000,
                        'amount': 9000
                      }
                    ]
                  }
                ]
              ),
            'POST /api/v1/staff/sales/verify' => (
                409,
                {'error': 'refused', 'detail': 'A voided sale is not verified.'}
              ),
            'GET /api/v1/staff/closing-counts' => (
                200,
                [
                  {
                    'id': 'c1',
                    'vendor_name': 'Asha',
                    'business_date': '2026-10-20',
                    'status': 'recorded',
                    'lines': [],
                    'counted_lines': [
                      {'product_id': 'p', 'name': 'Kuku', 'counted': 4}
                    ],
                    'blockers': {'unverified_sales': 2, 'pending_damage': 0}
                  }
                ]
              ),
            'POST /api/v1/staff/closing-counts/c1/confirm' => (
                403,
                {'error': 'forbidden'}
              ),
            'POST /api/v1/staff/damage-reports/d1/decision' => (
                200,
                {'id': 'd1', 'product_name': 'Kuku', 'status': 'rejected'}
              ),
            'GET /api/v1/staff/exceptions' => (200, []),
            'GET /api/v1/staff/damage-reports' => (200, []),
            _ => (404, {'error': 'not_found'}),
          };
        });
      final repo =
          HttpOfficeRepository(baseUrl: 'https://x', store: store, dio: dio);

      final queue = await repo.verificationQueue();
      expect(queue.first.name, 'Kariakoo');
      expect(queue.first.pendingSalesAmount, 11500);
      expect(queue.first.oldestPendingDate, DateTime.utc(2026, 10, 20));
      expect(queue.last.pendingSales, 0); // A malformed row still parses.

      final sales = await repo.stationSales('s1', status: 'reported');
      expect(sales.single.saleId, 'srv-1');
      expect(sales.single.clientId, 'client-1');
      expect(sales.single.lines.single.unitPrice, 9000);
      expect(requests.last.uri.queryParameters,
          {'station_id': 's1', 'status': 'reported'});

      await expectLater(
          repo.verifySales(['srv-1']),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.refused)
              .having((e) => e.detail, 'detail',
                  'A voided sale is not verified.')));
      expect(requests.last.data, {
        'sale_ids': ['srv-1']
      });

      final closing = (await repo.closingCounts(stationId: 's1')).single;
      expect(closing.lines, isEmpty);
      expect(closing.countedLines.single.counted, 4);
      expect(closing.unverifiedSales, 2);
      expect(closing.blocked, isTrue);
      expect(requests.last.uri.queryParameters,
          {'status': 'recorded', 'station_id': 's1'});

      await expectLater(
          repo.confirmClosing('c1'),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.forbidden)));

      final decided =
          await repo.decideDamage('d1', approve: false, reason: 'Si hasara');
      expect(decided.status, 'rejected');
      expect(requests.last.data, {'approve': false, 'reason': 'Si hasara'});

      expect(await repo.exceptions(stationId: 's1'), isEmpty);
      expect(await repo.damageReports(stationId: 's1'), isEmpty);
      expect(requests.last.uri.queryParameters,
          {'status': 'reported', 'station_id': 's1'});
      expect(
          requests
              .every((r) => r.headers['Authorization'] == 'Bearer staff-token'),
          isTrue);
    });
  });

  group('automatic verification', () {
    const sw = Strings('sw');
    const reasons = [
      'mpesa',
      'credit_not_allowed',
      'credit_over_limit',
      'oversold',
      'stale_price',
      'late',
      'possible_duplicate',
      'over_amount',
      'clock_skew',
      'sampled',
      'needs_approval',
      'day_locked',
    ];

    OfficeSale sale(String id,
            {String status = 'reported',
            String? method,
            OfficeAutoCheck? check,
            int amount = 5000}) =>
        OfficeSale(
            saleId: id,
            vendorId: 'v1',
            vendorName: 'Asha Juma',
            businessDate: _day20,
            recordedAt: DateTime.utc(2026, 10, 20, 7, 15),
            payment: 'cash',
            amount: amount,
            status: status,
            verificationMethod: method,
            autoCheck: check,
            product: id);

    testWidgets('a held sale shows why, in Swahili, for every reason code',
        (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..salesList.addAll([
          sale('normal'),
          for (final code in reasons)
            sale('held-$code',
                check: OfficeAutoCheck(
                    mode: 'live', result: 'held', reasons: [code])),
        ]);
      await openAs(tester, office,
          route: MNRoutes.officeVerificationStation('s1'),
          size: const Size(390, 4000));
      // Held sales come first: the first page is all held, and the normal one
      // waits behind Zaidi.
      expect(find.text('normal'), findsNothing);
      await tapVisible(tester, _button(sw.moreRows));
      expect(find.text('normal'), findsOneWidget);
      expect(tester.getTopLeft(find.text('held-mpesa')).dy,
          lessThan(tester.getTopLeft(find.text('normal')).dy));
      final known = <String>{};
      for (final code in reasons) {
        final text = sw.autoHoldReason(code);
        expect(known.add(text), isTrue,
            reason: 'each reason reads differently');
        expect(text, isNot(sw.autoHoldReason('something_new')));
        expect(find.text(text), findsOneWidget, reason: code);
      }
      expect(find.text(sw.autoHeldLabel), findsNWidgets(reasons.length));
    });

    testWidgets('a shadow check is never shown as held', (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..salesList.add(sale('shadow-1',
            check: const OfficeAutoCheck(
                mode: 'shadow', result: 'held', reasons: ['mpesa'])));
      await openAs(tester, office,
          route: MNRoutes.officeVerificationStation('s1'));
      expect(find.text('shadow-1'), findsOneWidget);
      expect(find.text(sw.autoHeldLabel), findsNothing);
      expect(find.text(sw.autoHoldReason('mpesa')), findsNothing);
    });

    testWidgets('auto-verified sales are labelled and listed apart',
        (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..salesList.add(sale('waiting'))
        ..automatic.add(sale('auto-1', status: 'verified', method: 'auto'));
      await openAs(tester, office,
          route: MNRoutes.officeVerificationStation('s1'),
          size: const Size(390, 1600));
      expect(find.text('auto-1'), findsNothing);
      await tapVisible(tester, find.text(sw.autoVerifiedFilter));
      expect(office.autoLoads, 1);
      expect(find.text('auto-1'), findsOneWidget);
      expect(find.text(sw.autoVerifiedLabel), findsOneWidget);
      // A supervisor reads them; only the owner corrects.
      expect(_button(sw.correctSale), findsNothing);
      await tapVisible(tester, find.text(sw.autoVerifiedFilter));
      expect(find.text('auto-1'), findsNothing);
    });

    testWidgets('the queue says how many went through and were held',
        (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..verificationList.add(const OfficeVerificationStation(
            id: 's1',
            code: 'KA01',
            name: 'Kariakoo',
            pendingSales: 1,
            pendingSalesAmount: 1000,
            autoVerifiedToday: 4,
            heldToday: 1));
      await openAs(tester, office, route: MNRoutes.officeVerification);
      expect(find.text(sw.autoQueueLine(4, 1)), findsOneWidget);
    });

    testWidgets('the owner can correct an auto-verified sale', (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..automatic.add(sale('auto-1', status: 'verified', method: 'auto'));
      await openAs(tester, office,
          roles: const ['business_owner'],
          route: MNRoutes.officeVerificationStation('s1'),
          size: const Size(390, 1600));
      await tapVisible(tester, find.text(sw.autoVerifiedFilter));
      await tapVisible(tester, _button(sw.correctSale));
      await tester.enterText(
          _inSheet(find.byType(TextField)), 'Mauzo ya makosa');
      await tester.tap(_inSheet(_button(sw.correctSale)));
      await tester.pumpAndSettle();
      expect(office.corrected, ['auto-1 Mauzo ya makosa']);
      expect(find.text(sw.correctSaleDone), findsOneWidget);
    });

    Future<void> choose(
        WidgetTester tester, String label, String option) async {
      await tapVisible(tester, find.widgetWithText(MNFieldButton, label));
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    Future<void> openSettings(WidgetTester tester, AutoOffice office,
        {List<String> roles = const ['business_owner']}) async {
      await openAs(tester, office,
          roles: roles,
          route: MNRoutes.officeMoneySettings,
          size: const Size(390, 1800));
      await tapVisible(tester, find.text(sw.autoVerifyTitle));
    }

    const complete = OfficeAutoVerifySetting(
        mode: 'off',
        stationIds: ['s1'],
        runTime: '21:30',
        lateHours: 12,
        duplicateWindowMinutes: 3,
        maxSaleAmount: 200000,
        samplePercent: 5,
        acceptStalePrice: false);

    testWidgets('the setting saves shadow and live, and off stops new runs',
        (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..moneySettingsValue = const OfficeMoneySettings(autoVerify: complete);
      await openSettings(tester, office);
      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('shadow'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect(office.settingWrites.last['key'], 'sales.auto_verify');
      expect(office.settingWrites.last['value'], {
        'mode': 'shadow',
        'station_ids': ['s1'],
        'run_time': '21:30',
        'late_hours': 12,
        'duplicate_window_minutes': 3,
        'max_sale_amount': 200000,
        'sample_percent': 5,
        'accept_stale_price': false,
      });

      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('live'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      // Live moves stock and money, so it asks first.
      expect(find.text(sw.autoVerifyLiveConfirmTitle), findsOneWidget);
      expect(find.text(sw.autoVerifyLiveConfirmBody), findsOneWidget);
      expect(sw.autoVerifyLiveConfirmBody, contains('kabla ya'));
      await tester.tap(find.text(sw.yesConfirm));
      await tester.pumpAndSettle();
      expect((office.settingWrites.last['value'] as Map)['mode'], 'live');

      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('off'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect((office.settingWrites.last['value'] as Map)['mode'], 'off');
      expect(office.settingWrites.length, 3);
    });

    testWidgets('off always saves, even with a field cleared', (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..moneySettingsValue = const OfficeMoneySettings(
            autoVerify: OfficeAutoVerifySetting(
                mode: 'live',
                stationIds: ['s1'],
                runTime: '21:30',
                lateHours: 12,
                duplicateWindowMinutes: 3,
                maxSaleAmount: 200000,
                samplePercent: 5,
                acceptStalePrice: false));
      await openSettings(tester, office);
      final late = find.descendant(
          of: find.widgetWithText(MNTextField, sw.autoVerifyLateHours),
          matching: find.byType(TextField));
      await tester.ensureVisible(late);
      await tester.enterText(late, '');
      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('off'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect(find.text(sw.autoVerifyIncomplete), findsNothing);
      expect(office.settingWrites.single['value'], {'mode': 'off'});
    });

    test('the help says the clock never closes today', () {
      expect(sw.autoVerifyHelp, contains('siku zilizopita'));
      expect(
          sw.autoVerifyHelp, isNot(contains('saa uliyoweka kwa siku zisizo')));
    });

    testWidgets('nothing is prefilled, and a part is never saved',
        (tester) async {
      final office = AutoOffice()..signedIn = true;
      await openSettings(tester, office);
      for (final label in [
        sw.autoVerifyLateHours,
        sw.autoVerifyDuplicateMinutes,
        sw.autoVerifyMaxAmount,
        sw.autoVerifySamplePercent,
      ]) {
        final field = tester.widget<TextField>(find.descendant(
            of: find.widgetWithText(MNTextField, label),
            matching: find.byType(TextField)));
        expect(field.controller!.text, isEmpty, reason: label);
      }
      expect(find.text(sw.autoVerifyNotSet), findsWidgets);
      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('shadow'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect(find.text(sw.autoVerifyIncomplete), findsOneWidget);
      expect(office.settingWrites, isEmpty);
      // Off needs no values at all.
      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('off'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect(office.settingWrites.single['value'], {'mode': 'off'});
    });

    testWidgets('a refused save keeps its retry', (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..moneySettingsValue = const OfficeMoneySettings(autoVerify: complete)
        ..refuseSave = const OfficeError(OfficeErrorKind.refused, 'Hapana');
      await openSettings(tester, office);
      await choose(tester, sw.autoVerifyMode, sw.autoVerifyModeName('shadow'));
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect(office.settingWrites, isEmpty);
      expect(find.text(sw.serverRefused('Hapana')), findsOneWidget);
      await tapVisible(tester, _button(sw.autoVerifySave));
      expect(office.settingWrites.length, 1);
    });

    testWidgets('the shadow summary is the owner\'s evidence', (tester) async {
      final office = AutoOffice()
        ..signedIn = true
        ..moneySettingsValue = const OfficeMoneySettings(autoVerify: complete)
        ..summary = const OfficeShadowSummary(
            checked: 12,
            wouldPass: 9,
            wouldHold: 3,
            heldByReason: {'mpesa': 2, 'late': 1},
            staffVerifiedWouldHold: 1,
            unchecked: 4);
      await openSettings(tester, office);
      expect(find.text(sw.autoSummaryWouldPass(9)), findsOneWidget);
      expect(find.text(sw.autoSummaryWouldHold(3)), findsOneWidget);
      expect(find.text(sw.autoSummaryReason(sw.autoHoldReason('mpesa'), 2)),
          findsOneWidget);
      expect(find.text(sw.autoSummaryStaffWouldHold(1)), findsOneWidget);
      expect(find.text(sw.autoSummaryUnchecked(4)), findsOneWidget);
      expect(OfficeShadowSummary.fromJson({'unchecked': 2}).unchecked, 2);
      expect(sw.autoSummaryUnchecked(4), contains('4'));
      final loaded = office.summaryRequests.length;
      await tapVisible(tester, find.text(sw.autoSummaryEarlierWeek));
      expect(office.summaryRequests.length, loaded + 1);
      expect(office.summaryRequests.last.$1,
          isNot(office.summaryRequests.first.$1));
    });

    testWidgets('only the owner sees the settings', (tester) async {
      final office = AutoOffice()..signedIn = true;
      await openAs(tester, office,
          roles: const ['supervisor'], route: MNRoutes.officeMoneySettings);
      expect(find.text(sw.autoVerifyTitle), findsNothing);
      expect(find.text(sw.notAllowed), findsOneWidget);
    });
  });
}

/// The office with automatic verification's calls.
class AutoOffice extends VerificationOffice
    implements OfficeAutoVerifyRepository, OwnerBonusesRepository {
  final automatic = <OfficeSale>[];
  final corrected = <String>[];
  final summaryRequests = <(String, String)>[];
  int autoLoads = 0;
  OfficeError? refuseSave;
  OfficeShadowSummary summary = const OfficeShadowSummary();

  @override
  Future<List<OfficeSale>> autoVerifiedSales(String stationId) async {
    autoLoads++;
    return automatic;
  }

  @override
  Future<OfficeShadowSummary> autoVerifySummary(
      {required String from, required String to}) async {
    summaryRequests.add((from, to));
    return summary;
  }

  @override
  Future<void> correctSale(String saleId, {required String reason}) async {
    corrected.add('$saleId $reason');
  }

  @override
  Future<OwnerBonusPeriod> bonuses(
          {required String period, String? date}) async =>
      const OwnerBonusPeriod();

  @override
  Future<OwnerVendorBonus> vendorBonus(String vendorId,
          {required String period, String? date}) =>
      throw UnimplementedError();

  @override
  Future<OwnerPerformanceSettings> performanceSettings() async =>
      const OwnerPerformanceSettings();

  @override
  Future<void> saveSetting(String key,
      {required Object value, required String reason}) async {
    if (refuseSave case final e?) {
      refuseSave = null;
      throw e;
    }
    settingWrites.add({'key': key, 'value': value, 'reason': reason});
    moneySettingsValue = OfficeMoneySettings(
        autoVerify: OfficeAutoVerifySetting.fromJson(value));
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
