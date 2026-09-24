import 'package:flutter/material.dart';

class AppMotion {
  static const page = Duration(milliseconds: 280);
  static const pageReverse = Duration(milliseconds: 200);
  static const control = Duration(milliseconds: 300);
  static const quick = Duration(milliseconds: 180);
  static const enter = Cubic(0.20, 0.85, 0.25, 1);
  static const settle = Cubic(0.22, 1, 0.36, 1);
}

/// Size Animation 1, adapted from the user-supplied Flutter Animation Gallery
/// example. Credit: Flutter Animation Gallery (see THIRD_PARTY_NOTICES.md).
/// A paint-only clip keeps layout fixed; an opaque backdrop isolates the route.
class SizePageTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  const SizePageTransition(
      {super.key, required this.animation, required this.child});

  @override
  State<SizePageTransition> createState() => _SizePageTransitionState();
}

class _SizePageTransitionState extends State<SizePageTransition> {
  late CurvedAnimation _curve;

  void _attachCurve() {
    _curve = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.fastLinearToSlowEaseIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
  }

  @override
  void initState() {
    super.initState();
    _attachCurve();
  }

  @override
  void didUpdateWidget(covariant SizePageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curve.dispose();
      _attachCurve();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: widget.animation,
          child: ClipRect(
            clipper: _BottomRevealClipper(_curve),
            child: RepaintBoundary(child: widget.child),
          ),
          builder: (context, child) => IgnorePointer(
            ignoring: widget.animation.status != AnimationStatus.completed,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BottomRevealClipper extends CustomClipper<Rect> {
  final Animation<double> progress;
  _BottomRevealClipper(this.progress) : super(reclip: progress);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
      0, size.height * (1 - progress.value), size.width, size.height);

  @override
  bool shouldReclip(covariant _BottomRevealClipper oldClipper) =>
      progress != oldClipper.progress;
}
