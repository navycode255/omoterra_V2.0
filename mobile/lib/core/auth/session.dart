import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../shared/models/domain.dart';
import '../api/repository.dart';

final sessionProvider =
    AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);
final activeRoleProvider = StateProvider<String>((ref) => 'buyer');
final selectedLanguageProvider = StateProvider<String>((ref) => 'en');
final greetingUntilProvider = StateProvider<DateTime?>((ref) => null);

String preferredRole(List<String> roles, String? saved) => roles.contains(saved)
    ? saved!
    : roles.contains('buyer')
        ? 'buyer'
        : 'supplier';

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
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void done() {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    }

    listener =
        ImageStreamListener((_, __) => done(), onError: (_, __) => done());
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
    final greetingAt = await storage.read(key: 'signed_in_at');
    final signedInAt = DateTime.tryParse(greetingAt ?? '');
    final greetingDeadline = signedInAt?.add(const Duration(minutes: 2));
    ref.read(greetingUntilProvider.notifier).state =
        greetingDeadline != null && greetingDeadline.isAfter(DateTime.now())
            ? greetingDeadline
            : null;
    final savedLanguage = await storage.read(key: 'selected_language');
    if (savedLanguage == 'en' || savedLanguage == 'sw') {
      ref.read(selectedLanguageProvider.notifier).state = savedLanguage!;
    }
    // The offline design preview opens straight into the signed-in app so the
    // whole product can be browsed without a backend. Build with
    // --dart-define=PREVIEW_ONBOARDING=true to land on the phone screen
    // instead and walk the sign-up flow.
    if (!(localPreview && !previewOnboarding)) {
      final token = await storage.read(key: 'session');
      if (token == null) return null;
    }
    final user = AppUser.fromJson(Map<String, dynamic>.from(
        await ref.read(repositoryProvider).read('/me')));
    await _restoreRole(user);
    return user;
  }

  Future<void> _restoreRole(AppUser user) async {
    final saved = await storage.read(key: 'active_role:${user.id}');
    ref.read(activeRoleProvider.notifier).state =
        preferredRole(user.roles, saved);
  }

  Future<void> verify(String challenge, String code) async {
    final response = await ref
        .read(repositoryProvider)
        .write('/auth/verify', {'challenge_id': challenge, 'code': code});
    await storage.write(key: 'session', value: response['access_token']);
    final user = AppUser.fromJson(Map<String, dynamic>.from(response['user']));
    await _restoreRole(user);
    final signedInAt = DateTime.now();
    await storage.write(
        key: 'signed_in_at', value: signedInAt.toIso8601String());
    ref.read(greetingUntilProvider.notifier).state =
        signedInAt.add(const Duration(minutes: 2));
    state = AsyncData(user);
  }

  Future<void> profile(Map<String, dynamic> data) async {
    final response =
        await ref.read(repositoryProvider).write('/me', data, method: 'PUT');
    final user = AppUser.fromJson(Map<String, dynamic>.from(response));
    await _restoreRole(user);
    state = AsyncData(user);
  }

  Future<void> setLanguage(String language) async {
    if (language != 'en' && language != 'sw') {
      throw ArgumentError.value(language, 'language');
    }
    await storage.write(key: 'selected_language', value: language);
    ref.read(selectedLanguageProvider.notifier).state = language;
  }

  Future<void> acceptRegisteredRole(dynamic response, String role) async {
    final user = AppUser.fromJson(Map<String, dynamic>.from(response));
    await _restoreRole(user);
    state = AsyncData(user);
    await switchRole(role);
  }

  /// Change only between capabilities already registered on this account.
  Future<void> switchRole(String role) async {
    if (role != 'buyer' && role != 'supplier') {
      throw ArgumentError.value(role, 'role');
    }
    final user = state.value;
    if (user == null) return;
    if (!user.roles.contains(role)) {
      throw StateError('Register this account as $role before switching.');
    }
    await storage.write(key: 'active_role:${user.id}', value: role);
    ref.read(activeRoleProvider.notifier).state = role;
  }

  Future<void> logout() async {
    try {
      await ref.read(repositoryProvider).write('/auth/logout', {});
    } finally {
      await storage.delete(key: 'session');
      await storage.delete(key: 'signed_in_at');
      ref.read(greetingUntilProvider.notifier).state = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ref.invalidate(resourceProvider);
      ref.invalidate(listingsProvider);
      state = const AsyncData(null);
    }
  }
}
