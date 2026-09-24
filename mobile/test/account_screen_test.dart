import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/auth/session.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/account/screens.dart';

void main() {
  for (final width in [320.0, 420.0]) {
    testWidgets('account actions and layout at $width', (tester) async {
      tester.view.physicalSize = Size(width, 935);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({'session': 'test'});
      final state = ProviderContainer(overrides: [
        repositoryProvider.overrideWithValue(LocalRepository()),
      ]);
      addTearDown(state.dispose);
      await tester.runAsync(() => state.read(sessionProvider.future));
      final router = state.read(routerProvider);
      router.go('/account');
      await tester.pumpWidget(UncontrolledProviderScope(
          container: state,
          child: MaterialApp.router(
              theme: omoterraTheme(), routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('Preview Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved delivery address'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressesScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sell Supply'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(state.read(activeRoleProvider), 'supplier');
      expect(find.text('SUPPLIER'), findsOneWidget);
      expect(find.text('Saved delivery address'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
