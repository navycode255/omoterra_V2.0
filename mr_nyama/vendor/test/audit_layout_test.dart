import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mr_nyama_vendor/core/api/providers.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/features/authentication/pin_screens.dart';
import 'package:mr_nyama_vendor/features/authentication/splash_screen.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'history_flow_test.dart' show now, record, voidButton;
import 'helpers.dart';
import 'package:mr_nyama_vendor/features/history/history_screen.dart';
import 'receiving_flow_test.dart' show delivery;
import 'sync_flow_test.dart' show recordSale;

/// Phase 2.10 audit: the screens and overlays that `layout_test.dart` does
/// not reach (splash, suspended, PIN confirmation, sync, receipt saved, the
/// void sheet and dialog), at every phone size and text scale.
void main() {
  for (final MapEntry(key: name, value: size) in phoneSizes.entries) {
    for (final scale in textScales) {
      Future<void> tapText(WidgetTester tester, String text) async {
        await tester.ensureVisible(find.textContaining(text).last);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining(text).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: text);
      }

      testWidgets('splash and suspended fit at $name, text ×$scale',
          (tester) async {
        setScreen(tester, size: size, textScale: scale, reducedMotion: true);
        for (final screen in const [SplashScreen(), SuspendedScreen()]) {
          await tester.pumpWidget(ProviderScope(
              overrides: [
                keyValueStoreProvider.overrideWithValue(InMemoryStore())
              ],
              child: MaterialApp.router(
                  theme: mrNyamaTheme(),
                  routerConfig: GoRouter(routes: [
                    GoRoute(path: '/', builder: (_, __) => screen),
                  ]))));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$screen');
        }
      });

      testWidgets('PIN confirmation fits at $name, text ×$scale',
          (tester) async {
        final signedOut = await pumpApp(tester,
            size: size, textScale: scale, startAs: StartAs.signedOut);
        signedOut.router.go(MNRoutes.confirmPin);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'confirm PIN');
      });

      testWidgets('sync review fits at $name, text ×$scale', (tester) async {
        final api = FakeVendorRepository()
          ..syncFailure = null
          ..syncDecision = (op) =>
              OperationResult(op.opId, OperationOutcome.rejected, 'invalid');
        final app =
            await pumpApp(tester, size: size, textScale: scale, api: api);
        await recordSale(app, 's1');
        await tester.pumpAndSettle();
        app.router.push(MNRoutes.sync);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sync');
      });

      testWidgets('receipt saved fits at $name, text ×$scale', (tester) async {
        final app = await pumpApp(tester,
            size: size,
            textScale: scale,
            api: FakeVendorRepository()..deliveryList = [delivery()]);
        app.router.push(MNRoutes.receive);
        await tester.pumpAndSettle();
        await tapText(tester, 'OMT-2041');
        await tapText(tester, 'Pokea bidhaa');
        await tapText(tester, 'Hifadhi');
        await tapText(tester, 'Ndiyo, thibitisha');
        expect(app.router.state.uri.path, MNRoutes.receiptSaved('c1'));
      });

      testWidgets('stock list fits at $name, text ×$scale', (tester) async {
        final app = await pumpApp(tester,
            size: size,
            textScale: scale,
            initial: MNRoutes.products,
            api: FakeVendorRepository()..catalogSnapshot = testCatalog);
        await app.container
            .read(salesStoreProvider)
            .replaceCatalog(testCatalog);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'stock list');
      });

      testWidgets('void sheet and dialog fit at $name, text ×$scale',
          (tester) async {
        final app =
            await pumpApp(tester, size: size, textScale: scale, now: now);
        await record(app, '0f3c2a91-7d4e-4b8a-9c1d-2e5f6a7b8c9d',
            now.subtract(const Duration(minutes: 5)));
        app.router.push(MNRoutes.history);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(HistoryRow), 200,
            scrollable: find
                .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable))
                .first);
        await tester.tap(find.textContaining('Kuku mzima').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(voidButton());
        await tester.pumpAndSettle();
        await tester.tap(voidButton());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'reason sheet');
        await tapText(tester, 'Idadi si sahihi');
        await tapText(tester, 'Endelea');
        await tapText(tester, 'Ndiyo, batilisha');
        expect(tester.takeException(), isNull, reason: 'voided detail');
      });
    }
  }
}
