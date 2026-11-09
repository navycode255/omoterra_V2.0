import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'product_card.dart';

/// `.row`: 64 px minimum, 16 px sides, a hairline above every row except the
/// first. Pressed rows tint `#F4F4F4` (`.row.tap:active`).
class MNListRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool first;
  final String? semanticLabel;
  final bool compact;

  const MNListRow(
      {super.key,
      this.leading,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      this.onLongPress,
      this.first = false,
      this.semanticLabel,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 52 : MNSize.row),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : MNSpace.x4, vertical: compact ? 7 : 10),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: MNSpace.x3)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, if (subtitle != null) subtitle!],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MNSpace.x3),
            trailing!
          ],
        ]),
      ),
    );
    final border =
        first ? null : const Border(top: BorderSide(color: MNColors.border));
    final interactive = onTap != null || onLongPress != null;
    final body = interactive
        ? MNPressable(
            onTap: onTap,
            onLongPress: onLongPress,
            pressedScale: 1,
            colorDuration: MNMotion.instant,
            color: MNColors.white,
            pressedColor: MNColors.surface,
            border: border,
            semanticLabel: semanticLabel,
            child: content)
        : DecoratedBox(
            decoration: BoxDecoration(color: MNColors.white, border: border),
            child: content);
    return semanticLabel == null || interactive
        ? body
        : Semantics(label: semanticLabel, container: true, child: body);
  }
}

/// A product in a list: thumbnail, name, red price, optional trailing.
class MNProductRow extends StatelessWidget {
  final String name;
  final int price;
  final ImageProvider? image;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool first;

  const MNProductRow(
      {super.key,
      required this.name,
      required this.price,
      this.image,
      this.trailing,
      this.onTap,
      this.first = false});

  @override
  Widget build(BuildContext context) => MNListRow(
        first: first,
        onTap: onTap,
        leading: MNProductImage.thumb(image: image),
        title: Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MNText.resolve(context, MNText.title)),
        subtitle: Text(formatTsh(price),
            style: MNText.resolve(context, MNText.price)),
        trailing: trailing,
      );
}

/// A recorded sale: time, thumbnail, "Kuku × 2", payment method, amount.
/// A voided sale is struck through and muted; the strike draws across in
/// 240 ms when [voided] turns on.
class MNTransactionRow extends ConsumerWidget {
  final String time;
  final String product;
  final int quantity;
  final String paymentMethod;

  /// Picks the phone icon instead of cash. Passed explicitly so the icon
  /// never depends on how [paymentMethod] is worded or translated.
  final bool mobileMoney;
  final int amount;
  final ImageProvider? image;
  final bool voided;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool first;
  final bool compact;

  const MNTransactionRow(
      {super.key,
      required this.time,
      required this.product,
      required this.quantity,
      required this.paymentMethod,
      required this.mobileMoney,
      required this.amount,
      this.image,
      this.voided = false,
      this.onTap,
      this.onLongPress,
      this.first = false,
      this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final title = strings.quantityOf(product, quantity);
    final color = voided ? MNColors.muted : null;
    final showImage = MediaQuery.textScalerOf(context).scale(16) <= 24;
    return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        decoration: BoxDecoration(
            border: Border.all(color: MNColors.cardBorder),
            borderRadius: BorderRadius.circular(9)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: MNListRow(
              first: true,
              compact: compact,
              onTap: onTap,
              onLongPress: onLongPress,
              semanticLabel:
                  '$time, $title, $paymentMethod, ${formatTsh(amount)}',
              leading: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                        color: MNColors.iconSurface,
                        borderRadius: BorderRadius.circular(6)),
                    child: ExcludeSemantics(
                        child: Text(time,
                            style: MNText.resolve(context, MNText.meta)
                                .copyWith(color: MNColors.ink)))),
                if (showImage) const SizedBox(width: 10),
                if (showImage && image == null)
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: MNColors.roseSurface,
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: MNIcon(
                              product.toLowerCase().contains('mzima')
                                  ? MNIconData.roast
                                  : product.toLowerCase().contains('firigisi')
                                      ? MNIconData.wings
                                      : MNIconData.food,
                              color: MNColors.red,
                              size: 25))),
                // No photo, no placeholder square: the row stays compact.
                if (showImage && image != null)
                  MNProductImage.thumb(image: image, dimmed: voided),
              ]),
              title: ExcludeSemantics(
                child: _Strike(
                    on: voided,
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MNText.resolve(context, MNText.title)
                            .copyWith(color: color))),
              ),
              subtitle: ExcludeSemantics(
                  child: Row(children: [
                MNIcon(mobileMoney ? MNIconData.phone : MNIconData.cash,
                    size: 15, color: MNColors.muted),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(paymentMethod,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MNText.resolve(context, MNText.meta)
                            .copyWith(fontSize: 11)))
              ])),
              trailing: ExcludeSemantics(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _Strike(
                      on: voided,
                      child: Text(groupDigits(amount),
                          style: MNText.resolve(context, MNText.amount)
                              .copyWith(color: color))),
                  const SizedBox(width: 4),
                  const MNIcon(MNIconData.chevron,
                      size: 16, color: MNColors.muted)
                ]),
              ),
            )));
  }
}

