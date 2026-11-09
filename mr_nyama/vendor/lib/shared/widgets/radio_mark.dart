import 'package:flutter/widgets.dart';
import '../../core/theme/theme.dart';

/// A reference radio mark; its containing row provides the full tap target.
class MNRadioMark extends StatelessWidget {
  final bool selected;
  const MNRadioMark({super.key, required this.selected});
  @override
  Widget build(BuildContext context) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? MNColors.red : MNColors.borderStrong,
              width: 1.5)),
      child: selected
          ? Center(
              child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                      color: MNColors.red, shape: BoxShape.circle)))
          : null);
}
