import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';

/// Routine guidance stays available without competing with operational data.
class OwnerHelp extends ConsumerWidget {
  final String message;
  final String? title;
  final bool compact;
  const OwnerHelp(
      {super.key, required this.message, this.title, this.compact = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    void open() => showMNSheet<void>(context,
        builder: (_) => MNSheet(title: title ?? s.help, children: [
              Text(message, style: OwnerStyle.text(context, 16, height: 1.45))
            ]));
    if (compact) {
      return IconButton(
          tooltip: title ?? s.help,
          onPressed: open,
          icon: const MNIcon(MNIconData.help, color: OwnerStyle.muted));
    }
    return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: OwnerStyle.muted,
                padding: const EdgeInsets.symmetric(horizontal: 4)),
            onPressed: open,
            icon: const MNIcon(MNIconData.help,
                size: 20, color: OwnerStyle.muted),
            label: Text(title ?? s.help,
                style: OwnerStyle.text(context, 14, color: OwnerStyle.muted))));
  }
}

/// Secondary calculations and record metadata are revealed deliberately.
class OwnerDetails extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Widget? leading;
  const OwnerDetails(
      {super.key,
      required this.title,
      required this.children,
      this.initiallyExpanded = false,
      this.leading});
  @override
  Widget build(BuildContext context) => Material(
      color: OwnerStyle.white,
      borderRadius: BorderRadius.circular(OwnerStyle.px(context, 14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        expansionAnimationStyle: AnimationStyle(
            duration: MNMotion.of(context, MNMotion.sheet),
            reverseDuration: MNMotion.of(context, MNMotion.exit),
            curve: MNMotion.easeOut),
        maintainState: true,
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: OwnerStyle.muted,
        collapsedIconColor: OwnerStyle.muted,
        leading: leading,
        title: Text(title, style: OwnerStyle.text(context, 16, weight: 500)),
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)
        ],
      ));
}

/// A consistent, quiet surface for a related group of office form fields.
class OwnerFormSection extends StatelessWidget {
  final List<Widget> children;
  const OwnerFormSection({super.key, required this.children});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Material(
          color: OwnerStyle.white,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children))));
}
