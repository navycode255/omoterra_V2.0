import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/push.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/push/push_client.dart';
import '../../core/routing/router.dart';
import '../../core/routing/routes.dart';
import 'notifications_state.dart';

/// Keeps the phone's push token bound to whoever is signed in (step 13B), in
/// their language, and opens the screen of a tapped notification. A phone
/// locked for inactivity keeps its token; signing out ends it.
class PushCoordinator {
  final Ref ref;
  PushCoordinator(this.ref);

  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _queue = Future.value();
  String? _account, _registered;
  PushTap? _pending;
  bool _started = false;

  PushClient get _client => ref.read(pushClientProvider);

  /// `vendor:<id>` or `staff:<id>` while signed in with an open session.
  String? get _current {
    final office = ref.read(officeSessionProvider).valueOrNull;
    // A lead session keeps the seller's push: the server binds one token to
    // one person (push.register moves it), so no second, staff registration.
    if (office is OfficeSignedIn && !office.viaLead) {
      return 'staff:${office.profile.id}';
    }
    final vendor = ref.read(sessionProvider).valueOrNull;
    return vendor is SignedIn ? 'vendor:${vendor.profile.id}' : null;
  }

  void start() {
    if (_started) return;
    _started = true;
    _subscriptions
      ..add(_client.tokenRefresh.listen((_) => sync()))
      ..add(
          _client.received.listen((_) => ref.invalidate(notificationsProvider)))
      ..add(_client.tapped.listen(_open));
    unawaited(_client.initialTap().then((tap) {
      if (tap != null) _open(tap);
    }));
    accountChanged();
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  void accountChanged() {
    final now = _current;
    final vendor = ref.read(sessionProvider).valueOrNull;
    final signedOut = now == null && vendor is! Locked;
    if (_account != null && signedOut) {
      _registered = null;
      _enqueue(_client.deleteToken);
    }
    _account = now;
    if (now == null) return;
    sync();
    if (_pending case final tap?) _open(tap);
  }

  /// Registers the token if the person, language or token changed. A failure
  /// is tried again when the app returns.
  void sync() => _enqueue(() async {
        final account = _current;
        if (account == null) return;
        final token = await _client.token();
        if (token == null) return;
        final lang = ref.read(languageProvider);
        final key = '$account|$lang|$token';
        if (key == _registered) return;
        try {
          if (account.startsWith('staff:')) {
            final repository = ref.read(officeRepositoryProvider);
            if (repository is! OfficePushRepository) return;
            await (repository as OfficePushRepository)
                .registerPushToken(token, lang: lang);
          } else {
            final repository = ref.read(vendorRepositoryProvider);
            if (repository is! VendorPushRepository) return;
            await (repository as VendorPushRepository)
                .registerPushToken(token, lang: lang);
          }
          if (_current == account) _registered = key;
        } catch (_) {
          // Offline, or an older server: the list and the bell still work.
        }
      });

  void _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((_) {});
  }

  void _open(PushTap tap) {
    final account = _current;
    if (account == null) {
      // Opened before the session is known or the PIN is entered.
      _pending = tap;
      return;
    }
    _pending = null;
    final office = account.startsWith('staff:');
    // A notification of the other side of this phone stays in that side's list.
    if (tap.side != null && (tap.side == 'staff') != office) return;
    if (tap.notificationId case final id?) {
      unawaited(sendNotificationsRead(ref.read, [id]).then((done) {
        if (done) ref.invalidate(notificationsProvider);
      }));
    }
    final route = routeForTarget(tap.target, office: office) ??
        (office ? MNRoutes.officeNotifications : MNRoutes.notifications);
    final router = ref.read(routerProvider);
    MNRoutes.tabs.contains(route) ? router.go(route) : router.push(route);
  }
}

final pushCoordinatorProvider = Provider<PushCoordinator>((ref) {
  final coordinator = PushCoordinator(ref);
  ref.listen(sessionProvider, (_, __) => coordinator.accountChanged());
  ref.listen(officeSessionProvider, (_, __) => coordinator.accountChanged());
  ref.listen(languageProvider, (_, __) => coordinator.sync());
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
