import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/auth/session.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'session': 'test-token'});
  });

  ProviderContainer container() => ProviderContainer(overrides: [
        repositoryProvider.overrideWithValue(LocalRepository()),
      ]);

  test('explicit supplier selection survives session refresh and app restart',
      () async {
    final first = container();
    await first.read(sessionProvider.future);
    await first.read(sessionProvider.notifier).switchRole('supplier');
    expect(first.read(activeRoleProvider), 'supplier');
    first.invalidate(sessionProvider);
    await first.read(sessionProvider.future);
    expect(first.read(activeRoleProvider), 'supplier');
    first.dispose();

    final restarted = container();
    addTearDown(restarted.dispose);
    await restarted.read(sessionProvider.future);
    expect(restarted.read(activeRoleProvider), 'supplier');
    await restarted.read(sessionProvider.notifier).switchRole('buyer');
    restarted.invalidate(sessionProvider);
    await restarted.read(sessionProvider.future);
    expect(restarted.read(activeRoleProvider), 'buyer');
  });

  test('roles are account scoped and unavailable saved roles are ignored',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'session': 'token',
      'active_role:another-user': 'supplier',
    });
    final state = container();
    addTearDown(state.dispose);
    await state.read(sessionProvider.future);
    expect(state.read(activeRoleProvider), 'buyer');
    expect(preferredRole(['supplier'], 'buyer'), 'supplier');
    expect(preferredRole(['buyer'], 'supplier'), 'buyer');
  });

  test('supplier selection prevents buyer URLs even on a dual-role account',
      () {
    for (final path in ['/buyer', '/explore', '/orders', '/checkout/1', '/']) {
      expect(
          routeGuard(path,
              signedIn: true,
              setup: true,
              roles: ['buyer', 'supplier'],
              activeRole: 'supplier'),
          '/supplier');
    }
    for (final path in [
      '/supplier',
      '/supplier-demand',
      '/sales',
      '/account'
    ]) {
      expect(
          routeGuard(path,
              signedIn: true,
              setup: true,
              roles: ['buyer', 'supplier'],
              activeRole: 'supplier'),
          isNull);
    }
  });

  testWidgets('restored supplier stays on supplier home until dropdown switch',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'session': 'token',
      'active_role:local-user': 'supplier',
    });
    final state = container();
    addTearDown(state.dispose);
    await tester.runAsync(() => state.read(sessionProvider.future));
    final router = state.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: state,
        child:
            MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/supplier');
    router.go('/buyer');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/supplier');
    await tester.tap(find.text('SUPPLIER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buyer'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/buyer');
    expect(await storage.read(key: 'active_role:local-user'), 'buyer');
  });
}
