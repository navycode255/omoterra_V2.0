import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import 'number_pad.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});
  @override
  ConsumerState<PhoneScreen> createState() => _PhoneState();
}

class _PhoneState extends ConsumerState<PhoneScreen> {
  final phone = TextEditingController();
  bool busy = false;
  bool keypadVisible = true;
  Object? error;

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final digits = phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) {
      setState(() => error = ref.read(stringsProvider).phoneTooShort);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final number = '+255${digits.substring(digits.length - 9)}';
      final response = await ref
          .read(repositoryProvider)
          .write('/auth/otp', {'phone': number});
      if (mounted) {
        context.push('/otp', extra: {
          ...Map<String, dynamic>.from(response),
          'phone': number,
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Tanzanian subscriber numbers are nine digits and never start with zero:
  /// the leading zero of the local form is replaced by the +255 prefix, which
  /// the field already shows.
  void _append(String digit) {
    final digits = phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) return;
    if (digits.isEmpty && digit == '0') {
      setState(() => error = ref.read(stringsProvider).leadingZero);
      return;
    }
    setState(() {
      phone.text = digits + digit;
      error = null;
    });
  }

  void _backspace() {
    if (phone.text.isEmpty) return;
    setState(() {
      phone.text = phone.text.substring(0, phone.text.length - 1);
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        appBar: const OmoterraAppBar(),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.phoneTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(s.phoneBody,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: OColors.secondary)),
                        const SizedBox(height: 28),
                        _PhoneField(value: phone.text, hint: s.phoneHint),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          if (error is String)
                            _PhoneValidationError(error! as String)
                          else
                            ErrorState(error!),
                        ],
                        const SizedBox(height: 20),
                        OmoterraButton(s.continueLabel,
                            busy: busy, onPressed: submit),
                        const SizedBox(height: 14),
                        Text(s.terms,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                color: OColors.muted,
                                height: 1.5)),
                      ]))),
          NumberPad(
            visible: keypadVisible,
            onToggle: () => setState(() => keypadVisible = !keypadVisible),
            onDigit: _append,
            onBackspace: _backspace,
          ),
        ])));
  }
}

class _PhoneValidationError extends StatelessWidget {
  final String message;
  const _PhoneValidationError(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE3E1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: OColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: OColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

/// Displays the number entered on the in-app keypad. It is not a TextField:
/// tapping it must never raise the system keyboard, since the pad below is the
/// only input. The value is announced so screen readers still read it back.
class _PhoneField extends StatelessWidget {
  final String value;
  final String hint;
  const _PhoneField({required this.value, required this.hint});

  /// 746484666 -> 746 484 666
  String get _grouped {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final parts = <String>[];
    for (var i = 0; i < digits.length; i += 3) {
      parts.add(digits.substring(i, (i + 3).clamp(0, digits.length)));
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Phone number',
      value: value.isEmpty ? 'empty' : _grouped.split('').join(' '),
      textField: true,
      container: true,
      explicitChildNodes: false,
      excludeSemantics: true,
      child: Row(children: [
        Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const _TanzanianFlag(),
              const SizedBox(width: 8),
              const Text('+255',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(width: 2),
              // Tanzania is the only supported country in V1, so the chevron
              // is an affordance for later rather than an active control.
              Icon(Icons.keyboard_arrow_down,
                  size: 18, color: OColors.muted.withValues(alpha: .9)),
            ])),
        const SizedBox(width: 10),
        Expanded(
            child: Container(
                height: 54,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OColors.border)),
                child: Text(value.isEmpty ? hint : _grouped,
                    style: TextStyle(
                        fontSize: 17,
                        letterSpacing: .6,
                        fontWeight:
                            value.isEmpty ? FontWeight.w400 : FontWeight.w600,
                        color: value.isEmpty ? OColors.muted : OColors.ink)))),
      ]));
}

/// The Tanzanian flag, drawn rather than shipped as an image so it stays sharp
/// at any size.
class _TanzanianFlag extends StatelessWidget {
  const _TanzanianFlag();
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
          width: 24, height: 17, child: CustomPaint(painter: _FlagPainter())));
}

class _FlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Green upper hoist triangle, blue lower fly triangle, black diagonal
    // band edged in yellow.
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0xFF1EB53A));
    canvas.drawPath(
        Path()
          ..moveTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0xFF00A3DD));
    canvas.drawPath(
        Path()
          ..moveTo(w, 0)
          ..lineTo(0, h)
          ..lineTo(0, h * .78)
          ..lineTo(w * .78, 0)
          ..close(),
        Paint()..color = const Color(0xFFFCD116));
    canvas.drawPath(
        Path()
          ..moveTo(w, 0)
          ..lineTo(w, h * .22)
          ..lineTo(w * .22, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0xFFFCD116));
    canvas.drawPath(
        Path()
          ..moveTo(w, 0)
          ..lineTo(w, h * .16)
          ..lineTo(w * .16, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
