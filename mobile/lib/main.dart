import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/router.dart';
import 'core/theme/theme.dart';
import 'core/auth/session.dart';
import 'core/notifications/notifications.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The page transition is adapted from Flutter Animation Gallery, whose
  // notice asks for in-app credit; it is listed with the other open-source
  // licenses under Account → Support → Open-source licenses.
  LicenseRegistry.addLicense(
      () => Stream.value(const LicenseEntryWithLineBreaks(
          ['Flutter Animation Gallery'],
          'Page transition (Size Animation 1) adapted from Flutter Animation '
          'Gallery. Credit: Flutter Animation Gallery.')));
  runApp(const ProviderScope(child: OmoterraApp()));
}

final _messenger = GlobalKey<ScaffoldMessengerState>();

class OmoterraApp extends ConsumerWidget {
  const OmoterraApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => NotificationsHost(
      router: ref.watch(routerProvider),
      messenger: _messenger,
      child: MaterialApp.router(
          title: 'Omoterra',
          scaffoldMessengerKey: _messenger,
          debugShowCheckedModeBanner: false,
          theme: omoterraTheme(),
          routerConfig: ref.watch(routerProvider),
          locale: Locale(ref.watch(sessionProvider).valueOrNull?.language ??
              ref.watch(selectedLanguageProvider)),
          supportedLocales: const [Locale('en'), Locale('sw')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates));
}
