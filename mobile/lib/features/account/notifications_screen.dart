import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
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
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(s.notifications,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: OColors.ink,
                    letterSpacing: -.4)),
            actions: [
              if (unread > 0)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                        onPressed: () => _markRead(ref, {'all': true}),
                        child: Text(s.markAllRead,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: OColors.forest)))),
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
                        children: [
                          EmptyState(
                              s.noNotificationsTitle, s.noNotificationsBody),
                        ]);
                  }
                  return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE6ECE8)),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final read = item['read'] == true;
                        return _NotificationRow(
                            key: ValueKey(item['id']),
                            item: item,
                            onTap: () async {
                              if (!read) {
                                _markRead(ref, {
                                  'ids': [item['id']]
                                });
                              }
                              final link = '${item['link'] ?? ''}';
                              // Nothing to open: read it here instead.
                              if (link.isEmpty || link == 'null') {
                                showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                            title: Text('${item['title']}'),
                                            content: Text('${item['body']}'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(s.ok))
                                            ]));
                                return;
                              }
                              await openNotification(ref, GoRouter.of(context),
                                  role: '${item['role']}', link: link);
                            });
                      });
                })));
  }

  static String _when(String iso, Strings s) {
    final at = DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    final age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return s.justNow;
    if (age.inHours < 1) return s.minutesAgo(age.inMinutes);
    if (age.inDays < 1) return s.hoursAgo(age.inHours);
    return '${s.dayMonth(at)}, ${DateFormat('HH:mm').format(at)}';
  }
}

/// One notification: role icon, bold title while unread, message, age, and
/// a green dot until it is read.
class _NotificationRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _NotificationRow({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final read = item['read'] == true;
    final body = '${item['body'] ?? ''}';
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                      color: read ? OColors.soft : const Color(0xFFE3F0E8),
                      shape: BoxShape.circle),
                  child: Icon(
                      item['role'] == 'supplier'
                          ? Icons.storefront_outlined
                          : Icons.shopping_basket_outlined,
                      size: 26,
                      color: OColors.forest)),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${item['title']}',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                read ? FontWeight.w600 : FontWeight.w800,
                            color: OColors.ink)),
                    if (body.isNotEmpty && body != 'null') ...[
                      const SizedBox(height: 4),
                      Text(body,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: OColors.secondary)),
                    ],
                    const SizedBox(height: 8),
                    Text(
                        NotificationsScreen._when(
                            '${item['created_at']}', context.s),
                        style: const TextStyle(
                            fontSize: 13, color: OColors.muted)),
                  ])),
              SizedBox(
                  width: 28,
                  height: 54,
                  child: read
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                              key: const Key('unread_dot'),
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF0B6B45),
                                  shape: BoxShape.circle)))),
            ])));
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
        tooltip: unread > 0
            ? ref.s.notificationsUnread(unread)
            : ref.s.notifications,
        onPressed: () => context.push('/notifications'),
        icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: const Color(0xFFD9534F),
            child: const Icon(Icons.notifications_none,
                size: 26, color: OColors.ink)));
  }
}
