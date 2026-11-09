import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'quantity.dart';

/// `.cartbar` + `.cartbtn`: the red bar above the navigation showing what is
/// in the active sale. It springs in (260 ms) when the first item is added
/// and drops out (160 ms) when the cart empties. [total] is computed from
/// the authoritative product prices by the caller.
class MNCartBar extends ConsumerStatefulWidget {
  final int itemCount;

  /// Null while any price is unknown; the bar then shows the count only.
  final int? total;
  final VoidCallback onTap;

  const MNCartBar(
      {super.key,
      required this.itemCount,
      required this.total,
      required this.onTap});

  @override
  ConsumerState<MNCartBar> createState() => _MNCartBarState();
}

class _MNCartBarState extends ConsumerState<MNCartBar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this,
      duration: MNMotion.cartIn,
      reverseDuration: MNMotion.cartOut,
      value: widget.itemCount > 0 ? 1 : 0);
  late final _curve = CurvedAnimation(
      parent: _controller,
      curve: MNMotion.spring,
      reverseCurve: MNMotion.easeIn);

  // Last non-empty values, so the bar keeps its content while it leaves.
  late int _count = widget.itemCount;
  late int _previousCount = widget.itemCount;
  late int? _total = widget.total;

  @override
  void didUpdateWidget(covariant MNCartBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount > 0) {
      _previousCount = _count;
      _count = widget.itemCount;
      _total = widget.total;
    }
    final show = widget.itemCount > 0;
    if (MNMotion.reduced(context)) {
      _controller.value = show ? 1 : 0;
    } else if (show) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final label = _total == null
        ? strings.itemsCount(_count)
        : '${strings.itemsCount(_count)} · ${formatTsh(_total!)}';
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        if (_controller.value == 0) return const SizedBox.shrink();
        // Height follows the linear controller so layout never overshoots;
        // the spring shows in the slide.
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _controller.value,
            child: Opacity(
              opacity: _curve.value.clamp(0.0, 1.0),
              child: FractionalTranslation(
                  translation: Offset(0, 1 - _curve.value), child: child),
            ),
          ),
        );
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
            color: MNColors.white,
            border: Border(top: BorderSide(color: MNColors.border))),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MNSpace.x4, vertical: MNSpace.x2),
          child: MNPressable(
            onTap: widget.onTap,
            color: MNColors.red,
            pressedColor: MNColors.redPressed,
            colorDuration: MNMotion.cardPress,
            borderRadius: BorderRadius.circular(MNRadius.medium),
            semanticLabel: '${strings.viewCart}, $label',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MNSize.button),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    MNSpace.x4, MNSpace.x2, MNSpace.x3, MNSpace.x2),
                child: Row(children: [
                  const MNIcon(MNIconData.bag, color: MNColors.white),
                  const SizedBox(width: MNSpace.x3),
                  Expanded(
                    child: ExcludeSemantics(
                      // The count and total roll with each change (160 ms).
                      child: MNRollingText(label,
                          up: _count >= _previousCount,
                          style: MNText.button.copyWith(color: MNColors.white)),
                    ),
                  ),
                  const MNIcon(MNIconData.chevron, color: MNColors.white),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
