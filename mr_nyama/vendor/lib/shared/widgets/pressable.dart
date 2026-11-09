import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Press feedback from the design system: transform and colour only, no
/// ripple. Scales to [pressedScale] and swaps [color] for [pressedColor]
/// while held. Disabled when [onTap] and [onLongPress] are both null.
class MNPressable extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration scaleDuration;
  final Duration colorDuration;
  final Color? color;
  final Color? pressedColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final String? semanticLabel;
  final bool button;
  final bool? selected;
  final Widget child;

  const MNPressable({
    super.key,
    required this.onTap,
    this.onLongPress,
    this.pressedScale = MNMotion.pressButton,
    this.scaleDuration = MNMotion.instant,
    this.colorDuration = MNMotion.small,
    this.color,
    this.pressedColor,
    this.borderRadius,
    this.border,
    this.semanticLabel,
    this.button = true,
    this.selected,
    required this.child,
  });

  @override
  State<MNPressable> createState() => _MNPressableState();
}

class _MNPressableState extends State<MNPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool pressed) {
    if (_pressed != pressed && mounted) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed && _enabled;
    final fill = pressed ? widget.pressedColor ?? widget.color : widget.color;
    final decorated = AnimatedContainer(
      duration: MNMotion.of(context, widget.colorDuration),
      curve: Curves.linear,
      decoration: BoxDecoration(color: fill, borderRadius: widget.borderRadius),
      // Drawn in front so it takes no layout space: the design uses
      // `box-sizing: border-box`, so a 56 px outlined button stays 56 px.
      foregroundDecoration: widget.border == null
          ? null
          : BoxDecoration(
              borderRadius: widget.borderRadius, border: widget.border),
      child: widget.child,
    );
    return Semantics(
      button: widget.button,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapUp: _enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onLongPressEnd: (_) => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: pressed ? widget.pressedScale : 1,
          duration: MNMotion.of(context, widget.scaleDuration),
          curve: MNMotion.easeOut,
          child: decorated,
        ),
      ),
    );
  }
}
