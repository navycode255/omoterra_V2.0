import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';

/// The reference workflow header keeps navigation above the page title.
class MNWorkflowHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  const MNWorkflowHeader(
      {super.key, required this.title, this.actions = const [], this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnnotatedRegion<
          SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: MNColors.white),
      child: ColoredBox(
          color: MNColors.white,
          child: SafeArea(
              bottom: false,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        height: 56,
                        child: Row(children: [
                          MNIconButton(MNIconData.back,
                              label: ref.watch(stringsProvider).back,
                              onPressed: onBack ??
                                  () {
                                    final router = GoRouter.of(context);
                                    if (router.canPop()) {
                                      router.pop();
                                    } else {
                                      router.go(MNRoutes.home);
                                    }
                                  }),
                          const Spacer(),
                          ...actions,
                        ])),
                    SizedBox(
                        height: 48,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Semantics(
                                    header: true,
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(title,
                                            style: MNText.pageTitle
                                                .copyWith(fontSize: 28))))))),
                  ]))));
}
