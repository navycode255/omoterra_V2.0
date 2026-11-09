import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// `.step` with `.qb` buttons and a `.qv` value: − value +. The value rolls
/// up or down (160 ms) when it changes. [large] is the 64 px variant used on
/// the quantity sheet. Buttons switch to the disabled style (`.qb.off`) at
/// [min] and [max]. [compact] is the Kikapu reference stepper (approved
/// 22 October 2026): 30 px light-grey squares inside 48 px tap targets; it
/// is the canonical inline "idadi" stepper for lists.
class MNQuantitySelector extends ConsumerWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final bool large;
  final bool compact;

  /// What is being counted, for screen readers ("Kuku Choma").
  final String itemLabel;

  const MNQuantitySelector(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.itemLabel,
      this.min = 0,
      this.max,
      this.large = false,
      this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final canDecrease = value > min;
    final canIncrease = max == null || value < max!;
    return Semantics(
      label: itemLabel,
      value: '$value',
      increasedValue: canIncrease ? '${value + 1}' : null,
      decreasedValue: canDecrease ? '${value - 1}' : null,
      onIncrease: canIncrease ? () => onChanged(value + 1) : null,
      onDecrease: canDecrease ? () => onChanged(value - 1) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MNQuantityButton(
              icon: MNIconData.minus,
              label: '${strings.decrease} $itemLabel',
              large: large,
              compact: compact,
              onPressed: canDecrease ? () => onChanged(value - 1) : null),
          ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: compact ? 31 : (large ? 88 : 40), minHeight: 24),
            child: ExcludeSemantics(
              child: MNRollingNumber(value,
                  style: compact
                      ? MNText.kikapuQuantity
                      : (large ? MNText.quantityLarge : MNText.quantity)),
            ),
          ),
          MNQuantityButton(
              icon: MNIconData.plus,
              label: '${strings.increase} $itemLabel',
              large: large,
              compact: compact,
              onPressed: canIncrease ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

/// `.qb`: square quantity button. [active] is the filled black style;
/// [compact] the Kikapu reference square (30 px visual, 48 px target).
class MNQuantityButton extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool large;
  final bool active;
  final bool compact;

  const MNQuantityButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.large = false,
      this.active = false,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (compact) {
      return MNPressable(
        onTap: onPressed,
        pressedScale: MNMotion.pressQuantity,
        scaleDuration: MNMotion.keyPress,
        semanticLabel: label,
        child: SizedBox.square(
          dimension: MNSize.minTouch,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: MNColors.kikapuStepper,
                  borderRadius: BorderRadius.circular(7)),
              child: Center(
                  child: MNIcon(icon,
                      size: 16,
                      strokeWidth: 1.8,
                      color: enabled ? MNColors.ink : MNColors.disabledText)),
            ),
          ),
        ),
      );
    }
    final size = large ? MNSize.quantityLarge : MNSize.quantity;
    final (fill, line, fg) = !enabled
        ? (MNColors.disabled, MNColors.disabled, MNColors.disabledText)
        : active
            ? (MNColors.ink, MNColors.ink, MNColors.white)
            : (MNColors.white, MNColors.borderStrong, MNColors.ink);
    return MNPressable(
      onTap: onPressed,
      pressedScale: MNMotion.pressQuantity,
      scaleDuration: MNMotion.keyPress,
      colorDuration: MNMotion.cardPress,
      color: fill,
      pressedColor: fill,
      borderRadius:
          BorderRadius.circular(large ? MNRadius.medium : MNRadius.small),
      border: Border.all(color: line, width: MNSize.borderWidth),
      semanticLabel: label,
      child: SizedBox.square(
          dimension: size, child: Center(child: MNIcon(icon, color: fg))),
    );
  }
}

/// A number that rolls in the direction it changed (`roll-up`/`roll-dn`).
class MNRollingNumber extends StatefulWidget {
  final int value;
  final TextStyle style;
  final String Function(int)? format;
  const MNRollingNumber(this.value,
      {super.key, required this.style, this.format});

  @override
  State<MNRollingNumber> createState() => _MNRollingNumberState();
}

class _MNRollingNumberState extends State<MNRollingNumber> {
  int _direction = 1;

  @override
  void didUpdateWidget(covariant MNRollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _direction = widget.value > oldWidget.value ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.format?.call(widget.value) ?? '${widget.value}',
        key: ValueKey(widget.value),
        textAlign: TextAlign.center,
        style: widget.style);
    return AnimatedSwitcher(
      duration: MNMotion.of(context, MNMotion.valueRoll),
      switchInCurve: MNMotion.easeOut,
      layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [if (current != null) current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(widget.value);
        if (!incoming) return const SizedBox.shrink();
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
              position:
                  Tween(begin: Offset(0, .45 * _direction), end: Offset.zero)
                      .animate(animation),
              child: child),
        );
      },
      child: text,
    );
  }
}

/// Text that rolls up (or down) to its new value: `roll-up` / `roll-dn`,
/// 160 ms. Used for running totals.
class MNRollingText extends StatelessWidget {
  final String text;
  final bool up;
  final TextStyle style;
  const MNRollingText(this.text,
      {super.key, required this.style, this.up = true});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MNMotion.of(context, MNMotion.valueRoll),
        switchInCurve: MNMotion.easeOut,
        layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [if (current != null) current]),
        transitionBuilder: (child, animation) {
          if (child.key != ValueKey(text)) return const SizedBox.shrink();
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
                position:
                    Tween(begin: Offset(0, up ? .45 : -.45), end: Offset.zero)
                        .animate(animation),
                child: child),
          );
        },
        child: Text(text,
            key: ValueKey(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style),
      );
}
