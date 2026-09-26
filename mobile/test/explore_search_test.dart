import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/buyer/explore_screen.dart';
import 'package:omoterra/features/buyer/request_supply_screen.dart';
import 'package:omoterra/shared/models/domain.dart';

SupplyListing _listing(int i) => SupplyListing(
    id: 'l$i',
    category: 'broilers',
    unitType: 'bird',
    region: 'Pwani',
    price: '10000',
    available: '10',
    specs: const {'breed_type': 'Kuroiler'});

/// Serves pages of [total] listings, or none for searches in [empty], and
/// records every request.
class _Server extends LocalRepository {
  final int total;
  final Set<String> empty;
  final calls = <Map<String, dynamic>>[];
  _Server({this.total = 3, this.empty = const {}});

  @override
  Future<ListingPage> listingPage(Map<String, dynamic> query,
      {String? cursor, int pageSize = listingPageSize}) async {
    calls.add({...query, if (cursor != null) 'cursor': cursor});
    if (empty.contains(query['q'])) return const ListingPage([]);
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, total);
    return ListingPage([for (var i = start; i < end; i++) _listing(i)],
        end < total ? '$end' : null);
  }
}

Future<void> _open(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/explore', routes: [
    GoRoute(
        path: '/explore',
        builder: (_, __) => const Scaffold(body: ExploreScreen())),
    GoRoute(
        path: '/request',
        builder: (_, s) => RequestSupplyScreen(
            search: s.uri.queryParameters['q'],
            category: s.uri.queryParameters['category'])),
  ]);
  await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(server)],
      child: MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing waits for a pause, then asks the server once',
      (tester) async {
    final server = _Server();
    await _open(tester, server);
    expect(server.calls, [{}]);
    final box = find.byType(TextField).first;
    for (final text in ['k', 'ku', 'kuk', 'kuku']) {
      await tester.enterText(box, text);
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(server.calls, hasLength(1), reason: 'nothing sent while typing');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
    expect(server.calls, hasLength(2));
    expect(server.calls.last, {'q': 'kuku'});
  });

  testWidgets('no results says so and offers a prefilled request',
      (tester) async {
    final server = _Server(empty: {'kuroiler'});
    await _open(tester, server);
    await tester.enterText(find.byType(TextField).first, 'kuroiler');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
    expect(find.text("No stock for 'kuroiler' right now"), findsOneWidget);
    expect(find.text('l0'), findsNothing);
    await tester.tap(find.text('Request Supply'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'kuroiler'), findsOneWidget);
  });

  testWidgets('scrolling near the end loads the next page', (tester) async {
    final server = _Server(total: 45);
    await _open(tester, server);
    expect(server.calls, hasLength(1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(server.calls.map((c) => c['cursor']), [null, '20', '40']);
    expect(find.byKey(const ValueKey('l44')), findsOneWidget);
  });

  test('a server from before paging still fills the feed', () async {
    FlutterSecureStorage.setMockInitialValues({'session': 'token'});
    final rows = await LocalRepository().read('/listings') as List;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
      ..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: rows))));
    final page = await ApiRepository(dio).listingPage({});
    expect(page.items, hasLength(rows.length));
    expect(page.nextCursor, isNull);
  });
}
