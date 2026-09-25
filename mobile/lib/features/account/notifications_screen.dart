import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/notifications/notifications.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markRead(WidgetRef ref, Map<String, dynamic> body) async {
    try {
      await ref.read(repositoryProvider).write('/notifications/read', body);
    } catch (_) {}
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final unread = (state.valueOrNull?['unread'] as int?) ?? 0;
    return Scaffold(
        appBar: OmoterraAppBar(title: const Text('Notifications'), actions: [
          if (unread > 0)
            TextButton(
                onPressed: () => _markRead(ref, {'all': true}),
                child: const Text('Mark all read')),
        ]),
        body: RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: state.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(20), child: LoadingSkeleton()),
                error: (error, _) =>
                    ListView(padding: const EdgeInsets.all(20), children: [
                      ErrorState(error,
                          retry: () => ref.invalidate(notificationsProvider)),
                    ]),
                data: (data) {
                  final items = List<Map<String, dynamic>>.from(
                      (data['items'] as List)
                          .map((e) => Map<String, dynamic>.from(e as Map)));
                  if (items.isEmpty) {
                    return ListView(
                        padding: const EdgeInsets.all(20),
                        children: const [
                          EmptyState('No notifications yet',
                              'Updates about your orders, stock and payouts will appear here.'),
                        ]);
                  }
                  return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final read = item['read'] == true;
                        return ListTile(
                            key: ValueKey(item['id']),
                            leading: CircleAvatar(
                                backgroundColor: read
                                    ? OColors.soft
                                    : const Color(0xFFE0EFE7),
                                child: Icon(
                                    item['role'] == 'supplier'
                                        ? Icons.storefront_outlined
                                        : Icons.shopping_basket_outlined,
                                    color: OColors.forest)),
                            title: Text('${item['title']}',
                                style: TextStyle(
                                    fontWeight: read
                                        ? FontWeight.w500
                                        : FontWeight.w800)),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ('${item['body']}'.isNotEmpty)
                                    Text('${item['body']}'),
                                  const SizedBox(height: 4),
                                  Text(_when('${item['created_at']}'),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: OColors.secondary)),
                                ]),
                            trailing: read
                                ? null
                                : const Icon(Icons.circle,
                                    size: 10, color: OColors.forest),
                            onTap: () async {
                              if (!read) {
                                _markRead(ref, {
                                  'ids': [item['id']]
                                });
                              }
                              await openNotification(ref, GoRouter.of(context),
                                  role: '${item['role']}',
                                  link: '${item['link']}');
                            });
                      });
                })));
  }

  static String _when(String iso) {
    final at = DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    final age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inHours < 1) return '${age.inMinutes} min ago';
    if (age.inDays < 1) return '${age.inHours} h ago';
    return DateFormat('d MMM, HH:mm').format(at);
  }
}

/// Top-bar bell with the unread count across both roles.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        (ref.watch(notificationsProvider).valueOrNull?['unread'] as int?) ?? 0;
    return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
        onPressed: () => context.push('/notifications'),
        icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: const Color(0xFFD9534F),
            child:
                const Icon(Icons.notifications_none, color: OColors.forest)));
  }
}
