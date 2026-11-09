import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/logo.dart';

/// The router owns initialization and leaves immediately when it completes.
/// This screen never starts authentication or holds navigation for animation.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: MNMotion.startupFade);
  Timer? _indicatorTimer;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    // Avoid flashing a spinner for a fast local session read. This timer only
    // reveals the indicator; it never delays initialization or navigation.
    _indicatorTimer = Timer(MNMotion.startupIndicatorDelay, () {
      if (mounted) setState(() => _showIndicator = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MNMotion.reduced(context)) {
      _fade.value = 1;
    } else if (_fade.status == AnimationStatus.dismissed) {
      _fade.forward();
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final vendor = ref.watch(sessionProvider);
    final office = ref.watch(officeSessionProvider);
    final pending = vendor.isLoading || office.isLoading;
    final reduced = MNMotion.reduced(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: MNColors.startupBlack,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: MNColors.startupBlack,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: MNColors.startupBlack,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: MNColors.startupBlack,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final size = (constraints.maxWidth * .76)
                .clamp(0.0, constraints.maxHeight * .55)
                .clamp(0.0, 360.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: FadeTransition(
                    opacity: _fade,
                    // Includes the original lettering and tagline. Do not
                    // typeset duplicates or reinterpret the official mark.
                    child: MNLogo(
                        height: size, full: true, semanticLabel: strings.brand),
                  ),
                ),
                if (pending && _showIndicator && !reduced)
                  Positioned(
                    top: constraints.maxHeight * .79,
                    left: constraints.maxWidth * .38,
                    right: constraints.maxWidth * .38,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(MNRadius.handle),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: MNColors.red,
                        backgroundColor: MNColors.muted,
                        semanticsLabel: strings.loading,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
