import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/shared/widgets/components.dart';
import 'package:omoterra/shared/widgets/screen_error.dart';

const _offline = ApiFailure(
    'We could not reach Omoterra. Check your connection and retry. Your action is not confirmed.',
    FailureKind.offline);

/// Offline until [online] is set, like a phone that lost and regained data.
class _Flaky extends LocalRepository {
  bool online = false;
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    calls++;
    if (gate != null) await gate!.future;
    if (!online) throw _offline;
    return {'ok': true};
  }
}

class _Screen extends ConsumerWidget {
  const _Screen();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(resourceProvider('/buyer/home')).when(
          data: (_) => const Text('Loaded'),
          loading: () => const Text('Loading'),
          error: (_, __) => const Text('Failed'));
}

Future<ProviderContainer> _pump(WidgetTester tester, _Flaky repo,
    {Widget child = const _Screen()}) async {
  final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: ScreenErrorGate(child: child)))));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('Try again shows progress and brings the screen back once online',
      (tester) async {
    final repo = _Flaky();
    await _pump(tester, repo);
    expect(find.byType(ErrorState), findsOneWidget);

    repo.online = true;
    repo.gate = Completer<void>();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    // The card stays, with visible progress, while the request runs.
    expect(find.text('Trying again…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Loaded'), findsOneWidget);
  });

  testWidgets('Try again while still offline keeps the card and stops the spinner',
      (tester) async {
    final repo = _Flaky();
    await _pump(tester, repo);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('a failure whose screen is gone is cleared by Try again',
      (tester) async {
    final repo = _Flaky()..online = true;
    final container = await _pump(tester, repo, child: const Text('Content'));
    // Recorded by a screen that has since closed: nothing can reload it.
    container.read(resourceFailuresProvider.notifier).state = {
      '/orders': _offline
    };
    await tester.pump();
    expect(find.byType(ErrorState), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('the screen comes back by itself when the connection returns',
      (tester) async {
    final repo = _Flaky();
    await _pump(tester, repo);
    expect(find.byType(ErrorState), findsOneWidget);

    repo.online = true;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Loaded'), findsOneWidget);
  });

  testWidgets('a request that fails after its screen closed leaves no error',
      (tester) async {
    final repo = _Flaky()..gate = Completer<void>();
    final container = await _pump(tester, repo);
    // Leave the screen while its request is still waiting on the network.
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(body: ScreenErrorGate(child: Text('Elsewhere'))))));
    await tester.pump();
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(resourceFailuresProvider), isEmpty);
    expect(find.byType(ErrorState), findsNothing);
  });
}
