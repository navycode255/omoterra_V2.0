import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// `.tile`: an 88 px action tile with an icon and a short title. [primary]
/// is the red tile. No counters or subtitles.
class MNTile extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const MNTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? MNColors.white : MNColors.ink;
    return MNPressable(
      onTap: onTap,
      pressedScale: MNMotion.pressCard,
      color: primary ? MNColors.red : MNColors.surface,
      pressedColor: primary ? MNColors.redPressed : MNColors.surfacePressed,
      colorDuration: MNMotion.instant,
      borderRadius: BorderRadius.circular(MNRadius.medium),
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MNSize.tile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MNIcon(icon, color: fg),
              const SizedBox(height: MNSpace.x2),
              ExcludeSemantics(
                child: Text(label, style: MNText.tile.copyWith(color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
