import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/pressable.dart';
import '../office/owner_reference.dart' show OwnerGlyph;
import 'notifications_state.dart';

/// The bell in the top bar, both modes: a small red dot while something is
/// unread (no counter, AGENTS.md §3). It asks the server again every
/// [notificationRefreshEvery] while shown and whenever the app returns.
class NotificationBell extends ConsumerStatefulWidget {
  final bool office;
  final double size;
  const NotificationBell({super.key, required this.office, this.size = 24});
  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
        notificationRefreshEvery, (_) => ref.invalidate(notificationsProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationsProvider);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final unread = ref.watch(notificationsUnreadProvider);
    return MNPressable(
      onTap: () => context.push(widget.office
          ? MNRoutes.officeNotifications
          : MNRoutes.notifications),
      pressedScale: MNMotion.pressChip,
      semanticLabel: unread ? s.notificationsNew : s.notificationsTitle,
      child: SizedBox.square(
        dimension: MNSize.minTouch,
        child: Center(
          child: Stack(clipBehavior: Clip.none, children: [
            OwnerGlyph('bell', size: widget.size, color: MNColors.ink),
            if (unread)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: MNColors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: MNColors.white, width: 1.5))),
              ),
          ]),
        ),
      ),
    );
  }
}
