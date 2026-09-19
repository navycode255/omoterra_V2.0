import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/supply_art.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        body: Stack(fit: StackFit.expand, children: [
      const BrandImage('splash', fallbackArt: 'cattle', fit: BoxFit.cover),
      // The photograph carries a bright sky at the top and foliage at the
      // bottom, so the wordmark sits over the sky in dark ink and only the
      // lower tagline needs a scrim.
      const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x80000000)])),
          child: SizedBox.expand()),
      SafeArea(
          child: Column(children: [
            const SizedBox(height: 64),
            // The supplied logo carries its own tagline, so the headline sits
            // below it rather than repeating the brand line.
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: BrandMark(size: 46)),
            const SizedBox(height: 18),
            Text(s.splashHeadline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: OColors.forest)),
            const Spacer(),
            Text(s.splashTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.5)),
            const SizedBox(height: 22),
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            const SizedBox(height: 40),
          ]))
    ]));
  }
}
