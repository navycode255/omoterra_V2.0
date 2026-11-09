import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Shared surface and icon proportions from the October screen references.
BoxDecoration referenceSurface({double radius = 16}) => BoxDecoration(
      color: MNColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: MNColors.cardBorder),
      boxShadow: const [
        BoxShadow(
            color: MNColors.cardShadow, blurRadius: 18, offset: Offset(0, 7))
      ],
    );

/// A large action card from the October screen references: icon square,
/// title, one line of help and a chevron. [primary] is the red card;
/// [compact] is the 2×2 grid size used on Nyumbani.
///
/// Press feedback is the design system's (scale and colour, no ripple), and
/// screen readers hear one button: "title, help".
class MNReferenceAction extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;
  const MNReferenceAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.subtitle,
      required this.onTap,
      this.primary = false,
      this.compact = false});
  @override
  Widget build(BuildContext context) {
    final fg = primary ? MNColors.white : MNColors.ink;
    final radius = BorderRadius.circular(primary ? 12 : 16);
    return MNPressable(
      onTap: onTap,
      pressedScale: MNMotion.pressCard,
      scaleDuration: MNMotion.cardPress,
      borderRadius: radius,
      semanticLabel: '$label, $subtitle',
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 72 : 74),
        decoration: primary
            ? BoxDecoration(color: MNColors.red, borderRadius: radius)
            : referenceSurface(),
        child: ExcludeSemantics(
          child: Padding(
              padding: EdgeInsets.all(compact ? 9 : 10),
              child: Row(children: [
                Container(
                    width: compact ? 42 : 54,
                    height: compact ? 44 : 54,
                    decoration: BoxDecoration(
                        color: primary
                            ? MNColors.white.withValues(alpha: .16)
                            : icon == MNIconData.truck
                                ? MNColors.roseSurface
                                : MNColors.iconSurface,
                        borderRadius: BorderRadius.circular(compact ? 10 : 13)),
                    child: Center(
                        child:
                            MNIcon(icon, size: compact ? 27 : 34, color: fg))),
                SizedBox(width: compact ? 8 : 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(label,
                          style: MNText.withWeight(
                                  compact
                                      ? MNText.tile.copyWith(
                                          fontSize: 14, letterSpacing: -.3)
                                      : MNText.heading.copyWith(fontSize: 20),
                                  FontWeight.w800)
                              .copyWith(color: fg)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: (compact
                                  ? MNText.withWeight(
                                          MNText.meta, FontWeight.w400)
                                      .copyWith(
                                          fontSize: 9.4,
                                          height: 1.3,
                                          letterSpacing: -.3)
                                  : MNText.body.copyWith(fontSize: 15))
                              .copyWith(
                                  color: primary
                                      ? MNColors.white
                                      : MNColors.muted)),
                    ])),
                MNIcon(MNIconData.chevron,
                    size: compact ? 16 : 22,
                    color: primary ? MNColors.white : MNColors.muted),
              ])),
        ),
      ),
    );
  }
}
