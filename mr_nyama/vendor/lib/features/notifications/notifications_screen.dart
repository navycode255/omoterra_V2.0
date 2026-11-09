import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/notifications.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/states.dart';
import '../office/owner_reference.dart' show OwnerPage;
import 'notifications_state.dart';

/// "Arifa" for the vendor (Manrope, the vendor header).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final unread = ref.watch(notificationsUnreadProvider);
    return Scaffold(
      backgroundColor: MNColors.pageBackground,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(right: MNSpace.x1),
            child: Row(children: [
              MNIconButton(MNIconData.back, label: s.back, onPressed: () {
                final router = GoRouter.of(context);
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go(MNRoutes.home);
                }
              }),
              const Spacer(),
              if (unread)
                MNTextButton(s.notificationsMarkAll,
                    onPressed: () => markNotificationsRead(ref, null)),
            ]),
          ),
          Expanded(
            child: NotificationList(
              office: false,
              header: Transform.translate(
                offset: const Offset(0, -6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: Text(s.notificationsTitle,
                      style: MNText.resolve(context, MNText.pageTitle)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// "Arifa" in office mode (Inter, the office page), with "Tuma ujumbe" for
/// supervisors and the business-wide roles.
class OfficeNotificationsScreen extends ConsumerWidget {
  const OfficeNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final unread = ref.watch(notificationsUnreadProvider);
    return OwnerPage(
      title: s.notificationsTitle,
      strings: s,
      onAdd: auth is OfficeSignedIn && canSendMessages(auth.profile.roles)
          ? () => context.push(MNRoutes.officeNewMessage)
          : null,
      addLabel: s.messageNew,
      trailing: unread
          ? MNTextButton(s.notificationsMarkAll,
              onPressed: () => markNotificationsRead(ref, null))
          : null,
      onRefresh: () => ref
          .refresh(notificationsProvider.future)
          .then((_) {}, onError: (_) {}),
      child: const NotificationList(office: true, scrolls: false),
    );
  }
}

/// Supervisors (their stations) and finance, operations admin and the owner.
bool canSendMessages(List<String> roles) => roles.any(
    {'supervisor', 'finance', 'operations_admin', 'business_owner'}.contains);

/// The list itself, newest first: unread ones carry a red dot and a bold
/// title. Tapping opens the screen a notification is about.
class NotificationList extends ConsumerStatefulWidget {
  final bool office;
  final Widget? header;

  /// False inside a page that already scrolls (the office page).
  final bool scrolls;
  const NotificationList(
      {super.key, required this.office, this.header, this.scrolls = true});
  @override
  ConsumerState<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends ConsumerState<NotificationList> {
  final List<AppNotification> _older = [];
  bool _more = false, _loading = false;

  Future<void> _loadMore(List<AppNotification> shown) async {
    if (_loading || shown.isEmpty) return;
    setState(() => _loading = true);
    try {
      final page = await olderNotifications(ref, shown.last.id);
      if (mounted) {
        setState(() {
          _older.addAll(page.items);
          _more = page.more;
        });
      }
    } catch (_) {
      // Offline: the button stays for another try.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() {
    _older.clear();
    return ref
        .refresh(notificationsProvider.future)
        .then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final state = ref.watch(notificationsProvider);
    final page = state.valueOrNull;
    if (page == null) {
      final content = state.hasError
          ? MNErrorState(
              error: state.error,
              onRetry: () => ref.invalidate(notificationsProvider))
          : const Center(child: MNSpinner(color: MNColors.ink));
      if (widget.header == null) return content;
      return Column(children: [
        widget.header!,
        Expanded(child: content),
      ]);
    }
    final items = [...page.items, ..._older];
    final more = _older.isEmpty ? page.more : _more;
    if (items.isEmpty) {
      final empty = Padding(
        padding: const EdgeInsets.only(top: MNSpace.x6),
        child: MNEmptyState(
            icon: MNIconData.info,
            title: s.notificationsEmpty,
            message: s.notificationsEmptyHelp),
      );
      if (!widget.scrolls) {
        return widget.header == null
            ? empty
            : Column(children: [widget.header!, empty]);
      }
      return MNRefreshArea(
        color: MNColors.red,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: MNSpace.x6),
          children: [
            if (widget.header != null) widget.header!,
            empty,
          ],
        ),
      );
    }
    final now = DateTime.now();
    final rows = [
      if (widget.header != null) widget.header!,
      for (final n in items)
        _NotificationRow(
            item: n,
            time: s.notificationTime(n.createdAt, now),
            onTap: () =>
                openNotification(context, ref, n, office: widget.office)),
      if (more)
        Padding(
          padding: const EdgeInsets.all(MNSpace.x4),
          child: MNButton.secondary(s.notificationsMore,
              busy: _loading, onPressed: () => _loadMore(items)),
        ),
    ];
    if (!widget.scrolls) return Column(children: rows);
    return MNRefreshArea(
      color: MNColors.red,
      onRefresh: _refresh,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: MNSpace.x6),
          children: rows),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification item;
  final String time;
  final VoidCallback onTap;
  const _NotificationRow(
      {required this.item, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final titleStyle = MNText.resolve(context, MNText.body);
    return MNPressable(
      onTap: onTap,
      color: Colors.transparent,
      pressedColor: MNColors.surfacePressed,
      pressedScale: 1,
      semanticLabel: '${item.title}. ${item.body}. $time',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: MNSize.minTouch),
          padding: const EdgeInsets.symmetric(
              horizontal: MNSpace.x4, vertical: MNSpace.x3),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: MNColors.border))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 16,
              child: item.read
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: MNColors.red, shape: BoxShape.circle))),
            ),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(item.title,
                                style: item.read
                                    ? titleStyle
                                    : MNText.withWeight(
                                        titleStyle, FontWeight.w700)),
                          ),
                          const SizedBox(width: MNSpace.x2),
                          Text(time,
                              style: MNText.resolve(context, MNText.meta)),
                        ]),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: MNSpace.x1),
                      Text(item.body,
                          style: MNText.resolve(context, MNText.body)
                              .copyWith(color: MNColors.ink2)),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
