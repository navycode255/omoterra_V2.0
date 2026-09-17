import 'package:flutter/material.dart';

class OColors {
  static const forest = Color(0xFF123D2D),
      pressed = Color(0xFF0B2E21),
      soft = Color(0xFFEEF5F0),
      pale = Color(0xFFF5F8F6),
      background = Color(0xFFFAFBF9),
      ink = Color(0xFF17201B),
      secondary = Color(0xFF657069),
      muted = Color(0xFF909A94),
      border = Color(0xFFE3E9E5),
      positive = Color(0xFF267A52),
      warning = Color(0xFFB87822),
      error = Color(0xFFB94747);
}

ThemeData omoterraTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: OColors.forest,
      primary: OColors.forest,
      surface: OColors.background,
      error: OColors.error);
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: OmoterraTransitions(),
      TargetPlatform.iOS: OmoterraTransitions()
    }),
    colorScheme: scheme,
    scaffoldBackgroundColor: OColors.background,
    fontFamily: 'Manrope',
    textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, color: OColors.ink),
        headlineMedium: TextStyle(
            fontSize: 25, fontWeight: FontWeight.w700, color: OColors.ink),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, color: OColors.secondary)),
    appBarTheme: const AppBarTheme(
        backgroundColor: OColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: OColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: OColors.border))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: OColors.border))),
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white, indicatorColor: OColors.soft),
    dividerTheme: const DividerThemeData(color: OColors.border),
  );
}

class OmoterraTransitions extends PageTransitionsBuilder {
  const OmoterraTransitions();
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
        child: SlideTransition(
            position: animation.drive(
                Tween(begin: const Offset(.025, 0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic))),
            child: child));
  }
}
