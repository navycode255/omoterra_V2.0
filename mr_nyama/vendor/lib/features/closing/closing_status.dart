import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/logo.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/motion/fire.dart';
import '../../shared/motion/played_effects.dart';
import '../../shared/widgets/rows.dart';
import 'closing_screen.dart';
import 'closing_store.dart';

/// The two lines that say where a closing count stands, one pair per state
/// so they can never contradict each other.
class ClosingStatusLines extends ConsumerWidget {
  final ClosingStatus status;
  final bool onDark;

  /// The server's reason for a [ClosingStatus.conflict].
  final String? conflictReason;
  const ClosingStatusLines(
      {super.key,
      required this.status,
      this.onDark = false,
      this.conflictReason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final (first, firstIcon, firstColor, second, secondIcon, secondColor) =
        switch (status) {
      ClosingStatus.savedOnPhone => (
          strings.countSavedOnPhone,
          MNIconData.check,
          onDark ? MNColors.successOnDark : MNColors.success,
          strings.waitingToSend,
          MNIconData.clock,
          onDark ? MNColors.warningOnDark : MNColors.warning,
        ),
      ClosingStatus.awaitingOffice => (
          strings.sentToOffice,
          MNIconData.cloudOk,
          onDark ? MNColors.successOnDark : MNColors.success,
          strings.awaitingOfficeCheck,
          MNIconData.dash,
          onDark ? MNColors.onDarkMuted : MNColors.ink2,
        ),
      // Another vendor at this kituo already counted today: the station's
      // count exists and this vendor's day is closed; not an error.
      ClosingStatus.conflict when conflictReason == 'station_counted' => (
          strings.sentToOffice,
          MNIconData.cloudOk,
          onDark ? MNColors.successOnDark : MNColors.success,
          strings.closingStationCounted,
          MNIconData.dash,
          onDark ? MNColors.onDarkMuted : MNColors.ink2,
        ),
      ClosingStatus.conflict => (
          strings.countSavedOnPhone,
          MNIconData.check,
          onDark ? MNColors.successOnDark : MNColors.success,
          strings.closingConflict,
          MNIconData.warn,
          onDark ? MNColors.warningOnDark : MNColors.warning,
        ),
      ClosingStatus.confirmed => (
          strings.sentToOffice,
          MNIconData.cloudOk,
          onDark ? MNColors.successOnDark : MNColors.success,
          strings.confirmedByOffice,
          MNIconData.okCircle,
          onDark ? MNColors.successOnDark : MNColors.success,
        ),
    };
    Widget line(String text, MNIconData icon, Color color) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          MNIcon(icon, size: MNSize.iconSmall, color: color),
          const SizedBox(width: 6),
          Flexible(
              child: Text(text, style: MNText.status.copyWith(color: color))),
        ]);
    return Semantics(
      liveRegion: true,
      label: '$first $second',
      child: ExcludeSemantics(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          line(first, firstIcon, firstColor),
          const SizedBox(height: MNSpace.x2),
          line(second, secondIcon, secondColor),
        ]),
      ),
    );
  }
}

/// Today's count, read-only: what was counted and where it stands.
class ClosingStatusScreen extends ConsumerWidget {
  final ClosingView view;
  final VoidCallback? onFilter;
  final int filterStatus;
  const ClosingStatusScreen(
      {super.key, required this.view, this.onFilter, this.filterStatus = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      appBar: MNAppHeader(light: true, title: strings.closeDay, actions: [
        MNWorkflowHelp(
            messages: [strings.closingOnlyCount, strings.correctionsByOffice]),
        if (onFilter != null)
          IconButton(
              tooltip: strings.filter,
              onPressed: onFilter,
              icon: const MNIcon(MNIconData.filter)),
      ]),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(MNSpace.x4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(strings.today(view.businessDate), style: MNText.label),
            Semantics(
                header: true,
                child: Text(strings.todayCountSaved, style: MNText.heading)),
            const SizedBox(height: MNSpace.x3),
            ClosingStatusLines(
                status: view.status, conflictReason: view.conflictReason),
          ]),
        ),
        for (final (i, l) in view.lines
            .where((l) =>
                filterStatus != 2 &&
                (filterStatus != 3 ||
                    (l.recorded != null && l.counted != l.recorded)))
            .indexed)
          MNInfoRow(
              first: i == 0,
              label: l.productName,
              value: Text('${l.counted}', style: MNText.quantity)),
        for (final l in view.lines.where((l) => l.note != null))
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('${l.productName}: ${l.note}', style: MNText.body)),
      ]),
    );
  }
}

