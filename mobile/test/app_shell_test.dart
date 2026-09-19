import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/shared/widgets/supply_art.dart';

// AppShell is pumped directly (as preview_test.dart does for its screens)
// rather than through the real router: booting the router waits on the
// splash's asset-precache step, which never resolves under flutter test.
Widget host(String path, Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
    child: MaterialApp(
        theme: omoterraTheme(), home: AppShell(path: path, child: child)));

void main() {
  testWidgets('the logo sits at the left of the top nav, not centered',
      (tester) async {
    await tester.pumpWidget(host('/buyer', const SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    final logoBox = tester.getTopLeft(find.byType(BrandMark));
    final shellBox = tester.getTopLeft(find.byType(AppShell));
    // Left-aligned means the logo starts near the shell's own left edge
    // (after the row's padding), not floating out in the middle of the
    // header the way Expanded(child: BrandMark(...)) used to center it.
    expect(logoBox.dx, lessThan(shellBox.dx + 40));
  });

  testWidgets('the role pill offers the other role without leaving Home',
      (tester) async {
    await tester.pumpWidget(host('/buyer', const SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('BUYER'), findsOneWidget);
    await tester.tap(find.text('BUYER'));
    await tester.pumpAndSettle();
    expect(find.text('Supplier'), findsOneWidget,
        reason: 'the popup menu should offer Supplier right there, instead '
            'of only via Account');
  });

  testWidgets('the shell shows supplier chrome once on a supplier route',
      (tester) async {
    await tester.pumpWidget(host('/supplier', const SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('SUPPLIER'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget,
        reason: 'the bottom tabs switch to the supplier set');
  });
}
