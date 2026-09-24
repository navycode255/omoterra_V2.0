import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/motion.dart';

/// Route-owned animation: no second entrance around the shell's Navigator.
GoRoute omoterraRoute({
  required String path,
  bool animate = true,
  required Widget Function(BuildContext, GoRouterState) builder,
}) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) {
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        // Hero flights paint above the route clip and would mix both pages.
        final child = HeroMode(enabled: false, child: builder(context, state));
        if (!animate || reducedMotion) {
          return NoTransitionPage<void>(key: state.pageKey, child: child);
        }
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: reducedMotion ? Duration.zero : AppMotion.page,
          reverseTransitionDuration:
              reducedMotion ? Duration.zero : AppMotion.pageReverse,
          child: child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SizePageTransition(animation: animation, child: child),
        );
      },
    );
