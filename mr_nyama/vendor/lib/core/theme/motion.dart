import 'package:flutter/material.dart';

/// Mr. Nyama motion system v1, copied from the approved design export.
/// Every animated widget reads its duration through [MNMotion.of] so reduced
/// motion turns it off in one place.
class MNMotion {
  // Startup branding fade and progress reveal; neither gates navigation.
  static const startupFade = Duration(milliseconds: 300);
  static const startupIndicatorDelay = Duration(milliseconds: 300);

  static const instant = Duration(milliseconds: 100);
  static const small = Duration(milliseconds: 150);
  static const sheet = Duration(milliseconds: 220);
  static const page = Duration(milliseconds: 220);
  static const confirm = Duration(milliseconds: 300);
  static const exit = Duration(milliseconds: 140);

  // Component-level values from the same file.
  static const keyPress = Duration(milliseconds: 90);
  static const cardPress = Duration(milliseconds: 120);
  static const tabIn = Duration(milliseconds: 150);
  static const fadeIn = Duration(milliseconds: 200);
  static const fadeOut = Duration(milliseconds: 120);
  static const sheetOut = Duration(milliseconds: 180);
  static const cartIn = Duration(milliseconds: 260);
  static const cartOut = Duration(milliseconds: 160);
  static const navPop = Duration(milliseconds: 180);
  static const valueRoll = Duration(milliseconds: 160);
  static const rise = Duration(milliseconds: 240);
  static const shake = Duration(milliseconds: 280);
  static const skeleton = Duration(milliseconds: 1200);
  static const spin = Duration(milliseconds: 800);

  /// Product photo loading ring: the arc grows and shrinks once per breath,
  /// and the ring only appears once a photo has taken [imageSpinnerDelay], so
  /// fast or cached photos never flash it.
  static const imageSpinnerBreath = Duration(milliseconds: 1600);
  static const imageSpinnerDelay = Duration(milliseconds: 150);
  static const radio = Duration(milliseconds: 160);

  /// How long the Kikapu undo snackbar ("Rudisha") stays up.
  static const undoWindow = Duration(seconds: 4);

  /// Refresh the displayed server retry deadline; never extends the lockout.
  static const retryCountdownTick = Duration(seconds: 1);

  /// Interim sale confirmation: check draw (60 ms delay + 220 ms) over the
  /// 260 ms scale-in.
  static const confirmMark = Duration(milliseconds: 280);

  /// Signature A, sale saved: flame to check.
  static const saleSuccess = Duration(milliseconds: 800);

  // Signature B (Funga Siku) layer timings from the prototype.
  static const logoIn = Duration(milliseconds: 320);
  static const fireGlowFade = Duration(milliseconds: 500);
  static const fireUnderglowFade = Duration(milliseconds: 600);
  static const fireHaloFade = Duration(milliseconds: 900);
  static const fireHaloScale = Duration(milliseconds: 1200);

  /// Gap between the two haptic taps (spec 10·60·18 ms).
  static const hapticGap = Duration(milliseconds: 70);

  static const easeOut = Cubic(.2, .8, .2, 1);
  static const easeIn = Cubic(.4, 0, 1, 1);
  static const standard = Cubic(.2, 0, 0, 1);
  static const spring = Cubic(.34, 1.36, .64, 1);

  /// Press feedback scales (transform + colour only).
  static const pressButton = .98;
  static const pressKey = .94;
  static const pressQuantity = .90;
  static const pressCard = .97;
  static const pressChip = .96;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when the system asks for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Push/pop transition (`m-push-in/out`, `m-pop-in/out`): the new page slides
/// 32 px from the right and fades in over 220 ms; the page underneath moves
/// 24 px left and fades out. Popping mirrors it in 140 ms.
class MNPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  const MNPageTransition(
      {super.key,
      required this.animation,
      required this.secondaryAnimation,
      required this.child});

  @override
  Widget build(BuildContext context) {
    if (MNMotion.reduced(context)) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final forward = animation.status != AnimationStatus.reverse;
        // Entering on push, leaving on pop.
        final t = (forward ? MNMotion.easeOut : MNMotion.easeIn)
            .transform(animation.value);
        final dx = forward ? 32 * (1 - t) : 24 * (1 - t);
        // Covered by a pushed page, or uncovered when it pops.
        final covering = secondaryAnimation.status != AnimationStatus.reverse;
        final s = (covering ? MNMotion.easeIn : MNMotion.easeOut)
            .transform(secondaryAnimation.value);
        final under = covering ? -24 * s : -32 * s;
        return Opacity(
          opacity: (t * (1 - s)).clamp(0, 1),
          child:
              Transform.translate(offset: Offset(dx + under, 0), child: child),
        );
      },
    );
  }
}

/// Tab switch (`m-tab-in`): the new tab rises 4 px and fades in over 150 ms.
/// The old tab leaves without animation.
class MNTabTransition extends StatefulWidget {
  final int index;
  final Widget child;
  const MNTabTransition({super.key, required this.index, required this.child});

  @override
  State<MNTabTransition> createState() => _MNTabTransitionState();
}

class _MNTabTransitionState extends State<MNTabTransition>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: MNMotion.tabIn, value: 1);
  late final _curve =
      CurvedAnimation(parent: _controller, curve: MNMotion.easeOut);

  @override
  void didUpdateWidget(covariant MNTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !MNMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Opacity(
            opacity: _curve.value,
            child: Transform.translate(
                offset: Offset(0, 4 * (1 - _curve.value)), child: child)),
      );
}

/// Sheet timing (`m-sheet-in/out`, scrim fade): 220 ms in, 180 ms out.
AnimationStyle mnSheetAnimation(BuildContext context) =>
    MNMotion.reduced(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: MNMotion.sheet,
            reverseDuration: MNMotion.sheetOut,
            curve: MNMotion.easeOut,
            reverseCurve: MNMotion.easeIn);

/// Staggered entrance (`m-rise`): 8 px rise and fade over 240 ms, delayed in
/// 40 ms steps by [order] (0–6).
class MNRise extends StatelessWidget {
  final int order;
  final Widget child;
  const MNRise({super.key, this.order = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MNMotion.reduced(context)) return child;
    final delay = 40.0 * order.clamp(0, 6);
    final total = delay + MNMotion.rise.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total.round()),
      child: child,
      builder: (context, v, child) {
        final t = MNMotion.easeOut.transform(
            ((v * total - delay) / MNMotion.rise.inMilliseconds)
                .clamp(0.0, 1.0));
        return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, 8 * (1 - t)), child: child));
      },
    );
  }
}
