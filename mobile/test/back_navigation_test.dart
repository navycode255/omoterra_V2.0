import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/routing/animated_route.dart';
import 'package:omoterra/core/routing/back_navigation.dart';
import 'package:omoterra/shared/widgets/components.dart';

Widget page(String name) => Scaffold(
    appBar: OmoterraAppBar(title: Text(name)), body: Text('page $name'));

class _Steps extends StatefulWidget {
  const _Steps();
  @override
  State<_Steps> createState() => _StepsState();
}

class _StepsState extends State<_Steps> with StepBackHistory {
  int step = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        Text('step $step'),
        TextButton(
            onPressed: () {
              setState(() => step++);
              pushStep(() => step--);
            },
            child: const Text('next')),
      ]));
}

GoRouter testRouter(String initial) =>
    GoRouter(initialLocation: initial, routes: [
      ShellRoute(
          // Mirrors AppShell, which guards the shell page.
          builder: (_, state, child) =>
              RouteBackGuard(path: state.uri.path, child: child),
          routes: [
            omoterraRoute(
                path: '/supplier',
                animate: false,
                builder: (_, __) => page('home')),
            omoterraRoute(
                path: '/stock',
                animate: false,
                builder: (_, __) => page('stock')),
          ]),
      omoterraRoute(path: '/stock/new', builder: (_, __) => const _Steps()),
      omoterraRoute(
          path: '/stock/:id',
          builder: (_, s) => page('detail ${s.pathParameters['id']}')),
    ]);

Future<List<MethodCall>> pressBack(WidgetTester tester) async {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    calls.add(call);
    return null;
  });
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
  return calls.where((c) => c.method == 'SystemNavigator.pop').toList();
}

void main() {
  test('every page steps up to a parent; only homes may exit', () {
    expect(backFallback('/supplier'), isNull);
    expect(backFallback('/buyer'), isNull);
    expect(backFallback('/stock'), '/supplier');
    expect(backFallback('/stock/new'), '/stock');
    expect(backFallback('/stock/abc'), '/stock');
    expect(backFallback('/stock/abc/correct'), '/stock/abc');
    expect(backFallback('/batches/new'), '/stock');
    expect(backFallback('/supplier-orders/9'), '/supplier-orders');
    expect(backFallback('/payouts'), '/supplier');
    expect(backFallback('/listing/4'), '/explore');
    expect(backFallback('/checkout/4'), '/listing/4');
    expect(backFallback('/order/2'), '/orders');
    expect(backFallback('/account'), '/');
    expect(backFallback('/account/edit'), '/account');
    expect(backFallback('/register-role/supplier'), '/account');
    expect(backFallback('/otp'), '/phone');
  });

  testWidgets(
      'system back from a page reached with go walks up to Home, then exits',
      (tester) async {
    final router = testRouter('/stock/42');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('page detail 42'), findsOneWidget);
    // Nothing to pop, but the page still offers a way back.
    expect(find.byType(BackChevron), findsOneWidget);

    expect(await pressBack(tester), isEmpty);
    expect(find.text('page stock'), findsOneWidget);

    expect(await pressBack(tester), isEmpty);
    expect(find.text('page home'), findsOneWidget);

    expect(await pressBack(tester), hasLength(1));
  });

  testWidgets('the back chevron on a lone page goes to its parent',
      (tester) async {
    final router = testRouter('/stock/42');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackChevron));
    await tester.pumpAndSettle();
    expect(find.text('page stock'), findsOneWidget);
  });

  testWidgets('system back steps back through a form before leaving it',
      (tester) async {
    final router = testRouter('/stock');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/stock/new');
    await tester.pumpAndSettle();
    await tester.tap(find.text('next'));
    await tester.pump();
    await tester.tap(find.text('next'));
    await tester.pump();
    expect(find.text('step 2'), findsOneWidget);

    expect(await pressBack(tester), isEmpty);
    expect(find.text('step 1'), findsOneWidget);
    expect(await pressBack(tester), isEmpty);
    expect(find.text('step 0'), findsOneWidget);
    expect(await pressBack(tester), isEmpty);
    expect(find.text('page stock'), findsOneWidget);
  });
}
