import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';
import 'logo.dart';
import 'pressable.dart';

/// Light vendor reference canvas. Everything above the navigation scrolls.
class MNReferencePage extends StatelessWidget {
  final Widget child;
  const MNReferencePage({super.key, required this.child});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: MNColors.pageBackground),
      child: Scaffold(
          backgroundColor: MNColors.pageBackground,
          body: SafeArea(bottom: false, child: child)));
}

class MNVendorHeading extends StatelessWidget {
  final String brand, title;
  final List<Widget> actions;
  const MNVendorHeading(
      {super.key,
      required this.brand,
      required this.title,
      this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox.square(
              dimension: 30, child: MNLogo(height: 30, semanticLabel: brand)),
          const SizedBox(width: 12),
          Expanded(
              child: ExcludeSemantics(
                  child: Text(brand, style: MNText.brandTitle))),
          ...actions,
        ]),
        SizedBox(height: actions.isEmpty ? 18 : 10),
        Semantics(header: true, child: Text(title, style: MNText.pageTitle)),
      ]));
}

class MNReferenceSurface extends StatelessWidget {
  final Widget child;
  const MNReferenceSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(MNRadius.medium),
      child: ColoredBox(color: MNColors.white, child: child));
}

class MNReferenceMenuAction extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool divider;
  final Color? color;
  const MNReferenceMenuAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.divider = false,
      this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
        if (divider)
          const Padding(
              padding: EdgeInsets.only(left: 62),
              child: Divider(
                  height: 1, thickness: 1, color: MNColors.referenceLine)),
        MNPressable(
            onTap: onTap,
            semanticLabel: label,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  MNIcon(icon,
                      size: 26, strokeWidth: 1.3, color: color ?? MNColors.ink),
                  const SizedBox(width: 20),
                  Expanded(
                      child: ExcludeSemantics(
                          child: Text(label,
                              style: MNText.withWeight(
                                      MNText.referenceBody, FontWeight.w500)
                                  .copyWith(color: color)))),
                  const SizedBox(width: 8),
                  const MNIcon(MNIconData.chevron,
                      size: 18, color: MNColors.referenceMuted),
                ]))),
      ]);
}
