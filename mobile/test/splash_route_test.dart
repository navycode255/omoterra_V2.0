import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/authentication/screens.dart';

/// A repository whose /me never resolves, standing in for a session restore
/// still in flight.
class _Hanging extends LocalRepository {
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) =>
      Completer<dynamic>().future;
}

void main() {
  testWidgets('the splash is on screen while the session resolves',
      (tester) async {
    final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(_Hanging())]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            theme: omoterraTheme(),
            routerConfig: container.read(routerProvider))));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget,
        reason: 'a pending session must show the splash, not onboarding');
    expect(find.byType(WelcomeScreen), findsNothing);
  });
}