/// `.m-strike`: a 1.5 px muted line drawn left to right at 56% height.
class _Strike extends StatelessWidget {
  final bool on;
  final Widget child;
  const _Strike({required this.on, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: on ? 1 : 0),
        duration: MNMotion.of(context, MNMotion.rise),
        curve: MNMotion.easeOut,
        child: child,
        builder: (context, t, child) => CustomPaint(
            foregroundPainter: t == 0 ? null : _StrikePainter(t), child: child),
      );
}

class _StrikePainter extends CustomPainter {
  final double t;
  _StrikePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * .56;
    canvas.drawLine(
        Offset(0, y),
        Offset(size.width * t, y),
        Paint()
          ..color = MNColors.muted
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.t != t;
}

/// A product held by the vendor: thumbnail, name, price, and on the right
/// a labelled count ("Imesalia 12"). Pass [trailing] instead for an editable
/// count (Funga Siku, damage).
class MNStockRow extends ConsumerWidget {
  final bool referenceStyle;
  final String? unit;
  final VoidCallback? onTap;
  final String name;
  final int? price;
  final ImageProvider? image;
  final String? quantity;
  final Widget? trailing;
  final bool first;

  const MNStockRow(
      {super.key,
      required this.name,
      this.referenceStyle = false,
      this.unit,
      this.onTap,
      this.price,
      this.image,
      this.quantity,
      this.trailing,
      this.first = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    if (referenceStyle) {
      final count = int.tryParse(quantity ?? '');
      return Column(children: [
        if (!first)
          const Padding(
              padding: EdgeInsets.only(left: 78),
              child: Divider(
                  height: 1, thickness: 1, color: MNColors.referenceLine)),
        MNPressable(
            onTap: onTap,
            semanticLabel:
                '$name, ${quantity == null ? strings.unknownQuantity : strings.remaining(quantity!)}',
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  MNProductImage.thumb(image: image, size: 44),
                  const SizedBox(width: 20),
                  Expanded(
                      child: ExcludeSemantics(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        Text(name,
                            style:
                                MNText.resolve(context, MNText.referenceBody)),
                        if (unit?.isNotEmpty ?? false)
                          Text(unit!,
                              style: MNText.resolve(
                                  context, MNText.referenceCaption)),
                      ]))),
                  const SizedBox(width: 10),
                  ExcludeSemantics(
                      child: SizedBox(
                          width: 46,
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(quantity ?? '—',
                                  style: MNText.resolve(
                                          context, MNText.referenceQuantity)
                                      .copyWith(
                                          color: count != null && count < 10
                                              ? MNColors.referenceAlert
                                              : MNColors.ink))))),
                  const SizedBox(width: 12),
                  const MNIcon(MNIconData.chevron,
                      size: 18, color: MNColors.referenceMuted),
                ]))),
      ]);
    }
    return MNListRow(
      first: first,
      leading: MNProductImage.thumb(image: image, size: MNSize.thumbLarge),
      title: Text(name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MNText.resolve(context, MNText.title)),
      subtitle: price == null
          ? null
          : Text(formatTsh(price!),
              style: MNText.resolve(context, MNText.price)),
      trailing: trailing ??
          (quantity == null
              ? null
              : Semantics(
                  label: strings.remaining(quantity!),
                  child: ExcludeSemantics(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(strings.remainingLabel,
                              style: MNText.resolve(context, MNText.meta)),
                          Text(quantity!,
                              style: MNText.resolve(context, MNText.quantity)),
                        ]),
                  ),
                )),
    );
  }
}

/// `.mrow`: 56 px menu row with an icon, a label and a chevron.
class MNMenuRow extends StatelessWidget {
  final MNIconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool first;

  const MNMenuRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.color,
      this.first = false});

  @override
  Widget build(BuildContext context) => MNPressable(
        onTap: onTap,
        pressedScale: 1,
        colorDuration: MNMotion.instant,
        color: MNColors.white,
        pressedColor: MNColors.surface,
        border: first
            ? null
            : const Border(top: BorderSide(color: MNColors.border)),
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MNSize.menuRow),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                MNSpace.x4, MNSpace.x2, MNSpace.x2, MNSpace.x2),
            child: Row(children: [
              MNIcon(icon, color: color ?? MNColors.ink),
              const SizedBox(width: 14),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(label,
                      style: MNText.resolve(context, MNText.menu)
                          .copyWith(color: color)),
                ),
              ),
              const MNIcon(MNIconData.chevron, color: MNColors.muted),
            ]),
          ),
        ),
      );
}

/// `.kv`: a label on the left, its value in bold on the right.
class MNInfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final bool first;
  const MNInfoRow(
      {super.key,
      required this.label,
      required this.value,
      this.first = false});

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: MNSize.menuRow),
          padding:
              const EdgeInsets.symmetric(horizontal: MNSpace.x4, vertical: 14),
          decoration: BoxDecoration(
              border: first
                  ? null
                  : const Border(top: BorderSide(color: MNColors.border))),
          child: Row(children: [
            Text(label,
                style: MNText.resolve(context, MNText.body)
                    .copyWith(color: MNColors.ink2)),
            const SizedBox(width: MNSpace.x4),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: DefaultTextStyle.merge(
                    textAlign: TextAlign.right,
                    style: MNText.resolve(context, MNText.title),
                    child: value),
              ),
            ),
          ]),
        ),
      );
}
