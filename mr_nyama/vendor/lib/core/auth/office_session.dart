import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/office_repository.dart';
import '../media/photo_cache.dart';
import 'biometrics.dart';
import 'lead_session.dart';
import 'device_sign_in.dart';
import '../api/providers.dart';
import '../api/vendor_repository.dart';

/// Office (staff) sign-in state. Separate from the vendor session: its own
/// tokens, its own screens under `/ofisi`, never the vendor tabs.
sealed class OfficeAuth {
  const OfficeAuth();
}

class OfficeSignedOut extends OfficeAuth {
  const OfficeSignedOut();
}

class OfficeSignedIn extends OfficeAuth {
  final StaffProfile profile;

  /// The session came from a seller who is an Outlet Lead (no office
  /// sign-in): it lives and ends with the seller session, has no
  /// fingerprint key, and opens only the lead's office pages.
  final bool viaLead;
  const OfficeSignedIn(this.profile, {this.viaLead = false});
}

final officeSessionProvider =
    AsyncNotifierProvider<OfficeSessionController, OfficeAuth>(
        OfficeSessionController.new);

class OfficeSessionController extends AsyncNotifier<OfficeAuth> {
  static const _profile = 'office_profile';
  static const _lead = 'office_via_lead';

  OfficeRepository get _repository => ref.read(officeRepositoryProvider);

