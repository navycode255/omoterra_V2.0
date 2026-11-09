import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'logo.dart';

/// `.bar`: the black 56 px header. Top-level tabs pass [root] and never show
/// a back button; pushed screens show one only when there is somewhere to go
/// back to. The status bar area is painted black with light icons.
class MNAppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool root;
  final bool light;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;

  const MNAppHeader(
      {super.key,
      required this.title,
      this.root = false,
      this.light = false,
      this.leading,
      this.actions = const [],
      this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(MNSize.appBar);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final router = GoRouter.maybeOf(context);
    final canGoBack = !root &&
        (onBack != null ||
            (router?.canPop() ?? Navigator.of(context).canPop()));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(statusBarColor: light ? MNColors.white : MNColors.black),
      child: ColoredBox(
        color: light ? MNColors.white : MNColors.black,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: MNSize.appBar,
            child: Padding(
              padding: EdgeInsets.only(
                  left: canGoBack || leading != null ? MNSpace.x1 : MNSpace.x4,
                  right: MNSpace.x1),
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (canGoBack)
                    MNIconButton(MNIconData.back,
                        label: strings.back,
                        color: light ? MNColors.ink : MNColors.white,
                        onPressed: onBack ??
                            () => router != null
                                ? router.pop()
                                : Navigator.of(context).maybePop()),
                  if (root && leading == null) ...[
                    MNLogo(height: 32, semanticLabel: strings.brand),
                    const SizedBox(width: MNSpace.x3),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: canGoBack || leading != null ? MNSpace.x1 : 0),
                      child: Semantics(
                        header: true,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MNText.barTitle.copyWith(
                                fontSize: 22,
                                color: light ? MNColors.ink : MNColors.white)),
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
