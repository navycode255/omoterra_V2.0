import '../../core/theme/theme.dart' show mrNyamaOfficeTheme;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../shared/widgets/states.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/tokens.dart';
export '../../core/theme/tokens.dart' show OwnerStyle;
import '../../core/routing/routes.dart';
import '../../shared/widgets/pressable.dart';

/// Scalable silhouettes traced from the approved reference, with the original
/// supplied brand artwork retained as a bitmap.
class OwnerGlyph extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const OwnerGlyph(this.name, {super.key, this.size = 24, this.color});
  @override
  Widget build(BuildContext context) => name == 'brand'
      ? Image.asset('assets/owner/brand.png',
          width: OwnerStyle.px(context, size),
          height: OwnerStyle.px(context, size),
          fit: BoxFit.contain,
          excludeFromSemantics: true)
      : SvgPicture.asset('assets/owner/icons/$name.svg',
          width: OwnerStyle.px(context, size),
          height: OwnerStyle.px(context, size),
          fit: BoxFit.contain,
          colorFilter:
              color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
          excludeFromSemantics: true);
}

class OwnerIconButton extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final double size;
  const OwnerIconButton(this.icon,
      {super.key, required this.label, required this.onTap, this.size = 22});
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      button: true,
      child: Tooltip(
          message: label,
          child: MNPressable(
              onTap: onTap,
              pressedScale: 1,
              child: SizedBox(
                  width: OwnerStyle.px(context, 48).clamp(48, 80),
                  height: OwnerStyle.px(context, 48).clamp(48, 80),
                  child: Center(child: OwnerGlyph(icon, size: size))))));
}

class OwnerCard extends StatelessWidget {
  final Widget child;
  final double radius;
  const OwnerCard({super.key, required this.child, this.radius = 14});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(OwnerStyle.px(context, radius)),
      child: ColoredBox(color: OwnerStyle.white, child: child));
}

/// One scroll viewport for the large heading and all page content.
class OwnerPage extends StatelessWidget {
  final String title;
  final Strings strings;
  final Widget child;
  final Widget? subtitle, trailingSubtitle;

  /// [header] replaces the large title and subtitle; [trailing] sits at the
  /// right of the top bar.
  final Widget? header, trailing;
  final String? collapsedTitle;
  final Widget? bottom;
  final VoidCallback? onAdd, onBack;
  final String? addLabel;
  final bool vendorSpacing;
  final double? contentGap, headingSize, headingTopGap;
  final String? addIcon;
  final bool showBack;
  final double backSize;
  final Future<void> Function()? onRefresh;
  const OwnerPage(
      {super.key,
      required this.title,
      required this.strings,
      required this.child,
      this.subtitle,
      this.trailingSubtitle,
      this.header,
      this.bottom,
      this.trailing,
      this.collapsedTitle,
      this.onAdd,
      this.onBack,
      this.addLabel,
      this.vendorSpacing = false,
      this.contentGap,
      this.headingSize,
      this.headingTopGap,
      this.addIcon,
      this.showBack = true,
      this.backSize = 18,
      this.onRefresh});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    final color =
        vendorSpacing ? OwnerStyle.vendorsBackground : OwnerStyle.background;
    var titleCollapsed = false;
    return StatefulBuilder(builder: (context, setPageState) {
      return Theme(
          data: mrNyamaOfficeTheme(Theme.of(context)),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: color,
                systemNavigationBarColor: color,
                systemNavigationBarIconBrightness: Brightness.dark),
            child: Scaffold(
                backgroundColor: color,
                body: SafeArea(
                    child: Center(
                        child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(children: [
                    Padding(
                        padding: EdgeInsets.only(right: u(4.5)),
                        child: Row(children: [
                          if (showBack)
                            OwnerIconButton('back',
                                size: backSize,
                                label: strings.back,
                                onTap: onBack ??
                                    () {
                                      final router = GoRouter.of(context);
                                      if (router.canPop()) {
                                        router.pop();
                                      } else {
                                        router.go(MNRoutes.office);
                                      }
                                    })
                          else
                            SizedBox(height: u(48)),
                          if (titleCollapsed && collapsedTitle != null)
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.only(left: u(12)),
                                    child: Text(collapsedTitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: OwnerStyle.text(context, 17,
                                            weight: 600))))
                          else
                            const Spacer(),
                          if (onAdd != null)
                            OwnerIconButton(
                                addIcon ??
                                    (vendorSpacing ? 'plus' : 'product-plus'),
                                size: 22,
                                label: addLabel ?? strings.register,
                                onTap: onAdd!),
                          if (trailing != null) trailing!,
                        ])),
                    Expanded(
                        child: _OwnerScroll(
                            onRefresh: onRefresh,
                            onScroll: collapsedTitle == null
                                ? null
                                : (offset) {
                                    final collapsed = offset >= u(120);
                                    if (collapsed != titleCollapsed) {
                                      titleCollapsed = collapsed;
                                      setPageState(() {});
                                    }
                                  },
                            child: Transform.translate(
                                offset: Offset(0, -u(6)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                          height: u(headingTopGap ??
                                              (vendorSpacing ? 7 : 0))),
                                      if (header != null)
                                        header!
                                      else
                                        Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: u(19)),
                                            child: Semantics(
                                                header: true,
                                                child: Text(title,
                                                    style: OwnerStyle.text(
                                                        context,
                                                        headingSize ??
                                                            (vendorSpacing
                                                                ? 32
                                                                : 31),
                                                        weight: 700,
                                                        height: 1.23,
                                                        spacing: vendorSpacing
                                                            ? -.5
                                                            : -.9)))),
                                      if (header == null &&
                                          (subtitle != null ||
                                              trailingSubtitle != null))
                                        Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                u(19),
                                                u(vendorSpacing ? 6 : 5),
                                                u(30),
                                                0),
                                            child: Row(children: [
                                              if (subtitle != null)
                                                Expanded(child: subtitle!),
                                              if (trailingSubtitle != null)
                                                trailingSubtitle!
                                            ])),
                                      SizedBox(
                                          height: u(contentGap ??
                                              (vendorSpacing ? 16.8 : 8))),
                                      child,
                                      SizedBox(height: u(20)),
                                    ])))),
                    if (bottom != null) bottom!,
                  ]),
                )))),
          ));
    });
  }
}

