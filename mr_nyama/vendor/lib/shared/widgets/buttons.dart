import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// `.btn-p`, `.btn-s`, `.btn-d`, `.btn-df`, `.btn-dk`.
enum MNButtonVariant {
  primary,
  secondary,
  destructive,
  destructiveFilled,
  onDark
}

/// Full-width 56 px button. A null [onPressed] shows the disabled style
/// (`.btn-x`). [busy] keeps the label width and shows a spinner instead of
/// the icon while an action is in progress.
class MNButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final MNButtonVariant variant;
  final MNIconData? icon;
  final bool busy;

  const MNButton(this.label,
      {super.key,
      required this.onPressed,
      this.variant = MNButtonVariant.primary,
      this.icon,
      this.busy = false});

  const MNButton.secondary(this.label,
      {super.key, required this.onPressed, this.icon, this.busy = false})
      : variant = MNButtonVariant.secondary;

  const MNButton.destructive(this.label,
      {super.key, required this.onPressed, this.icon, this.busy = false})
      : variant = MNButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final (
      Color fill,
      Color pressed,
      Color text,
      Color? line
    ) = !enabled && !busy
        ? (MNColors.disabled, MNColors.disabled, MNColors.disabledText, null)
        : switch (variant) {
            MNButtonVariant.primary => (
                MNColors.red,
                MNColors.redPressed,
                MNColors.white,
                null
              ),
            MNButtonVariant.secondary => (
                MNColors.white,
                MNColors.surfacePressed,
                MNColors.ink,
                MNColors.ink
              ),
            MNButtonVariant.destructive => (
                MNColors.white,
                MNColors.errorSurface,
                MNColors.error,
                MNColors.error
              ),
            MNButtonVariant.destructiveFilled => (
                MNColors.error,
                MNColors.error,
                MNColors.white,
                null
              ),
            MNButtonVariant.onDark => (
                MNColors.white,
                MNColors.surfacePressed,
                MNColors.ink,
                null
              ),
          };
    return MNPressable(
      onTap: enabled ? onPressed : null,
      color: fill,
      pressedColor: pressed,
      borderRadius: BorderRadius.circular(MNRadius.medium),
      border: line == null
          ? null
          : Border.all(color: line, width: MNSize.borderWidth),
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MNSize.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MNSpace.x5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                Padding(
                    padding: const EdgeInsets.only(right: MNSpace.x2),
                    child: MNSpinner(color: text, size: MNSize.iconMedium))
              else if (icon != null)
                Padding(
                    padding: const EdgeInsets.only(right: MNSpace.x2),
                    child: MNIcon(icon!, color: text)),
              Flexible(
                child: ExcludeSemantics(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: MNText.resolve(context, MNText.button)
                          .copyWith(color: text)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.btn-t`: red text button, 48 px tall.
class MNTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  const MNTextButton(this.label,
      {super.key, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) => MNPressable(
        onTap: onPressed,
        color: Colors.transparent,
        pressedColor: MNColors.textPressed,
        borderRadius: BorderRadius.circular(MNRadius.medium),
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minHeight: MNSize.textButton, minWidth: MNSize.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MNSpace.x3),
            child: Center(
              widthFactor: 1,
              child: ExcludeSemantics(
                child: Text(label,
                    style: MNText.resolve(context, MNText.textButton).copyWith(
                        color: onPressed == null
                            ? MNColors.disabledText
                            : color ?? MNColors.red)),
              ),
            ),
          ),
        ),
      );
}

/// `.ib`: 48 px round icon button, used in the app header.
class MNIconButton extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  const MNIconButton(this.icon,
      {super.key, required this.label, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: MNPressable(
          onTap: onPressed,
          pressedScale: MNMotion.pressChip,
          borderRadius: BorderRadius.circular(MNSize.iconButton / 2),
          semanticLabel: label,
          child: SizedBox.square(
              dimension: MNSize.iconButton,
              child: Center(child: MNIcon(icon, color: color))),
        ),
      );
}

/// `.spin`: the design system's arc spinner. Static under reduced motion.
class MNSpinner extends StatefulWidget {
  final Color? color;
  final double size;
  const MNSpinner({super.key, this.color, this.size = MNSize.icon});

  @override
  State<MNSpinner> createState() => _MNSpinnerState();
}

class _MNSpinnerState extends State<MNSpinner>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: MNMotion.spin);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MNMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _controller,
        child: MNIcon(MNIconData.spin, size: widget.size, color: widget.color),
      );
}
