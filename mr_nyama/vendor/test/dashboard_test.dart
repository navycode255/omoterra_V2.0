import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/rows.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

import 'helpers.dart';

SaleSummary sale(String id, int hour, String product, int amount,
        {PaymentMethod payment = PaymentMethod.cash}) =>
    SaleSummary(
        id: id,
        recordedAt: DateTime(2026, 10, 7, hour, 5),
        product: product,
        quantity: 2,
        payment: payment,
        amount: amount);

void main() {
  testWidgets('shows the vendor, today\'s total and count from the server',
      (tester) async {
    final api = FakeVendorRepository()
      ..dashboardSummary = DashboardSummary(
          date: DateTime(2026, 10, 7),
          todayTotal: 245000,
          saleCount: 24,
          cashTotal: 200000,
          mpesaTotal: 45000,
          recent: [
            sale('a', 11, 'Paja (Robo)', 4000),
            sale('b', 10, 'Nusu kuku', 9000, payment: PaymentMethod.mpesa),
            sale('c', 9, 'Kuku mzima', 18000),
            sale('d', 8, 'Shingo (1)', 1000),
          ]);
    await pumpApp(tester, api: api);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('245,000'), findsOneWidget);
    expect(find.text('Miamala 24'), findsOneWidget);
    // Full server subtotals, not sums of the truncated recent-sales list.
    expect(find.text('200,000'), findsOneWidget);
    expect(find.text('45,000'), findsOneWidget);
    // Up to five recent sales, matching the dashboard reference.
    expect(find.byType(MNTransactionRow), findsNWidgets(4));
    expect(find.text('Shingo (1) × 2'), findsOneWidget);
    expect(find.text('M-Pesa ya Mr. Nyama'), findsOneWidget);
    expect(find.bySemanticsLabel('Imetumwa ofisini'), findsOneWidget);
  });

  testWidgets('no sales yet: zero total and one quiet line', (tester) async {
    await pumpApp(tester);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Miamala 0'), findsOneWidget);
    expect(find.text('Hakuna mauzo bado'), findsOneWidget);
    expect(find.byType(MNTransactionRow), findsNothing);
  });

  testWidgets('no M-Pesa number and no M-Pesa sales: no M-Pesa total',
      (tester) async {
    await pumpApp(tester,
        api: FakeVendorRepository()
          ..catalogSnapshot = CatalogSnapshot(products: testCatalog.products)
          ..dashboardSummary = DashboardSummary(
              date: DateTime(2026, 10, 7),
              todayTotal: 5000,
              saleCount: 1,
              cashTotal: 5000,
              mpesaTotal: 0,
              recent: [sale('a', 11, 'Paja (Robo)', 5000)]));
    await tester.pumpAndSettle();
    expect(find.text('Taslimu'), findsWidgets);
    expect(find.text('M-Pesa'), findsNothing);
  });

  testWidgets('loading shows placeholders, never a placeholder amount',
      (tester) async {
    final api = FakeVendorRepository()..gate = Completer();
    setScreen(tester, reducedMotion: true);
    await pumpApp(tester, api: api, reducedMotion: true);
    expect(find.byType(MNSkeleton), findsWidgets);
    expect(find.textContaining('TSh'), findsNothing);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('offline explains itself and shows no figures', (tester) async {
    final api = FakeVendorRepository()
      ..dashboardFailure = const AuthFailure(AuthFailureKind.offline);
    await pumpApp(tester, api: api);
    expect(
        find.text('Hakuna intaneti. Takwimu za leo zitaonekana ukiunganishwa.'),
        findsOneWidget);
    expect(find.textContaining('TSh'), findsNothing);
  });

  testWidgets('quick actions: Mauzo, Pokea Bidhaa, Vimeharibika, Funga siku',
      (tester) async {
    final app = await pumpApp(tester);
    for (final label in [
      'Rekodi mauzo',
      'Pokea bidhaa',
      'Vimeharibika',
      'Funga siku'
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await tester.tap(find.text('Funga siku'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.closeDay);
  });

  testWidgets('"Ona yote" opens the sales history', (tester) async {
    final app = await pumpApp(tester);
    await tester.ensureVisible(find.text('Ona yote'));
    await tester.tap(find.text('Ona yote'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.history);
  });

  testWidgets('profile: own details only, no company figures or admin',
      (tester) async {
    await pumpApp(tester, initial: MNRoutes.profile);
    expect(find.text('Asha Mussa'), findsOneWidget);
    expect(find.text('Kariakoo'), findsOneWidget);
    expect(find.text('+255 712 345 678'), findsOneWidget);
    for (final label in ['Badilisha PIN', 'Msaada', 'Toka kwenye akaunti']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final forbidden in ['Ripoti', 'Faida', 'Deni', 'Admin', 'Msimamizi']) {
      expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
    }
  });

  testWidgets('reduced motion: the dashboard settles with no animation',
      (tester) async {
    await pumpApp(tester, reducedMotion: true);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
