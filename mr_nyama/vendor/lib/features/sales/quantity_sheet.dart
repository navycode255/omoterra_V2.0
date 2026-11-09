import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pin.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/sheet.dart';
import 'cart.dart';
import 'sales_store.dart';

/// Opens the quantity sheet for [product]: large − / + and a keypad for
/// typing the number directly. "Weka idadi" sets the cart quantity
/// (zero removes the product).
Future<void> showQuantitySheet(BuildContext context, Product product) =>
    showMNSheet<void>(context, builder: (_) => _QuantitySheet(product));

class _QuantitySheet extends ConsumerStatefulWidget {
  final Product product;
  const _QuantitySheet(this.product);

  @override
  ConsumerState<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends ConsumerState<_QuantitySheet> {
  static const _max = 999;
  late int _value = ref.read(cartProvider).quantityOf(widget.product.id) == 0
      ? 1
      : ref.read(cartProvider).quantityOf(widget.product.id);

  /// The first key typed replaces the number; later keys append.
  bool _typing = false;

  void _digit(int d) => setState(() {
        final next = _typing ? _value * 10 + d : d;
        _typing = true;
        _value = next > _max ? _value : next;
      });

  void _backspace() => setState(() {
        _typing = true;
        _value = _value ~/ 10;
      });

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final p = widget.product;
    final low = p.availableToSell != null && _value > p.availableToSell!;
    return MNSheet(title: p.name, children: [
      if (p.price != null) Text(formatTsh(p.price!), style: MNText.price),
      Center(
        child: MNQuantitySelector(
          value: _value,
          min: 0,
          max: _max,
          large: true,
          itemLabel: p.name,
          onChanged: (v) => setState(() {
            _typing = false;
            _value = v;
          }),
        ),
      ),
      if (low) MNNote(strings.lowStock(p.name)),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: MNPinKeypad(onDigit: _digit, onBackspace: _backspace),
        ),
      ),
      MNButton(strings.setQuantity, onPressed: () {
        ref.read(cartProvider.notifier).setQuantity(p.id, _value);
        Navigator.of(context).pop();
      }),
    ]);
  }
}
