import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/features/authentication/splash_screen.dart';
import 'package:mr_nyama_vendor/shared/widgets/logo.dart';

class PendingSession extends SessionController {
  final Completer<AuthState> result;
  PendingSession(this.result);
  @override
  Future<AuthState> build() => result.future;
}

class ReadyOffice extends OfficeSessionController {
  @override
  Future<OfficeAuth> build() async => const OfficeSignedOut();
}

void main() {
  testWidgets('small phone shows original full logo and only real pending work',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = Completer<AuthState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => PendingSession(result)),
        officeSessionProvider.overrideWith(ReadyOffice.new),
      ],
      child: const MaterialApp(home: SplashScreen()),
    ));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<MNLogo>(find.byType(MNLogo)).full, isTrue);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black);
    await tester.pump(const Duration(milliseconds: 301));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    result.complete(const SignedOut());
    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion shows branding without animated progress',
      (tester) async {
    final result = Completer<AuthState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => PendingSession(result)),
        officeSessionProvider.overrideWith(ReadyOffice.new),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const SplashScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1);
    await tester.pumpWidget(const SizedBox());
    result.complete(const SignedOut());
  });
}
