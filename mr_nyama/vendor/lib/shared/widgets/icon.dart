import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/theme.dart';

/// One of the approved line icons, tinted like text (`background:
/// currentColor` in the design system). Decorative unless [semanticLabel]
/// is given.
class MNIcon extends StatelessWidget {
  final MNIconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final double? strokeWidth;
  const MNIcon(this.icon,
      {super.key,
      this.size = MNSize.icon,
      this.color,
      this.semanticLabel,
      this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    final tint = color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        MNColors.ink;
    final detailed =
        {MNIconData.food, MNIconData.roast, MNIconData.wings}.contains(icon);
    final ink =
        '#${(tint.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    var svg =
        detailed ? icon.svg.replaceAll(RegExp('#000000|#000'), ink) : icon.svg;
    if (strokeWidth != null && !detailed) {
      svg = svg.replaceAll(
          RegExp(r'stroke-width="[^"]+"'), 'stroke-width="$strokeWidth"');
    }
    final picture = SvgPicture.string(svg,
        width: size,
        height: size,
        colorFilter: detailed ? null : ColorFilter.mode(tint, BlendMode.srcIn),
        excludeFromSemantics: true);
    if (semanticLabel == null) return ExcludeSemantics(child: picture);
    return Semantics(label: semanticLabel, image: true, child: picture);
  }
}
