import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/auth/session.dart';
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

  testWidgets('startup waits for resources before leaving the splash',
      (tester) async {
    // Config is part of the warmup, so a repository that never answers it
    // must keep the splash on screen rather than falling through.
    final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(_SlowConfig())]);
    addTearDown(container.dispose);

    SessionController.holdSplash = true;
    addTearDown(() => SessionController.holdSplash = false);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            theme: omoterraTheme(),
            routerConfig: container.read(routerProvider))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(SplashScreen), findsOneWidget,
        reason: 'pending startup resources must hold the splash');
    // Release the pending config and drain the floor timer. Asset decoding
    // does not complete under test, so settle by pumping a bounded number of
    // frames rather than waiting for a quiet tree.
    _SlowConfig.release();
    await tester.pump(const Duration(seconds: 1));
  });
}

/// Answers every read except /config, which stays pending until released.
class _SlowConfig extends LocalRepository {
  static Completer<dynamic> pending = Completer<dynamic>();
  static void release() {
    if (!pending.isCompleted) pending.complete(<String, dynamic>{});
    pending = Completer<dynamic>();
  }

  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) =>
      path == '/config' ? pending.future : super.read(path, query);
}
