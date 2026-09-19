import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/supply_art.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        body: Stack(fit: StackFit.expand, children: [
      const BrandImage('splash', fallbackArt: 'cattle', fit: BoxFit.cover),
      // The photograph carries a bright sky at the top and foliage at the
      // bottom, so the wordmark sits over the sky in dark ink and only the
      // lower tagline needs a scrim.
      const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x80000000)])),
          child: SizedBox.expand()),
      SafeArea(
          child: Column(children: [
            const SizedBox(height: 64),
            // The supplied logo carries its own tagline, so the headline sits
            // below it rather than repeating the brand line.
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: BrandMark(size: 46)),
            const SizedBox(height: 18),
            Text(s.splashHeadline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: OColors.forest)),
            const Spacer(),
            Text(s.splashTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.5)),
            const SizedBox(height: 22),
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            const SizedBox(height: 40),
          ]))
    ]));
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    // The photograph fills the screen and the content panel floats over its
    // lower half, its background fading up into the image so the two meet as
    // haze rather than at a cut line.
    return ExitOnBack(
        child: Scaffold(
        body: Stack(fit: StackFit.expand, children: [
      // The photograph runs well past the panel's top edge so the panel's
      // gradient dissolves over the image itself rather than over bare
      // background, which would still read as a cut.
      const Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
              heightFactor: .78,
              // welcome.jpg is authored at this slot's aspect ratio, so the
              // cover fit keeps every animal in frame without cropping.
              child: BrandImage('welcome', fallbackArt: 'cattle'))),
      Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                  child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 150, 24, 20),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, .18, .40, 1],
                              colors: [
                                OColors.background.withValues(alpha: 0),
                                OColors.background.withValues(alpha: .70),
                                OColors.background,
                                OColors.background,
                              ])),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.welcomeTitle,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 10),
                            Text(s.welcomeBody,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: OColors.secondary, height: 1.5)),
                            const SizedBox(height: 26),
                            OmoterraButton(s.getStarted,
                                onPressed: () => context.push('/phone')),
                            const SizedBox(height: 10),
                            OmoterraButton(s.haveAccount,
                                secondary: true,
                                onPressed: () => context.push('/phone')),
                          ]))))),
    ])));
  }
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});
  @override
  ConsumerState<PhoneScreen> createState() => _PhoneState();
}

class _PhoneState extends ConsumerState<PhoneScreen> {
  final phone = TextEditingController();
  bool busy = false;
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
      final response =
          await ref.read(repositoryProvider).write('/auth/otp', {'phone': number});
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
        appBar: AppBar(
            leading: const Padding(
                padding: EdgeInsets.only(left: 12), child: BackChevron()),
            leadingWidth: 60),
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
                        if (error != null) ErrorState(error!),
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
          NumberPad(onDigit: _append, onBackspace: _backspace),
        ])));
  }
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
          width: 24,
          height: 17,
          child: CustomPaint(painter: _FlagPainter())));
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

/// In-app numeric keypad. Replaces the system keyboard so the screen matches
/// the design, and keeps every key a real focusable button with a spoken
/// label so the flow stays usable with a screen reader or switch access.
class NumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const NumberPad({super.key, required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) => Container(
      color: const Color(0xFFF2F4F2),
      padding: EdgeInsets.fromLTRB(
          6, 8, 6, 8 + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      ]));
}

class _Key extends StatelessWidget {
  final String value;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _Key(
      {required this.value,
      required this.onDigit,
      required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox(height: 56);
    final backspace = value == 'back';
    return Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
            button: true,
            label: backspace ? 'Delete' : value,
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

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> challenge;
  const OtpScreen(this.challenge, {super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpState();
}

class _OtpState extends ConsumerState<OtpScreen> {
  late Map<String, dynamic> challenge;
  late final int length;
  late final List<TextEditingController> cells;
  late final List<FocusNode> nodes;
  Timer? timer;
  int remaining = 0;
  bool busy = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    challenge = widget.challenge;
    length = (challenge['otp_length'] as int?) ?? 6;
    cells = List.generate(length, (_) => TextEditingController());
    nodes = List.generate(length, (_) => FocusNode());
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
    for (final c in cells) {
      c.dispose();
    }
    for (final n in nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get code => cells.map((c) => c.text).join();

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
        for (final c in cells) {
          c.clear();
        }
        countdown();
        if (mounted) nodes.first.requestFocus();
      } else {
        await ref
            .read(sessionProvider.notifier)
            .verify(challenge['challenge_id'], code);
        if (mounted) context.go('/setup');
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
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
        appBar: AppBar(
            leading: const Padding(
                padding: EdgeInsets.only(left: 12), child: BackChevron()),
            leadingWidth: 60),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.otpTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Text(s.otpBody(challenge['phone']?.toString() ?? ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: OColors.secondary, height: 1.5)),
                      const SizedBox(height: 28),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < length; i++)
                              Padding(
                                  padding: EdgeInsets.only(
                                      right: i == length - 1 ? 0 : 8),
                                  child: _OtpCell(
                                      controller: cells[i],
                                      node: nodes[i],
                                      autofocus: i == 0,
                                      onChanged: (value) {
                                        if (value.isNotEmpty &&
                                            i < length - 1) {
                                          nodes[i + 1].requestFocus();
                                        }
                                        if (value.isEmpty && i > 0) {
                                          nodes[i - 1].requestFocus();
                                        }
                                        setState(() {});
                                        if (code.length == length && !busy) {
                                          submit();
                                        }
                                      })),
                          ]),
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
                                'Development code: ${challenge['development_code']}',
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
                      const Spacer(),
                    ]))));
  }
}

