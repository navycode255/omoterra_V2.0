import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    // The photograph fills the screen and the content panel floats over its
    // lower half, its background fading up into the image so the two meet as
    // haze rather than at a cut line.
    return ExitOnBack(
        child: Scaffold(
            body: Stack(fit: StackFit.expand, children: [
      // The photograph runs well past the panel's top edge so the panel's
      // gradient dissolves over the image itself rather than over bare
      // background, which would still read as a cut.
      const Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
              heightFactor: .78,
              // welcome.jpg is authored at this slot's aspect ratio, so the
              // cover fit keeps every animal in frame without cropping.
              child: BrandImage('welcome', fallbackArt: 'cattle'))),
      Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                  child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 150, 24, 20),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [
                            0,
                            .18,
                            .40,
                            1
                          ],
                              colors: [
                            OColors.background.withValues(alpha: 0),
                            OColors.background.withValues(alpha: .70),
                            OColors.background,
                            OColors.background,
                          ])),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(s.welcomeTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(s.welcomeBody,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: OColors.secondary, height: 1.5)),
                        const SizedBox(height: 26),
                        // One button, because there is one auth path: the
                        // OTP creates the account if the number is new and
                        // signs in if it already exists. A separate
                        // "I already have an account" would lead to the
                        // very same screen.
                        OmoterraButton(s.getStarted,
                            onPressed: () => context.push('/phone')),
                        const SizedBox(height: 12),
                        Text(s.signInHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: OColors.secondary)),
                        // Small on purpose: only Omoterra staff need it.
                        TextButton(
                            onPressed: () => context.push('/admin'),
                            child: Text(s.omoterraStaff,
                                style: const TextStyle(
                                    fontSize: 12, color: OColors.muted))),
                      ]))))),
    ])));
  }
}
