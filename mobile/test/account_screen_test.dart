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
      // Deleting the account is never one tap away from Log out.
      expect(find.text('Delete account'), findsNothing);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('delete_account_link')), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Delete my account'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery location'));
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
      // Suppliers set their farm location; buyers their delivery location.
      expect(find.text('Delivery location'), findsNothing);
      expect(find.text('Farm location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
