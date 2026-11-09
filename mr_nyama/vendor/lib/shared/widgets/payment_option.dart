import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// `.pay`: a 72 px payment choice with a radio. Selected: 2 px ink border
/// and a radio that thickens with the spring curve. Disabled when
/// [onTap] is null.
class MNPaymentOption extends StatelessWidget {
  final MNIconData icon;
  final String title;
  final String caption;
  final bool selected;
  final bool reference;
  final VoidCallback? onTap;

  const MNPaymentOption(
      {super.key,
      required this.icon,
      required this.title,
      required this.caption,
      required this.selected,
      this.reference = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (reference) return _reference(context);
    final enabled = onTap != null;
    final fg = enabled ? MNColors.ink : MNColors.disabledText;
    return MNPressable(
      onTap: onTap,
      pressedScale: .99,
      color: reference
          ? (selected ? MNColors.roseSurface : MNColors.white)
          : (enabled ? MNColors.white : MNColors.disabled),
      borderRadius: BorderRadius.circular(MNRadius.medium),
      border: reference
          ? null
          : Border.all(
              color: selected
                  ? (reference ? MNColors.red : MNColors.ink)
                  : MNText.isOffice(context)
                      ? OwnerStyle.line
                      : MNColors.borderStrong,
              width: selected ? MNSize.focusBorderWidth : MNSize.borderWidth),
      semanticLabel: '$title, $caption',
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MNSize.payOption),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            AnimatedContainer(
              duration: MNMotion.of(context, MNMotion.radio),
              curve: MNMotion.spring,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: reference
                    ? null
                    : Border.all(
                        color: selected
                            ? (reference ? MNColors.red : MNColors.ink)
                            : MNText.isOffice(context)
                                ? OwnerStyle.line
                                : MNColors.borderStrong,
                        width: selected ? 7 : 2),
              ),
            ),
            const SizedBox(width: MNSpace.x3),
            if (!MNText.isOffice(context)) ...[
              MNIcon(icon, color: fg),
              const SizedBox(width: MNSpace.x3),
            ],
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: MNText.resolve(context, MNText.title)
                            .copyWith(color: fg)),
                    if (caption.isNotEmpty)
                      Text(caption,
                          style: MNText.resolve(context, MNText.meta).copyWith(
                              color: enabled
                                  ? MNColors.ink2
                                  : MNColors.disabledText)),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Kikapu reference (22 October 2026): no border; selected is a soft red
  /// tint with a red radio; unavailable is grey with a lock.
  Widget _reference(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? MNColors.ink : MNColors.kikapuDisabledText;
    return MNPressable(
      onTap: onTap,
      pressedScale: .99,
      color: !enabled
          ? MNColors.kikapuDisabledSurface
          : (selected ? MNColors.kikapuSelected : MNColors.white),
      borderRadius: BorderRadius.circular(MNRadius.medium),
      semanticLabel: '$title, $caption',
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MNSize.payOption),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 16, 10),
          child: Row(children: [
            AnimatedContainer(
              duration: MNMotion.of(context, MNMotion.radio),
              curve: MNMotion.spring,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? MNColors.red : MNColors.kikapuRadio,
                      width: selected ? 2 : 1.5)),
              child: Center(
                child: AnimatedScale(
                  duration: MNMotion.of(context, MNMotion.radio),
                  curve: MNMotion.easeOut,
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                        color: MNColors.red, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 19),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: enabled
                      ? MNColors.kikapuTile
                      : MNColors.kikapuDisabledTile,
                  borderRadius: BorderRadius.circular(MNRadius.small)),
              child: Center(
                  child: MNIcon(icon, size: 28, strokeWidth: 1.7, color: fg)),
            ),
            const SizedBox(width: 19),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: MNText.resolve(context, MNText.kikapuOption)
                            .copyWith(color: fg)),
                    const SizedBox(height: 4),
                    if (caption.isNotEmpty)
                      Text(caption,
                          style: MNText.resolve(
                                  context, MNText.kikapuOptionCaption)
                              .copyWith(
                                  color: enabled
                                      ? null
                                      : MNColors.kikapuDisabledText)),
                  ],
                ),
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: 8),
              const MNIcon(MNIconData.lock,
                  size: 22,
                  strokeWidth: 1.6,
                  color: MNColors.kikapuDisabledText),
            ],
          ]),
        ),
      ),
    );
  }
}
