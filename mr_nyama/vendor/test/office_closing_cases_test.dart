import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/closing_case_screens.dart';
import 'package:mr_nyama_vendor/features/office/product_screens.dart' show officeProductsProvider;
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

const sw = Strings('sw');

ClosingCase aCase(
        {String id = 'c1',
        String outcome = 'estimate',
        String status = 'open',
        bool mine = false,
        String? reason}) =>
    ClosingCase(
        id: id,
        stationId: 's1',
        businessDate: '2026-10-28',
        outcome: outcome,
        status: status,
        basis: 'Nimekagua daftari la mauzo.',
        openedBy: const CasePerson(id: 'u1', name: 'Juma'),
        decidedBy: status == 'open' || status == 'withdrawn'
            ? null
            : const CasePerson(id: 'u2', name: 'Neema'),
        decisionReason: reason,
        openedByMe: mine,
        lines: outcome == 'estimate'
            ? const [
                ClosingCaseLine(
                    productCode: 'kuku',
                    name: 'Kuku mzima',
                    unit: 'piece',
                    estimated: 4)
              ]
            : const []);

MissedDay aDay({ClosingCase? current, List<ClosingCase> history = const []}) =>
    MissedDay(
        stationId: 's1',
        stationName: 'Kariakoo',
        businessDate: '2026-10-28',
        vendors: const [MissedDayVendor(id: 'v1', name: 'Asha')],
        current: current,
        history: history);

class CasesOffice extends FakeOfficeRepository
    implements OfficeClosingCasesRepository {
  List<MissedDay> days = [];
  Object? loadError;
  Object? decideError;
  bool openFails = false;
  final opened = <Map<String, Object?>>[];
  final decisions = <String>[];

  @override
  Future<List<MissedDay>> missedDays({String? stationId}) async {
    if (loadError != null) throw loadError!;
    return List.of(days);
  }

  @override
  Future<ClosingCase> openClosingCase(
      {required String clientId,
      required String stationId,
      required String businessDate,
      required String outcome,
      required String basis,
      List<CaseLineDraft> lines = const []}) async {
    opened.add({
      'client': clientId,
      'outcome': outcome,
      'basis': basis,
      'lines': [for (final l in lines) '${l.product}:${l.estimated}'],
    });
    if (openFails) throw Exception('no answer');
    return aCase(outcome: outcome, mine: true);
  }

  @override
  Future<ClosingCase> decideClosingCase(String id,
      {required bool approve, required String reason}) async {
    if (decideError != null) throw decideError!;
    decisions.add('$id/$approve/$reason');
    return aCase(status: approve ? 'approved' : 'rejected');
  }
}

Future<(TestApp, CasesOffice)> officeApp(WidgetTester tester, String role,
    {String route = '/ofisi/uthibitisho/s1/siku-zisizofungwa',
    bool mine = false,
    bool withCase = true}) async {
  final office = CasesOffice()..signedIn = true;
  office.owner = StaffProfile(
      id: 'o1', name: 'Maternus', phone: '+255746484666', roles: [role]);
  final app = await pumpApp(tester, startAs: StartAs.signedOut, office: office);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  await tester.pumpAndSettle();
  office.days = [aDay(current: withCase ? aCase(mine: mine) : null)];
  app.router.push(route);
  await tester.pumpAndSettle();
  return (app, office);
}

