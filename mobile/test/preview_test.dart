import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/buyer/screens.dart';
import 'package:omoterra/features/supplier/screens.dart';
import 'package:omoterra/core/api/repository.dart';

void main() {
  final repo = LocalRepository();

  test('preview serves a signed-in account and browsable supply', () async {
    expect((await repo.read('/me'))['name'], 'Preview Account');
    expect((await repo.listings({})).length, 4);
    expect((await repo.read('/listings') as List).length, 4);
    expect((await repo.read('/supplier/stock') as List).length, 2);
    expect((await repo.read('/addresses') as List).length, 1);
    expect(await repo.read('/orders'), isEmpty);
  });

  test('preview never lets a transaction appear to succeed', () async {
    for (final path in [
      '/reservations',
      '/orders',
      '/requests',
      '/business-opportunities',
      '/supplier/stock',
      '/addresses',
    ]) {
      expect(() => repo.write(path, {}), throwsA(isA<ApiFailure>()),
          reason: '$path must fail closed in preview mode');
    }
    expect(() => repo.uploadPhoto([1, 2, 3]), throwsA(isA<ApiFailure>()));
  });

  // Each screen is pumped against the preview repository so a layout error
  // like an unbounded Row fails here rather than rendering blank on a phone.
  Widget host(Widget child) => ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(LocalRepository())],
      child: MaterialApp(
          theme: omoterraTheme(), home: Scaffold(body: child)));

  testWidgets('buyer home lays out against preview data', (tester) async {
    await tester.pumpWidget(host(const BuyerHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Buy Supply'), findsOneWidget);
  });

  testWidgets('explore lays out against preview data', (tester) async {
    await tester.pumpWidget(host(const ExploreScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplier home lays out against preview data', (tester) async {
    await tester.pumpWidget(host(const SupplierHome()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  test('preview hides a supplier identity behind the approved alias',
      () async {
    final detail = await repo.read('/listings/local-broilers');
    expect(detail['supplier']['public_alias'], 'Lake Zone Poultry');
    expect(detail.toString(), isNot(contains('Preview Supplier Ltd')));
  });
}
