import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A push notification the person tapped.
class PushTap {
  final String? notificationId, target, side;
  const PushTap({this.notificationId, this.target, this.side});
}

/// The phone's push service (step 13B). Everything fails quietly: without
/// push the bell and the list still work.
abstract class PushClient {
  /// Asks the phone's permission (Android 13+) and returns the token, if any.
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// A notification arrived while the app is open (no banner: the bell shows it).
  Stream<void> get received;
  Stream<PushTap> get tapped;

  /// The notification that opened the app from closed, if any.
  Future<PushTap?> initialTap();

  /// Ends this phone's token, so a signed-out phone receives nothing even if
  /// the server could not be told.
  Future<void> deleteToken();
}

class NoPushClient implements PushClient {
  const NoPushClient();
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<void> get received => const Stream.empty();
  @override
  Stream<PushTap> get tapped => const Stream.empty();
  @override
  Future<PushTap?> initialTap() async => null;
  @override
  Future<void> deleteToken() async {}
}

class FirebasePushClient implements PushClient {
  /// Null when Firebase could not start.
  late final Future<FirebaseMessaging?> _messaging = () async {
    try {
      await Firebase.initializeApp();
      return FirebaseMessaging.instance;
    } catch (error) {
      debugPrint('push: Firebase did not start: ${error.runtimeType}');
      return null;
    }
  }();

  Stream<T> _stream<T>(Stream<T> Function() open) async* {
    if (await _messaging != null) yield* open();
  }

  static PushTap _tap(RemoteMessage m) => PushTap(
      notificationId: m.data['notification_id'] as String?,
      target: m.data['target'] as String?,
      side: m.data['side'] as String?);

  @override
  Future<String?> token() async {
    try {
      final messaging = await _messaging;
      if (messaging == null) return null;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await messaging.getToken();
    } catch (error) {
      debugPrint('push: no token: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh =>
      _stream(() => FirebaseMessaging.instance.onTokenRefresh);
  @override
  Stream<void> get received => _stream(() => FirebaseMessaging.onMessage);
  @override
  Stream<PushTap> get tapped =>
      _stream(() => FirebaseMessaging.onMessageOpenedApp.map(_tap));

  @override
  Future<PushTap?> initialTap() async {
    try {
      final messaging = await _messaging;
      final message = await messaging?.getInitialMessage();
      return message == null ? null : _tap(message);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await (await _messaging)?.deleteToken();
    } catch (_) {
      // The server ends it anyway once it hears of the sign-out.
    }
  }
}

final pushClientProvider = Provider<PushClient>((ref) =>
    !kIsWeb && Platform.isAndroid
        ? FirebasePushClient()
        : const NoPushClient());
