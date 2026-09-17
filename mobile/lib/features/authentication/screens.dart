import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(children: [
                const SizedBox(height: 24),
                const Row(children: [
                  Icon(Icons.eco, color: OColors.forest),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text('omoterra',
                          style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: OColors.forest)))
                ]),
                const SizedBox(height: 40),
                Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: OColors.soft,
                        borderRadius: BorderRadius.circular(28)),
                    child: const Icon(Icons.agriculture_outlined,
                        size: 96, color: OColors.forest)),
                const SizedBox(height: 32),
                Text('Good supply.\nBetter business.',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                const Text(
                    'Buy quality livestock and meat. Sell your available stock. Omoterra coordinates the rest.'),
                const SizedBox(height: 40),
                OmoterraButton('Get started',
                    onPressed: () => context.go('/phone')),
                const SizedBox(height: 16),
                const Center(
                    child: Text('Agricultural supply, made dependable.',
                        style:
                            TextStyle(color: OColors.secondary, fontSize: 12))),
                const SizedBox(height: 8)
              ]))));
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});
  @override
  ConsumerState<PhoneScreen> createState() => _PhoneState();
}

class _PhoneState extends ConsumerState<PhoneScreen> {
  final phone = TextEditingController(text: '+255');
  bool busy = false;
  Object? error;
  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await ref
          .read(repositoryProvider)
          .write('/auth/otp', {'phone': phone.text.trim()});
      if (mounted) {
        context.push('/otp', extra: {
          ...Map<String, dynamic>.from(response),
          'phone': phone.text.trim()
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Let’s get you started',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
            'Enter your Tanzanian mobile number. We’ll send a verification code.'),
        const SizedBox(height: 32),
        OmoterraTextField('Phone number', phone, keyboard: TextInputType.phone),
        if (error != null) ErrorState(error!),
        OmoterraButton('Continue', busy: busy, onPressed: submit)
      ]));
}

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> challenge;
  const OtpScreen(this.challenge, {super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpState();
}

class _OtpState extends ConsumerState<OtpScreen> {
  final code = TextEditingController();
  late Map<String, dynamic> challenge;
  Timer? timer;
  int remaining = 0;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    challenge = widget.challenge;
    countdown();
  }

  void countdown() {
    remaining = challenge['resend_after_seconds'] as int;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && remaining > 0) setState(() => remaining--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
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
        countdown();
      } else {
        await ref
            .read(sessionProvider.notifier)
            .verify(challenge['challenge_id'], code.text.trim());
        if (mounted) context.go('/buyer');
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Verify your number',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
            'Enter the ${challenge['otp_length']}-digit code for ${challenge['phone']}.'),
        const SizedBox(height: 24),
        if (challenge['development_code'] != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('Development code: ${challenge['development_code']}',
                  style: const TextStyle(color: OColors.warning))),
        OmoterraTextField('Verification code', code,
            keyboard: TextInputType.number),
        if (error != null) ErrorState(error!),
        OmoterraButton('Verify & continue',
            busy: busy, onPressed: () => submit()),
        TextButton(
            onPressed:
                remaining == 0 && !busy ? () => submit(resend: true) : null,
            child:
                Text(remaining > 0 ? 'Resend in ${remaining}s' : 'Resend code'))
      ]));
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
  Object? error;
  @override
  void dispose() {
    name.dispose();
    region.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!buy && !sell) {
      setState(() => error = 'Choose Buy Supply or Sell Supply.');
      return;
    }
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

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Your Omoterra account')),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('How will you use Omoterra?',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Choose one or both. You can enable the other later.'),
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Buy Supply'),
                value: buy,
                onChanged: (v) => setState(() => buy = v!)),
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sell Supply'),
                value: sell,
                onChanged: (v) => setState(() => sell = v!)),
            if (buy)
              Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: DropdownButtonFormField<String>(
                      initialValue: buyerType,
                      decoration:
                          const InputDecoration(labelText: 'Buyer type'),
                      items: [
                        'personal',
                        'restaurant',
                        'butchery',
                        'hotel',
                        'retailer',
                        'caterer',
                        'other'
                      ]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(label(e))))
                          .toList(),
                      onChanged: (v) => setState(() => buyerType = v!))),
            OmoterraTextField('Your name', name),
            OmoterraTextField('General region', region),
            DropdownButtonFormField<String>(
                initialValue: language,
                decoration:
                    const InputDecoration(labelText: 'Preferred language'),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'sw', child: Text('Kiswahili'))
                ],
                onChanged: (v) => setState(() => language = v!)),
            const SizedBox(height: 24),
            if (error != null) ErrorState(error!),
            OmoterraButton('Finish setup', busy: busy, onPressed: submit)
          ])));
}
