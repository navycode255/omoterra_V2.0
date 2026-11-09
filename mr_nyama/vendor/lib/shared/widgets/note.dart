import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';

enum MNNoteTone { info, warning, error }

/// `.note`: a calm inline message on a tinted surface. `info` (`.note.i`)
/// is neutral grey, for facts such as "voided"; warning and error are for
/// things that need attention.
class MNNote extends StatelessWidget {
  final String text;
  final MNNoteTone tone;
  final MNIconData? icon;

  const MNNote(this.text,
      {super.key, bool error = false, MNNoteTone? tone, this.icon})
      : tone = tone ?? (error ? MNNoteTone.error : MNNoteTone.warning);

  @override
  Widget build(BuildContext context) {
    final (surface, iconColor, textColor, defaultIcon) = switch (tone) {
      MNNoteTone.info => (
          MNColors.surface,
          MNColors.ink2,
          MNColors.ink,
          MNIconData.info
        ),
      MNNoteTone.warning => (
          MNColors.warningSurface,
          MNColors.warning,
          MNColors.ink,
          MNIconData.warn
        ),
      MNNoteTone.error => (
          MNColors.errorSurface,
          MNColors.error,
          MNColors.error,
          MNIconData.error
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: MNSpace.x3),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(MNRadius.medium)),
        child: Row(children: [
          MNIcon(icon ?? defaultIcon, color: iconColor),
          const SizedBox(width: MNSpace.x3),
          Expanded(
              child: Text(text,
                  style: MNText.resolve(context, MNText.note)
                      .copyWith(color: textColor))),
        ]),
      ),
    );
  }
}
