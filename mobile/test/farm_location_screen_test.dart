import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/account/farm_location_screen.dart';

class _Supplier extends LocalRepository {
  String? path, method;
  Map<String, dynamic>? sent;
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async =>
      path == '/supplier/profile'
          ? {
              'farm_latitude': '-6.781234',
              'farm_longitude': '38.912345',
              'farm_map_url':
                  'https://www.google.com/maps/search/?api=1&query=-6.781234,38.912345',
              'internal_pickup_address': 'Maili Moja farm road',
            }
          : super.read(path, query);
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    this.path = path;
    this.method = method;
    sent = data;
    return {};
  }
}

void main() {
  testWidgets('the saved pin and directions load and save to the farm setting',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Supplier();
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            theme: omoterraTheme(), home: const FarmLocationScreen())));
    await tester.pumpAndSettle();
    expect(find.text('-6.781234, 38.912345'), findsOneWidget);
    expect(find.text('Maili Moja farm road'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('farm_pickup')), 'Maili Moja, past the school');
    await tester.tap(find.text('Save farm location'));
    await tester.pumpAndSettle();
    expect(repo.path, '/supplier/farm-location');
    expect(repo.method, 'PUT');
    expect(repo.sent!['farm_latitude'], '-6.781234');
    expect(
        repo.sent!['internal_pickup_address'], 'Maili Moja, past the school');
  });
}
