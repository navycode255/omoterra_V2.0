import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/office_repository.dart' show StaffProfile;
import '../api/providers.dart';
import '../api/vendor_repository.dart' show VendorSession;
import 'biometrics.dart';
import 'secure_store.dart';

/// Fingerprint sign-in after sign-out (MN024, owner decision 29 October
/// 2026, "like a bank app"). Turning the fingerprint on asks the server for a
/// sign-in key for this phone; it lives only in secure storage and is
/// released only after the phone's own fingerprint check, then exchanged for
/// a new session. The PIN is never stored. Signing out keeps the key; the
/// server ends it on a PIN reset, phone change, suspension, leaving,
/// deletion, staff "end sessions" or misuse, and turning the fingerprint off
/// ends it on both sides.
///
/// "Nikumbuke" on the sign-in form (owner decision 30 October 2026) does the
/// same as turning the fingerprint on, right after a correct PIN. A
/// remembered phone opens on "Karibu tena" and asks for the fingerprint by
/// itself, with the PIN one tap away; the side signed in to last (vendor or
/// office) opens first.

abstract interface class VendorDeviceKeyRepository {
  /// A key for the signed-in vendor on this phone.
  Future<String> issueDeviceKey();
  Future<void> forgetDeviceKey();

  /// A new session for the key's owner (no session needed).
  Future<VendorSession> deviceSignIn(String key);
}

abstract interface class OfficeDeviceKeyRepository {
  Future<String> issueDeviceKey();
  Future<void> forgetDeviceKey();
  Future<StaffProfile> deviceSignIn(String key);
}

/// What the sign-in screen needs to offer the fingerprint: whose key it is.
class SavedDeviceSignIn {
  /// `biometricAccount(audience, id)`, to match the fingerprint opt-in.
  final String account;
  final String key, name, phone;
  const SavedDeviceSignIn(
      {required this.account,
      required this.key,
      required this.name,
      required this.phone});
}

class DeviceSignInStore {
  final KeyValueStore store;
  DeviceSignInStore(this.store);

  /// One key per side (vendor, office) on this phone.
  String _key(String audience) => 'device_sign_in_$audience';

  Future<SavedDeviceSignIn?> read(String audience) async {
    final raw = await store.read(_key(audience));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return SavedDeviceSignIn(
          account: j['account'] as String,
          key: j['key'] as String,
          name: j['name'] as String? ?? '',
          phone: j['phone'] as String? ?? '');
    } catch (_) {
      await store.delete(_key(audience));
      return null;
    }
  }

  Future<void> save(String audience, SavedDeviceSignIn saved) => store.write(
      _key(audience),
      jsonEncode({
        'account': saved.account,
        'key': saved.key,
        'name': saved.name,
        'phone': saved.phone,
      }));

  Future<void> delete(String audience) => store.delete(_key(audience));

  /// "Kumbuka namba hii": the number the side's phone form starts with.
  String _numberKey(String audience) => 'remember_number_$audience';
  Future<String?> rememberedNumber(String audience) =>
      store.read(_numberKey(audience));
  Future<void> keepNumber(String audience, String? phone) => phone == null
      ? store.delete(_numberKey(audience))
      : store.write(_numberKey(audience), phone);

  static const _lastSide = 'sign_in_last_side';

  /// The side ('vendor' or 'staff') signed in to last on this phone.
  Future<String?> lastSide() => store.read(_lastSide);
  Future<void> markLastSide(String audience) =>
      store.write(_lastSide, audience);
}

final deviceSignInStoreProvider = Provider<DeviceSignInStore>(
    (ref) => DeviceSignInStore(ref.read(keyValueStoreProvider)));

/// The saved fingerprint sign-in of one side, for the sign-in screens.
final savedDeviceSignInProvider = FutureProvider.autoDispose
    .family<SavedDeviceSignIn?, String>(
        (ref, audience) => ref.read(deviceSignInStoreProvider).read(audience));

/// The account a sign-in screen opens on: a saved key whose fingerprint is
/// still on, on a phone that can check one. Null shows the phone form.
final rememberedSignInProvider = FutureProvider.autoDispose
    .family<SavedDeviceSignIn?, String>((ref, audience) async {
  final saved = await ref.watch(savedDeviceSignInProvider(audience).future);
  if (saved == null) return null;
  if (!await ref.watch(biometricEnabledProvider(saved.account).future)) {
    return null;
  }
  return await ref.watch(biometricAvailableProvider.future) ? saved : null;
});

/// "Si wewe?" was chosen: the side shows the phone form for someone else
/// until its sign-in screens close.
final otherAccountProvider =
    StateProvider.autoDispose.family<bool, String>((ref, audience) => false);

/// The side signed in to last, read once when the app opens.
final lastSignInSideProvider = FutureProvider<String?>(
    (ref) => ref.read(deviceSignInStoreProvider).lastSide());

/// The vendor sign-in moved to the office one at most once per app start.
final lastSideAppliedProvider = StateProvider<bool>((ref) => false);

/// The number "Kumbuka namba hii" kept for a side's phone form.
final rememberedNumberProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, audience) =>
        ref.read(deviceSignInStoreProvider).rememberedNumber(audience));
