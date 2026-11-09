import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import '../api/vendor_repository.dart';
import 'secure_store.dart';
import 'session.dart';

/// Offline unlock (business policies §10). After an online sign-in the server
/// may issue an offline grant for this device; the phone then keeps:
/// - the grant (id, expiry and the three limits the server sent),
/// - a PIN verifier: PBKDF2-HMAC-SHA256 of the PIN with a random salt, never
///   the PIN itself,
/// - the failed offline attempts (survive closing the app),
/// - when the server was last reached.
/// All in [KeyValueStore] (Android Keystore-backed in production).
///
/// While the phone cannot reach the server, the PIN unlocks against the
/// verifier as long as the grant has not expired and the last online contact
/// is within the validity. Too many wrong PINs erase grant and verifier: the
/// vendor must sign in online. An offline unlock is not a server session;
/// operations made then carry the grant id and the server decides them.
/// Without a grant (the limits unset on the server) nothing changes: the
/// vendor signs in online after the lock, as before.

/// PBKDF2 rounds for new verifiers. Stored with each verifier, so a change
/// never breaks an existing one.
const pinRounds = 120000;

typedef PinHasher = Future<List<int>> Function(
    String pin, List<int> salt, int rounds);

/// The slow hash, off the UI thread. Tests override it with fewer rounds.
final pinHasherProvider = Provider<PinHasher>((ref) => (pin, salt, rounds) =>
    Isolate.run(() => pbkdf2Sha256(utf8.encode(pin), salt, rounds, 32)));

/// PBKDF2 (RFC 8018) with HMAC-SHA256.
List<int> pbkdf2Sha256(
    List<int> password, List<int> salt, int rounds, int length) {
  final hmac = Hmac(sha256, password);
  final out = <int>[];
  for (var block = 1; out.length < length; block++) {
    final first = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..buffer.asByteData().setUint32(salt.length, block);
    var u = hmac.convert(first).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
  }
  return out.sublist(0, length);
}

/// What the phone keeps of a grant.
class StoredGrant {
  final String id;
  final DateTime expiresAt;
  final int validityHours, relockMinutes, pinAttempts;
  const StoredGrant(
      {required this.id,
      required this.expiresAt,
      required this.validityHours,
      required this.relockMinutes,
      required this.pinAttempts});

  Map<String, dynamic> toJson() => {
        'id': id,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'validity_hours': validityHours,
        'relock_minutes': relockMinutes,
        'pin_attempts': pinAttempts,
      };

  static StoredGrant? fromJson(Object? v) {
    if (v is! Map) return null;
    final expires = DateTime.tryParse('${v['expires_at']}');
    int? n(Object? x) => x is int ? x : int.tryParse('$x');
    final validity = n(v['validity_hours']),
        relock = n(v['relock_minutes']),
        attempts = n(v['pin_attempts']);
    if (v['id'] == null ||
        expires == null ||
        validity == null ||
        relock == null ||
        attempts == null) {
      return null;
    }
    return StoredGrant(
        id: '${v['id']}',
        expiresAt: expires,
        validityHours: validity,
        relockMinutes: relock,
        pinAttempts: attempts);
  }
}

/// Why an offline unlock was refused.
enum OfflineRefusal {
  /// No grant on this phone (never issued, erased, or not enabled).
  noGrant,

  /// The grant expired or the last online contact is too long ago.
  expired,

  /// Wrong PIN; [OfflineUnlockFailure.attemptsLeft] remain.
  wrongPin,

  /// Too many wrong PINs: grant and verifier erased.
  erased,
}

class OfflineUnlockFailure implements Exception {
  final OfflineRefusal refusal;
  final int? attemptsLeft;
  const OfflineUnlockFailure(this.refusal, {this.attemptsLeft});
}

final offlineUnlockProvider =
    Provider<OfflineUnlock>((ref) => OfflineUnlock(ref));

class OfflineUnlock {
  static const _grant = 'offline_grant';
  static const _verifier = 'offline_pin_verifier';
  static const _failures = 'offline_pin_failures';
  static const _lastOnline = 'offline_last_online';

  /// The grant the current offline unlock runs under; operations queued
  /// meanwhile carry it (see `enqueueOperation`). Null while online.
  static const _activeGrant = 'offline_active_grant';

  final Ref ref;
  OfflineUnlock(this.ref);

  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  /// The grant id new operations are marked with, kept in memory for the
  /// outbox (which has no `ref`). Set while offline-unlocked.
  static String? markForNewOperations;

