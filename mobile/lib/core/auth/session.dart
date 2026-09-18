import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/painting.dart';
import '../../shared/models/domain.dart';
import '../api/repository.dart';

final sessionProvider =
    AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);
final activeRoleProvider = StateProvider<String>((ref) => 'buyer');

class SessionController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    // The offline design preview opens straight into the signed-in app; there
    // is no server to hold a session against.
    if (localPreview) {
      return AppUser.fromJson(Map<String, dynamic>.from(
          await ref.read(repositoryProvider).read('/me')));
    }
    final token = await storage.read(key: 'session');
    if (token == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(
        await ref.read(repositoryProvider).read('/me')));
  }

  Future<void> verify(String challenge, String code) async {
    final response = await ref
        .read(repositoryProvider)
        .write('/auth/verify', {'challenge_id': challenge, 'code': code});
    await storage.write(key: 'session', value: response['access_token']);
    state = AsyncData(
        AppUser.fromJson(Map<String, dynamic>.from(response['user'])));
  }

  Future<void> profile(Map<String, dynamic> data) async {
    final response =
        await ref.read(repositoryProvider).write('/me', data, method: 'PUT');
    state = AsyncData(AppUser.fromJson(Map<String, dynamic>.from(response)));
  }

  Future<void> logout() async {
    try {
      await ref.read(repositoryProvider).write('/auth/logout', {});
    } finally {
      await storage.delete(key: 'session');
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ref.invalidate(resourceProvider);
      ref.invalidate(listingsProvider);
      state = const AsyncData(null);
    }
  }
}