  @override
  Future<OfficeAuth> build() async {
    final store = ref.read(keyValueStoreProvider);
    final saved = await store.read(_profile);
    if (saved == null || !await _repository.hasSession()) {
      return const OfficeSignedOut();
    }
    return OfficeSignedIn(
        StaffProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>),
        viaLead: await store.read(_lead) == '1');
  }

  /// Keeps the lead session issued from the seller session. Never touches
  /// the fingerprint keys or the "last side", and never replaces a real
  /// office sign-in. Returns whether it was kept.
  Future<bool> adoptLeadSession(LeadSession lead) async {
    final current = state.valueOrNull;
    if (current is OfficeSignedIn && !current.viaLead) return false;
    final repository = _repository;
    if (repository is! OfficeLeadRepository) return false;
    await (repository as OfficeLeadRepository).keepLeadTokens(lead.tokens);
    final store = ref.read(keyValueStoreProvider);
    await store.write(_profile, jsonEncode(lead.profile.toJson()));
    await store.write(_lead, '1');
    state = AsyncData(OfficeSignedIn(lead.profile, viaLead: true));
    return true;
  }

  /// Ends the lead session on this phone (the seller signed out, or is no
  /// longer a lead). The server ends it with the seller session; the call
  /// here is best effort. A real office sign-in is left alone.
  Future<void> endLeadSession() async {
    final current = await future;
    if (current is! OfficeSignedIn || !current.viaLead) return;
    try {
      await _repository.signOut();
    } catch (_) {}
    final store = ref.read(keyValueStoreProvider);
    await store.delete(_profile);
    await store.delete(_lead);
    state = const AsyncData(OfficeSignedOut());
  }

  /// [remember] is "Nikumbuke": after the PIN, the fingerprint signs in on
  /// this phone from now on.
  Future<void> signedIn(StaffProfile profile,
      {bool pinVerified = false, bool remember = false}) async {
    await ref
        .read(keyValueStoreProvider)
        .write(_profile, jsonEncode(profile.toJson()));
    await ref.read(keyValueStoreProvider).delete(_lead);
    final account = biometricAccount('staff', profile.id);
    if (pinVerified) {
      ref.read(biometricUnlockedAccountProvider.notifier).state = account;
    }
    await _devices.markLastSide(_side);
    state = AsyncData(OfficeSignedIn(profile));
    if (!pinVerified) return;
    // A PIN sign-in while the fingerprint is on keeps a fresh sign-in key
    // (a PIN reset ends the old one).
    final preferences = ref.read(biometricPreferencesProvider);
    if (remember) {
      await preferences.enable(account);
      ref.invalidate(biometricEnabledProvider(account));
    } else if (!await preferences.enabled(account)) {
      return;
    }
    await rememberDevice();
  }

  // Fingerprint sign-in after sign-out (MN024) ----------------------------

  static const _side = 'staff';
  DeviceSignInStore get _devices => ref.read(deviceSignInStoreProvider);

  /// Keeps a fingerprint sign-in key for the signed-in staff member on this
  /// phone. Best effort: without it the office sign-in asks for the PIN.
  Future<void> rememberDevice() async {
    final current = state.valueOrNull;
    final repository = _repository;
    // A lead session never gets a fingerprint key (the server refuses).
    if (current is! OfficeSignedIn ||
        current.viaLead ||
        repository is! OfficeDeviceKeyRepository) {
      return;
    }
    try {
      final key =
          await (repository as OfficeDeviceKeyRepository).issueDeviceKey();
      await _devices.save(
          _side,
          SavedDeviceSignIn(
              account: biometricAccount('staff', current.profile.id),
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
    if (state.valueOrNull is OfficeSignedIn &&
        repository is OfficeDeviceKeyRepository) {
      try {
        await (repository as OfficeDeviceKeyRepository).forgetDeviceKey();
      } catch (_) {}
    }
    await _devices.delete(_side);
    ref.invalidate(savedDeviceSignInProvider(_side));
  }

  /// Signs in after sign-out with the saved key, once the phone's fingerprint
  /// check passed. A key the server ended is forgotten (PIN next time).
  Future<void> signInWithFingerprint() async {
    final saved = await _devices.read(_side);
    final repository = _repository;
    if (saved == null || repository is! OfficeDeviceKeyRepository) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    try {
      final profile = await (repository as OfficeDeviceKeyRepository)
          .deviceSignIn(saved.key);
      await ref
          .read(keyValueStoreProvider)
          .write(_profile, jsonEncode(profile.toJson()));
      await ref.read(keyValueStoreProvider).delete(_lead);
      ref.read(biometricUnlockedAccountProvider.notifier).state =
          biometricAccount('staff', profile.id);
      await _devices.markLastSide(_side);
      state = AsyncData(OfficeSignedIn(profile));
    } on AuthFailure catch (failure) {
      if (failure.kind != AuthFailureKind.offline) {
        await _devices.delete(_side);
        ref.invalidate(savedDeviceSignInProvider(_side));
      }
      rethrow;
    }
  }

  Future<void> updateProfileImageUrl(String url) async {
    final current = state.valueOrNull;
    if (current is! OfficeSignedIn || current.viaLead) return;
    await signedIn(current.profile.copyWith(profileImageUrl: url));
  }

  Future<void> lockForPin() async {
    final current = state.valueOrNull;
    // A lead session is locked by the seller's lock, not by its own PIN.
    if (current is! OfficeSignedIn || current.viaLead) return;
    await ref.read(keyValueStoreProvider).delete(_profile);
    ref.read(officeFlowProvider.notifier).state =
        OfficeFlow(phone: current.profile.phone, localUnlock: true);
    ref.read(biometricUnlockedAccountProvider.notifier).state = null;
    state = const AsyncData(OfficeSignedOut());
  }

  Future<void> signOut() async {
    unawaited(PhotoStore.clear());
    await _repository.signOut();
    // The fingerprint choice stays for this account on this phone (it opens
    // nothing without a live session): signing in again keeps it on.
    ref.read(biometricUnlockedAccountProvider.notifier).state = null;
    await ref.read(keyValueStoreProvider).delete(_profile);
    await ref.read(keyValueStoreProvider).delete(_lead);
    state = const AsyncData(OfficeSignedOut());
  }

  /// Runs an office call; an ended session returns to the office sign-in.
  Future<T> guard<T>(
      Future<T> Function(OfficeRepository repository) call) async {
    try {
      return await call(_repository);
    } on AuthFailure catch (failure) {
      if (failure.kind == AuthFailureKind.sessionExpired ||
          failure.kind == AuthFailureKind.suspended) {
        await ref.read(keyValueStoreProvider).delete(_profile);
        await ref.read(keyValueStoreProvider).delete(_lead);
        state = const AsyncData(OfficeSignedOut());
      }
      rethrow;
    }
  }
}

/// Values carried between the office sign-in screens (memory only).
class OfficeFlow {
  final String? phone;
  final bool reset;
  final String? setupToken;
  final String? newPin;
  final bool mismatch;
  final bool localUnlock;

  /// "Nikumbuke" was ticked on the phone form.
  final bool remember;
  const OfficeFlow(
      {this.phone,
      this.reset = false,
      this.setupToken,
      this.newPin,
      this.mismatch = false,
      this.localUnlock = false,
      this.remember = false});

  OfficeFlow copyWith(
          {String? phone,
          bool? reset,
          String? setupToken,
          String? newPin,
          bool? mismatch}) =>
      OfficeFlow(
          phone: phone ?? this.phone,
          reset: reset ?? this.reset,
          setupToken: setupToken ?? this.setupToken,
          newPin: newPin ?? this.newPin,
          mismatch: mismatch ?? this.mismatch,
          localUnlock: localUnlock,
          remember: remember);

  /// Forgets the first PIN entry.
  OfficeFlow withoutPin({bool mismatch = false}) => OfficeFlow(
      phone: phone,
      reset: reset,
      setupToken: setupToken,
      mismatch: mismatch,
      localUnlock: localUnlock,
      remember: remember);
}

final officeFlowProvider =
    StateProvider<OfficeFlow>((ref) => const OfficeFlow());
