import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Native port of the approved Claude Design fire engine (the `FireClose`
/// component in `docs/mr_nyama/design/html/`). Same emitters, curves,
/// colour ramp, sizes, velocities and lifetimes; drawn with a CustomPainter
/// from five pre-rendered radial sprites, driven by one Ticker, and capped
/// at [FireSpec.maxParticles]. No WebView, no video.

/// Colour stops of the flame ramp, by particle age (design: core → orange →
/// Mr. Nyama red → deep ember → char), with each sprite's mid-stop alpha.
const _ramp = <(int, int, int, double)>[
  (255, 230, 160, .5), // #FFE6A0
  (255, 150, 50, .5), // #FF9632
  (227, 6, 19, .55), // #E30613
  (170, 10, 14, .5), // #AA0A0E
  (80, 6, 6, .4), // char
];
const _smokeColour = (150, 140, 130, .5);

/// Parameters of one fire. [FireSpec.fungaSiku] is Signature B exactly;
/// [FireSpec.saleSuccess] is the small flame for a saved sale.
class FireSpec {
  /// Emitter x positions in [referenceWidth] coordinates.
  final List<double> emitterX;

  /// When each emitter starts (ms); it ramps up over [igniteRampMs].
  final List<double> igniteMs;
  final double igniteRampMs;
  final double referenceWidth;

  /// Canvas height in logical pixels; flames rise from its bottom edge.
  final double height;

  /// Particles per second per emitter at full intensity.
  final double rate;

  /// Intensity (0–1) and flame height factor at time T (ms).
  final double Function(double t) intensity;
  final double Function(double t) flameHeight;

  final double spread, sizeMin, sizeRange, speedMin, speedRange;
  final double lifeMin, lifeRange, swirl, buoyancy;

  /// Embers are spawned between these times (ms), if set.
  final (double, double)? emberWindow;
  final bool smoke;

  /// Additive blending (on charcoal). Off on light backgrounds, where
  /// adding light would wash out to white.
  final bool additive;
  final int maxParticles;

  /// No new particles after this; the loop stops when all have died.
  final double endMs;

  const FireSpec({
    required this.emitterX,
    required this.igniteMs,
    this.igniteRampMs = 150,
    required this.referenceWidth,
    required this.height,
    required this.rate,
    required this.intensity,
    required this.flameHeight,
    required this.spread,
    required this.sizeMin,
    required this.sizeRange,
    required this.speedMin,
    required this.speedRange,
    required this.lifeMin,
    required this.lifeRange,
    required this.swirl,
    required this.buoyancy,
    this.emberWindow,
    this.smoke = false,
    this.additive = true,
    this.maxParticles = 400,
    required this.endMs,
  });

  /// Signature B, Funga Siku: 13 burners across a 390 × 300 canvas, lit from
  /// the centre outward by 250 ms; full until 900 ms, down to 30% by 1300,
  /// held, then out by 4600. Height .55 → 1 (400–900) → .4 (by 1300).
  static FireSpec fungaSiku() => FireSpec(
        emitterX: [for (var i = 0; i < 13; i++) 15.0 + i * 30],
        igniteMs: [for (var i = 0; i < 13; i++) 150 + (i - 6).abs() / 6 * 250],
        referenceWidth: 390,
        height: 300,
        rate: 55,
        intensity: fungaSikuIntensity,
        flameHeight: fungaSikuHeight,
        spread: 26,
        sizeMin: 38,
        sizeRange: 30,
        speedMin: 110,
        speedRange: 80,
        lifeMin: .55,
        lifeRange: .35,
        swirl: 16,
        buoyancy: 60,
        emberWindow: (400, 1400),
        smoke: true,
        endMs: 4600,
      );

  /// Sale saved: a small flame from four close burners (0–60 ms), rising
  /// until ~360 ms, held, then gone by 560 ms as the circle grows over it.
  static FireSpec saleSuccess() => FireSpec(
        emitterX: const [36, 44, 52, 60],
        igniteMs: const [0, 20, 40, 60],
        igniteRampMs: 80,
        referenceWidth: 96,
        height: 112,
        rate: 90,
        intensity: saleIntensity,
        flameHeight: saleHeight,
        spread: 10,
        sizeMin: 18,
        sizeRange: 14,
        speedMin: 100,
        speedRange: 50,
        lifeMin: .28,
        lifeRange: .18,
        swirl: 8,
        buoyancy: 80,
        additive: false,
        maxParticles: 140,
        endMs: 560,
      );
}

/// Signature B intensity G(T) from the prototype.
double fungaSikuIntensity(double t) => t < 900
    ? 1
    : t < 1300
        ? 1 - .7 * (t - 900) / 400
        : t < 3600
            ? .3
            : t < 4600
                ? .3 * (1 - (t - 3600) / 1000)
                : 0;

/// Signature B flame height Hh(T) from the prototype.
double fungaSikuHeight(double t) => t < 400
    ? .55
    : t < 900
        ? .55 + .45 * (t - 400) / 500
        : t < 1300
            ? 1 - .6 * (t - 900) / 400
            : .4;

double saleIntensity(double t) =>
    t < 420 ? 1 : (t < 560 ? 1 - (t - 420) / 140 : 0);

double saleHeight(double t) => t < 360 ? .6 + .4 * t / 360 : 1;

class _Flame {
  double x, y, vx, vy, age = 0;
  final double home, life, size, phase;
  _Flame(this.x, this.y, this.home, this.vx, this.vy, this.life, this.size,
      this.phase);
}

class _Ember {
  double x, y, age = 0;
  final double vy, life, phase;
  final bool red;
  _Ember(this.x, this.y, this.vy, this.life, this.phase, this.red);
}

class _Smoke {
  double x, y, age = 0;
  final double vy, life, size;
  _Smoke(this.x, this.y, this.vy, this.life, this.size);
}

/// The particle simulation (pure Dart, testable). Coordinates are in the
/// spec's reference canvas; the painter scales them to the real width.
class FireSystem {
  final FireSpec spec;
  final math.Random _random;
  final _flames = <_Flame>[];
  final _embers = <_Ember>[];
  final _smoke = <_Smoke>[];
  late final List<double> _accumulators = List.filled(spec.emitterX.length, 0);
  double _t = 0;

  FireSystem(this.spec, {math.Random? random})
      : _random = random ?? math.Random();

  int get liveParticles => _flames.length;
  bool get finished =>
      _t >= spec.endMs && _flames.isEmpty && _embers.isEmpty && _smoke.isEmpty;
  double get time => _t;

  double _rand() => _random.nextDouble();

  /// Advances to time [t] (ms since start) by [dt] seconds (capped at 33 ms
  /// so a stalled frame cannot burst particles).
  void step(double t, double dt) {
    _t = t;
    dt = dt.clamp(0, .033);
    final g = spec.intensity(t);
    final h = spec.flameHeight(t);
    final bottom = spec.height - 6;

    if (t < spec.endMs) {
      for (var k = 0; k < spec.emitterX.length; k++) {
        final on = ((t - spec.igniteMs[k]) / spec.igniteRampMs).clamp(0.0, 1.0);
        _accumulators[k] += spec.rate * on * g * dt;
        while (_accumulators[k] >= 1) {
          _accumulators[k] -= 1;
          if (_flames.length >= spec.maxParticles) continue;
          _flames.add(_Flame(
            spec.emitterX[k] + (_rand() - .5) * spec.spread,
            bottom,
            spec.emitterX[k],
            (_rand() - .5) * spec.spread * .9,
            -(spec.speedMin + _rand() * spec.speedRange) * (.5 + h * .7),
            (spec.lifeMin + _rand() * spec.lifeRange) * (.75 + h * .45),
            spec.sizeMin + _rand() * spec.sizeRange,
            _rand() * 6.28,
          ));
        }
      }
      final window = spec.emberWindow;
      if (window != null &&
          t > window.$1 &&
          t < window.$2 &&
          _rand() < 8 * dt) {
        final w = spec.referenceWidth;
        _embers.add(_Ember(
            40 + _rand() * (w - 80),
            spec.height - 40 - _rand() * 60,
            -(60 + _rand() * 60),
            1.2 + _rand() * .8,
            _rand() * 6.28,
            _embers.length % 3 == 0));
      }
      if (spec.smoke && _rand() < 6 * g * dt) {
        _smoke.add(_Smoke(40 + _rand() * (spec.referenceWidth - 80),
            spec.height - 150 * h, -30 - _rand() * 20, 1.6 + _rand(), 40));
      }
    }

    for (var i = _flames.length - 1; i >= 0; i--) {
      final p = _flames[i];
      p.age += dt;
      if (p.age >= p.life) {
        _flames.removeAt(i);
        continue;
      }
      p.vy -= spec.buoyancy * dt;
      p.vx += (p.home - p.x) * 1.4 * dt;
      p.x += (p.vx + math.sin(p.age * 7 + p.phase) * spec.swirl) * dt;
      p.y += p.vy * dt;
    }
    for (var i = _embers.length - 1; i >= 0; i--) {
      final e = _embers[i];
      e.age += dt;
      if (e.age >= e.life) {
        _embers.removeAt(i);
        continue;
      }
      e.y += e.vy * dt;
      e.x += math.sin(e.age * 4 + e.phase) * 12 * dt;
    }
    for (var i = _smoke.length - 1; i >= 0; i--) {
      final s = _smoke[i];
      s.age += dt;
      if (s.age >= s.life) {
        _smoke.removeAt(i);
        continue;
      }
      s.y += s.vy * dt;
      s.x += math.sin(s.age * 2) * 8 * dt;
    }
  }
}

/// The five flame sprites and the smoke sprite: 64 px radial gradients,
/// rendered once per process.
class FireSprites {
  static List<ui.Image>? _flames;
  static ui.Image? _smoke;

  static ui.Image _render((int, int, int, double) c) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final (r, g, b, mid) = c;
    canvas.drawCircle(
      const Offset(32, 32),
      32,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(32, 32), 32, [
          Color.fromRGBO(r, g, b, 1),
          Color.fromRGBO(r, g, b, mid),
          Color.fromRGBO(r, g, b, 0),
        ], const [
          0,
          .45,
          1
        ]),
    );
    return recorder.endRecording().toImageSync(64, 64);
  }

  static List<ui.Image> get flames => _flames ??= _ramp.map(_render).toList();
  static ui.Image get smoke => _smoke ??= _render(_smokeColour);
}

