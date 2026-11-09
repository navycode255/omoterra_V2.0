import 'package:mr_nyama_vendor/shared/widgets/account.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';

import 'helpers.dart';

Future<void> recordSale(TestApp app, String id) =>
    app.container.read(salesStoreProvider).saveSale(SaleDraft(
            clientId: id,
            vendorId: 'v1',
            stationKey: 'S1',
            recordedAt: DateTime.now(),
            payment: PaymentMethod.cash,
            lines: const [
              DraftLine(
                  productId: 'kuku',
                  productName: 'Kuku mzima',
                  quantity: 1,
                  unitPrice: 9000)
            ]));

void main() {
  testWidgets('saving an operation starts a sync by itself', (tester) async {
    final api = FakeVendorRepository()..syncFailure = null;
    final app = await pumpApp(tester, api: api);
    await recordSale(app, 's1');
    await tester.pumpAndSettle();
    expect(api.syncedBatches.single.single.opId, 's1');
    expect(find.bySemanticsLabel('Imetumwa ofisini'), findsWidgets);
  });

  testWidgets('offline, then the network returns: it syncs without a dialog',
      (tester) async {
    final network = StreamController<bool>();
    addTearDown(network.close);
    final api = FakeVendorRepository()
      ..syncFailure = const AuthFailure(AuthFailureKind.offline);
    final app = await pumpApp(tester, api: api, connectivity: network.stream);
    network.add(false);
    for (final id in ['s1', 's2', 's3']) {
      await recordSale(app, id);
    }
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Inasubiri kusawazisha'), findsWidgets);
    expect(find.byType(Dialog), findsNothing);
    expect(
        tester
            .widget<MNSyncIndicator>(find.byType(MNSyncIndicator))
            .pendingCount,
        3);
    await tester.tap(find.byType(MNSyncIndicator));
    await tester.pumpAndSettle();
    expect(find.text('Usawazishaji'), findsOneWidget);

    api.syncFailure = null;
    // Back-off would hold a timed retry; connectivity asks again now, and
    // the engine still respects back-off, so move past it.
    await app.db.customStatement('UPDATE outbox SET next_attempt_at = NULL');
    network.add(true);
    await tester.pumpAndSettle();
    expect((await app.db.select(app.db.outbox).get()).map((op) => op.status),
        everyElement('synchronized'));
    await tester.pumpAndSettle();
    expect(tester.widget<MNSyncIndicator>(find.byType(MNSyncIndicator)).status,
        MNSyncStatus.sent);
    expect(find.bySemanticsLabel('Imetumwa ofisini'), findsWidgets);
  });

  testWidgets('resuming the app asks for a sync', (tester) async {
    final api = FakeVendorRepository();
    final app = await pumpApp(tester, api: api);
    await recordSale(app, 's1');
    await tester.pumpAndSettle();
    final before = api.calls.where((c) => c.startsWith('sync')).length;
    await app.db.customStatement('UPDATE outbox SET next_attempt_at = NULL');
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c.startsWith('sync')).length,
        greaterThan(before));
  });

  testWidgets('the sync screen explains what needs review', (tester) async {
    final api = FakeVendorRepository()
      ..syncFailure = null
      ..syncDecision = (op) =>
          OperationResult(op.opId, OperationOutcome.rejected, 'invalid');
    final app = await pumpApp(tester, api: api);
    await recordSale(app, 's1');
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.sync);
    await tester.pumpAndSettle();
    expect(find.byType(MNSyncIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Inahitaji ukaguzi'), findsWidgets);
    expect(find.text('Mauzo'), findsOneWidget);
    expect(
        find.textContaining('Ofisi haikukubali kumbukumbu hii. Haihesabiwi. '
            'Mwambie msimamizi wako.'),
        findsOneWidget);
    expect(find.textContaining('ofisi itakagua'), findsNothing);
  });

  testWidgets('a record under office review is asked about again',
      (tester) async {
    var decision = OperationOutcome.conflict;
    String reason = 'not_assigned';
    final api = FakeVendorRepository()
      ..syncFailure = null
      ..syncDecision = (op) => op.opId == 's1'
          ? OperationResult(op.opId, decision, reason)
          : OperationResult(op.opId, OperationOutcome.accepted, 'accepted');
    final app = await pumpApp(tester, api: api);
    Future<String> status() async => (await app.db.select(app.db.outbox).get())
        .singleWhere((o) => o.opId == 's1')
        .status;
    await recordSale(app, 's1');
    await tester.pumpAndSettle();
    expect(await status(), 'conflict');

    // Within the hour an ordinary sync does not ask again.
    await recordSale(app, 's2');
    await tester.pumpAndSettle();
    expect(api.syncedBatches.last.map((o) => o.opId), ['s2']);

    app.router.push(MNRoutes.sync);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Inahitaji ukaguzi'), findsWidgets);

    // Offline: the record stays under review rather than "waiting".
    api.syncFailure = const AuthFailure(AuthFailureKind.offline);
    await tester.tap(find.text('Sawazisha sasa'));
    await tester.pumpAndSettle();
    expect(await status(), 'conflict');

    // The office retried it and the server accepted it.
    api.syncFailure = null;
    decision = OperationOutcome.duplicate;
    reason = 'accepted';
    await tester.tap(find.text('Sawazisha sasa'));
    await tester.pumpAndSettle();
    expect(api.syncedBatches.last.map((o) => o.opId), ['s1']);
    expect(await status(), 'synchronized');
    final sale = await (app.db.select(app.db.sales)
          ..where((s) => s.clientId.equals('s1')))
        .getSingle();
    expect(sale.syncStatus, 'sent');
    expect(find.text('Inahitaji ukaguzi'), findsNothing);
  });

  testWidgets('a record the office refused says so and asks no more',
      (tester) async {
    var decision = OperationOutcome.conflict;
    String reason = 'not_assigned';
    final api = FakeVendorRepository()
      ..syncFailure = null
      ..syncDecision = (op) => OperationResult(op.opId, decision, reason);
    final app = await pumpApp(tester, api: api);
    await recordSale(app, 's1');
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.sync);
    await tester.pumpAndSettle();
    decision = OperationOutcome.rejected;
    reason = 'office_rejected';
    await tester.tap(find.text('Sawazisha sasa'));
    await tester.pumpAndSettle();
    expect((await app.db.select(app.db.outbox).getSingle()).status, 'failed');
    expect(find.textContaining('Ofisi imekagua na kuikataa kumbukumbu hii.'),
        findsOneWidget);
    expect(find.textContaining('ofisi itakagua'), findsNothing);
    final batches = api.syncedBatches.length;
    await tester.tap(find.text('Sawazisha sasa'));
    await tester.pumpAndSettle();
    expect(api.syncedBatches, hasLength(batches)); // nothing left to ask
  });

  testWidgets('signing out with unsent records says so first', (tester) async {
    final app = await pumpApp(tester); // fake server: sync not available
    await recordSale(app, 's1');
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.profile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toka kwenye akaunti'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Kumbukumbu 1 bado hazijatumwa'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(MNAccountSignOutSheet),
        matching: find.text('Toka kwenye akaunti')));
    await tester.pumpAndSettle();
    // The record stays on the phone for the next sign-in.
    expect(await app.db.select(app.db.outbox).get(), hasLength(1));
  });
}
