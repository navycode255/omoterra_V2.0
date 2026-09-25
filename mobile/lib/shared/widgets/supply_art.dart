import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Original vector artwork: livestock, meat and the managed supply journey.
/// Drawn in-app so the artwork stays crisp without stock photos or icon fonts.
class SupplyArt extends StatelessWidget {
  final String kind;
  final double size;
  final bool surface;
  const SupplyArt(this.kind, {super.key, this.size = 80, this.surface = true});
  @override
  Widget build(BuildContext context) => Semantics(
      label: '${kind.replaceAll('_', ' ')} illustration',
      image: true,
      child: Container(
          width: size,
          height: size,
          decoration: surface
              ? BoxDecoration(
                  color: OColors.soft, borderRadius: BorderRadius.circular(16))
              : null,
          child: CustomPaint(painter: _SupplyPainter(kind))));
}

class FarmScene extends StatelessWidget {
  final double height;
  const FarmScene({super.key, this.height = 200});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Chicken, goats and cattle from farms, coordinated by Omoterra',
      image: true,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
              height: height,
              color: const Color(0xFFEDF3E9),
              child: LayoutBuilder(
                  builder: (context, box) => Stack(children: [
                        Positioned.fill(
                            child: CustomPaint(painter: _LandscapePainter())),
                        Positioned(
                            left: box.maxWidth * .04,
                            bottom: 8,
                            child: SupplyArt('cattle',
                                size: height * .83, surface: false)),
                        Positioned(
                            right: box.maxWidth * .09,
                            bottom: 13,
                            child: SupplyArt('goats',
                                size: height * .66, surface: false)),
                        Positioned(
                            left: box.maxWidth * .39,
                            bottom: 2,
                            child: SupplyArt('broilers',
                                size: height * .52, surface: false)),
                      ])))));
}

/// The Omoterra logo. Renders the supplied artwork from
/// assets/images/logo.png, falling back to the drawn wordmark if it is
/// missing so no screen is ever left blank.
class BrandMark extends StatelessWidget {
  /// Cap height of the wordmark, matching the previous drawn mark's sizing.
  final double size;

  /// Reverses the drawn fallback to white for use over photography. The
  /// supplied logo is full colour and is not recoloured.
  final bool onDark;
  const BrandMark({super.key, this.size = 25, this.onDark = false});

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Omoterra',
      image: true,
      child: Image.asset('assets/images/logo.png',
          height: size * 1.45,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _drawn()));

  Widget _drawn() => Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(
            size: Size(size, size),
            painter: _LeafPainter(onDark ? Colors.white : OColors.forest)),
        const SizedBox(width: 7),
        Flexible(
            child: Text('Omoterra',
                style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w800,
                    color: onDark ? Colors.white : OColors.forest,
                    letterSpacing: -.9))),
      ]);
}

/// A faint, oversized copy of the brand leaf used as a decorative watermark
/// on cards — the same shape as the logo mark, kept visually consistent with
/// it rather than introducing a second leaf motif.
class LeafWatermark extends StatelessWidget {
  final double size;
  final double opacity;
  const LeafWatermark({super.key, this.size = 90, this.opacity = .5});
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: Opacity(
          opacity: opacity,
          child: CustomPaint(
              size: Size(size, size), painter: _LeafPainter(OColors.soft))));
}