class _OtpCell extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode node;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  const _OtpCell(
      {required this.controller,
      required this.node,
      required this.autofocus,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    return SizedBox(
        width: 48,
        height: 56,
        child: TextField(
            controller: controller,
            focusNode: node,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: filled ? OColors.soft : Colors.white,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: filled ? OColors.forest : OColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: OColors.forest, width: 1.6))),
            onChanged: onChanged));
  }
}

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<SetupScreen> {
  final name = TextEditingController(), region = TextEditingController();
  final form = GlobalKey<FormState>();
  bool buy = true, sell = false, busy = false;
  String buyerType = 'personal', language = 'en';
  int step = 0;
  Object? error;

  @override
  void dispose() {
    name.dispose();
    region.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).profile({
        'name': name.text.trim(),
        'region': region.text.trim(),
        'language': language,
        'roles': [if (buy) 'buyer', if (sell) 'supplier'],
        'buyer_type': buy ? buyerType : null
      });
      ref.read(activeRoleProvider.notifier).state = buy ? 'buyer' : 'supplier';
      if (mounted) context.go(buy ? '/buyer' : '/supplier');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const _buyerTypes = <String, IconData>{
    'personal': Icons.person_outline,
    'restaurant': Icons.restaurant_outlined,
    'butchery': Icons.storefront_outlined,
    'hotel': Icons.apartment_outlined,
    'retailer': Icons.shopping_bag_outlined,
    'caterer': Icons.room_service_outlined,
    'other': Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        appBar: AppBar(
            leading: step == 0
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(
                        () => step = step == 2 && !buy ? 0 : step - 1))),
        body: Form(
            key: form,
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(children: [
                      Expanded(
                          child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                            if (step == 0) ...[
                              Text(s.roleTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 10),
                              Text(s.roleBody,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: OColors.secondary, height: 1.5)),
                              const SizedBox(height: 28),
                              _RoleCard(
                                  icon: Icons.shopping_cart_outlined,
                                  title: s.buySupply,
                                  body: s.buySupplyBody,
                                  selected: buy,
                                  onTap: () => setState(() => buy = !buy)),
                              const SizedBox(height: 12),
                              _RoleCard(
                                  icon: Icons.eco_outlined,
                                  title: s.sellSupply,
                                  body: s.sellSupplyBody,
                                  selected: sell,
                                  onTap: () => setState(() => sell = !sell)),
                            ],
                            if (step == 1) ...[
                              Text(s.buyerTypeTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 10),
                              Text(s.buyerTypeBody,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: OColors.secondary)),
                              const SizedBox(height: 24),
                              for (final entry in _buyerTypes.entries)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ChoiceRow(
                                        icon: entry.value,
                                        label: label(entry.key),
                                        selected: buyerType == entry.key,
                                        onTap: () => setState(
                                            () => buyerType = entry.key))),
                            ],
                            if (step == 2) ...[
                              Text(s.profileTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 24),
                              OmoterraTextField(s.fullName, name),
                              OmoterraTextField(s.region, region),
                              DropdownButtonFormField<String>(
                                  initialValue: language,
                                  decoration:
                                      InputDecoration(labelText: s.language),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'en', child: Text('English')),
                                    DropdownMenuItem(
                                        value: 'sw', child: Text('Kiswahili'))
                                  ],
                                  onChanged: (v) =>
                                      setState(() => language = v!)),
                            ],
                          ])),
                      if (error != null) ErrorState(error!),
                      OmoterraButton(
                          step == 2 ? s.finishSetup : s.continueLabel,
                          busy: busy, onPressed: () {
                        if (step == 2) {
                          submit();
                          return;
                        }
                        if (!buy && !sell) {
                          setState(() => error = s.isSwahili
                              ? 'Chagua Nunua Bidhaa au Uuze Bidhaa.'
                              : 'Choose Buy Supply or Sell Supply.');
                          return;
                        }
                        setState(() {
                          error = null;
                          step = step == 0 && !buy ? 2 : step + 1;
                        });
                      }),
                    ])))));
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard(
      {required this.icon,
      required this.title,
      required this.body,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: selected ? OColors.soft : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? OColors.forest : OColors.border,
                  width: selected ? 1.5 : 1)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 26, color: OColors.forest),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 13,
                          color: OColors.secondary,
                          height: 1.4))
                ])),
            const SizedBox(width: 8),
            _Check(selected: selected),
          ])));
}

class _Check extends StatelessWidget {
  final bool selected;
  const _Check({required this.selected});
  @override
  Widget build(BuildContext context) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
          color: selected ? OColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? OColors.forest : OColors.border, width: 1.5)),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null);
}

class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceRow(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
              color: selected ? OColors.soft : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? OColors.forest : OColors.border,
                  width: selected ? 1.5 : 1)),
          child: Row(children: [
            Icon(icon, size: 21, color: OColors.forest),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500))),
            Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 21,
                color: selected ? OColors.forest : OColors.border),
          ])));
}