class OwnerMenuRow extends StatelessWidget {
  final String label;
  final String? icon, value, subtitle;
  final Widget? leading;
  final Color? valueColor, labelColor;
  final double valueSize, valueWeight, valueMaxWidth;
  final bool showChevron;
  final VoidCallback? onTap;
  final double height;
  const OwnerMenuRow(
      {super.key,
      required this.label,
      this.icon,
      this.leading,
      this.value,
      this.subtitle,
      this.valueColor,
      this.labelColor,
      this.valueMaxWidth = 150,
      this.valueSize = 17,
      this.valueWeight = 500,
      this.showChevron = true,
      this.onTap,
      this.height = 60});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    return MNPressable(
        onTap: onTap,
        pressedScale: 1,
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: u(height)),
            child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: u(16), vertical: u(12)),
                child: Row(children: [
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: u(22))
                  ] else if (icon != null) ...[
                    OwnerGlyph(icon!, size: 25),
                    SizedBox(width: u(22))
                  ],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: OwnerStyle.text(context, 17,
                                weight: subtitle == null ? 500 : 400,
                                color: labelColor ?? OwnerStyle.ink,
                                spacing: -.55)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: OwnerStyle.text(context, 12.5,
                                  color: OwnerStyle.muted)),
                      ])),
                  if (value != null) ...[
                    SizedBox(width: u(8)),
                    ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: u(valueMaxWidth)),
                        child: Text(value!,
                            textAlign: TextAlign.end,
                            style: OwnerStyle.text(context, valueSize,
                                weight: valueWeight,
                                color: valueColor ?? OwnerStyle.ink)))
                  ],
                  if (showChevron) ...[
                    SizedBox(width: u(12)),
                    OwnerGlyph(subtitle == null ? 'chevron' : 'vendor-chevron',
                        size: subtitle == null ? 12 : 17)
                  ],
                ]))));
  }
}

/// The approved pages have one outer scroll; bound skeleton rows while
/// asynchronous data loads so they do not create an unbounded viewport.
class OwnerAsyncView<T> extends MNAsyncView<T> {
  const OwnerAsyncView(
      {super.key,
      required super.value,
      required super.data,
      super.onRetry,
      super.isEmpty,
      super.empty,
      super.loadingRows});
  @override
  Widget build(BuildContext context) {
    if (value is AsyncData<T> || value is AsyncError<T>) {
      return super.build(context);
    }
    return SizedBox(
        height: 64 * loadingRows.toDouble(), child: super.build(context));
  }
}

class _OwnerScroll extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final ValueChanged<double>? onScroll;
  const _OwnerScroll({required this.child, this.onRefresh, this.onScroll});
  @override
  Widget build(BuildContext context) => MNRefreshArea(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              onScroll?.call(notification.metrics.pixels);
            }
            return false;
          },
          child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              child: child)));
}
