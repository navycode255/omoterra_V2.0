import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'image_spinner.dart';
import 'pressable.dart';
import 'quantity.dart';

/// A product photo on the dark image background, or the background alone
/// (`.ph`) when there is no photo. Out-of-stock photos are greyed (`.pc.out`).
/// Server photos show the ember ring ([MNImageSpinner]) while they load.
class MNProductImage extends StatelessWidget {
  final ImageProvider? image;
  final bool dimmed;
  final double? size;
  final double radius;

  const MNProductImage(
      {super.key, this.image, this.dimmed = false, this.size, this.radius = 0});

  /// `.th` / `.th56`: square thumbnail for rows.
  const MNProductImage.thumb(
      {super.key, this.image, this.dimmed = false, this.size = MNSize.thumb})
      : radius = MNRadius.small;

  @override
  Widget build(BuildContext context) {
    Widget picture =
        image == null ? const SizedBox.expand() : MNLoadingImage(image: image!);
    if (dimmed) {
      picture = Opacity(
          opacity: .45,
          child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0, //
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: picture));
    }
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: MNColors.imageBackground, child: picture),
    );
    return size == null ? box : SizedBox.square(dimension: size, child: box);
  }
}

/// `.pc`: grid card with photo, name, price and what is left. Tapping the
/// card opens the quantity sheet ([onTap]); the round + adds one ([onAdd]).
/// Once [quantity] is above zero the + becomes the black stepper pill.
class MNProductCard extends ConsumerWidget {
  final String name;

  /// From the authoritative product configuration; never a constant. Null
  /// when none is configured: the card says so and cannot be added.
  final int? price;
  final ImageProvider? image;
  final String? remaining;
  final int quantity;
  final bool selected;
  final bool outOfStock;

  /// Light catalogue presentation; existing tap/quantity behavior is identical.
  final bool referenceStyle;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onDecrease;
  final VoidCallback? onLongPress;
  final VoidCallback? onQuantityTap;

  const MNProductCard(
      {super.key,
      required this.name,
      required this.price,
      this.image,
      this.remaining,
      this.quantity = 0,
      this.selected = false,
      this.outOfStock = false,
      this.referenceStyle = false,
      this.onTap,
      this.onAdd,
      this.onDecrease,
      this.onLongPress,
      this.onQuantityTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final priced = price != null;
    final priceText = priced ? formatTsh(price!) : strings.noPrice;
    final borderColor = selected
        ? MNColors.red
        : referenceStyle
            ? MNColors.white
            : MNColors.border;
    final radius = referenceStyle ? MNRadius.catalogueCard : MNRadius.medium;
    return MNPressable(
      onTap: outOfStock || !priced ? null : onTap,
      onLongPress: outOfStock || !priced ? null : onLongPress,
      pressedScale: MNMotion.pressCard,
      scaleDuration: MNMotion.cardPress,
      color: MNColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: selected ? 2 : 1),
      semanticLabel: '$name, $priceText'
          '${outOfStock ? ', ${strings.outOfStock}' : remaining == null ? '' : ', ${strings.remaining(remaining!)}'}'
          '${quantity > 0 ? ', ${strings.quantityOf(name, quantity)}' : ''}',
      selected: selected,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: MNSize.productImageAspect,
              child: Stack(fit: StackFit.expand, children: [
                Padding(
                    padding: referenceStyle
                        ? const EdgeInsets.all(6)
                        : EdgeInsets.zero,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            referenceStyle ? MNRadius.medium : 0),
                        child:
                            MNProductImage(image: image, dimmed: outOfStock))),
                if (priced && !outOfStock && quantity > 0)
                  Positioned(
                      left: MNSpace.x2,
                      right: MNSpace.x2,
                      bottom: MNSpace.x2,
                      child: _Stepper(
                          name: name,
                          quantity: quantity,
                          onAdd: onAdd,
                          onDecrease: onDecrease,
                          onQuantityTap: onQuantityTap))
                else if (priced && !outOfStock && onAdd != null)
                  Positioned(
                      right: MNSpace.x2,
                      bottom: MNSpace.x2,
                      child: _RoundAdd(
                          label: '${strings.increase} $name', onTap: onAdd!)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  MNSpace.x3, 10, MNSpace.x3, MNSpace.x3),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: referenceStyle
                            ? MNText.catalogueName
                            : MNText.productName),
                    const SizedBox(height: 2),
                    Text(priceText,
                        style: priced
                            ? (referenceStyle
                                ? MNText.cataloguePrice
                                : MNText.price)
                            : MNText.meta.copyWith(color: MNColors.ink2)),
                    if (outOfStock || remaining != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          outOfStock
                              ? strings.outOfStock
                              : strings.remaining(remaining!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MNText.meta),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAdd extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RoundAdd({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => MNPressable(
        onTap: onTap,
        pressedScale: .88,
        scaleDuration: MNMotion.keyPress,
        color: MNColors.white,
        borderRadius: BorderRadius.circular(MNSize.minTouch / 2),
        semanticLabel: label,
        child: const SizedBox.square(
            dimension: MNSize.minTouch,
            child: Center(child: MNIcon(MNIconData.plus, color: MNColors.ink))),
      );
}

/// `.pc-step`: the black pill shown once a product is in the cart.
class _Stepper extends ConsumerWidget {
  final String name;
  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onDecrease;
  final VoidCallback? onQuantityTap;
  const _Stepper(
      {required this.name,
      required this.quantity,
      this.onAdd,
      this.onDecrease,
      this.onQuantityTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    Widget button(MNIconData icon, String label, VoidCallback? onTap) =>
        MNPressable(
          onTap: onTap,
          pressedScale: .86,
          scaleDuration: MNMotion.keyPress,
          semanticLabel: label,
          child: SizedBox.square(
              dimension: MNSize.minTouch,
              child: Center(child: MNIcon(icon, color: MNColors.white))),
        );
    return Container(
      height: MNSize.minTouch,
      decoration: BoxDecoration(
          color: MNColors.black,
          borderRadius: BorderRadius.circular(MNRadius.pill)),
      child: Row(children: [
        button(MNIconData.minus, '${strings.decrease} $name', onDecrease),
        Expanded(
          // Tapping the number opens direct entry.
          child: MNPressable(
            onTap: onQuantityTap,
            pressedScale: MNMotion.pressChip,
            semanticLabel: strings.quantityFor(name),
            child: SizedBox(
              height: MNSize.minTouch,
              child: Center(
                child: ExcludeSemantics(
                  child: MNRollingNumber(quantity,
                      style: MNText.quantity.copyWith(color: MNColors.white)),
                ),
              ),
            ),
          ),
        ),
        button(MNIconData.plus, '${strings.increase} $name', onAdd),
      ]),
    );
  }
}

/// `.grid`: two columns, 12 px apart. Each row is as tall as its tallest
/// card, so names and prices never clip at large text sizes (a fixed-ratio
/// GridView would cut them off).
class MNProductGrid extends StatelessWidget {
  final List<Widget> children;
  const MNProductGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: MNSpace.x3),
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: children[i]),
              const SizedBox(width: MNSpace.x3),
              Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox()),
            ]),
          ),
        ],
      ]);
}
