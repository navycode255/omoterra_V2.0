import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import 'number_pad.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> challenge;
  const OtpScreen(this.challenge, {super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpState();
}

class _OtpState extends ConsumerState<OtpScreen> {
  late Map<String, dynamic> challenge;
  late final int length;
  String code = '';
  Timer? timer;
  int remaining = 0;
  bool busy = false;
  bool keypadVisible = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    challenge = widget.challenge;
    length = (challenge['otp_length'] as int?) ?? 6;
    countdown();
  }

  void countdown() {
    remaining = (challenge['resend_after_seconds'] as int?) ?? 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remaining > 0) setState(() => remaining--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _append(String digit) {
    if (code.length >= length || busy) return;
    setState(() {
      code += digit;
      error = null;
    });
    if (code.length == length) submit();
  }

  void _backspace() {
    if (code.isEmpty || busy) return;
    setState(() {
      code = code.substring(0, code.length - 1);
      error = null;
    });
  }

  Future<void> submit({bool resend = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (resend) {
        final next = await ref
            .read(repositoryProvider)
            .write('/auth/otp', {'phone': challenge['phone']});
        challenge = {
          ...Map<String, dynamic>.from(next),
          'phone': challenge['phone']
        };
        code = '';
        countdown();
      } else {
        await ref
            .read(sessionProvider.notifier)
            .verify(challenge['challenge_id'], code);
        if (mounted) context.go('/setup');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          // A rejected code is cleared so the next attempt starts fresh
          // rather than editing a code the server has already refused.
          if (!resend) code = '';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get clock {
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final sec = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$sec';
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
                        Text(s.otpTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: OColors.forest)),
                        const SizedBox(height: 10),
                        Text(s.otpBody(challenge['phone']?.toString() ?? ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: OColors.secondary, height: 1.5)),
                        const SizedBox(height: 28),
                        _OtpCells(code: code, length: length),
                        const SizedBox(height: 18),
                        if (challenge['development_code'] != null)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFDF6EC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFF0DEC4))),
                              child: Text(
                                  s.developmentCode(
                                      '${challenge['development_code']}'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: OColors.warning,
                                      fontWeight: FontWeight.w600))),
                        Center(
                            child: TextButton(
                                onPressed: remaining == 0 && !busy
                                    ? () => submit(resend: true)
                                    : null,
                                child: Text(remaining > 0
                                    ? s.resendIn(clock)
                                    : s.resendNow))),
                        if (error != null) ErrorState(error!),
                        const SizedBox(height: 8),
                        OmoterraButton(s.verify,
                            busy: busy,
                            onPressed:
                                code.length == length ? () => submit() : null),
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

/// Six boxes grouped 3-3 with a dash, filled and advanced from the in-app
/// keypad rather than a focused TextField, so no OS keyboard ever appears.
class _OtpCells extends StatelessWidget {
  final String code;
  final int length;
  const _OtpCells({required this.code, required this.length});

  @override
  Widget build(BuildContext context) {
    final mid = (length / 2).ceil();
    // Sized to fit six boxes plus a dash on the narrowest supported screen
    // (320px) without overflowing: content width must clear ~272px.
    return Semantics(
        label: context.s.verificationCode,
        value: code.isEmpty ? context.s.empty : code.split('').join(' '),
        textField: true,
        container: true,
        explicitChildNodes: false,
        excludeSemantics: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < length; i++) ...[
            _OtpBox(
                digit: i < code.length ? code[i] : '',
                active: i == code.length),
            if (i < length - 1)
              SizedBox(
                  width: i == mid - 1 ? 16 : 6,
                  child: i == mid - 1
                      ? const Center(
                          child: Text('—',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: OColors.muted,
                                  fontWeight: FontWeight.w600)))
                      : null),
          ],
        ]));
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  final bool active;
  const _OtpBox({required this.digit, required this.active});
  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    return Container(
        width: 38,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: filled ? OColors.soft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active
                    ? OColors.forest
                    : filled
                        ? OColors.forest
                        : OColors.border,
                width: active ? 1.6 : 1)),
        child: Text(digit,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)));
  }
}