void main() {
  testWidgets('a station with a missed day shows Siku zisizofungwa',
      (tester) async {
    final (app, _) = await officeApp(tester, StaffRole.supervisor,
        route: MNRoutes.officeVerificationStation('s1'));
    expect(find.text('Siku zisizofungwa'), findsOneWidget);
    await tester.tap(find.text('Siku zisizofungwa'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeClosingCases('s1'));
    expect(find.textContaining('Asha'), findsOneWidget);
    expect(find.textContaining('Inasubiri uamuzi'), findsOneWidget);
  });

  testWidgets('a station with no missed day shows no row', (tester) async {
    final office = CasesOffice()..signedIn = true;
    office.owner = const StaffProfile(
        id: 'o1',
        name: 'Maternus',
        phone: '+255746484666',
        roles: [StaffRole.supervisor]);
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeVerificationStation('s1'));
    await tester.pumpAndSettle();
    expect(find.text('Siku zisizofungwa'), findsNothing);
  });

  testWidgets('an estimate is labelled Makadirio, si hesabu halisi',
      (tester) async {
    await officeApp(tester, StaffRole.finance);
    await tester.tap(find.textContaining('Inasubiri uamuzi'));
    await tester.pumpAndSettle();
    expect(find.text('Makadirio'), findsOneWidget);
    expect(find.text('Makadirio, si hesabu halisi'), findsOneWidget);
    expect(find.textContaining('Kuku mzima: 4'), findsOneWidget);
  });

  testWidgets('the opener sees no approve button', (tester) async {
    // The owner may decide cases, but not one they opened themselves.
    await officeApp(tester, StaffRole.owner, mine: true);
    await tester.tap(find.textContaining('Inasubiri uamuzi'));
    await tester.pumpAndSettle();
    expect(find.text(sw.closingCaseOwnWaiting), findsOneWidget);
    expect(find.widgetWithText(MNButton, 'Kubali'), findsNothing);
    expect(find.widgetWithText(MNButton, 'Kataa'), findsNothing);
  });

  testWidgets('the owner decides a case somebody else opened', (tester) async {
    final (_, office) = await officeApp(tester, StaffRole.owner);
    await tester.tap(find.textContaining('Inasubiri uamuzi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Kubali'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nimeona ushahidi');
    await tester.pump();
    await tester.tap(find.widgetWithText(MNButton, 'Kubali').last);
    await tester.pumpAndSettle();
    expect(office.decisions, ['c1/true/Nimeona ushahidi']);
  });

  testWidgets('finance sees approve but no open button', (tester) async {
    final (app, office) = await officeApp(tester, StaffRole.finance);
    await tester.tap(find.textContaining('Inasubiri uamuzi'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MNButton, 'Kubali'), findsOneWidget);
    expect(find.widgetWithText(MNButton, 'Kataa'), findsOneWidget);
    expect(find.text('Fungua kesi'), findsNothing);
    // A day with no case: finance can open nothing.
    office.days = [aDay()];
    app.container.invalidate(closingCasesProvider('s1'));
    app.router.pop();
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeClosingCase('nje', stationId: 's1'),
        extra: '2026-10-28');
    await tester.pumpAndSettle();
    expect(find.text('Fungua kesi'), findsNothing);
  });

  testWidgets('approval shows the server refusal with pending counts',
      (tester) async {
    final (_, office) = await officeApp(tester, StaffRole.finance);
    office.decideError =
        const ClosingCaseBlocked(unverifiedSales: 2, pendingDamage: 1);
    await tester.tap(find.textContaining('Inasubiri uamuzi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Kubali'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nimeona ushahidi');
    await tester.pump();
    await tester.tap(find.widgetWithText(MNButton, 'Kubali').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('mauzo 2 hayajathibitishwa'), findsOneWidget);
    expect(find.textContaining('uharibifu 1 haujaamuliwa'), findsOneWidget);
    expect(office.decisions, isEmpty);
  });

  testWidgets('a supervisor opens an estimate; the confirm says it changes no stock',
      (tester) async {
    final (app, office) = await officeApp(tester, StaffRole.supervisor,
        withCase: false);
    await tester.tap(find.textContaining('Hakuna kesi bado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Fungua kesi'));
    await tester.pumpAndSettle();
    // Not ready: nothing chosen yet.
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Tuma kesi'))
            .onPressed,
        isNull);
    office.productsList.add(const OfficeProduct(
        code: 'KUKU-MZIMA',
        name: 'Kuku mzima',
        category: 'kuku',
        unit: 'piece'));
    app.container.invalidate(officeProductsProvider);
    await tester.tap(find.text('Chagua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makadirio').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nimekagua daftari.');
    await tester.pump();
    await tester.tap(find.widgetWithText(MNButton, 'Ongeza bidhaa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuku mzima').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Tuma kesi'));
    await tester.pumpAndSettle();
    expect(find.text(sw.closingCaseConfirmEstimate), findsOneWidget);
    await tester.tap(find.widgetWithText(MNButton, 'Tuma kesi').last);
    await tester.pumpAndSettle();
    expect(office.opened, hasLength(1));
    expect(office.opened.single['outcome'], 'estimate');
    expect(office.opened.single['lines'], ['KUKU-MZIMA:1']);
    // Back on the day, which now shows the sent case.
    expect(find.text(sw.closingCaseConfirmEstimate), findsNothing);
    expect(app.router.state.uri.path, '/ofisi/siku-zisizofungwa/nje');
  });

  testWidgets('a retry keeps the id only while the form is unchanged',
      (tester) async {
    final (_, office) =
        await officeApp(tester, StaffRole.supervisor, withCase: false);
    office.openFails = true;
    await tester.tap(find.textContaining('Hakuna kesi bado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Fungua kesi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chagua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haikuhesabiwa').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nimekagua daftari.');
    await tester.pump();
    Future<void> send() async {
      await tester.tap(find.widgetWithText(MNButton, 'Tuma kesi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MNButton, 'Tuma kesi').last);
      await tester.pumpAndSettle();
    }

    await send();
    await send();
    expect(office.opened[0]['client'], office.opened[1]['client']);
    await tester.enterText(
        find.byType(TextField).last, 'Nimekagua daftari na stoo.');
    await tester.pump();
    await send();
    expect(office.opened[2]['client'], isNot(office.opened[1]['client']));
  });

  testWidgets('a load error shows the error state, swipe to retry, no button',
      (tester) async {
    final (app, office) = await officeApp(tester, StaffRole.supervisor);
    office.loadError = Exception('offline');
    app.container.invalidate(closingCasesProvider('s1'));
    await tester.pumpAndSettle();
    expect(find.byType(MNErrorState), findsOneWidget);
    expect(find.byType(MNButton), findsNothing);
    office.loadError = null;
    app.container.invalidate(closingCasesProvider('s1'));
    await tester.pumpAndSettle();
    expect(find.byType(MNErrorState), findsNothing);
  });

  testWidgets('Stoo also has the Siku zisizofungwa row', (tester) async {
    await officeApp(tester, StaffRole.supervisor,
        route: MNRoutes.officeStock('s1'));
    expect(find.text('Siku zisizofungwa'), findsOneWidget);
  });
}
