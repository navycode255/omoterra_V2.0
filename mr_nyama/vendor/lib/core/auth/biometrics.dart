import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../api/providers.dart';
import '../l10n/strings.dart';
import 'secure_store.dart';

/// Authentication stays with the OS. No PIN, biometric template or successful
/// unlock is persisted. This gate does not create or renew server sessions.
abstract class BiometricAuthenticator {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  /// The app's language, for the texts of the phone's own dialog.
  final Strings Function() strings;
  DeviceBiometricAuthenticator(this.strings);

  @override
  Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      final s = strings();
      return await _auth.authenticate(
          localizedReason: reason,
          authMessages: [
            AndroidAuthMessages(
                signInTitle: s.biometricPromptTitle,
                cancelButton: s.biometricPromptCancel),
          ],
          biometricOnly: true,
          persistAcrossBackgrounding: false);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
    (ref) => DeviceBiometricAuthenticator(() => ref.read(stringsProvider)));

/// How long the fingerprint lock waits: untouched in front of the user, or
/// away in the background (choosing a photo, answering a call). Owner's
/// decision, 31 October 2026.
const biometricIdleLock = Duration(minutes: 5);

/// Prevent the OS prompt's own lifecycle transitions from re-locking the UI.
final biometricPromptActiveProvider = StateProvider<bool>((_) => false);

// Memory only: a fresh successful app PIN also satisfies this local gate.
final biometricUnlockedAccountProvider = StateProvider<String?>((_) => null);
final biometricLockEpochProvider = StateProvider<int>((_) => 0);

String biometricAccount(String audience, String id) =>
    sha256.convert(utf8.encode('$apiUrl|$audience|$id')).toString();

class BiometricPreferences {
  final KeyValueStore store;
  BiometricPreferences(this.store);
  String _key(String account) => 'biometric_enabled_$account';
  Future<bool> enabled(String account) async =>
      await store.read(_key(account)) == '1';
  Future<void> enable(String account) => store.write(_key(account), '1');
  Future<void> clear(String account) => store.delete(_key(account));
}

final biometricPreferencesProvider = Provider<BiometricPreferences>(
    (ref) => BiometricPreferences(ref.read(keyValueStoreProvider)));

/// Whether this phone can check a fingerprint or face at all.
final biometricAvailableProvider = FutureProvider.autoDispose<bool>(
    (ref) => ref.read(biometricAuthenticatorProvider).available());
final biometricEnabledProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, account) =>
        ref.read(biometricPreferencesProvider).enabled(account));

/// One prompt at a time, shared by enrollment and the app gate.
Future<bool> authenticateBiometric(WidgetRef ref, String reason) async {
  final prompt = ref.read(biometricPromptActiveProvider.notifier);
  if (prompt.state) return false;
  final authenticator = ref.read(biometricAuthenticatorProvider);
  final epoch = ref.read(biometricLockEpochProvider.notifier);
  final startedAt = epoch.state;
  prompt.state = true;
  try {
    final authenticated = await authenticator.authenticate(reason);
    return authenticated && epoch.state == startedAt;
  } finally {
    prompt.state = false;
  }
}
