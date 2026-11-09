import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'buttons.dart';
import 'icon.dart';
import 'note.dart';
import 'pressable.dart';
import 'sheet.dart';

/// Shared geometry, with the approved typeface retained in each mode.
TextStyle accountText(BuildContext context, double size,
        {double weight = 400, Color color = MNColors.ink}) =>
    MNText.isOffice(context)
        ? OwnerStyle.text(context, size, weight: weight, color: color)
        : MNText.withWeight(
            MNText.body.copyWith(fontSize: size, height: 1.25, color: color),
            FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)]);

class MNAccountGroup extends StatelessWidget {
  final List<Widget> children;
  const MNAccountGroup({super.key, required this.children});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
          color: MNColors.white,
          child: Column(children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: MNColors.referenceLine)),
              child,
            ]
          ])));
}

class MNAccountIdentity extends StatelessWidget {
  final String name, subtitle;
  final String? detail, imageUrl;
  const MNAccountIdentity(
      {super.key,
      required this.name,
      required this.subtitle,
      this.detail,
      this.imageUrl});
  @override
  Widget build(BuildContext context) => MNAccountGroup(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              MNPersonPhoto(
                  imageUrl: imageUrl,
                  size: 60,
                  color: MNColors.referenceAvatar,
                  initials: Text(MNAvatar.initials(name),
                      style: accountText(context, 21,
                          weight: 600, color: MNColors.referenceMuted))),
              const SizedBox(width: 20),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name, style: accountText(context, 18, weight: 600)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: accountText(context, 14,
                            color: MNColors.referenceMuted)),
                    if (detail != null) ...[
                      const SizedBox(height: 3),
                      Text(detail!,
                          style: accountText(context, 13,
                              color: MNColors.referenceMuted)),
                    ],
                  ])),
            ])),
      ]);
}

class MNAccountSectionTitle extends StatelessWidget {
  final String title;
  const MNAccountSectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(3, 22, 3, 12),
      child: Semantics(
          header: true,
          child: Text(title,
              style:
                  accountText(context, 14, color: MNColors.referenceMuted))));
}

class MNAccountRow extends StatelessWidget {
  final String title;
  final String? subtitle, value;
  final MNIconData icon;
  final Widget? trailing;
  final VoidCallback onTap;
  const MNAccountRow(
      {super.key,
      required this.title,
      required this.icon,
      required this.onTap,
      this.subtitle,
      this.value,
      this.trailing});
  @override
  Widget build(BuildContext context) => MNPressable(
      onTap: onTap,
      pressedScale: 1,
      color: MNColors.white,
      pressedColor: MNColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              MNIcon(icon, size: 27),
              const SizedBox(width: 22),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title, style: accountText(context, 16)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(subtitle!,
                          style: accountText(context, 13,
                              color: MNColors.referenceMuted)),
                    ],
                  ])),
              if (value != null) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .3),
                    child: Text(value!,
                        textAlign: TextAlign.right,
                        style: accountText(context, 15,
                            color: MNColors.referenceMuted))),
              ],
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              const SizedBox(width: 8),
              const MNIcon(MNIconData.chevron,
                  size: 17, color: MNColors.referenceMuted),
            ])),
      ));
}

/// Both modes use the same sheet; the actual session operation runs only
/// after confirmation. Cancel, back and dismissal never call it.
class MNAccountSignOut extends ConsumerStatefulWidget {
  final Future<void> Function() onSignOut;
  final String? Function()? warning;
  const MNAccountSignOut({super.key, required this.onSignOut, this.warning});
  @override
  ConsumerState<MNAccountSignOut> createState() => _MNAccountSignOutState();
}

class _MNAccountSignOutState extends ConsumerState<MNAccountSignOut> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNAccountGroup(children: [
      MNPressable(
          onTap: _open
              ? null
              : () async {
                  setState(() => _open = true);
                  try {
                    await showMNSheet<void>(context,
                        builder: (_) => MNAccountSignOutSheet(
                            onSignOut: widget.onSignOut,
                            warning: widget.warning?.call()));
                  } finally {
                    if (mounted) setState(() => _open = false);
                  }
                },
          pressedScale: 1,
          color: MNColors.white,
          pressedColor: MNColors.surface,
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.logout,
                          textAlign: TextAlign.center,
                          style: accountText(context, 17,
                              color: MNColors.red)))))),
    ]);
  }
}

class MNAccountSignOutSheet extends ConsumerStatefulWidget {
  final Future<void> Function() onSignOut;
  final String? warning;
  const MNAccountSignOutSheet(
      {super.key, required this.onSignOut, this.warning});
  @override
  ConsumerState<MNAccountSignOutSheet> createState() =>
      _MNAccountSignOutSheetState();
}

class _MNAccountSignOutSheetState extends ConsumerState<MNAccountSignOutSheet> {
  bool _busy = false;
  String? _error;
  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = ref.read(stringsProvider).accountSignOutFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return PopScope(
        canPop: !_busy,
        child: MNSheet(children: [
          const SizedBox(height: 12),
          Semantics(
              header: true,
              child: Text(s.logoutConfirm,
                  textAlign: TextAlign.center,
                  style: accountText(context, 20, weight: 700))),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(s.accountSignOutBody,
                  textAlign: TextAlign.center,
                  style: accountText(context, 15,
                      color: MNColors.referenceMuted))),
          if (widget.warning != null)
            Text(widget.warning!,
                textAlign: TextAlign.center,
                style: accountText(context, 14, color: MNColors.warning)),
          if (_error != null) MNNote(_error!, error: true),
          MNPressable(
              onTap: _busy ? null : () => Navigator.of(context).pop(),
              pressedScale: 1,
              color: MNColors.disabled,
              pressedColor: MNColors.surfacePressed,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(s.cancel,
                              textAlign: TextAlign.center,
                              style: accountText(context, 17,
                                  weight: 600,
                                  color: MNColors.referenceMuted)))))),
          if (_busy)
            const Center(child: MNSpinner(color: MNColors.red))
          else
            MNTextButton(s.logout, color: MNColors.red, onPressed: _signOut),
        ]));
  }
}