/// Signature B, Funga Siku: the approved charcoal fire sweep, natively.
/// Mounted only after the count is saved on the phone. One Ticker drives
/// the fire and the sequence; "Ruka" jumps to the settled frame; the effect
/// plays once per closing ID; reduced motion and reopening show the settled
/// frame without particles. Text and the button sit above the flame band.
class DayClosedScreen extends ConsumerStatefulWidget {
  const DayClosedScreen({super.key});

  @override
  ConsumerState<DayClosedScreen> createState() => _DayClosedScreenState();
}

/// Phases from the prototype: 1 glow (400 ms), 2 logo (900), 3 headline
/// (1300), 4 tagline (1450), 5 status and button (1600), 6 halo eases down
/// (2600). [settled] is the reduced-motion / replay frame.
int _phaseAt(double ms) => ms >= 2600
    ? 6
    : ms >= 1600
        ? 5
        : ms >= 1450
            ? 4
            : ms >= 1300
                ? 3
                : ms >= 900
                    ? 2
                    : ms >= 400
                        ? 1
                        : 0;
const settled = 9;

class _DayClosedScreenState extends ConsumerState<DayClosedScreen> {
  FireController? _fire;
  int _phase = 0;
  bool _skipped = false;
  String? _decidedFor;

  void _decide(String countId) {
    if (_decidedFor == countId) return;
    _decidedFor = countId;
    final played = ref.read(playedEffectsProvider);
    if (MNMotion.reduced(context) || played.contains(countId)) {
      _phase = settled;
      return;
    }
    played.add(countId);
    _fire = FireController()..addListener(_onTick);
    // Haptic: a light tap, then a firmer one (spec: 10·60·18 ms).
    HapticFeedback.lightImpact();
    Future<void>.delayed(
        MNMotion.hapticGap, () => HapticFeedback.mediumImpact());
  }

  void _onTick() {
    final next = _skipped
        ? math.max(5, _phaseAt(_fire!.elapsedMs))
        : _phaseAt(_fire!.elapsedMs);
    if (next != _phase && mounted) setState(() => _phase = next);
  }

  void _skip() {
    _skipped = true;
    _fire?.skipTo(1300); // the fire jumps to its settle
    setState(() => _phase = math.max(_phase, 5));
  }

