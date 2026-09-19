import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../shared/models/domain.dart';
import '../api/repository.dart';

final sessionProvider =
    AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);
final activeRoleProvider = StateProvider<String>((ref) => 'buyer');

class SessionController extends AsyncNotifier<AppUser?> {
  /// The splash is shown while this resolves. Restoring a session is usually
  /// instantaneous, which would flash the brand past too quickly to read, so
  /// the first resolution is held to this floor. Real work runs concurrently,
  /// so a slow restore is never delayed by it.
  ///
  /// The floor is counted from Flutter's first frame, not from app start:
  /// Android's own launch screen covers everything before that, and on a debug
  /// build the engine can take several seconds to boot, which would otherwise
  /// consume the whole window before anything is drawn.
  static const _splashFloor = Duration(milliseconds: 1600);
  static bool _shown = false;

  /// Disabled in tests, where a pending timer would outlive the widget tree
  /// and the delay serves no purpose.
  static bool holdSplash = true;

  @override
  Future<AppUser?> build() async {
    final hold = holdSplash && !_shown;
    _shown = true;
    final floor = hold ? _floorFromFirstFrame() : Future<void>.value();
    final user = await _restore();
    await floor;
    return user;
  }

  Future<void> _floorFromFirstFrame() async {
    // endOfFrame completes after the next frame is rendered, so the hold is
    // measured from when the splash is actually on screen.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_splashFloor);
  }

  Future<AppUser?> _restore() async {
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
