import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/repository.dart';
import '../auth/session.dart';

/// The signed-in user's inbox: `{unread, items}`. Kept apart from
/// resourceProvider so a failed badge check never replaces the screen with
/// an error; the bell simply shows no count.
final notificationsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(repositoryProvider).read('/notifications');
  return Map<String, dynamic>.from(data as Map);
});

/// Opens what a notification points at, switching to the role it concerns
/// first (a supplier notification opened while in buyer mode would otherwise
/// be redirected to the buyer home).
Future<void> openNotification(WidgetRef ref, GoRouter router,
    {required String role, required String link, bool replace = false}) async {
  final user = ref.read(sessionProvider).valueOrNull;
  if (user != null &&
      ref.read(activeRoleProvider) != role &&
      user.roles.contains(role)) {
    await ref.read(sessionProvider.notifier).switchRole(role);
  }
  if (link.isEmpty) return;
  replace ? router.go(link) : router.push(link);
}

/// Firebase Cloud Messaging for the signed-in user: registers this phone
/// with Omoterra, refreshes the inbox when a push arrives, and opens the
/// notification's page when one is tapped.
class PushNotifications {
  PushNotifications(this._repository);
  final OmoterraRepository _repository;
  String? _token;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _started = false;

  /// Push needs the Android Firebase config; web and the offline preview run
  /// with the in-app inbox only.
  static bool get supported => !kIsWeb && !localPreview && apiUrl.isNotEmpty;

  Future<void> start(
      {required void Function(RemoteMessage) onForeground,
      required void Function(RemoteMessage) onOpened}) async {
    if (_started || !supported) return;
    _started = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _token = await messaging.getToken();
      await _register();
      _subscriptions
        ..add(messaging.onTokenRefresh.listen((token) {
          _token = token;
          _register();
        }))
        ..add(FirebaseMessaging.onMessage.listen(onForeground))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(onOpened));
      final initial = await messaging.getInitialMessage();
      if (initial != null) onOpened(initial);
    } catch (error) {
      // Push is a convenience: the inbox still works without it.
      debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<void> _register() async {
    final token = _token;
    if (token == null) return;
    try {
      await _repository
          .write('/devices', {'token': token, 'platform': 'android'});
    } catch (error) {
      debugPrint('Could not register this phone for push: $error');
    }
  }

  /// Called before signing out so the next person on this phone doesn't
  /// receive the previous account's alerts.
  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _started = false;
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _repository.write(
          '/devices/unregister', {'token': token, 'platform': 'android'});
    } catch (_) {}
  }
}

final pushProvider = Provider<PushNotifications>(
    (ref) => PushNotifications(ref.watch(repositoryProvider)));

/// Starts push once someone is signed in, keeps the inbox fresh when the app
/// comes back to the foreground, and routes taps on system notifications.
class NotificationsHost extends ConsumerStatefulWidget {
  final GoRouter router;
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messenger;
  const NotificationsHost(
      {super.key,
      required this.router,
      required this.messenger,
      required this.child});
  @override
  ConsumerState<NotificationsHost> createState() => _NotificationsHostState();
}

class _NotificationsHostState extends ConsumerState<NotificationsHost> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationsProvider));

  @override
  void initState() {
    super.initState();
    _lifecycle;
    ref.listenManual(sessionProvider, (_, next) {
      if (next.valueOrNull != null) _start();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _start() {
    ref.read(pushProvider).start(
        onForeground: (message) {
          ref.invalidate(notificationsProvider);
          final title = message.notification?.title;
          if (title == null) return;
          widget.messenger.currentState?.showSnackBar(SnackBar(
              content: Text(title),
              action: SnackBarAction(
                  label: 'View',
                  onPressed: () => _open(message, replace: false))));
        },
        onOpened: (message) => _open(message, replace: true));
  }

  void _open(RemoteMessage message, {required bool replace}) {
    ref.invalidate(notificationsProvider);
    final data = message.data;
    final id = data['notification_id'];
    if (id is String && id.isNotEmpty) {
      ref
          .read(repositoryProvider)
          .write('/notifications/read', {
            'ids': [id]
          })
          .then((_) => ref.invalidate(notificationsProvider))
          .catchError((_) {});
    }
    openNotification(ref, widget.router,
        role: '${data['role'] ?? ''}',
        link: '${data['link'] ?? ''}',
        replace: replace);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
