import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../authentication/fingerprint_sign_in.dart';
import '../authentication/sign_in_page.dart';
import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/device_sign_in.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/states.dart';
import '../authentication/widgets.dart';

/// Ofisi: staff sign in with their phone. Activated accounts go to the PIN,
/// new ones to the code an administrator gave them. A remembered phone opens
/// on "Karibu tena" and the fingerprint (owner decision 30 October 2026).
class OfficeSignInScreen extends ConsumerStatefulWidget {
  const OfficeSignInScreen({super.key});

  @override
  ConsumerState<OfficeSignInScreen> createState() => _OfficeSignInScreenState();
}

class _OfficeSignInScreenState extends ConsumerState<OfficeSignInScreen> {
  static const _side = 'staff';
  String? _note;

  /// Asks the server whether [phone] needs its PIN or the administrator's
  /// code, then opens that screen. Returns the error to show, if any.
  Future<String?> _start(String phone, {bool remember = false}) async {
    final strings = ref.read(stringsProvider);
    try {
      final step = await ref.read(officeRepositoryProvider).startSignIn(phone);
      if (!mounted) return null;
      ref.read(officeFlowProvider.notifier).state =
          OfficeFlow(phone: phone, remember: remember);
      context.push(
          step == SignInStep.pin ? MNRoutes.officePin : MNRoutes.officeCode);
      return null;
    } on AuthFailure catch (failure) {
      return strings.failure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final remembered = ref.watch(rememberedSignInProvider(_side));
    final other = ref.watch(otherAccountProvider(_side));
    final saved = other ? null : remembered.valueOrNull;
    final menu = [
      // Back to the vendor sign-in, whichever way this screen was reached.
      SignInMenuItem(MNIconData.user, strings.vendorSignIn,
          () => context.go(MNRoutes.login)),
      SignInMenuItem(
          MNIconData.help,
          strings.help,
          () => showSignInHelp(
              context, strings.help, [strings.officeSignInHelp])),
    ];
    final page = !remembered.hasValue
        ? SignInPage(menu: menu, children: const [])
        : saved != null
            ? SignInPage(menu: menu, children: [
                Text(strings.office,
                    textAlign: TextAlign.center,
                    style: MNText.resolve(context, MNText.meta)),
                const SizedBox(height: MNSpace.x2),
                RememberedSignIn(
                    key: ValueKey(saved.account),
                    saved: saved,
                    signIn: () => ref
                        .read(officeSessionProvider.notifier)
                        .signInWithFingerprint(),
                    usePin: () => _start(saved.phone),
                    notYou: () =>
                        ref.read(otherAccountProvider(_side).notifier).state = true,
                    onEnded: (note) => setState(() => _note = note)),
              ])
            : SignInPage(
                title: strings.officeSignIn,
                subtitle: strings.officeSignInHelp,
                menu: menu,
                children: [
                  PhoneSignInForm(
                      side: _side,
                      prefill: !other,
                      notice: _note == null ? null : MNNote(_note!),
                      start: _start),
                ]);
    return Theme(data: mrNyamaOfficeTheme(Theme.of(context)), child: page);
  }
}

/// The office PIN. From a remembered phone's "Tumia PIN" it greets the
/// staff member by name, its fingerprint key signs in with the saved key,
/// and "Si wewe?" returns to the phone form.
class OfficePinScreen extends ConsumerStatefulWidget {
  const OfficePinScreen({super.key});
  @override
  ConsumerState<OfficePinScreen> createState() => _OfficePinScreenState();
}

class _OfficePinScreenState extends ConsumerState<OfficePinScreen> {
  bool _busy = false;
  String? _note;

  Future<void> _fingerprint() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final note = await fingerprintSignIn(ref,
        () => ref.read(officeSessionProvider.notifier).signInWithFingerprint());
    if (mounted) {
      setState(() {
        _busy = false;
        _note = note;
      });
    }
  }

