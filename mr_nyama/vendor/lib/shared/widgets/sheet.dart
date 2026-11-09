import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Opens a `.sheet` over a 50% scrim: slides up in 220 ms, down in 180 ms.
Future<T?> showMNSheet<T>(BuildContext context,
        {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: MNColors.scrim,
      backgroundColor: MNColors.white,
      sheetAnimationStyle: mnSheetAnimation(context),
      builder: builder,
    );

/// Sheet content: drag handle, optional heading, then [children] 16 px
/// apart. Stays above the keyboard and the gesture area.
class MNSheet extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final TextStyle? titleStyle;
  const MNSheet(
      {super.key, this.title, this.titleStyle, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4 + bottom),
      child: SingleChildScrollView(
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
            if (title != null) ...[
              const SizedBox(height: MNSpace.x4 + MNSpace.x1),
              Semantics(
                  header: true,
                  child: Text(title!,
                      style: titleStyle ??
                          MNText.resolve(context, MNText.heading))),
            ],
            for (final child in children) ...[
              const SizedBox(height: MNSpace.x4),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
