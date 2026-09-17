import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/router.dart';
import 'core/theme/theme.dart';
import 'core/auth/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OmoterraApp()));
}

class OmoterraApp extends ConsumerWidget {
  const OmoterraApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
      title: 'Omoterra',
      debugShowCheckedModeBanner: false,
      theme: omoterraTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: Locale(ref.watch(sessionProvider).valueOrNull?.language ?? 'en'),
      supportedLocales: const [Locale('en'), Locale('sw')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates);
}
