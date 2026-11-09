import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

class MNNavItem {
  final MNIconData icon;
  final String label;
  const MNNavItem(this.icon, this.label);
}

/// Reference navigation: 56 px bar (grows with accessibility text) of equal columns. The active item is red and its icon
/// pops (.85 → 1, 180 ms spring). No badges or counters, by design.
class MNBottomNav extends StatelessWidget {
  final List<MNNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const MNBottomNav(
      {super.key,
      required this.items,
      required this.currentIndex,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
            color: MNColors.white,
            border: Border(top: BorderSide(color: MNColors.border))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MNSize.navBar +
                (MediaQuery.textScalerOf(context).scale(16) - 16),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                      child: _NavButton(
                          item: items[i],
                          selected: i == currentIndex,
                          onTap: () => onSelect(i))),
              ],
            ),
          ),
        ),
      );
}

class _NavButton extends StatelessWidget {
  /// The reference caption at medium weight: at regular (400) Manrope's thin
  /// strokes anti-alias to pale pixels on 1× screens and the label falls
  /// below the 4.5:1 text-contrast guideline.
  static final _label =
      MNText.withWeight(MNText.referenceCaption, FontWeight.w500);

  final MNNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? MNColors.red : MNColors.ink2;
    return MNPressable(
      onTap: onTap,
      pressedScale: 1,
      semanticLabel: item.label,
      selected: selected,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pop(
              key: ValueKey(selected),
              play: selected,
              child:
                  MNIcon(item.icon, size: 28, strokeWidth: 1.5, color: color)),
          const SizedBox(height: MNSpace.x1),
          ExcludeSemantics(
            child: AnimatedDefaultTextStyle(
              duration: MNMotion.of(context, MNMotion.small),
              style: _label.copyWith(color: color),
              child: Text(item.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pop extends StatelessWidget {
  final bool play;
  final Widget child;
  const _Pop({super.key, required this.play, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!play || MNMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .85, end: 1),
      duration: MNMotion.navPop,
      curve: MNMotion.spring,
      child: child,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
    );
  }
}
