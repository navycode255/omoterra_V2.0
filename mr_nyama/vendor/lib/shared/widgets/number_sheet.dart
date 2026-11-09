import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'pin.dart';
import 'sheet.dart';

/// Asks for a whole number from 0 to [max] with the large keypad. The
/// first key typed replaces [initial], which is clamped into 0..[max].
/// Returns null when dismissed.
Future<int?> showNumberSheet(BuildContext context,
    {required String title, required int initial, required int max}) {
  assert(max >= 0, 'max must not be negative');
  return showMNSheet<int>(context,
      builder: (_) =>
          _NumberSheet(title: title, initial: initial.clamp(0, max), max: max));
}

class _NumberSheet extends ConsumerStatefulWidget {
  final String title;
  final int initial;
  final int max;
  const _NumberSheet(
      {required this.title, required this.initial, required this.max});

  @override
  ConsumerState<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends ConsumerState<_NumberSheet> {
  late int _value = widget.initial;
  bool _typing = false;

  void _digit(int d) => setState(() {
        final next = _typing ? _value * 10 + d : d;
        _typing = true;
        if (next <= widget.max) _value = next;
      });

  void _backspace() => setState(() {
        _typing = true;
        _value = _value ~/ 10;
      });

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      Center(
        child: Semantics(
          liveRegion: true,
          child: Text('$_value',
              style: MNText.resolve(context, MNText.quantityLarge)),
        ),
      ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: MNPinKeypad(onDigit: _digit, onBackspace: _backspace),
        ),
      ),
      MNButton(strings.setQuantity,
          onPressed: () => Navigator.of(context).pop(_value)),
    ]);
  }
}
