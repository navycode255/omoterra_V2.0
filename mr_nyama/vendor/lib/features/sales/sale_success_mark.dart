import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../shared/motion/fire.dart';
import '../../shared/motion/played_effects.dart';

/// Signature A: a small charcoal flame ignites, rises briefly and gives way
/// to the confirmation check (~800 ms). Shown only after the sale is saved
/// on the phone; it never blocks the buttons, plays once per sale ([playId])
/// and shows the finished mark under reduced motion.
///
///   0–420 ms   flame (four close burners, srcOver on white)
///   380–640    brand-red circle scales in (.6 → 1, ease out, no bounce)
///   540–760    check draws itself (design `m-check`, 220 ms)
class SaleSuccessMark extends ConsumerStatefulWidget {
  final String playId;
  final double size;

  /// The settled mark's circle and check. The Kikapu sent sheet settles into
  /// a soft green circle with a green check (reference, 22 October 2026).
  final Color circleColor;
  final Color checkColor;

  /// Check size relative to the mark and its stroke (null: the original).
  final double checkScale;
  final double? checkStroke;
  const SaleSuccessMark(
      {super.key,
      required this.playId,
      this.size = MNSize.hero,
      this.circleColor = MNColors.red,
      this.checkColor = MNColors.white,
      this.checkScale = .62,
      this.checkStroke});

  /// Total length of the mark's own timeline.
  static const duration = MNMotion.saleSuccess;

  @override
  ConsumerState<SaleSuccessMark> createState() => _SaleSuccessMarkState();
}

class _SaleSuccessMarkState extends ConsumerState<SaleSuccessMark>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: SaleSuccessMark.duration);
  bool _play = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.value > 0) return;
    final played = ref.read(playedEffectsProvider);
    if (MNMotion.reduced(context) || played.contains(widget.playId)) {
      _controller.value = 1;
      return;
    }
    played.add(widget.playId);
    _play = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _segment(double ms, double start, double length) =>
      ((ms - start) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          // The flame burns first; the circle grows over it, keeping the
          // check clean.
          if (_play)
            // The flame rises from the lower part of the mark.
            Positioned(
              left: 0,
              right: 0,
              bottom: size * .1,
              height: size * 112 / 96,
              child: IgnorePointer(
                  child: FireCanvas(spec: FireSpec.saleSuccess())),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final ms = _controller.value * 800;
              final grow = MNMotion.easeOut.transform(_segment(ms, 380, 260));
              final draw = MNMotion.easeOut.transform(_segment(ms, 540, 220));
              return Opacity(
                opacity: grow,
                child: Transform.scale(
                  scale: .6 + .4 * grow,
                  child: CustomPaint(
                      size: Size.square(size),
                      painter: _CheckPainter(
                          draw,
                          widget.circleColor,
                          widget.checkColor,
                          widget.checkScale,
                          widget.checkStroke)),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color circle;
  final Color check;
  final double scale;
  final double? stroke;
  _CheckPainter(
      this.progress, this.circle, this.check, this.scale, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.drawCircle(Offset(r, r), r, Paint()..color = circle);
    if (progress == 0) return;
    // The design system's check path (5,12.5 → 9.5,17 → 19,7 on 24 px).
    final u = size.width / 24 * scale;
    final o = Offset(r - 12 * u, r - 12 * u);
    final path = Path()
      ..moveTo(o.dx + 5 * u, o.dy + 12.5 * u)
      ..lineTo(o.dx + 9.5 * u, o.dy + 17 * u)
      ..lineTo(o.dx + 19 * u, o.dy + 7 * u);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = check
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke ?? 2 * u * 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.circle != circle || old.check != check;
}
