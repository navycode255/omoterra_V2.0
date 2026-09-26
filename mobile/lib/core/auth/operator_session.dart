import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/repository.dart';

/// An Omoterra operator signed in from the app to register buyers and
/// suppliers. Kept apart from the marketplace session: the same phone can be
/// signed in as a buyer and as staff, and signing out of one leaves the
/// other.
final operatorSessionProvider =
    AsyncNotifierProvider<OperatorSessionController, Map<String, dynamic>?>(
        OperatorSessionController.new);

const operatorSessionKey = 'operator_session';

class OperatorSessionController extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    if (await storage.read(key: operatorSessionKey) == null) return null;
    try {
      return Map<String, dynamic>.from(
          await ref.read(repositoryProvider).read('/mobile-admin/me'));
    } catch (_) {
      // Expired or revoked: sign in again with the passphrase.
      await storage.delete(key: operatorSessionKey);
      return null;
    }
  }

  /// Checks the passphrase and sends a code to the operator's phone.
  Future<Map<String, dynamic>> start(String passphrase, String phone) async =>
      Map<String, dynamic>.from(await ref.read(repositoryProvider).write(
          '/mobile-admin/auth/otp',
          {'passphrase': passphrase, 'phone': phone}));

  Future<void> verify(String challengeId, String code) async {
    final response = await ref.read(repositoryProvider).write(
        '/mobile-admin/auth/verify',
        {'challenge_id': challengeId, 'code': code});
    await storage.write(
        key: operatorSessionKey, value: response['session_token'] as String);
    state = AsyncData(Map<String, dynamic>.from(response['operator']));
  }

  Future<void> signOut() async {
    try {
      await ref.read(repositoryProvider).write('/mobile-admin/auth/logout', {});
    } catch (_) {
      // Signing out locally still ends access from this phone.
    }
    await storage.delete(key: operatorSessionKey);
    state = const AsyncData(null);
  }
}