  Future<StoredGrant?> grant() async {
    final raw = await _store.read(_grant);
    if (raw == null) return null;
    try {
      return StoredGrant.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// After an online sign-in with [pin]: a fresh verifier, attempts back to 0.
  Future<void> rememberPin(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await ref.read(pinHasherProvider)(pin, salt, pinRounds);
    await _store.write(
        _verifier,
        jsonEncode({
          'salt': base64Encode(salt),
          'hash': base64Encode(hash),
          'rounds': pinRounds,
        }));
    await _store.write(_failures, '0');
  }

  /// Stores the server's answer to a grant request: a grant, or none (the
  /// limits are unset), which erases any earlier one.
  Future<void> keepGrant(OfflineGrantAnswer? answer, DateTime now) async {
    if (answer == null || !answer.enabled) {
      await _store.delete(_grant);
      return;
    }
    await _store.write(
        _grant,
        jsonEncode(StoredGrant(
                id: answer.grantId!,
                expiresAt: answer.expiresAt!,
                validityHours: answer.validityHours!,
                relockMinutes: answer.relockMinutes!,
                pinAttempts: answer.pinAttempts!)
            .toJson()));
    await markOnline(now);
  }

  /// The server answered: the validity counts from now, and the phone is no
  /// longer offline-unlocked.
  Future<void> markOnline(DateTime now) async {
    await _store.write(_lastOnline, now.toUtc().toIso8601String());
    await _store.delete(_activeGrant);
    markForNewOperations = null;
  }

  Future<DateTime?> lastOnline() async =>
      DateTime.tryParse(await _store.read(_lastOnline) ?? '');

  /// Whether the grant still covers [now] (expiry and validity since the last
  /// online contact).
  Future<bool> valid(DateTime now) async {
    final g = await grant();
    final last = await lastOnline();
    if (g == null || last == null) return false;
    return now.isBefore(g.expiresAt) &&
        now.difference(last) < Duration(hours: g.validityHours);
  }

  /// The grant id of the current offline unlock, if any (survives a restart).
  Future<String?> activeGrant() async => _store.read(_activeGrant);

  /// Checks [pin] against the verifier while offline. Returns the grant id
  /// to work under, or throws [OfflineUnlockFailure].
  Future<String> unlock(String pin, DateTime now) async {
    final g = await grant();
    final rawVerifier = await _store.read(_verifier);
    if (g == null || rawVerifier == null) {
      throw const OfflineUnlockFailure(OfflineRefusal.noGrant);
    }
    if (!await valid(now)) {
      throw const OfflineUnlockFailure(OfflineRefusal.expired);
    }
    final v = jsonDecode(rawVerifier) as Map<String, dynamic>;
    final salt = base64Decode(v['salt'] as String);
    final rounds = v['rounds'] as int;
    final expected = base64Decode(v['hash'] as String);
    final actual = await ref.read(pinHasherProvider)(pin, salt, rounds);
    if (!_same(expected, actual)) {
      final failures =
          (int.tryParse(await _store.read(_failures) ?? '') ?? 0) + 1;
      if (failures >= g.pinAttempts) {
        await erase();
        throw const OfflineUnlockFailure(OfflineRefusal.erased);
      }
      await _store.write(_failures, '$failures');
      throw OfflineUnlockFailure(OfflineRefusal.wrongPin,
          attemptsLeft: g.pinAttempts - failures);
    }
    await _store.write(_failures, '0');
    await _store.write(_activeGrant, g.id);
    markForNewOperations = g.id;
    return g.id;
  }

  /// The fingerprint stood in for the PIN while offline (the phone's own
  /// check passed): works under the grant exactly like an offline PIN unlock,
  /// while it is valid. Wrong attempts are the OS's to count.
  Future<String> unlockWithoutPin(DateTime now) async {
    final g = await grant();
    if (g == null) throw const OfflineUnlockFailure(OfflineRefusal.noGrant);
    if (!await valid(now)) {
      throw const OfflineUnlockFailure(OfflineRefusal.expired);
    }
    await _store.write(_activeGrant, g.id);
    markForNewOperations = g.id;
    return g.id;
  }

  /// Sign-out, suspension, too many wrong PINs: nothing offline remains.
  Future<void> erase() async {
    for (final key in [_grant, _verifier, _failures, _activeGrant]) {
      await _store.delete(key);
    }
    markForNewOperations = null;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// True while the phone works under an offline unlock whose grant no longer
/// covers now: recording stops until the phone reaches the server (policies
/// §10.4). Nyumbani and history stay readable.
final offlineRecordingStoppedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn || !auth.session.offline) return false;
  return !await ref
      .read(offlineUnlockProvider)
      .valid(ref.read(clockProvider)());
});