class _LeafPainter extends CustomPainter {
  final Color color;
  _LeafPainter([this.color = OColors.forest]);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 30, size.height / 30);
    final fill = Paint()..color = color;
    canvas.drawPath(
        Path()
          ..moveTo(14, 25)
          ..cubicTo(0, 22, 0, 9, 2, 6)
          ..cubicTo(17, 8, 20, 18, 14, 25),
        fill);
    canvas.drawPath(
        Path()
          ..moveTo(17, 22)
          ..cubicTo(9, 10, 20, 1, 29, 1)
          ..cubicTo(29, 12, 24, 19, 17, 22),
        fill);
    canvas.drawPath(
        Path()
          ..moveTo(14, 29)
          ..quadraticBezierTo(13, 17, 24, 6),
        Paint()
          ..color = const Color(0xFFA7C4A3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawCircle(Offset(s.width * .73, s.height * .23), 22,
        Paint()..color = const Color(0xFFF0DCA9));
    c.drawPath(
        Path()
          ..moveTo(0, s.height * .64)
          ..quadraticBezierTo(
              s.width * .25, s.height * .18, s.width * .58, s.height * .65)
          ..quadraticBezierTo(
              s.width * .85, s.height * .32, s.width, s.height * .56)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close(),
        Paint()..color = const Color(0xFFD4E2CE));
    c.drawPath(
        Path()
          ..moveTo(0, s.height * .8)
          ..quadraticBezierTo(
              s.width * .5, s.height * .55, s.width, s.height * .85)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close(),
        Paint()..color = const Color(0xFFB5CEAD));
    final line = Paint()
      ..color = const Color(0xFF86A47E)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final x = s.width * (.07 + i * .055);
      c.drawLine(Offset(x, s.height * .71), Offset(x, s.height * .54), line);
      c.drawLine(
          Offset(x, s.height * .61), Offset(x - 5, s.height * .57), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SupplyPainter extends CustomPainter {
  final String kind;
  _SupplyPainter(this.kind);
  final ink = OColors.forest;
  void shape(Canvas c, Path path, Color color, {bool outline = true}) {
    c.drawPath(path, Paint()..color = color);
    if (outline) {
      c.drawPath(
          path,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round);
    }
  }

  void line(Canvas c, List<Offset> pts, {Color? color, double width = 1.8}) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..color = color ?? ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  void oval(Canvas c, Rect rect, Color color) =>
      shape(c, Path()..addOval(rect), color);
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 100, s.height / 100);
    c.drawOval(const Rect.fromLTWH(16, 83, 70, 6),
        Paint()..color = ink.withValues(alpha: .08));
    if (['broilers', 'local_chicken', 'chicken_shop', 'local_chicken_business']
        .contains(kind)) {
      chicken(c, kind.contains('local'));
    } else if (['goats', 'goat_meat_business'].contains(kind)) {
      animal(c, goat: true);
    } else if (kind == 'cattle') {
      animal(c, goat: false);
    } else if (['beef', 'goat_meat', 'chicken_meat', 'butchery']
        .contains(kind)) {
      meat(c);
    } else if (['delivery', 'meat_delivery'].contains(kind)) {
      truck(c);
    } else if (['request', 'receipt', 'history', 'settlement'].contains(kind)) {
      document(c);
    } else if (['store', 'restaurant_grill', 'fish_shop'].contains(kind)) {
      shop(c);
    } else {
      crate(c);
    }
  }

  void chicken(Canvas c, bool local) {
    final feather = local ? const Color(0xFFC99455) : const Color(0xFFFFFCED);
    shape(
        c,
        Path()
          ..moveTo(29, 62)
          ..lineTo(13, 42)
          ..quadraticBezierTo(7, 47, 22, 67)
          ..lineTo(12, 55)
          ..quadraticBezierTo(10, 69, 28, 74)
          ..close(),
        local ? ink : const Color(0xFFD8DDC9));
    shape(
        c,
        Path()
          ..moveTo(23, 54)
          ..cubicTo(30, 39, 53, 52, 59, 43)
          ..lineTo(64, 27)
          ..quadraticBezierTo(69, 20, 77, 28)
          ..quadraticBezierTo(81, 37, 73, 45)
          ..cubicTo(82, 67, 65, 82, 44, 79)
          ..cubicTo(26, 79, 18, 65, 23, 54)
          ..close(),
        feather);
    shape(
        c,
        Path()
          ..moveTo(63, 26)
          ..quadraticBezierTo(60, 13, 68, 19)
          ..quadraticBezierTo(72, 10, 75, 20)
          ..quadraticBezierTo(83, 18, 77, 28)
          ..close(),
        const Color(0xFFAE5944));
    shape(
        c,
        Path()
          ..moveTo(78, 32)
          ..lineTo(90, 36)
          ..lineTo(78, 40)
          ..close(),
        const Color(0xFFD4AA54));
    c.drawCircle(const Offset(73, 31), 1.7, Paint()..color = ink);
    shape(
        c,
        Path()
          ..moveTo(69, 43)
          ..quadraticBezierTo(77, 40, 76, 49)
          ..quadraticBezierTo(70, 55, 69, 43),
        const Color(0xFFAE5944));
    shape(
        c,
        Path()
          ..moveTo(34, 56)
          ..quadraticBezierTo(46, 45, 60, 59)
          ..quadraticBezierTo(52, 76, 34, 66)
          ..close(),
        local ? const Color(0xFFE6B874) : const Color(0xFFEAEBD8));
    line(c, [const Offset(42, 79), const Offset(40, 88), const Offset(34, 88)]);
    line(c, [const Offset(56, 79), const Offset(55, 88), const Offset(61, 88)]);
    line(c, [const Offset(38, 60), const Offset(48, 66), const Offset(55, 61)],
        width: 1);
  }

  void animal(Canvas c, {required bool goat}) {
    final coat = goat ? const Color(0xFFDCCBB0) : const Color(0xFFFFFBEE);
    shape(
        c,
        Path()
          ..moveTo(22, 46)
          ..quadraticBezierTo(47, 35, 68, 47)
          ..lineTo(76, 70)
          ..lineTo(67, 70)
          ..lineTo(65, 85)
          ..lineTo(59, 85)
          ..lineTo(57, 68)
          ..lineTo(35, 68)
          ..lineTo(31, 85)
          ..lineTo(24, 85)
          ..lineTo(25, 66)
          ..lineTo(20, 55)
          ..close(),
        coat);
    if (!goat) {
      shape(
          c,
          Path()
            ..moveTo(33, 43)
            ..quadraticBezierTo(48, 39, 49, 55)
            ..quadraticBezierTo(42, 66, 32, 60)
            ..close(),
          ink,
          outline: false);
      shape(
          c,
          Path()
            ..moveTo(56, 46)
            ..quadraticBezierTo(68, 49, 68, 61)
            ..lineTo(57, 59)
            ..close(),
          ink,
          outline: false);
    }
    line(c, [const Offset(23, 46), const Offset(15, 44), const Offset(12, 57)]);
    shape(
        c,
        Path()
          ..moveTo(66, 43)
          ..lineTo(70, 30)
          ..lineTo(85, 31)
          ..lineTo(91, 55)
          ..quadraticBezierTo(84, 68, 72, 57)
          ..close(),
        coat);
    shape(
        c,
        Path()
          ..moveTo(71, 33)
          ..quadraticBezierTo(60, 25, 62, 39)
          ..lineTo(70, 43)
          ..close(),
        const Color(0xFFB39473));
    shape(
        c,
        Path()
          ..moveTo(86, 32)
          ..quadraticBezierTo(100, 27, 94, 41)
          ..lineTo(87, 43)
          ..close(),
        const Color(0xFFB39473));
    line(
        c,
        [
          const Offset(73, 30),
          Offset(goat ? 69 : 65, goat ? 14 : 23),
          Offset(goat ? 75 : 62, goat ? 18 : 20)
        ],
        width: 3);
    line(
        c,
        [
          const Offset(84, 30),
          Offset(goat ? 85 : 93, goat ? 13 : 22),
          Offset(goat ? 89 : 95, goat ? 18 : 19)
        ],
        width: 3);
    oval(c, const Rect.fromLTWH(73, 50, 17, 11), const Color(0xFFE9D7BF));
    c.drawCircle(const Offset(77, 42), 1.6, Paint()..color = ink);
    c.drawCircle(const Offset(86, 43), 1.6, Paint()..color = ink);
    if (goat) {
      shape(
          c,
          Path()
            ..moveTo(76, 59)
            ..lineTo(80, 70)
            ..lineTo(85, 59)
            ..close(),
          const Color(0xFFB39473));
    }
  }

  void meat(Canvas c) {
    oval(c, const Rect.fromLTWH(12, 70, 76, 13), const Color(0xFFE0D6BE));
    shape(
        c,
        Path()
          ..moveTo(22, 58)
          ..cubicTo(13, 37, 28, 20, 45, 26)
          ..cubicTo(63, 33, 76, 27, 83, 45)
          ..cubicTo(95, 71, 67, 81, 43, 73)
          ..quadraticBezierTo(26, 74, 22, 58)
          ..close(),
        const Color(0xFFB66B62));
    shape(
        c,
        Path()
          ..moveTo(29, 54)
          ..cubicTo(22, 40, 32, 28, 47, 35)
          ..cubicTo(64, 42, 78, 31, 79, 54)
          ..cubicTo(79, 70, 60, 71, 43, 65)
          ..quadraticBezierTo(31, 65, 29, 54)
          ..close(),
        const Color(0xFFD29482),
        outline: false);
    oval(c, const Rect.fromLTWH(43, 43, 18, 15), const Color(0xFFFFF8DD));
    oval(c, const Rect.fromLTWH(48, 47, 7, 6), const Color(0xFFD8C3A5));
    line(c, [const Offset(34, 43), const Offset(39, 38)],
        color: const Color(0xFFFFE1C9));
    line(c, [const Offset(65, 58), const Offset(70, 63)],
        color: const Color(0xFFFFE1C9));
  }

  void crate(Canvas c) {
    for (var i = 0; i < 3; i++) {
      oval(c, Rect.fromLTWH(25 + i * 17, 29 - (i % 2) * 5, 18, 26),
          const Color(0xFFEDE0BD));
    }
    shape(
        c,
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(18, 47, 66, 34), const Radius.circular(5))),
        const Color(0xFF9EBA92));
    line(c, [const Offset(18, 57), const Offset(84, 57)]);
    line(c, [const Offset(18, 70), const Offset(84, 70)]);
    line(c, [const Offset(31, 49), const Offset(31, 79)]);
    line(c, [const Offset(71, 49), const Offset(71, 79)]);
  }

  void document(Canvas c) {
    shape(
        c,
        Path()
          ..moveTo(25, 17)
          ..lineTo(65, 17)
          ..lineTo(79, 32)
          ..lineTo(79, 79)
          ..lineTo(25, 79)
          ..close(),
        const Color(0xFFFFFBEF));
    line(c, [const Offset(65, 18), const Offset(65, 32), const Offset(79, 32)]);
    for (var i = 0; i < 3; i++) {
      line(c, [Offset(35, 44 + i * 10), Offset(i == 2 ? 50 : 67, 44 + i * 10)],
          color: const Color(0xFF9EBA92));
    }
    oval(c, const Rect.fromLTWH(57, 59, 29, 29), ink);
    if (kind == 'request') {
      line(c, [const Offset(72, 66), const Offset(72, 81)],
          color: Colors.white);
      line(c, [const Offset(65, 73), const Offset(79, 73)],
          color: Colors.white);
    } else {
      line(
          c, [const Offset(65, 73), const Offset(70, 78), const Offset(79, 68)],
          color: Colors.white);
    }
  }

  void shop(Canvas c) {
    shape(c, Path()..addRect(const Rect.fromLTWH(23, 39, 55, 42)),
        const Color(0xFFFFFBEE));
    shape(
        c,
        Path()
          ..moveTo(20, 37)
          ..lineTo(28, 22)
          ..lineTo(73, 22)
          ..lineTo(82, 37)
          ..lineTo(82, 46)
          ..lineTo(20, 46)
          ..close(),
        const Color(0xFF9EBA92));
    for (var i = 0; i < 4; i++) {
      line(c, [Offset(29 + i * 14, 24), Offset(26 + i * 17, 44)],
          width: 4, color: const Color(0xFFFFFBEF));
    }
    shape(c, Path()..addRect(const Rect.fromLTWH(55, 55, 15, 26)),
        const Color(0xFFB5CEAD));
    shape(c, Path()..addRect(const Rect.fromLTWH(31, 55, 16, 14)),
        const Color(0xFFDFEAE1));
    line(c, [const Offset(16, 82), const Offset(85, 82)]);
  }

  void truck(Canvas c) {
    shape(
        c,
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(12, 29, 47, 43), const Radius.circular(5))),
        const Color(0xFF9EBA92));
    shape(
        c,
        Path()
          ..moveTo(59, 44)
          ..lineTo(78, 44)
          ..lineTo(89, 59)
          ..lineTo(89, 72)
          ..lineTo(59, 72)
          ..close(),
        const Color(0xFFFFFBEF));
    shape(
        c,
        Path()
          ..moveTo(65, 49)
          ..lineTo(76, 49)
          ..lineTo(82, 59)
          ..lineTo(65, 59)
          ..close(),
        const Color(0xFFDCE8E1));
    for (final x in [28.0, 73.0]) {
      oval(c, Rect.fromCircle(center: Offset(x, 75), radius: 9), ink);
      c.drawCircle(Offset(x, 75), 4, Paint()..color = const Color(0xFFF6F5E7));
    }
    line(c, [const Offset(22, 48), const Offset(31, 58), const Offset(47, 39)],
        color: Colors.white, width: 3);
  }

  @override
  bool shouldRepaint(covariant _SupplyPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
