import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import '../api/vendor_repository.dart';
import 'offline_unlock.dart';
import '../media/photo_cache.dart';
import 'biometrics.dart';
import 'device_sign_in.dart';
import 'lead_session.dart';
import 'office_session.dart';
import 'secure_store.dart';

/// Where the vendor stands with sign-in.
sealed class AuthState {
  const AuthState();
}

/// No session on this phone. [phone] is the last number used, if any.
class SignedOut extends AuthState {
  final String? phone;
  const SignedOut([this.phone]);
}

/// A session exists but the PIN must be entered again: the app was closed
/// for longer than [SessionController.lockAfter], or the server ended the
/// session ([expired]).
class Locked extends AuthState {
  final VendorProfile profile;
  final bool expired;

  /// An explicit PIN choice must not immediately reopen the biometric prompt.
  final bool pinRequested;
  const Locked(this.profile, {this.expired = false, this.pinRequested = false});
}

class SignedIn extends AuthState {
  final VendorSession session;
  const SignedIn(this.session);
  VendorProfile get profile => session.profile;
}

/// The server reports the vendor's account as suspended.
class Suspended extends AuthState {
  const Suspended();
}

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final sessionProvider =
    AsyncNotifierProvider<SessionController, AuthState>(SessionController.new);

/// Owns the session token and the PIN lock. Tokens live only in
/// [KeyValueStore]; PINs and codes pass straight through to the server and
/// are never stored or logged.
class SessionController extends AsyncNotifier<AuthState> {
  /// The PIN is asked again after the app has been closed this long
  /// (street vendor build plan, sign-in screen).
  static const lockAfter = Duration(hours: 12);

  static const _token = 'session_token';
  static const _profile = 'session_profile';
  static const _phone = 'last_phone';
  static const _lastActive = 'last_active';

  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  VendorRepository get _repository => ref.read(vendorRepositoryProvider);
  OfflineUnlock get _offline => ref.read(offlineUnlockProvider);
  DateTime _now() => ref.read(clockProvider)();

  /// How long the app may stay closed before the PIN is asked again: the
  /// server's re-lock interval while an offline grant is kept, else 12 hours.
  Future<Duration> _lockAfter() async {
    final grant = await _offline.grant();
    return grant == null ? lockAfter : Duration(minutes: grant.relockMinutes);
  }

  @override
  Future<AuthState> build() async {
    return _restore();
  }

  Future<AuthState> _restore() async {
    final token = await _store.read(_token);
    final profileJson = await _store.read(_profile);
    final profile = profileJson == null
        ? null
        : VendorProfile.fromJson(
            jsonDecode(profileJson) as Map<String, dynamic>);
    if (token == null || profile == null) {
      return SignedOut(await _store.read(_phone));
    }
    final lastActive = DateTime.tryParse(await _store.read(_lastActive) ?? '');
    if (lastActive == null ||
        _now().difference(lastActive) > await _lockAfter()) {
      return Locked(profile);
    }
    // Still inside an offline unlock: its operations keep carrying the grant.
    final offlineGrant = await _offline.activeGrant();
    OfflineUnlock.markForNewOperations = offlineGrant;
    _keepLeadSessionSoon(profile);
    return SignedIn(
        VendorSession(token, profile, offlineGrantId: offlineGrant));
  }

  // Outlet Lead office session ---------------------------------------------

  /// A seller who is an Outlet Lead gets the lead office session from the
  /// server, in the background: after sign-in, unlock and app start. Best
  /// effort. Offline, a refusal or any other failure leaves selling as it
  /// is and shows nothing. A seller who is no longer a lead loses a kept one.
  void _keepLeadSessionSoon(VendorProfile profile) {
    unawaited(Future<void>.delayed(
        Duration.zero, () => _keepLeadSession(profile)));
  }

  Future<void> _keepLeadSession(VendorProfile profile) async {
    try {
      final office = ref.read(officeSessionProvider.notifier);
      if (!profile.isOutletLead) {
        await office.endLeadSession();
        return;
      }
      final repository = _repository;
      if (repository is! VendorLeadRepository) return;
      final current = await future;
      if (current is! SignedIn || current.session.offline) return;
      final lead = await (repository as VendorLeadRepository)
          .leadSession(current.session.token);
      // The seller may have signed out while the answer was on its way.
      if (state.valueOrNull is! SignedIn) return;
      await office.adoptLeadSession(lead);
    } catch (_) {
      // Selling never waits for, or shows, the lead session.
    }
  }

