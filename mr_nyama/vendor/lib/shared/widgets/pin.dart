import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// `.dots`: one dot per PIN digit. Empty dots are outlined and slightly
/// smaller; filled dots spring to full size. On [error] the dots empty and
/// shake (280 ms). Digits are never shown or announced, only the count.
class MNPinDots extends ConsumerStatefulWidget {
  final int length;
  final int filled;
  final bool error;

  /// Space between dots, and how empty dots look; the sign-in defaults.
  final double gap;
  final double emptyScale;
  final Color emptyBorder;
  const MNPinDots(
      {super.key,
      this.length = 4,
      required this.filled,
      this.error = false,
      this.gap = MNSpace.x5,
      this.emptyScale = .8,
      this.emptyBorder = MNColors.ink2});

  @override
  ConsumerState<MNPinDots> createState() => _MNPinDotsState();
}

class _MNPinDotsState extends ConsumerState<MNPinDots>
    with SingleTickerProviderStateMixin {
  late final _shake =
      AnimationController(vsync: this, duration: MNMotion.shake);

  @override
  void didUpdateWidget(covariant MNPinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error && !MNMotion.reduced(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// `m-shake` keyframes: 0, −8, 7, −4, 2, 0 px at 0/20/40/60/80/100%.
  static double _offset(double t) {
    const points = [0.0, -8.0, 7.0, -4.0, 2.0, 0.0];
    final x = MNMotion.standard.transform(t) * 5;
    final i = math.min(x.floor(), 4);
    return points[i] + (points[i + 1] - points[i]) * (x - i);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Semantics(
      label: strings.pinDigits(widget.filled, widget.length),
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
            offset: Offset(_offset(_shake.value), 0), child: child),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) SizedBox(width: widget.gap),
              _Dot(
                  filled: i < widget.filled,
                  error: widget.error,
                  emptyScale: widget.emptyScale,
                  emptyBorder: widget.emptyBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool filled;
  final bool error;
  final double emptyScale;
  final Color emptyBorder;
  const _Dot(
      {required this.filled,
      required this.error,
      required this.emptyScale,
      required this.emptyBorder});

  @override
  Widget build(BuildContext context) {
    final fill = error
        ? Colors.transparent
        : filled
            ? MNColors.ink
            : Colors.transparent;
    return AnimatedScale(
      scale: filled || error ? 1 : emptyScale,
      duration: MNMotion.of(context, MNMotion.cardPress),
      curve: MNMotion.spring,
      child: AnimatedContainer(
        duration: MNMotion.of(context, MNMotion.keyPress),
        width: MNSize.pinDot,
        height: MNSize.pinDot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          // The reference empties the dots on an error; the shake and the
          // red message under them say what happened.
          border: filled && !error
              ? null
              : Border.all(color: emptyBorder, width: 1.5),
        ),
      ),
    );
  }
}

/// `.keys`: 3-column keypad of 64 px keys (1–9, then blank, 0, backspace).
/// Each key gives light haptic feedback. [tiles] is the PIN pad of the
/// owner-approved reference (30 October 2026): white rounded keys filling
/// the row, a red fingerprint key, and grey keys while disabled.
class MNPinKeypad extends ConsumerWidget {
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final VoidCallback? onBiometric;
  final bool tiles;

  /// Tile sizing and colours for a pad that differs from sign-in's.
  final double? tileHeight, tileGap, tileColumnGap, tileRadius, backspaceSize;
  final TextStyle? digitStyle;
  final Color? disabledKey, disabledGlyph;

  const MNPinKeypad(
      {super.key,
      required this.onDigit,
      required this.onBackspace,
      this.enabled = true,
      this.onBiometric,
      this.tiles = false,
      this.tileHeight,
      this.tileGap,
      this.tileColumnGap,
      this.tileRadius,
      this.backspaceSize,
      this.digitStyle,
      this.disabledKey,
      this.disabledGlyph});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final keyText = digitStyle ?? MNText.resolve(context, MNText.key);
    final height = tileHeight ?? _Key.tileHeight;
    final glyphOff = disabledGlyph ?? MNColors.disabledText;
    Widget digit(int d) => _Key(
        label: '$d',
        tiles: tiles,
        height: height,
        radius: tileRadius,
        disabledColor: disabledKey,
        onTap: enabled ? () => onDigit(d) : null,
        child: Text('$d',
            style: tiles && !enabled
                ? keyText.copyWith(color: glyphOff)
                : keyText));
    Widget row(List<Widget> keys) => Row(children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: tileColumnGap ?? MNSpace.x3),
            Expanded(child: keys[i]),
          ]
        ]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ]) ...[
          row([for (final d in r) digit(d)]),
          SizedBox(height: tiles ? tileGap ?? MNSpace.x2 + 2 : MNSpace.x3),
        ],
        row([
          onBiometric == null
              ? SizedBox(height: tiles ? height : MNSize.key)
              : _Key(
                  label: strings.biometricUnlock,
                  tiles: tiles,
                  onTap: enabled ? onBiometric : null,
                  child: Icon(Icons.fingerprint,
                      size: 30,
                      color: !tiles
                          ? MNColors.ink2
                          : enabled
                              ? MNColors.red
                              : MNColors.disabledText)),
          digit(0),
          _Key(
              label: strings.backspace,
              ghost: !tiles,
              tiles: tiles,
              height: height,
              radius: tileRadius,
              disabledColor: disabledKey,
              onTap: enabled ? onBackspace : null,
              child: MNIcon(MNIconData.backspace,
                  size: backspaceSize ?? 28,
                  color: tiles && !enabled ? glyphOff : null)),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  /// A tile key's height (at least the 48 px tap target).
  static const tileHeight = 52.0;

  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  final bool tiles;
  final Widget child;
  final double height;
  final double? radius;
  final Color? disabledColor;
  const _Key(
      {required this.label,
      required this.onTap,
      required this.child,
      this.ghost = false,
      this.tiles = false,
      this.height = tileHeight,
      this.radius,
      this.disabledColor});

  @override
  Widget build(BuildContext context) => tiles ? _tile() : _round();

  Widget _tile() => MNPressable(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        pressedScale: MNMotion.pressKey,
        scaleDuration: MNMotion.keyPress,
        colorDuration: MNMotion.keyPress,
        color:
            onTap == null ? disabledColor ?? MNColors.disabled : MNColors.white,
        pressedColor: MNColors.surfacePressed,
        borderRadius: BorderRadius.circular(radius ?? MNRadius.medium),
        semanticLabel: label,
        child: SizedBox(
            height: height,
            child: Center(child: ExcludeSemantics(child: child))),
      );

  Widget _round() => Align(
      child: SizedBox(
          width: MNSize.key,
          child: MNPressable(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            pressedScale: MNMotion.pressKey,
            scaleDuration: MNMotion.keyPress,
            colorDuration: MNMotion.keyPress,
            color: ghost ? Colors.transparent : MNColors.referenceAvatar,
            pressedColor: MNColors.surfacePressed,
            borderRadius: BorderRadius.circular(100),
            semanticLabel: label,
            child: SizedBox(
                height: MNSize.key,
                child: Center(child: ExcludeSemantics(child: child))),
          )));
}

/// `.codebox`: one 48 × 56 box per digit of a staff-issued code. The next
/// box to fill has the 2 px ink border; on [error] all boxes turn red and
/// shake. Unlike a PIN, the code's digits are shown so it can be checked
/// against the paper it was written on.
class MNCodeBoxes extends ConsumerStatefulWidget {
  final int length;
  final String value;
  final bool error;
  const MNCodeBoxes(
      {super.key, this.length = 6, required this.value, this.error = false});

  @override
  ConsumerState<MNCodeBoxes> createState() => _MNCodeBoxesState();
}

class _MNCodeBoxesState extends ConsumerState<MNCodeBoxes>
    with SingleTickerProviderStateMixin {
  late final _shake =
      AnimationController(vsync: this, duration: MNMotion.shake);

  @override
  void didUpdateWidget(covariant MNCodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error && !MNMotion.reduced(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Semantics(
      label: strings.pinDigits(widget.value.length, widget.length),
      value: widget.value,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
              offset: Offset(_MNPinDotsState._offset(_shake.value), 0),
              child: child),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: MNSpace.x2),
                  _CodeBox(
                      digit: i < widget.value.length ? widget.value[i] : '',
                      focused: i == widget.value.length,
                      error: widget.error),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String digit;
  final bool focused;
  final bool error;
  const _CodeBox(
      {required this.digit, required this.focused, required this.error});

  @override
  Widget build(BuildContext context) {
    final color = error
        ? MNColors.error
        : focused
            ? MNColors.ink
            : MNColors.borderStrong;
    return AnimatedContainer(
      duration: MNMotion.of(context, MNMotion.cardPress),
      width: 48,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MNRadius.medium),
          border: Border.all(
              color: color,
              width: error || focused
                  ? MNSize.focusBorderWidth
                  : MNSize.borderWidth)),
      child: Text(digit, style: MNText.resolve(context, MNText.code)),
    );
  }
}
