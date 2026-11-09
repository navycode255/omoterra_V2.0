import 'package:flutter/material.dart';

import '../../core/media/photo_cache.dart';
import '../../core/theme/theme.dart';
import 'image_spinner.dart';
import 'pressable.dart';

/// A person's circle: their photo when they have uploaded one, with the ember
/// ring while it loads; otherwise, or if it fails, [initials]. The photo is
/// decoded at the circle's size, so a long list stays light in memory.
class MNPersonPhoto extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color color;
  final Widget initials;
  const MNPersonPhoto(
      {super.key,
      required this.imageUrl,
      required this.size,
      required this.color,
      required this.initials});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: ExcludeSemantics(
            child: url == null
                ? initials
                : ClipOval(
                    child: SizedBox.square(
                        dimension: size,
                        child: MNLoadingImage(
                            image: ResizeImage(CachedPhoto(url), width: pixels),
                            onDark: false,
                            error: Center(child: initials))))));
  }
}

/// `.avatar`: initials on a dark 40 px circle. With [onTap] it becomes a
/// 48 px touch target (the circle stays 40 px).
class MNAvatar extends StatelessWidget {
  final String name;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const MNAvatar(
      {super.key,
      required this.name,
      this.size = MNSize.avatar,
      this.onTap,
      this.semanticLabel});

  /// "Maternus Juma" → "MJ"; one name → its first letter. Words that do
  /// not start with a letter ("(Mwenge)", "2") are skipped.
  static String initials(String name) {
    final letter = RegExp(r'^\p{L}', unicode: true);
    final firsts = name
        .split(RegExp(r'\s+'))
        .map((p) => letter.stringMatch(p))
        .whereType<String>()
        .take(2);
    return firsts.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: MNColors.avatar, shape: BoxShape.circle),
      child: ExcludeSemantics(
        child: Text(initials(name),
            style: MNText.chip
                .copyWith(color: MNColors.white, fontSize: size * .35)),
      ),
    );
    if (onTap == null) {
      return Semantics(label: semanticLabel ?? name, child: circle);
    }
    return MNPressable(
      onTap: onTap,
      pressedScale: MNMotion.pressChip,
      semanticLabel: semanticLabel ?? name,
      child: SizedBox.square(
          dimension: size < MNSize.minTouch ? MNSize.minTouch : size,
          child: Center(child: circle)),
    );
  }
}
