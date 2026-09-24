import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/routing/animated_route.dart';
import 'package:omoterra/core/theme/theme.dart';

const detailsKey = ValueKey('details-page');

GoRouter testRouter({VoidCallback? onLayout}) => GoRouter(routes: [
      omoterraRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      omoterraRoute(
          path: '/details',
          builder: (_, __) => _LayoutProbe(
              onLayout: onLayout ?? () {},
              child: const Scaffold(
                  key: detailsKey, body: Center(child: Text('Details'))))),
    ]);

void main() {
  testWidgets(
      'paint-only reveal keeps page geometry fixed and reverses in 200ms',
      (tester) async {
    final router = testRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: omoterraTheme(), routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/details');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final details = find.byKey(detailsKey);
    final transition =
        find.ancestor(of: details, matching: find.byType(ClipRect));
    expect(transition, findsOneWidget);
    final route = ModalRoute.of(tester.element(details))! as PageRoute;
    expect(route.transitionDuration, const Duration(milliseconds: 280));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 200));

    final fullSize = tester.getSize(find.byType(Navigator).first);
    final clip = tester.widget<ClipRect>(transition).clipper!.getClip(fullSize);
    expect(tester.getSize(details), fullSize,
        reason: 'The page layout must not compress during its reveal.');
    expect(clip.height, greaterThan(0));
    expect(clip.height, lessThan(fullSize.height));
    expect(tester.getBottomLeft(transition).dy, fullSize.height);
    expect(
        (1 -
            tester.widget<ClipRect>(transition).clipper!.getClip(fullSize).top /
                fullSize.height),
        closeTo(Curves.fastLinearToSlowEaseIn.transform(route.animation!.value),
            .00001));
    expect(find.ancestor(of: details, matching: find.byType(ScaleTransition)),
        findsNothing);
    expect(find.ancestor(of: details, matching: find.byType(FadeTransition)),
        findsNothing);

    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(details, findsOneWidget);
    expect(
        (1 -
            tester.widget<ClipRect>(transition).clipper!.getClip(fullSize).top /
                fullSize.height),
        closeTo(
            Curves.fastOutSlowIn.transform(route.animation!.value), .00001));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(details, findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('reveal frames do not relayout the page', (tester) async {
    var layouts = 0;
    final router = testRouter(onLayout: () => layouts++);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: omoterraTheme(), routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/details');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(layouts, greaterThan(0));
    layouts = 0;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(layouts, 0,
        reason: 'Animation must only update the clip, not page layout.');
    await tester.pumpAndSettle();
  });

  testWidgets('rapid tab changes replace content without overlapping routes',
      (tester) async {
    final router = GoRouter(initialLocation: '/one', routes: [
      ShellRoute(builder: (_, __, child) => Scaffold(body: child), routes: [
        for (final name in ['one', 'two', 'three'])
          omoterraRoute(
              path: '/$name',
              animate: false,
              builder: (_, __) => Center(child: Text('Tab $name'))),
      ]),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    for (final name in ['two', 'three', 'one', 'three']) {
      router.go('/$name');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Tab $name'), findsOneWidget);
      for (final other
          in ['one', 'two', 'three'].where((other) => other != name)) {
        expect(find.text('Tab $other'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reduced motion shows the complete page without a reveal',
      (tester) async {
    final router = testRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: omoterraTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
    ));
    await tester.pumpAndSettle();
    router.push('/details');
    await tester.pumpAndSettle();
    final details = find.byKey(detailsKey);
    final route = ModalRoute.of(tester.element(details))! as PageRoute;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(find.ancestor(of: details, matching: find.byType(ClipRect)),
        findsNothing);
  });
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  final VoidCallback onLayout;
  const _LayoutProbe({required this.onLayout, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LayoutCounter(onLayout);
}

class _LayoutCounter extends RenderProxyBox {
  final VoidCallback onLayout;
  _LayoutCounter(this.onLayout);
  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}