  /// The phone number of the vendor signing in, if known.
  String? get currentPhone => switch (state.valueOrNull) {
        SignedOut(:final phone) => phone,
        Locked(:final profile) => profile.phone,
        SignedIn(:final profile) => profile.phone,
        _ => null,
      };

  Future<SignInStep> startSignIn(String phone) async {
    final step = await _guard(() => _repository.startSignIn(phone));
    await _store.write(_phone, phone);
    state = AsyncData(SignedOut(phone));
    return step;
  }

  /// Signs in with the server. When the server cannot be reached and the
  /// phone is locked (not ended by the server), the PIN unlocks offline
  /// against the kept verifier while the offline grant is valid (business
  /// policies §10); refusals come as [OfflineUnlockFailure]. [remember] is
  /// "Nikumbuke": the fingerprint signs in on this phone from now on.
  Future<void> signIn(String phone, String pin, {bool remember = false}) async {
    final VendorSession session;
    try {
      session = await _guard(() => _repository.signIn(phone: phone, pin: pin));
    } on AuthFailure catch (failure) {
      final current = state.valueOrNull;
      if (failure.kind == AuthFailureKind.offline &&
          current is Locked &&
          !current.expired) {
        await _unlockOffline(current.profile, pin);
        return;
      }
      rethrow;
    }
    await _save(session);
    await _goneOnline(pin: pin);
    await _keepDeviceSignIn(remember: remember);
    _keepLeadSessionSoon(session.profile);
  }

  Future<void> _unlockOffline(VendorProfile profile, String pin) async {
    final grant = await _offline.unlock(pin, _now());
    final token = await _store.read(_token) ?? '';
    await _store.write(_lastActive, _now().toIso8601String());
    ref.read(biometricUnlockedAccountProvider.notifier).state =
        biometricAccount('vendor', profile.id);
    state = AsyncData(
        SignedIn(VendorSession(token, profile, offlineGrantId: grant)));
  }

