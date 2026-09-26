import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';

/// In-app numeric keypad, shared by PhoneScreen and OtpScreen. Replaces the
/// system keyboard so the screen matches the design, and keeps every key a
/// real focusable button with a spoken label so the flow stays usable with a
/// screen reader or switch access.
class NumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool visible;
  final VoidCallback onToggle;
  const NumberPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
          color: const Color(0xFFF2F4F2),
          padding: EdgeInsets.fromLTRB(
              6, 2, 6, 8 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggle,
                icon: Icon(visible
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded),
                label: Text(
                    visible ? context.s.hideKeyboard : context.s.showKeyboard),
                style: TextButton.styleFrom(
                  foregroundColor: OColors.forest,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            if (visible)
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', 'back'],
              ])
                Row(
                    children: row
                        .map((key) => Expanded(
                            child: _Key(
                                value: key,
                                onDigit: onDigit,
                                onBackspace: onBackspace)))
                        .toList()),
          ])));
}

class _Key extends StatelessWidget {
  final String value;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _Key(
      {required this.value, required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox(height: 56);
    final backspace = value == 'back';
    return Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
            button: true,
            label: backspace ? context.s.delete : value,
            excludeSemantics: true,
            child: Material(
                color: backspace ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      backspace ? onBackspace() : onDigit(value);
                    },
                    child: SizedBox(
                        height: 48,
                        child: Center(
                            child: backspace
                                ? const Icon(Icons.backspace_outlined,
                                    size: 21, color: OColors.ink)
                                : Text(value,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w500,
                                        color: OColors.ink))))))));
  }
}