/// Paints a [FireSystem]; repaints when [repaint] ticks.
class FirePainter extends CustomPainter {
  final FireSystem system;
  FirePainter(this.system, {required Listenable repaint})
      : super(repaint: repaint);

  static const _src = Rect.fromLTWH(0, 0, 64, 64);

  @override
  void paint(Canvas canvas, Size size) {
    final spec = system.spec;
    final sx = size.width / spec.referenceWidth;
    final sy = size.height / spec.height;
    final paint = Paint()..filterQuality = FilterQuality.low;

    for (final s in system._smoke) {
      final ts = s.age / s.life;
      final z = s.size * (1 + ts * 1.8);
      paint
        ..blendMode = BlendMode.srcOver
        ..color = Color.fromRGBO(255, 255, 255,
            (.07 * (1 - ts) * math.min(1, ts * 3)).clamp(0.0, 1.0));
      canvas.drawImageRect(
          FireSprites.smoke,
          _src,
          Rect.fromCenter(
              center: Offset(s.x * sx, s.y * sy),
              width: z * sx,
              height: z * sx),
          paint);
    }

    final sprites = FireSprites.flames;
    paint.blendMode = spec.additive ? BlendMode.plus : BlendMode.srcOver;
    for (final p in system._flames) {
      final t = p.age / p.life;
      final index = t < .13
          ? 0
          : t < .3
              ? 1
              : t < .66
                  ? 2
                  : t < .86
                      ? 3
                      : 4;
      final z = p.size * (1 - .55 * t) * (t < .08 ? .5 + t / .16 : 1);
      paint.color = Color.fromRGBO(255, 255, 255,
          (math.pow(1 - t, 1.2) * (index == 2 ? .7 : .55)).clamp(0.0, 1.0));
      canvas.drawImageRect(
          sprites[index],
          _src,
          Rect.fromLTWH(
              (p.x - z / 2) * sx, (p.y - z * .6) * sy, z * sx, z * 1.2 * sx),
          paint);
    }

    paint.blendMode = spec.additive ? BlendMode.plus : BlendMode.srcOver;
    for (var i = 0; i < system._embers.length; i++) {
      final e = system._embers[i];
      final te = e.age / e.life;
      paint.color = (e.red
              ? const Color.fromRGBO(255, 60, 50, 1)
              : const Color.fromRGBO(255, 196, 120, 1))
          .withValues(alpha: ((1 - te) * .9).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(e.x * sx, e.y * sy, 2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) => oldDelegate.system != system;
}

/// Runs a [FireSystem] on one Ticker from mount and stops it when the fire
/// has died out. [startAtMs] lets a caller skip ahead.
class FireCanvas extends StatefulWidget {
  final FireSpec spec;
  final FireController? controller;
  const FireCanvas({super.key, required this.spec, this.controller});

  @override
  State<FireCanvas> createState() => _FireCanvasState();
}

/// Lets a screen read the fire's clock (to sequence text with it) and skip.
class FireController extends ChangeNotifier {
  double _elapsedMs = 0;
  double _offsetMs = 0;
  bool _running = false;
  double get elapsedMs => _elapsedMs + _offsetMs;
  bool get running => _running;

  void _update({double? elapsedMs, bool? running}) {
    if (elapsedMs != null) _elapsedMs = elapsedMs;
    if (running != null) _running = running;
    notifyListeners();
  }

  /// Jumps the timeline to [ms] (Signature B "Ruka" jumps to the settle).
  void skipTo(double ms) {
    if (ms > elapsedMs) _offsetMs += ms - elapsedMs;
    notifyListeners();
  }
}

class _FireCanvasState extends State<FireCanvas>
    with SingleTickerProviderStateMixin {
  late final FireSystem _system = FireSystem(widget.spec);
  late final _tick = ValueNotifier<int>(0);
  late final _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._running = true; // set before the first frame
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final c = widget.controller;
    final ms = elapsed.inMicroseconds / 1000;
    c?._update(elapsedMs: ms);
    _system.step(c?.elapsedMs ?? ms, dt);
    _tick.value++;
    if (_system.finished) {
      _ticker.stop();
      c?._update(running: false);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: FirePainter(_system, repaint: _tick),
          size: Size.infinite,
        ),
      );
}
