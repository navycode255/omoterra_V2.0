import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session.dart';
import '../shared/widgets/biometric_lock.dart';
import '../core/l10n/language.dart';
import '../core/l10n/strings.dart';
import '../core/routing/router.dart';
import '../core/theme/theme.dart';
import '../dev/preview_repository.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_triggers.dart';
import '../features/notifications/push_coordinator.dart';
import '../features/sales/cart.dart';

class MrNyamaApp extends ConsumerStatefulWidget {
  const MrNyamaApp({super.key});

  @override
  ConsumerState<MrNyamaApp> createState() => _MrNyamaAppState();
}

class _MrNyamaAppState extends ConsumerState<MrNyamaApp> {
  /// Records when the app goes to the background and checks the 12-hour PIN
  /// lock when it returns.
  late final _lifecycle = AppLifecycleListener(
    onHide: () => ref.read(sessionProvider.notifier).markActive(),
    onShow: () async {
      await ref.read(sessionProvider.notifier).checkLock();
      ref.read(syncEngineProvider.notifier).requestSync();
      ref.read(pushCoordinatorProvider).sync();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    restoreLanguage(ref);
    ref.read(pushCoordinatorProvider).start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A cart never outlives the session it was built in.
    ref.listen(sessionProvider, (_, next) {
      if (next.valueOrNull is! SignedIn) {
        ref.read(cartProvider.notifier).clear();
      }
    });
    final router = ref.watch(routerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: MNColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp.router(
        title: ref.watch(stringsProvider).brand,
        debugShowCheckedModeBanner: false,
        theme: mrNyamaTheme(),
        routerConfig: router,
        locale: Locale(ref.watch(languageProvider)),
        supportedLocales: const [Locale('sw'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Sync triggers wrap every screen; preview builds are marked.
        builder: (context, child) => ListenableBuilder(
            listenable: router.routeInformationProvider,
            builder: (context, _) => Theme(
                data: router.routeInformationProvider.value.uri.path
                        .startsWith('/ofisi')
                    ? mrNyamaOfficeTheme(Theme.of(context))
                    : Theme.of(context),
                child: SyncTriggers(
                    child: BiometricLock(
                        child: devPreviewEnabled
                            ? PreviewBanner(child: child!)
                            : child!)))),
      ),
    );
  }
}
