import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../shared/models/domain.dart';
import '../api/repository.dart';

final sessionProvider =
    AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);
final activeRoleProvider = StateProvider<String>((ref) => 'buyer');

class SessionController extends AsyncNotifier<AppUser?> {
  /// The splash stays up until startup work is done, so its duration follows
  /// what actually has to load rather than a fixed timer. The floor below only
  /// stops it flashing past when everything resolves instantly.
  ///
  /// It is counted from Flutter's first frame, not app start: Android's own
  /// launch screen covers everything before that, so a timer started earlier
  /// would elapse before anything of ours was drawn.
  static const _splashFloor = Duration(milliseconds: 600);
  static bool _shown = false;

  /// Disabled in tests, where a pending timer would outlive the widget tree
  /// and the delay serves no purpose.
  static bool holdSplash = true;

  @override
  Future<AppUser?> build() async {
    final first = holdSplash && !_shown;
    _shown = true;
    if (!first) return _restore();

    // Everything the first screens need is loaded here, while the splash is
    // on screen, so the user never watches images or config pop in later.
    final warmup = Future.wait([
      _floorFromFirstFrame(),
      _precacheArtwork(),
      _warmConfig(),
    ]);
    final user = await _restore();
    await warmup;
    return user;
  }

  Future<void> _floorFromFirstFrame() async {
    // endOfFrame completes after the next frame is rendered, so the hold is
    // measured from when the splash is actually on screen.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_splashFloor);
  }

  /// Decodes the photographs the welcome and home screens open with. Without
  /// this they decode on first paint and visibly fade in.
  Future<void> _precacheArtwork() async {
    const assets = [
      'assets/images/welcome.jpg',
      'assets/images/category_broilers.jpg',
      'assets/images/logo.png',
    ];
    await Future.wait(assets.map(_decode));
  }

  /// Resolves one asset into the image cache. A missing file is not fatal:
  /// BrandImage falls back to vector artwork, so startup continues.
  Future<void> _decode(String asset) {
    final completer = Completer<void>();
    final stream =
        AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void done() {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener((_, __) => done(),
        onError: (_, __) => done());
    stream.addListener(listener);
    return completer.future;
  }

  /// Server-driven configuration such as the enabled payment methods. A
  /// failure here must not block startup; the screens that need it fetch it
  /// again and surface their own errors.
  Future<void> _warmConfig() async {
    try {
      await ref.read(repositoryProvider).read('/config');
    } catch (_) {}
  }

  Future<AppUser?> _restore() async {
    // The offline design preview opens straight into the signed-in app so the
    // whole product can be browsed without a backend. Build with
    // --dart-define=PREVIEW_ONBOARDING=true to land on the phone screen
    // instead and walk the sign-up flow.
    if (localPreview && !previewOnboarding) {
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

  /// Switches the active role, enabling the capability first if the user
  /// doesn't have it yet. Shared by the Account screen and the top nav's
  /// role switcher so there is one implementation of "become a buyer" /
  /// "become a supplier", not two.
  Future<void> switchRole(String role) async {
    final user = state.value;
    if (user == null) return;
    if (!user.roles.contains(role)) {
      await profile({
        'name': user.name,
        'region': user.region,
        'language': user.language,
        'roles': {...user.roles, role}.toList(),
        'buyer_type': role == 'buyer' ? user.buyerType ?? 'personal' : user.buyerType
      });
    }
    ref.read(activeRoleProvider.notifier).state = role;
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
