import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'pressable.dart';

/// `.chips`: a horizontally scrolling row of 40 px filter chips; the
/// selected chip is black. No counts on chips.
class MNChipBar extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const MNChipBar(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: MNSpace.x4, vertical: MNSpace.x1),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: MNSpace.x2),
            MNPressable(
              onTap: () => onSelect(i),
              pressedScale: MNMotion.pressChip,
              color: i == selected ? MNColors.black : MNColors.surface,
              borderRadius: BorderRadius.circular(MNRadius.small),
              semanticLabel: labels[i],
              selected: i == selected,
              child: Container(
                constraints: const BoxConstraints(minHeight: MNSize.minTouch),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
                child: ExcludeSemantics(
                  child: Text(labels[i],
                      style: MNText.chip.copyWith(
                          color:
                              i == selected ? MNColors.white : MNColors.ink)),
                ),
              ),
            ),
          ],
        ]),
      );
}
