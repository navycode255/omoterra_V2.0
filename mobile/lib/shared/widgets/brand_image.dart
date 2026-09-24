import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import 'supply_art.dart';

/// Photography slots used by the designed screens.
///
/// Drop a file into `assets/images/` using the names below and it appears
/// automatically; until then the screen falls back to the in-app vector
/// artwork, so no screen is ever broken by a missing file.
///
///   splash.jpg          full-bleed splash background
///   welcome.jpg         welcome hero
///   `category_<name>.jpg` broilers, local_chicken, goats, cattle, meat, other
///   `business_<name>.jpg` chicken_shop, butchery, fish_shop, meat_delivery,
///                       egg_reseller, local_chicken_business,
///                       goat_meat_business, restaurant_grill
///
/// Any common format works as long as the extension is .jpg; see
/// docs/photography.md for the full slot list and sizing.
class BrandImage extends StatelessWidget {
  final String name;
  final String fallbackArt;
  final String extension;
  final BoxFit fit;

  /// Which part of the photograph survives a cover crop.
  final Alignment alignment;
  final double? height;
  final double? width;
  final Widget? overlay;

  const BrandImage(
    this.name, {
    super.key,
    required this.fallbackArt,
    this.extension = 'jpg',
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.height,
    this.width,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/$name.$extension',
      fit: fit,
      alignment: alignment,
      height: height,
      width: width,
      // A missing asset is the expected state until photography is supplied.
      errorBuilder: (context, error, stack) => Container(
        height: height,
        width: width,
        color: OColors.soft,
        child: Center(
          child: SupplyArt(fallbackArt,
              size: (height ?? 160) * .7, surface: false),
        ),
      ),
    );
    if (overlay == null) return image;
    return Stack(fit: StackFit.passthrough, children: [image, overlay!]);
  }
}

/// Dark scrim so white type stays legible over photography of any brightness.
class PhotoScrim extends StatelessWidget {
  final double opacity;
  const PhotoScrim({super.key, this.opacity = .45});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
            Colors.black.withValues(alpha: opacity * .35),
            Colors.black.withValues(alpha: opacity),
          ])),
      child: const SizedBox.expand());
}
