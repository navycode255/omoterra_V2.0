import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/buyer/screens.dart';

Map<String, dynamic> _request({String status = 'open', bool editable = true}) =>
    {
      'id': '514ca549-1111-2222-3333-444455556666',
      'category': 'broilers',
      'unit_type': 'bird',
      'quantity': '20',
      'status': status,
      'needed_by_date': '2026-09-27',
      'delivery_region': 'Dar es Salaam',
      'delivery_area': 'Kinondoni',
      'live_dressed_or_cut': 'live',
      'requirement_type': 'one_time',
      'secured_quantity': '0',
      'remaining_quantity': '20',
      'editable': editable,
    };

class _Repo extends LocalRepository {
  final List<Map<String, dynamic>> requests;
  String? path, method;
  Map<String, dynamic>? sent;
  _Repo({this.requests = const []});
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/orders') return const [];
    if (path == '/requests') return requests;
    if (path.startsWith('/requests/')) return requests.first;
    return super.read(path, query);
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    this.path = path;
    this.method = method;
    sent = data;
    return requests.first;
  }
}

Future<void> _pump(WidgetTester tester, _Repo repo, String location) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(
        path: '/orders',
        builder: (_, __) => const Scaffold(body: OrdersScreen())),
    GoRoute(
        path: '/requests/:id/edit',
        builder: (_, s) => RequestSupplyScreen(
            editId: s.pathParameters['id'],
            initial: s.extra! as Map<String, dynamic>)),
    GoRoute(
        path: '/requests/:id',
        builder: (_, s) => RequestDetail(s.pathParameters['id']!)),
  ]);
  await tester.pumpWidget(ProviderScope(overrides: [
    repositoryProvider.overrideWithValue(repo),
    stringsProvider.overrideWithValue(Strings('en')),
  ], child: MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an open request is not hidden behind the no-orders message',
      (tester) async {
    await _pump(tester, _Repo(requests: [_request()]), '/orders');
    expect(find.text('Request #514CA549'), findsOneWidget);
    expect(find.text('Broilers · 20 birds'), findsOneWidget);
    expect(find.text(Strings('en').noOrdersTitle), findsNothing);
  });

  testWidgets('the empty message shows when a tab has nothing at all',
      (tester) async {
    await _pump(
        tester, _Repo(requests: [_request(status: 'completed')]), '/orders');
    expect(find.text(Strings('en').noOrdersTitle), findsOneWidget);
    await tester.tap(find.text(Strings('en').past));
    await tester.pumpAndSettle();
    expect(find.text('Request #514CA549'), findsOneWidget);
  });

  testWidgets('detail shows progress and edits until supply is secured',
      (tester) async {
    final repo = _Repo(requests: [_request()]);
    await _pump(tester, repo, '/requests/514ca549');
    expect(find.text('We’re on it.'), findsOneWidget);
    expect(find.text('0 of 20 secured'), findsOneWidget);
    expect(find.text('27 Sep 2026'), findsOneWidget);

    await tester.tap(find.text('Edit request'));
    await tester.pumpAndSettle();
    expect(find.text('Update your request.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('request_quantity')), '35');
    await tester.tap(find.text('Next: Delivery Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repo.method, 'PUT');
    expect(repo.path, '/requests/514ca549');
    expect(repo.sent!['quantity'], '35');
    expect(repo.sent!['needed_by_date'], '2026-09-27');
    expect(repo.sent!['delivery_area'], 'Kinondoni');
    // Saved: back on the request itself, not on the form's first step.
    expect(find.text('Update your request.'), findsNothing);
    expect(find.text('Request details'), findsOneWidget);
  });

  testWidgets('no edit once Omoterra has started securing supply',
      (tester) async {
    await _pump(
        tester,
        _Repo(
            requests: [_request(status: 'partially_matched', editable: false)]),
        '/requests/514ca549');
    expect(find.text('Edit request'), findsNothing);
  });

  testWidgets('the info button explains what happens next in a dialog',
      (tester) async {
    await _pump(tester, _Repo(requests: [_request()]), '/requests/514ca549');
    await tester.tap(find.byTooltip('What happens next'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Omoterra will contact you'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the info button opens the explanation as a dialog',
      (tester) async {
    await _pump(tester, _Repo(requests: [_request()]), '/requests/514ca549');
    expect(find.textContaining('Omoterra will contact you'), findsNothing);
    await tester.tap(find.byTooltip('What happens next'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Omoterra will contact you'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