  /// Opens a phone locked for inactivity with the fingerprint instead of the
  /// PIN (the vendor turned it on in Wasifu). Only a lock with its session
  /// still kept; a session the server ended needs the PIN. The server is asked
  /// first; when it cannot be reached, the offline grant must still be valid,
  /// exactly as for an offline PIN unlock, so offline work carries the grant.
  /// Throws [OfflineUnlockFailure] offline, [AuthFailure] when the server
  /// ended the session (the PIN screen then says so).
  Future<void> unlockWithBiometric() async {
    final current = state.valueOrNull;
    final token = await _store.read(_token);
    if (current is! Locked || current.expired || token == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    final profile = current.profile;
    try {
      await _guard(() => _repository.dashboard(token));
    } on AuthFailure catch (failure) {
      if (failure.kind == AuthFailureKind.offline) {
        final grant = await _offline.unlockWithoutPin(_now());
        await _open(token, profile, offlineGrantId: grant);
        return;
      }
      if (failure.kind == AuthFailureKind.sessionExpired) await expire();
      rethrow;
    }
    await _open(token, profile);
    await _goneOnline();
    _keepLeadSessionSoon(profile);
  }

  Future<void> _open(String token, VendorProfile profile,
      {String? offlineGrantId}) async {
    await _store.write(_lastActive, _now().toIso8601String());
    ref.read(biometricUnlockedAccountProvider.notifier).state =
        biometricAccount('vendor', profile.id);
    state = AsyncData(SignedIn(
        VendorSession(token, profile, offlineGrantId: offlineGrantId)));
  }

  /// After the server answered: the validity counts from now, a new PIN
  /// verifier when the PIN was just entered, and a fresh offline grant
  /// (none while the server's limits are unset). Never blocks sign-in.
  Future<void> _goneOnline({String? pin}) async {
    try {
      final now = _now();
      await _offline.markOnline(now);
      if (pin != null) await _offline.rememberPin(pin);
      final repository = _repository;
      final current = state.valueOrNull;
      if (repository is VendorOfflineRepository && current is SignedIn) {
        final answer = await (repository as VendorOfflineRepository)
            .offlineGrant(current.session.token);
        await _offline.keepGrant(answer, now);
      }
    } catch (_) {
      // Offline unlock simply stays unavailable until the next online contact.
    }
  }

  // Fingerprint sign-in after sign-out (MN024) ----------------------------

  static const _side = 'vendor';
  DeviceSignInStore get _devices => ref.read(deviceSignInStoreProvider);

  /// Keeps a fingerprint sign-in key for the signed-in vendor on this phone:
  /// when the fingerprint is turned on, and after a PIN sign-in while it is
  /// on (a PIN reset ends the old key). Best effort: without a key the
  /// sign-in screen simply asks for the PIN.
  Future<void> rememberDevice() async {
    final current = state.valueOrNull;
    final repository = _repository;
    if (current is! SignedIn || repository is! VendorDeviceKeyRepository) {
      return;
    }
    try {
      final key =
          await (repository as VendorDeviceKeyRepository).issueDeviceKey();
      await _devices.save(
          _side,
          SavedDeviceSignIn(
              account: biometricAccount('vendor', current.profile.id),
              key: key,
              name: current.profile.name,
              phone: current.profile.phone));
      ref.invalidate(savedDeviceSignInProvider(_side));
    } catch (_) {
      // Sign-in keeps working with the PIN.
    }
  }

  /// The fingerprint was turned off: the key ends here and at the server.
  Future<void> forgetDevice() async {
    final repository = _repository;
    if (state.valueOrNull is SignedIn &&
        repository is VendorDeviceKeyRepository) {
      try {
        await (repository as VendorDeviceKeyRepository).forgetDeviceKey();
      } catch (_) {
        // The local key goes anyway; the server's ends with the next misuse
        // check or account change.
      }
    }
    await _devices.delete(_side);
    ref.invalidate(savedDeviceSignInProvider(_side));
  }

  /// After a PIN: "Nikumbuke" turns the fingerprint on, and a fingerprint
  /// already on gets a fresh key.
  Future<void> _keepDeviceSignIn({bool remember = false}) async {
    final current = state.valueOrNull;
    if (current is! SignedIn) return;
    final account = biometricAccount('vendor', current.profile.id);
    final preferences = ref.read(biometricPreferencesProvider);
    if (remember) {
      await preferences.enable(account);
      ref.invalidate(biometricEnabledProvider(account));
    } else if (!await preferences.enabled(account)) {
      return;
    }
    await rememberDevice();
  }

  /// Signs in after sign-out with the saved key, once the phone's fingerprint
  /// check passed (the caller asks for it). A key the server ended is
  /// forgotten, so the screen falls back to the PIN.
  Future<void> signInWithFingerprint() async {
    final saved = await _devices.read(_side);
    final repository = _repository;
    if (saved == null || repository is! VendorDeviceKeyRepository) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    try {
      final session = await _guard(() =>
          (repository as VendorDeviceKeyRepository).deviceSignIn(saved.key));
      await _save(session);
      await _goneOnline();
      _keepLeadSessionSoon(session.profile);
    } on AuthFailure catch (failure) {
      if (failure.kind != AuthFailureKind.offline) {
        await _devices.delete(_side);
        ref.invalidate(savedDeviceSignInProvider(_side));
      }
      rethrow;
    }
  }

  Future<String> verifyCode(String phone, String code, {bool reset = false}) =>
      _guard(
          () => _repository.verifyCode(phone: phone, code: code, reset: reset));

  Future<void> setPin(String setupToken, String pin,
      {bool remember = false}) async {
    final session = await _guard(
        () => _repository.setPin(setupToken: setupToken, pin: pin));
    await _save(session);
    await _goneOnline(pin: pin);
    await _keepDeviceSignIn(remember: remember);
    _keepLeadSessionSoon(session.profile);
  }

  Future<void> changePin(String currentPin, String newPin) async {
    final current = state.valueOrNull;
    if (current is! SignedIn) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    await _guard(() => _repository.changePin(
        token: current.session.token, currentPin: currentPin, newPin: newPin));
    await _goneOnline(pin: newPin);
  }

  /// Runs [call] with the current session token. A rejected session moves
  /// to the PIN screen and a suspended account to its screen, wherever the
  /// call was made from.
  Future<T> authorised<T>(Future<T> Function(String token) call) {
    final current = state.valueOrNull;
    if (current is! SignedIn) {
      return Future.error(const AuthFailure(AuthFailureKind.sessionExpired));
    }
    return _guard(() => call(current.session.token)).then((value) async {
      // The server answered with this session: no longer offline.
      await _offline.markOnline(_now());
      final now = state.valueOrNull;
      if (now is SignedIn && now.session.offline) {
        state =
            AsyncData(SignedIn(VendorSession(now.session.token, now.profile)));
      }
      return value;
    });
  }

  Future<void> updateProfile(VendorProfile profile) async {
    final current = state.valueOrNull;
    if (current is! SignedIn) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    final session = VendorSession(
      current.session.token,
      profile,
      offlineGrantId: current.session.offlineGrantId,
    );
    await _store.write(_profile, jsonEncode(profile.toJson()));
    state = AsyncData(SignedIn(session));
  }

  /// Ends the session on this phone. The server is told when it can be
  /// reached; signing out locally always succeeds.
  Future<void> signOut() async {
    unawaited(PhotoStore.clear());
    final current = state.valueOrNull;
    final phone = currentPhone;
    // The lead session goes first, while its own tokens still work.
    try {
      await ref.read(officeSessionProvider.notifier).endLeadSession();
    } catch (_) {}
    if (current is SignedIn) {
      try {
        await _repository.signOut(current.session.token);
      } catch (_) {}
    }
    await _clear(keepBiometric: true);
    await _offline.erase();
    state = AsyncData(SignedOut(phone));
  }

  /// Re-enter the account PIN without discarding unsent work or its grant.
  Future<void> lockForPin() async {
    final current = state.valueOrNull;
    if (current is! SignedIn) return;
    await _store.delete(_lastActive);
    ref.read(biometricUnlockedAccountProvider.notifier).state = null;
    state = AsyncData(Locked(current.profile, pinRequested: true));
  }

  /// The server rejected the session: ask for the PIN again.
  Future<void> expire() async {
    final current = state.valueOrNull;
    final profile = switch (current) {
      SignedIn(:final profile) => profile,
      Locked(:final profile) => profile,
      _ => null,
    };
    await _store.delete(_token);
    state = AsyncData(profile == null
        ? SignedOut(currentPhone)
        : Locked(profile, expired: true));
  }

  /// Records when the app was last in use, for the 12-hour PIN lock.
  Future<void> markActive() async {
    if (state.valueOrNull is SignedIn) {
      await _store.write(_lastActive, _now().toIso8601String());
    }
  }

  /// Called when the app returns to the foreground.
  Future<void> checkLock() async {
    final current = state.valueOrNull;
    if (current is! SignedIn) return;
    final lastActive = DateTime.tryParse(await _store.read(_lastActive) ?? '');
    if (lastActive == null ||
        _now().difference(lastActive) > await _lockAfter()) {
      state = AsyncData(Locked(current.profile));
    }
  }

  Future<void> _save(VendorSession session) async {
    await _store.write(_token, session.token);
    await _store.write(_profile, jsonEncode(session.profile.toJson()));
    await _store.write(_phone, session.profile.phone);
    await _store.write(_lastActive, _now().toIso8601String());
    ref.read(biometricUnlockedAccountProvider.notifier).state =
        biometricAccount('vendor', session.profile.id);
    await _devices.markLastSide(_side);
    state = AsyncData(SignedIn(session));
  }

  /// Forgets the session. Signing out keeps this phone's fingerprint choice
  /// for the account (it opens nothing without a live session, and the
  /// vendor expects it on when they sign in again); a suspension clears it.
  Future<void> _clear({bool keepBiometric = false}) async {
    try {
      await ref.read(officeSessionProvider.notifier).endLeadSession();
    } catch (_) {}
    final current = state.valueOrNull;
    final profile = switch (current) {
      SignedIn(:final profile) => profile,
      Locked(:final profile) => profile,
      _ => null,
    };
    if (!keepBiometric) {
      await _devices.delete(_side);
      ref.invalidate(savedDeviceSignInProvider(_side));
    }
    if (profile != null && !keepBiometric) {
      final account = biometricAccount('vendor', profile.id);
      await ref.read(biometricPreferencesProvider).clear(account);
      ref.invalidate(biometricEnabledProvider(account));
    }
    ref.read(biometricUnlockedAccountProvider.notifier).state = null;
    for (final key in [_token, _profile, _lastActive]) {
      await _store.delete(key);
    }
  }

  /// Runs a server call; a suspended account ends the session here so every
  /// screen reacts the same way.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthFailure catch (failure) {
      if (failure.kind == AuthFailureKind.suspended) {
        await _clear();
        await _offline.erase();
        state = const AsyncData(Suspended());
      } else if (failure.kind == AuthFailureKind.sessionExpired) {
        await expire();
      }
      rethrow;
    }
  }
}
