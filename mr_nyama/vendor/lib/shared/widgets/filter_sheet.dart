import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'icon.dart';
import 'pressable.dart';
import 'radio_mark.dart';

/// Filter sheet from the approved reference (28 October 2026): close button,
/// heading and a red "Weka upya" across the top, grouped choices that scroll,
/// and the apply button pinned at the bottom. Closing returns null.
class MNFilterSheet extends ConsumerWidget {
  final String title;
  final VoidCallback onReset;
  final String applyLabel;
  final VoidCallback onApply;
  final List<Widget> children;
  const MNFilterSheet(
      {super.key,
      required this.title,
      required this.onReset,
      required this.applyLabel,
      required this.onApply,
      required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return MNSheetFrame(
        title: title,
        closeLabel: s.close,
        action: MNPressable(
            onTap: onReset,
            pressedScale: MNMotion.pressChip,
            semanticLabel: s.resetFilters,
            child: ConstrainedBox(
                constraints: const BoxConstraints(
                    minHeight: MNSize.minTouch, minWidth: MNSize.minTouch),
                child: Center(
                    widthFactor: 1,
                    child: ExcludeSemantics(
                        child: Text(s.resetFilters,
                            style:
                                MNText.withWeight(MNText.body, FontWeight.w700)
                                    .copyWith(color: MNColors.red)))))),
        button: MNButton(applyLabel, onPressed: onApply),
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: MNSpace.x5),
            child,
          ]
        ]);
  }
}

/// The frame shared by the filter and date-wheel sheets: handle, a header
/// row with the close button (and an optional [action]), scrolling
/// [children] and a pinned [button]. [divider] rules off the header.
class MNSheetFrame extends StatelessWidget {
  final String title, closeLabel;
  final Widget? action;
  final bool divider;
  final Widget button;
  final List<Widget> children;
  const MNSheetFrame(
      {super.key,
      required this.title,
      required this.closeLabel,
      required this.button,
      required this.children,
      this.action,
      this.divider = false});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4 + bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: MNColors.borderStrong,
                    borderRadius: BorderRadius.circular(MNRadius.handle)),
              ),
            ),
            const SizedBox(height: MNSpace.x2),
            Row(children: [
              Transform.translate(
                  offset: const Offset(-MNSpace.x3, 0),
                  child: MNIconButton(MNIconData.x,
                      label: closeLabel,
                      color: MNColors.ink,
                      onPressed: () => Navigator.pop(context))),
              Expanded(
                  flex: 3,
                  child: Transform.translate(
                      offset: const Offset(-MNSpace.x2, 0),
                      child: Semantics(
                          header: true,
                          child: Text(title,
                              style: MNText.resolve(
                                  context, MNText.sheetTitle))))),
              // Large text shrinks the action rather than break the title.
              if (action != null)
                Flexible(
                    flex: 2,
                    child: Align(
                        alignment: Alignment.centerRight,
                        child:
                            FittedBox(fit: BoxFit.scaleDown, child: action!))),
            ]),
            if (divider)
              const Divider(height: MNSpace.x3, color: MNColors.border)
            else
              const SizedBox(height: MNSpace.x2),
            Flexible(
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children))),
            const SizedBox(height: MNSpace.x5),
            button,
          ]),
    );
  }
}

/// A bold label over a bordered group of rows with hairlines between them.
class MNFilterGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const MNFilterGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
            header: true,
            child: Text(title, style: MNText.resolve(context, MNText.title))),
        const SizedBox(height: MNSpace.x2),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              border: Border.all(color: MNColors.border),
              borderRadius: BorderRadius.circular(MNRadius.medium)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MNRadius.medium),
            child: Column(children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(height: 1, color: MNColors.border),
                child,
              ]
            ]),
          ),
        ),
      ]);
}

enum MNFilterMark { radio, check, calendar }

/// One choice in a [MNFilterGroup]: a radio (one of the group), a check
/// (any of the group) or a calendar (opens the date wheel). [detail] shows
/// the chosen value at the right, such as a custom date.
class MNFilterOption extends StatelessWidget {
  final String label;
  final MNFilterMark mark;
  final bool selected;
  final String? detail;
  final VoidCallback onTap;
  const MNFilterOption(
      {super.key,
      required this.label,
      required this.mark,
      required this.selected,
      required this.onTap,
      this.detail});

  @override
  Widget build(BuildContext context) {
    final body = MNText.resolve(context, MNText.body);
    return Semantics(
      container: true,
      checked: mark == MNFilterMark.calendar ? null : selected,
      selected: mark == MNFilterMark.calendar ? selected : null,
      inMutuallyExclusiveGroup: mark == MNFilterMark.radio,
      label: detail == null ? label : '$label, $detail',
      child: MNPressable(
        onTap: onTap,
        button: mark == MNFilterMark.calendar,
        pressedScale: 1,
        color: MNColors.white,
        pressedColor: MNColors.surface,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MNSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: MNSpace.x3 + 2, vertical: MNSpace.x2),
              child: Row(children: [
                switch (mark) {
                  MNFilterMark.radio => MNRadioMark(selected: selected),
                  MNFilterMark.check => MNCheckMark(selected: selected),
                  MNFilterMark.calendar => MNIcon(MNIconData.calendar,
                      size: MNSize.iconMedium,
                      color: selected ? MNColors.red : MNColors.ink2),
                },
                const SizedBox(width: MNSpace.x4),
                Expanded(child: Text(label, style: body)),
                if (detail != null) ...[
                  const SizedBox(width: MNSpace.x2),
                  Text(detail!,
                      style: MNText.withWeight(body, FontWeight.w700)
                          .copyWith(color: MNColors.red)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The square check of the filter reference: outlined, or brand red with a
/// white tick.
class MNCheckMark extends StatelessWidget {
  final bool selected;

  /// The fill when selected: brand red, or ink on the sign-in form.
  final Color color;
  const MNCheckMark(
      {super.key, required this.selected, this.color = MNColors.red});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
      duration: MNMotion.of(context, MNMotion.radio),
      curve: MNMotion.standard,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
          color: selected ? color : MNColors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: selected ? color : MNColors.borderStrong, width: 1.5)),
      child: selected
          ? const MNIcon(MNIconData.check, size: 16, color: MNColors.white)
          : null);
}

/// A muted label and the switch, the whole row toggling it.
class MNFilterSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const MNFilterSwitch(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        toggled: value,
        label: label,
        child: MNPressable(
          onTap: () => onChanged(!value),
          button: false,
          pressedScale: 1,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MNSize.minTouch),
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style: MNText.resolve(context, MNText.body)
                            .copyWith(color: MNColors.muted))),
                Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: MNColors.white,
                    activeTrackColor: MNColors.red,
                    inactiveThumbColor: MNColors.white,
                    inactiveTrackColor: MNColors.disabled,
                    trackOutlineColor:
                        const WidgetStatePropertyAll(Colors.transparent)),
              ]),
            ),
          ),
        ),
      );
}
