import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/account/notifications_screen.dart';

class _InboxRepository extends LocalRepository {
  final writes = <(String, Map<String, dynamic>)>[];
  bool seen = false;

  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/notifications') {
      return {
        'unread': seen ? 0 : 1,
        'items': [
          {
            'id': 'n1',
            'role': 'buyer',
            'kind': 'order_in_transit',
            'title': 'Order on the way',
            'body': 'Your order has left for delivery.',
            'link': '/order/o1',
            'read': seen,
            'created_at': DateTime.now().toIso8601String(),
          }
        ]
      };
    }
    return super.read(path, query);
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    writes.add((path, data));
    if (path == '/notifications/read') seen = true;
    return null;
  }
}

Widget _app(_InboxRepository repository) {
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(appBar: _Bar(), body: Text('home'))),
    GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen()),
    GoRoute(
        path: '/order/:id',
        builder: (_, s) => Text('order ${s.pathParameters['id']}')),
  ]);
  return ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: omoterraTheme(), routerConfig: router));
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) =>
      AppBar(actions: const [NotificationBell()]);
}

void main() {
  testWidgets(
      'the bell shows unread, opens the inbox, and a tap opens the order',
      (tester) async {
    final repository = _InboxRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('Order on the way'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Order on the way'));
    await tester.pumpAndSettle();
    expect(find.text('order o1'), findsOneWidget);
    expect(repository.writes.single.$1, '/notifications/read');
    expect(repository.writes.single.$2, {
      'ids': ['n1']
    });
  });
}
