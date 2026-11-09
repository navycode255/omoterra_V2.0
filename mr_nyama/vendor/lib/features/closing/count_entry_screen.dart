import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/pin.dart';
import '../sales/sales_store.dart';

class CountEntry {
  final int quantity;
  const CountEntry(this.quantity);
}

/// A count is entered explicitly; opening a product never counts it as zero.
class CountEntryScreen extends ConsumerStatefulWidget {
  final Product product;
  final int? initial;
  const CountEntryScreen({super.key, required this.product, this.initial});

  @override
  ConsumerState<CountEntryScreen> createState() => _CountEntryScreenState();
}

class _CountEntryScreenState extends ConsumerState<CountEntryScreen> {
  late int? _value = widget.initial;
  bool _typing = false;
  void _digit(int digit) => setState(() {
        final next = _typing ? (_value ?? 0) * 10 + digit : digit;
        _typing = true;
        if (next <= 9999) _value = next;
      });

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    // Blind count: only the number is entered. Reasons come after the
    // count is frozen, on the closing screen.
    final valid = _value != null;
    return Scaffold(
      appBar: MNAppHeader(light: true, title: strings.closeDay),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.product.name, style: MNText.heading),
        const SizedBox(height: 24),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                border: Border.all(color: MNColors.border),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_value == null ? strings.countEntryHint : '$_value',
                textAlign: TextAlign.center,
                style:
                    _value == null ? MNText.secondary : MNText.quantityLarge)),
            const SizedBox(height: 24),
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: MNPinKeypad(
                    onDigit: _digit,
                    onBackspace: () => setState(() {
                          _typing = true;
                          _value = (_value ?? 0) ~/ 10;
                        })))),
      ]),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: MNButton(strings.saveWorkflow,
                  onPressed: !valid
                      ? null
                      : () => Navigator.pop(
                          context, CountEntry(_value!))))),
    );
  }
}
