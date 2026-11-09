import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_approvals.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/approval_screens.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

const sw = Strings('sw');

class ApprovingOffice extends FakeOfficeRepository
    implements OfficeApprovalsRepository {
  final items = <ApprovalItem>[];
  final problems = <OfficeException>[];
  final decisions = <String>[];
  final resolved = <String>[];
  final saved = <String, Object?>{};
  Map<String, dynamic> settings = {};
  bool settles = true;

  @override
  Future<List<OfficeException>> exceptions(
          {String status = 'open', String? stationId}) async =>
      problems;
  @override
  Future<ResolveResult> resolveException(String id,
      {required String resolution, required String reason}) async {
    resolved.add('$id/$resolution/$reason');
    return ResolveResult(resolved: settles, tier: settles ? 0 : 1);
  }

  @override
  Future<List<ApprovalItem>> approvals() async => List.of(items);
  @override
  Future<void> decideApproval(String id,
      {required bool approve, required String reason}) async {
    decisions.add('$id/$approve/$reason');
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<AlertSettings> alertSettings() async => AlertSettings(settings);
  @override
  Future<void> saveAlertSetting(String key,
      {required Object? value, required String reason}) async {
    saved[key] = value;
    settings = {...settings, key: value};
  }
}

ApprovalItem item(String id, {bool canDecide = true, int? value = 2000}) =>
    ApprovalItem(
        id: id,
        kind: 'stock_difference',
        resolution: 'loss',
        reason: 'Vimeharibika',
        requestedBy: 'Asha',
        tier: 1,
        canDecide: canDecide,
        station: 'Kariakoo',
        value: value,
        countedValue: value);

Future<(TestApp, ApprovingOffice)> officeApp(WidgetTester tester, String route,
    {String role = StaffRole.owner}) async {
  final office = ApprovingOffice()..signedIn = true;
  office.owner = StaffProfile(
      id: 'o1', name: 'Maternus', phone: '+255746484666', roles: [role]);
  final app = await pumpApp(tester, startAs: StartAs.signedOut, office: office);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  await tester.pumpAndSettle();
  app.router.push(route);
  await tester.pumpAndSettle();
  return (app, office);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an approver decides with a reason', (tester) async {
    final (app, office) = await officeApp(tester, MNRoutes.officeApprovals);
    office.items.add(item('r1'));
    app.container.invalidate(approvalsProvider);
    await tester.pumpAndSettle();
    expect(find.text('TSh 2,000'), findsOneWidget);
    await tapText(tester, sw.approvalApprove);
    expect(office.decisions, isEmpty);
    await tester.enterText(find.byType(TextField).last, 'Nimeona ushahidi');
    await tester.pump();
    await tapText(tester, sw.approvalApprove);
    expect(office.decisions, ['r1/true/Nimeona ushahidi']);
    expect(find.text(sw.approvalsEmpty), findsOneWidget);
  });

  testWidgets('the asker sees their request waiting, with no buttons',
      (tester) async {
    final (app, office) = await officeApp(tester, MNRoutes.officeApprovals);
    office.items.add(item('r1', canDecide: false, value: null));
    app.container.invalidate(approvalsProvider);
    await tester.pumpAndSettle();
    expect(find.text(sw.approvalWaiting), findsOneWidget);
    expect(find.text(sw.approvalValueUnknown), findsOneWidget);
    expect(find.text(sw.approvalApprove), findsNothing);
  });

  for (final (settles, message) in [
    (true, sw.problemResolved),
    (false, sw.problemSentForApproval),
  ]) {
    testWidgets('resolving a problem says what happened: $message',
        (tester) async {
      final office = ApprovingOffice()
        ..signedIn = true
        ..settles = settles
        ..problems.add(const OfficeException(
            id: 'e1',
            kind: 'stock_difference',
            stationId: 's1',
            resolutions: ['loss', 'count_correction']));
      final app =
          await pumpApp(tester, startAs: StartAs.signedOut, office: office);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(office.owner);
      await tester.pumpAndSettle();
      app.router.push(MNRoutes.officeVerificationProblems('s1'));
      await tester.pumpAndSettle();
      await tapText(tester, sw.problemKind('stock_difference'));
      await tapText(tester, sw.problemResolve);
      await tapText(tester, sw.selectPlaceholder);
      await tapText(tester, sw.resolutionName('loss'));
      await tester.enterText(find.byType(TextField).last, 'Vimeungua');
      await tester.pump();
      await tapText(tester, sw.problemResolve);
      expect(office.resolved, ['e1/loss/Vimeungua']);
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('a late entry needs a note and can be resolved', (tester) async {
    final office = ApprovingOffice()
      ..signedIn = true
      ..problems.add(const OfficeException(
          id: 'late-1',
          kind: 'late_entry',
          stationId: 's1',
          resolutions: ['reviewed']));
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeVerificationProblems('s1'));
    await tester.pumpAndSettle();
    await tapText(tester, sw.problemKind('late_entry'));

    expect(find.text('0/140'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'x' * 160);
    await tester.pump();
    expect(find.text('140/140'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).last, 'Mauzo ya jana yameandikwa');
    await tester.pump();
    await tapText(tester, sw.problemResolve);

    expect(office.resolved, ['late-1/reviewed/Mauzo ya jana yameandikwa']);
    expect(find.text(sw.problemResolved), findsOneWidget);
  });

  testWidgets('a problem with its own screen offers no general resolve',
      (tester) async {
    final office = ApprovingOffice()
      ..signedIn = true
      ..problems.add(const OfficeException(id: 'e1', kind: 'damage_reported'));
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeVerificationProblems('s1'));
    await tester.pumpAndSettle();
    expect(find.text(sw.problemResolve), findsNothing);
  });

  testWidgets('the owner sees every setting unset, and can switch texts on',
      (tester) async {
    final (_, office) = await officeApp(tester, MNRoutes.officeAlertSettings);
    expect(find.text(sw.limitSupervisor), findsOneWidget);
    expect(find.text(sw.notSet), findsWidgets);
    expect(office.saved, isEmpty);
    final toggle = find.byType(Switch);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(office.saved[AlertSettings.supervisorSms], true);
  });

  testWidgets('a set alert time can be cleared', (tester) async {
    final office = ApprovingOffice()
      ..signedIn = true
      ..settings = {AlertSettings.closingDue: '19:30'};
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeAlertSettings);
    await tester.pumpAndSettle();
    await tapText(tester, sw.alertClosingDue);
    await tapText(tester, sw.settingClear);
    expect(office.saved.containsKey(AlertSettings.closingDue), isTrue);
    expect(office.saved[AlertSettings.closingDue], isNull);
  });

  testWidgets('only the owner reaches the settings', (tester) async {
    await officeApp(tester, MNRoutes.officeAlertSettings,
        role: StaffRole.supervisor);
    expect(find.text(sw.notAllowed), findsOneWidget);
    expect(find.text(sw.limitSupervisor), findsNothing);
  });

  testWidgets('a supervisor finds Idhini on their account page',
      (tester) async {
    final (app, _) = await officeApp(tester, MNRoutes.officeApprovals,
        role: StaffRole.supervisor);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.text(sw.approvalsTitle), findsOneWidget);
    expect(find.text(sw.alertSettingsTitle), findsNothing);
  });
}