  void _notYou() {
    ref.read(otherAccountProvider('staff').notifier).state = true;
    context.canPop() ? context.pop() : context.go(MNRoutes.officeSignIn);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final flow = ref.watch(officeFlowProvider);
    final remembered = ref.watch(rememberedSignInProvider('staff')).valueOrNull;
    final welcome = remembered != null && remembered.phone == flow.phone
        ? remembered
        : null;
    return AuthPage(showBack: !flow.localUnlock, children: [
      PinEntry(
        busy: _busy,
        title: strings.pinTitle,
        subtitle: strings.pinSubtitle,
        notice: _note == null ? null : MNNote(_note!),
        onBiometric: welcome != null ? _fingerprint : null,
        onComplete: (pin) async {
          final flow = ref.read(officeFlowProvider);
          final phone = flow.phone;
          if (phone == null) return strings.errUnknownPhone;
          try {
            final profile = await ref
                .read(officeRepositoryProvider)
                .signIn(phone: phone, pin: pin);
            ref.read(officeFlowProvider.notifier).state = const OfficeFlow();
            await ref
                .read(officeSessionProvider.notifier)
                .signedIn(profile, pinVerified: true, remember: flow.remember);
            return null;
          } on AuthFailure catch (failure) {
            if (failure.kind == AuthFailureKind.locked) rethrow;
            return strings.failure(failure);
          }
        },
        footer: Column(mainAxisSize: MainAxisSize.min, children: [
          MNTextButton(strings.forgotPin,
              onPressed: () => context.push(MNRoutes.officeForgotPin)),
          if (welcome != null)
            MNTextButton(strings.notYou,
                color: MNColors.ink, onPressed: _notYou),
        ]),
      ),
    ]);
  }
}

/// The 6-digit code an administrator issued (first sign-in or PIN reset).
class OfficeCodeScreen extends ConsumerWidget {
  const OfficeCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return AuthPage(children: [
      PinEntry(
        title: strings.activationTitle,
        subtitle: strings.activationHelp,
        length: 6,
        codeBoxes: true,
        onComplete: (code) async {
          final flow = ref.read(officeFlowProvider);
          if (flow.phone == null) return strings.errUnknownPhone;
          try {
            final token = await ref
                .read(officeRepositoryProvider)
                .verifyCode(phone: flow.phone!, code: code, reset: flow.reset);
            ref.read(officeFlowProvider.notifier).state =
                flow.copyWith(setupToken: token);
            if (context.mounted) context.push(MNRoutes.officeCreatePin);
            return null;
          } on AuthFailure catch (failure) {
            return strings.failure(failure);
          }
        },
      ),
    ]);
  }
}

/// Chagua PIN mpya, then Rudia PIN, for the office account.
class OfficeCreatePinScreen extends ConsumerWidget {
  final bool confirm;
  const OfficeCreatePinScreen({super.key, this.confirm = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final flowNotifier = ref.read(officeFlowProvider.notifier);
    final mismatch = !confirm && ref.watch(officeFlowProvider).mismatch;
    return AuthPage(children: [
      PinEntry(
        key: ValueKey(confirm),
        title: confirm ? strings.confirmPin : strings.createPin,
        notice: mismatch ? MNNote(strings.pinMismatch, error: true) : null,
        onComplete: (pin) async {
          final flow = ref.read(officeFlowProvider);
          if (!confirm) {
            if (isWeakPin(pin)) return strings.pinWeak;
            flowNotifier.state = flow.copyWith(newPin: pin, mismatch: false);
            context.push(MNRoutes.officeConfirmPin);
            return null;
          }
          if (pin != flow.newPin) {
            flowNotifier.state = flow.withoutPin(mismatch: true);
            if (context.mounted) context.pop();
            return null;
          }
          try {
            final profile = await ref
                .read(officeRepositoryProvider)
                .setPin(setupToken: flow.setupToken ?? '', pin: pin);
            flowNotifier.state = const OfficeFlow();
            await ref
                .read(officeSessionProvider.notifier)
                .signedIn(profile, pinVerified: true, remember: flow.remember);
            return null;
          } on AuthFailure catch (failure) {
            return strings.failure(failure);
          }
        },
      ),
    ]);
  }
}

/// Umesahau PIN? (office): who gives a reset code, then the code screen.
class OfficeForgotPinScreen extends ConsumerWidget {
  const OfficeForgotPinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return AuthPage(children: [
      SizedBox(
        height: 340,
        child: MNEmptyState(
            icon: MNIconData.key,
            title: strings.forgotPinTitle,
            message: strings.officeForgotBody),
      ),
      MNButton(strings.haveCode, onPressed: () {
        final flow = ref.read(officeFlowProvider);
        ref.read(officeFlowProvider.notifier).state =
            OfficeFlow(phone: flow.phone, reset: true, remember: flow.remember);
        context.push(MNRoutes.officeCode);
      }),
    ]);
  }
}