  @override
  void dispose() {
    _fire?.removeListener(_onTick);
    _fire?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final view = ref.watch(todayClosingProvider).valueOrNull;
    if (view != null) _decide(view.countId);
    final p = _phase;
    final instant = p == settled;
    final width = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;

    Duration d(Duration duration) =>
        instant ? Duration.zero : MNMotion.of(context, duration);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(MNRoutes.home);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: MNColors.charcoal,
          body: Stack(fit: StackFit.expand, children: [
            // Orange glow from the lower edge (.fx-glow-b).
            Positioned(
              left: -40,
              right: -40,
              bottom: 0,
              height: 460,
              child: _Fade(
                opacity: p >= 2 ? .65 : (p >= 1 ? 1 : 0),
                duration: d(MNMotion.fireGlowFade),
                child: const _Glow(
                    colors: [MNColors.fireGlow, MNColors.fireGlowEdge],
                    stops: [0, .48, .76],
                    rx: .65,
                    ry: .7),
              ),
            ),
            // Red underglow.
            Positioned(
              left: -60,
              right: -60,
              bottom: 0,
              height: 400,
              child: _Fade(
                opacity: p >= 2 ? .75 : (p >= 1 ? 1 : 0),
                duration: d(MNMotion.fireUnderglowFade),
                child: const _Glow(colors: [
                  MNColors.fireUnderglow,
                  MNColors.fireUnderglowEdge
                ], stops: [
                  0,
                  .46,
                  .74
                ], rx: .6, ry: .62),
              ),
            ),
            // Halo behind the logo.
            Positioned(
              top: topInset + 60,
              left: (width - 320) / 2,
              width: 320,
              height: 320,
              child: _Fade(
                opacity: p >= 6 ? .6 : (p >= 2 ? 1 : 0),
                duration: d(MNMotion.fireHaloFade),
                child: AnimatedScale(
                  scale: p >= 6 ? 1.04 : (p >= 2 ? 1 : .8),
                  duration: d(MNMotion.fireHaloScale),
                  curve: MNMotion.easeOut,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        MNColors.fireHalo,
                        MNColors.fireHaloEdge,
                        MNColors.charcoalClear
                      ], stops: [
                        0,
                        .52,
                        1
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            // The fire, above the 24 px gesture inset, under the content.
            if (_fire != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                height: 300,
                child: IgnorePointer(
                  child:
                      FireCanvas(spec: FireSpec.fungaSiku(), controller: _fire),
                ),
              ),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(children: [
                  SizedBox(
                    height: MNSize.appBar,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: p < 5
                          ? MNTextButton(strings.skip,
                              color: MNColors.onDarkSkip, onPressed: _skip)
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        MNSpace.x6, MNSpace.x6, MNSpace.x6, 0),
                    child: Column(children: [
                      _LogoIn(
                          visible: p >= 2,
                          duration: d(MNMotion.logoIn),
                          child: MNLogo(
                              height: 210, semanticLabel: strings.brand)),
                      const SizedBox(height: MNSpace.x7),
                      _Rise(
                        visible: p >= 3,
                        duration: d(MNMotion.rise),
                        child: Semantics(
                          liveRegion: true,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${strings.dayClosedLead} '),
                              TextSpan(
                                  text: strings.dayClosedTail,
                                  style: const TextStyle(
                                      color: MNColors.fireHeadline)),
                            ]),
                            textAlign: TextAlign.center,
                            style: MNText.fireHeadline.copyWith(shadows: const [
                              Shadow(
                                  color: MNColors.fireHeadlineShadow,
                                  blurRadius: 28)
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Rise(
                        visible: p >= 4,
                        duration: d(MNMotion.rise),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const _TagBar(),
                          const SizedBox(width: MNSpace.x3),
                          Flexible(
                            child: Text(strings.tagline,
                                textAlign: TextAlign.center,
                                style: MNText.fireTagline),
                          ),
                          const SizedBox(width: MNSpace.x3),
                          const _TagBar(),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      _Rise(
                        visible: p >= 5,
                        duration: d(MNMotion.rise),
                        child: Column(children: [
                          Text(strings.finalCountSaved,
                              textAlign: TextAlign.center,
                              style: MNText.body.copyWith(
                                  fontSize: 15, color: MNColors.onDarkText)),
                          const SizedBox(height: MNSpace.x2),
                          if (view != null)
                            ClosingStatusLines(
                                status: view.status,
                                onDark: true,
                                conflictReason: view.conflictReason),
                        ]),
                      ),
                      const SizedBox(height: MNSpace.x7),
                      _Rise(
                        visible: p >= 5,
                        duration: d(MNMotion.rise),
                        child: MNButton(strings.backHome,
                            onPressed: p >= 5
                                ? () => context.go(MNRoutes.home)
                                : null),
                      ),
                      const SizedBox(height: MNSpace.x6),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A radial glow from the bottom centre (CSS `radial-gradient(ellipse
/// rx ry at 50% 100%, …)`).
class _Glow extends StatelessWidget {
  final List<Color> colors;
  final List<double> stops;
  final double rx, ry;
  const _Glow(
      {required this.colors,
      required this.stops,
      required this.rx,
      required this.ry});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomCenter,
            radius: 1,
            colors: [...colors, MNColors.charcoalClear],
            stops: stops,
            transform: _EllipseTransform(rx, ry),
          ),
        ),
      );
}

/// Stretches a circular gradient into the CSS ellipse.
class _EllipseTransform extends GradientTransform {
  final double sx, sy;
  const _EllipseTransform(this.sx, this.sy);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final scaleX = bounds.width * sx / (bounds.shortestSide / 2) / 2;
    final scaleY = bounds.height * sy / (bounds.shortestSide / 2) / 2;
    final origin = bounds.bottomCenter;
    return Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1)
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
  }
}

class _Fade extends StatelessWidget {
  final double opacity;
  final Duration duration;
  final Widget child;
  const _Fade(
      {required this.opacity, required this.duration, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedOpacity(
            opacity: opacity,
            duration: duration,
            curve: MNMotion.easeOut,
            child: child),
      );
}

/// `m-logo-in`: fade and scale .96 → 1 over 320 ms.
class _LogoIn extends StatelessWidget {
  final bool visible;
  final Duration duration;
  final Widget child;
  const _LogoIn(
      {required this.visible, required this.duration, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: MNMotion.easeOut,
        child: AnimatedScale(
            scale: visible ? 1 : .96,
            duration: duration,
            curve: MNMotion.easeOut,
            child: child),
      );
}

/// `m-rise`: fade in while rising 8 px over 240 ms.
class _Rise extends StatelessWidget {
  final bool visible;
  final Duration duration;
  final Widget child;
  const _Rise(
      {required this.visible, required this.duration, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: visible ? 1 : 0),
        duration: duration,
        curve: MNMotion.easeOut,
        child: child,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 8 * (1 - t)),
              child: IgnorePointer(ignoring: t < 1, child: child)),
        ),
      );
}

/// The short glowing red bars either side of the tagline.
class _TagBar extends StatelessWidget {
  const _TagBar();

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 3,
        decoration: BoxDecoration(
          color: MNColors.red,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(color: MNColors.fireBarGlow, blurRadius: 10)
          ],
        ),
      );
}
