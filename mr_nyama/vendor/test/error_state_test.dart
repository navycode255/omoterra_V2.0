import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

Widget app(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('shows the illustration and no button', (tester) async {
    await tester.pumpWidget(app(MNErrorState(onRetry: () {})));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).imageProvider, isA<AssetImage>());
    expect(find.text('Imeshindikana'), findsOneWidget);
    expect(find.byType(MNButton), findsNothing);
  });

  group('no network', () {
    String asset(WidgetTester tester) =>
        ((tester.widget<Image>(find.byType(Image)).image as ResizeImage)
                .imageProvider as AssetImage)
            .assetName;

    testWidgets('no connection shows its own screen, over any message',
        (tester) async {
      await tester.pumpWidget(app(MNErrorState(
          message: 'imeshindwa',
          error: const AuthFailure(AuthFailureKind.offline),
          onRetry: () {})));
      expect(asset(tester), 'assets/errors/network_state.png');
      expect(find.text('Hakuna intaneti'), findsOneWidget);
      expect(find.text('Unganisha intaneti, kisha vuta chini kuonyesha upya.'),
          findsOneWidget);
      expect(find.text('imeshindwa'), findsNothing);
      expect(find.byType(MNButton), findsNothing);
    });

    testWidgets('a swipe retries it', (tester) async {
      var retried = 0;
      await tester.pumpWidget(app(MNErrorState(
          error: const AuthFailure(AuthFailureKind.offline),
          onRetry: () => retried++)));
      await tester.drag(find.text('Hakuna intaneti'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });

    for (final (name, error) in [
      (
        'a server that answers badly',
        const AuthFailure(AuthFailureKind.offline, serviceProblem: true)
      ),
      ('another failure', const AuthFailure(AuthFailureKind.sessionExpired)),
      ('an unknown error', StateError('x')),
    ]) {
      testWidgets('$name is not called no internet', (tester) async {
        await tester.pumpWidget(app(MNErrorState(error: error)));
        expect(asset(tester), 'assets/errors/error_state.png');
        expect(find.text('Imeshindikana'), findsOneWidget);
      });
    }

    testWidgets('MNAsyncView passes the error along', (tester) async {
      await tester.pumpWidget(app(MNAsyncView<int>(
          value: const AsyncError(
              AuthFailure(AuthFailureKind.offline), StackTrace.empty),
          data: (_) => const SizedBox())));
      expect(find.text('Hakuna intaneti'), findsOneWidget);
    });
  });

  testWidgets('with nothing to retry, a swipe does nothing', (tester) async {
    await tester.pumpWidget(app(const MNErrorState()));
    await tester.drag(find.text('Imeshindikana'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'in a page with nothing to refresh, one swipe retries every failed '
      'part and only the first shows', (tester) async {
    var first = 0, second = 0;
    late StateSetter set;
    var failing = true;
    await tester.pumpWidget(app(MNRefreshArea(
        child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: StatefulBuilder(builder: (context, setter) {
              set = setter;
              return Column(children: [
                if (failing) MNErrorState(onRetry: () => first++),
                MNErrorState(message: 'second', onRetry: () => second++),
              ]);
            })))));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('second'), findsNothing);
    await tester.drag(find.text('Imeshindikana'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect((first, second), (1, 1));
    // When the first recovers, the next failure shows.
    set(() => failing = false);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page refresh that fails stays quiet', (tester) async {
    await tester.pumpWidget(app(MNRefreshArea(
        onRefresh: () async => throw StateError('offline'),
        child: ListView(children: const [SizedBox(height: 900)]))));
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a large text size scrolls instead of overflowing',
      (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: Scaffold(body: MNErrorState(onRetry: () {})))));
    expect(tester.takeException(), isNull);
  });
}
