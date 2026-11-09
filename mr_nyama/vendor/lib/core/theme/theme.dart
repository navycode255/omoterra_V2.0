import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';

export 'icon_data.dart';
export 'motion.dart';
export 'tokens.dart';

/// Material theme built only from [MNColors], [MNText] and [MNSize], so that
/// stock Material widgets (dialogs, text selection, scroll glow) match the
/// design system. Mr. Nyama components style themselves from the same tokens.
ThemeData mrNyamaTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: MNColors.red,
    onPrimary: MNColors.white,
    secondary: MNColors.black,
    onSecondary: MNColors.white,
    error: MNColors.error,
    onError: MNColors.white,
    surface: MNColors.white,
    onSurface: MNColors.ink,
    surfaceContainerHighest: MNColors.surface,
    outline: MNColors.borderStrong,
    outlineVariant: MNColors.border,
    scrim: MNColors.scrim,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: MNColors.white,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _MNPageTransitions(),
      TargetPlatform.iOS: _MNPageTransitions(),
    }),
    textTheme: TextTheme(
      headlineMedium: MNText.amountLarge,
      titleLarge: MNText.heading,
      titleMedium: MNText.title,
      bodyLarge: MNText.body,
      bodyMedium: MNText.secondary,
      labelLarge: MNText.button,
      labelMedium: MNText.label,
      bodySmall: MNText.meta,
    ),
    dividerTheme:
        const DividerThemeData(color: MNColors.border, thickness: 1, space: 1),
    textSelectionTheme: const TextSelectionThemeData(
        cursorColor: MNColors.ink,
        selectionColor: MNColors.selection,
        selectionHandleColor: MNColors.red),
    dialogTheme: DialogThemeData(
        backgroundColor: MNColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MNRadius.sheet))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MNColors.white,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: MNColors.scrim,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(MNRadius.sheet)))),
    // `.toast`: black, 12 px radius, 600 15/20, 16 px from the edges.
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MNColors.black,
        contentTextStyle: MNText.note.copyWith(color: MNColors.white),
        insetPadding: const EdgeInsets.all(MNSpace.x4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MNRadius.medium))),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: MNColors.red),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

class _MNPageTransitions extends PageTransitionsBuilder {
  const _MNPageTransitions();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      MNPageTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child);
}

/// Office routes, including their dialogs and sheets, use the approved face.
ThemeData mrNyamaOfficeTheme(ThemeData base) {
  final family = OwnerStyle.fontFamily(base.platform, 17);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    scaffoldBackgroundColor: OwnerStyle.background,
    snackBarTheme: base.snackBarTheme.copyWith(
        contentTextStyle:
            base.snackBarTheme.contentTextStyle?.copyWith(fontFamily: family)),
  );
}
