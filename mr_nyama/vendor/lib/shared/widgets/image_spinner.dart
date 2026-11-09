import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Ember ring shown while a product photo is fetched: a charcoal-fire arc
/// (deep ember → red → orange) chasing a glowing ember head around a faint
/// track. It fades in only after [MNMotion.imageSpinnerDelay], so cached
/// photos never flash it. Reduced motion shows a still arc.
class MNImageSpinner extends StatefulWidget {
  final double size;

  /// True on the dark photo background; false on light tiles.
  final bool onDark;
  const MNImageSpinner({super.key, this.size = 32, this.onDark = true});

  @override
  State<MNImageSpinner> createState() => _MNImageSpinnerState();
}

class _MNImageSpinnerState extends State<MNImageSpinner>
    with SingleTickerProviderStateMixin {
  final _elapsed = ValueNotifier(Duration.zero);
  late final Ticker _ticker = createTicker((t) => _elapsed.value = t);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MNMotion.reduced(context);
    if (_still) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _EmberRingPainter(_elapsed,
                still: _still, onDark: widget.onDark),
          ),
        ),
      );
}

class _EmberRingPainter extends CustomPainter {
  final ValueListenable<Duration> elapsed;
  final bool still;
  final bool onDark;
  _EmberRingPainter(this.elapsed, {required this.still, required this.onDark})
      : super(repaint: elapsed);

  static double _ms(Duration d) => d.inMicroseconds / 1000;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _ms(elapsed.value);
    final appear = still
        ? 1.0
        : MNMotion.easeOut.transform(
            ((t - _ms(MNMotion.imageSpinnerDelay)) / _ms(MNMotion.fadeIn))
                .clamp(0.0, 1.0));
    if (appear == 0) return;

    final stroke = math.max(2.0, size.shortestSide * .1);
    final radius = (size.shortestSide - stroke * 2) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // The arc breathes between 1/8 and 5/8 of a turn while the head turns
    // once per MNMotion.spin, so the tail visibly chases the ember.
    final breath = still
        ? .5
        : .5 -
            .5 * math.cos(2 * math.pi * (t / _ms(MNMotion.imageSpinnerBreath)));
    final sweep =
        2 * math.pi * (.125 + .5 * MNMotion.standard.transform(breath));
    final head = -math.pi / 2 +
        (still ? 0 : 2 * math.pi * (t / _ms(MNMotion.spin))) +
        (still ? sweep : 0);
    final tail = head - sweep;

    Color fade(Color c) => c.withValues(alpha: c.a * appear);

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = fade(
              onDark ? MNColors.spinnerTrackOnDark : MNColors.spinnerTrack));

    canvas.drawArc(
        rect,
        tail,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            endAngle: sweep,
            colors: [
              fade(MNColors.flameDeepClear),
              fade(MNColors.flameDeep),
              fade(MNColors.red),
              fade(MNColors.flameOrange),
            ],
            stops: const [0, .3, .7, 1],
            transform: GradientRotation(tail),
          ).createShader(rect));

    // The ember: an orange glow that flickers slightly, then a hot core.
    final ember = center + Offset(math.cos(head), math.sin(head)) * radius;
    final flicker = still ? 1.0 : .85 + .15 * math.sin(t / 90);
    canvas.drawCircle(
        ember,
        stroke * 1.1 * flicker,
        Paint()
          ..color = fade(MNColors.flameOrange.withValues(alpha: .55))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * .9));
    canvas.drawCircle(ember, stroke * .45,
        Paint()..color = fade(onDark ? MNColors.flameCore : MNColors.red));
  }

  @override
  bool shouldRepaint(_EmberRingPainter old) =>
      old.still != still || old.onDark != onDark;
}

/// A product photo that shows [MNImageSpinner] while it is fetched and fades
/// in once decoded. Bundled photos and photos already in the image cache
/// appear at once, exactly as a plain [Image] would. A failed fetch shows
/// [error], usually the empty photo background.
class MNLoadingImage extends StatelessWidget {
  final ImageProvider image;
  final bool onDark;
  final Widget error;
  const MNLoadingImage(
      {super.key,
      required this.image,
      this.onDark = true,
      this.error = const SizedBox.expand()});

  /// Ring size for a photo box: about a quarter of its short side.
  static double spinnerSize(BoxConstraints c) {
    final side = math.min(c.maxWidth, c.maxHeight);
    return (side.isFinite ? side * .26 : 36.0).clamp(14.0, 36.0);
  }

  @override
  Widget build(BuildContext context) {
    final bundled = image is AssetBundleImageProvider;
    return Image(
      image: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => error,
      frameBuilder: bundled
          ? null
          : (context, child, frame, synchronous) {
              if (synchronous) return child;
              final loaded = frame != null;
              return Stack(fit: StackFit.expand, children: [
                LayoutBuilder(
                  builder: (context, c) => AnimatedSwitcher(
                    duration: MNMotion.of(context, MNMotion.fadeIn),
                    reverseDuration: MNMotion.of(context, MNMotion.fadeOut),
                    child: loaded
                        ? const SizedBox.shrink()
                        : Center(
                            child: MNImageSpinner(
                                size: spinnerSize(c), onDark: onDark)),
                  ),
                ),
                AnimatedOpacity(
                  opacity: loaded ? 1 : 0,
                  duration: MNMotion.of(context, MNMotion.fadeIn),
                  curve: MNMotion.easeOut,
                  child: child,
                ),
              ]);
            },
    );
  }
}
