import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Soft botanical decoration for the supplier screens: leaves, card waves,
/// hills and clouds. Drawn as vectors so they stay crisp on every screen and
/// cost no download.

const leafLight = Color(0xFFDCEBDF);
const leafMid = Color(0xFFC5DCC9);
const leafDeep = Color(0xFF9FC3A6);

/// One pointed leaf with a centre vein, pointing up before [angle] (radians).
class Leaf extends StatelessWidget {
  final double size;
  final double angle;
  final Color color;
  const Leaf({super.key, this.size = 40, this.angle = 0, this.color = leafMid});
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: Transform.rotate(
          angle: angle,
          child: CustomPaint(
              size: Size(size * .55, size), painter: _LeafPainter(color))));
}

class _LeafPainter extends CustomPainter {
  final Color color;
  _LeafPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final leaf = Path()
      ..moveTo(w * .5, h)
      ..cubicTo(-w * .05, h * .72, w * .02, h * .22, w * .5, 0)
      ..cubicTo(w * .98, h * .22, w * 1.05, h * .72, w * .5, h)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);
    canvas.drawPath(
        Path()
          ..moveTo(w * .5, h * .98)
          ..quadraticBezierTo(w * .46, h * .5, w * .5, h * .1),
        Paint()
          ..color = Colors.white.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, w * .045));
  }

  @override
  bool shouldRepaint(covariant _LeafPainter old) => old.color != color;
}

/// A little stem of leaves, as used beside titles and in card corners.
class LeafSprig extends StatelessWidget {
  final double size;
  final double angle;
  final Color color;
  const LeafSprig(
      {super.key, this.size = 48, this.angle = 0, this.color = leafMid});
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: Transform.rotate(
          angle: angle,
          child: SizedBox(
              width: size,
              height: size,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                    left: size * .18,
                    bottom: 0,
                    child: Leaf(size: size * .72, angle: -.55, color: color)),
                Positioned(
                    left: size * .46,
                    bottom: size * .06,
                    child: Leaf(size: size * .82, angle: .35, color: color)),
              ]))));
}

/// Two soft swooshes rising into the bottom-right corner of a card.
class CardWave extends StatelessWidget {
  final Color color;
  const CardWave({super.key, this.color = const Color(0xFFE3F0E7)});
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: CustomPaint(painter: _WavePainter(color), size: Size.infinite));
}

class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawPath(
        Path()
          ..moveTo(w * .58, h)
          ..cubicTo(w * .72, h * .78, w * .8, h * .3, w, h * .12)
          ..lineTo(w, h)
          ..close(),
        Paint()..color = color.withValues(alpha: .55));
    canvas.drawPath(
        Path()
          ..moveTo(w * .74, h)
          ..cubicTo(w * .84, h * .72, w * .9, h * .5, w, h * .42)
          ..lineTo(w, h)
          ..close(),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.color != color;
}

/// The rounded, softly shadowed card the supplier screens are built from,
/// with an optional wave in its corner.
class DecorCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color color;
  final bool wave;
  final Color waveColor;
  final double radius;
  const DecorCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(16),
      this.gradient,
      this.color = Colors.white,
      this.wave = false,
      this.waveColor = const Color(0xFFE3F0E7),
      this.radius = 22});
  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
        decoration: BoxDecoration(borderRadius: shape, boxShadow: [
          BoxShadow(
              color: OColors.forest.withValues(alpha: .05),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ]),
        child: Material(
            color: gradient == null ? color : Colors.transparent,
            borderRadius: shape,
            clipBehavior: Clip.antiAlias,
            child: Ink(
                decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: shape,
                    border: Border.all(color: const Color(0xFFE6EEE9))),
                child: InkWell(
                    onTap: onTap,
                    child: Stack(children: [
                      if (wave)
                        Positioned.fill(child: CardWave(color: waveColor)),
                      Padding(padding: padding, child: child),
                    ])))));
  }
}

/// Rolling hills, clouds and sprigs behind an empty-state message.
class HillsBackdrop extends StatelessWidget {
  const HillsBackdrop({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: CustomPaint(painter: _HillsPainter(), size: Size.infinite));
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final cloud = Paint()..color = const Color(0xFFEFF2F0);
    void cloudAt(double x, double y, double r) {
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), width: r * 3.2, height: r * 1.1),
          cloud);
      c.drawCircle(Offset(x - r * .35, y - r * .3), r * .55, cloud);
      c.drawCircle(Offset(x + r * .35, y - r * .4), r * .7, cloud);
    }

    cloudAt(w * .3, h * .1, 14);
    cloudAt(w * .72, h * .14, 16);
    cloudAt(w * .12, h * .2, 8);
    c.drawPath(
        Path()
          ..moveTo(0, h * .44)
          ..quadraticBezierTo(w * .25, h * .3, w * .52, h * .42)
          ..quadraticBezierTo(w * .8, h * .5, w, h * .36)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0xFFEDF3EE));
    c.drawPath(
        Path()
          ..moveTo(0, h * .82)
          ..quadraticBezierTo(w * .3, h * .66, w * .55, h * .8)
          ..quadraticBezierTo(w * .8, h * .94, w, h * .78)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0xFFE7F0E9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Big faint leaves in the corners of a page background.
class PageLeaves extends StatelessWidget {
  const PageLeaves({super.key});
  @override
  Widget build(BuildContext context) => const IgnorePointer(
          child: Stack(children: [
        Positioned(
            right: -26,
            top: 60,
            child: Leaf(size: 120, angle: .7, color: Color(0xFFEFF5F0))),
        Positioned(
            left: -40,
            bottom: 120,
            child: Leaf(size: 190, angle: -.35, color: Color(0xFFEFF5F0))),
        Positioned(
            right: -30,
            bottom: 260,
            child: Leaf(size: 110, angle: .55, color: Color(0xFFF1F6F2))),
      ]));
}

/// Outline cube (Material Icons has none): the idle supplier Stock tab and
/// the empty production-batch card.
class CubeOutlineIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double stroke;
  const CubeOutlineIcon(
      {super.key,
      this.size = 23,
      this.color = const Color(0xFF6F7775),
      this.stroke = 1.8});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _CubePainter(color, stroke));
}

class _CubePainter extends CustomPainter {
  final Color color;
  final double stroke;
  const _CubePainter(this.color, this.stroke);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
        Path()
          ..moveTo(w * .5, h * .08)
          ..lineTo(w * .9, h * .3)
          ..lineTo(w * .9, h * .74)
          ..lineTo(w * .5, h * .95)
          ..lineTo(w * .1, h * .74)
          ..lineTo(w * .1, h * .3)
          ..close()
          ..moveTo(w * .1, h * .3)
          ..lineTo(w * .5, h * .52)
          ..lineTo(w * .9, h * .3)
          ..moveTo(w * .5, h * .52)
          ..lineTo(w * .5, h * .95),
        p);
  }

  @override
  bool shouldRepaint(covariant _CubePainter old) =>
      old.color != color || old.stroke != stroke;
}
