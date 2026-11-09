import 'package:flutter/material.dart';

/// The supplied Mr. Nyama brand mark, bundled for offline use.
const mrNyamaLogoAsset = 'assets/brand/icon.png';

/// The same artwork with the "MR. NYAMA Smokeeyyy!" wording under it.
const mrNyamaFullLogoAsset = 'assets/brand/logo.png';

/// Reuses the original artwork without redrawing or recolouring it.
class MNLogo extends StatelessWidget {
  final double height;
  final String semanticLabel;
  final bool full;
  const MNLogo(
      {super.key,
      required this.height,
      required this.semanticLabel,
      this.full = false});

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        image: true,
        child: Image.asset(full ? mrNyamaFullLogoAsset : mrNyamaLogoAsset,
            height: height,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => SizedBox(height: height)),
      );
}
