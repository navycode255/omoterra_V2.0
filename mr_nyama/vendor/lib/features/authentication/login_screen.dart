import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/device_sign_in.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/icon_data.dart';
import '../../shared/widgets/note.dart';
import 'fingerprint_sign_in.dart';
import 'sign_in_page.dart';

/// The vendor sign-in of the owner-approved reference (30 October 2026):
/// "Karibu Mr. Nyama", the phone form, "Kumbuka namba hii", the three-dot
/// menu (Ingia ofisini, Msaada) and the language at the bottom. A remembered
/// phone opens on "Karibu tena" and the fingerprint instead; when the office
/// side was signed in to last, the app opens there.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _side = 'vendor';
  bool _sideChecked = false, _toOffice = false;
  String? _note;

  /// Asks the server whether [phone] needs its PIN or the activation code,
  /// then opens that screen. Returns the error to show, if any.
  Future<String?> _start(String phone, {bool remember = false}) async {
    final strings = ref.read(stringsProvider);
    try {
      final step = await ref.read(sessionProvider.notifier).startSignIn(phone);
      if (!mounted) return null;
      ref.read(authFlowProvider.notifier).state = AuthFlow(remember: remember);
      context.push(step == SignInStep.pin ? MNRoutes.pin : MNRoutes.activate);
      return null;
    } on AuthFailure catch (failure) {
      return strings.failure(failure);
    }
  }

  /// Once per app start: open the office sign-in when it was used last and
  /// remembers its account. Returns whether to wait before showing a form.
  bool _checkLastSide() {
    if (ref.watch(lastSideAppliedProvider)) return false;
    final last = ref.watch(lastSignInSideProvider);
    final office = ref.watch(rememberedSignInProvider('staff'));
    if (!last.hasValue || !office.hasValue || _sideChecked) return true;
    _sideChecked = true;
    _toOffice = last.value == 'staff' && office.value != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lastSideAppliedProvider.notifier).state = true;
      if (_toOffice) context.go(MNRoutes.officeSignIn);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final remembered = ref.watch(rememberedSignInProvider(_side));
    final other = ref.watch(otherAccountProvider(_side));
    final waiting = _checkLastSide() || _toOffice || !remembered.hasValue;
    final saved = other ? null : remembered.valueOrNull;
    final menu = [
      SignInMenuItem(MNIconData.store, strings.officeSignIn,
          () => context.push(MNRoutes.officeSignIn)),
      SignInMenuItem(MNIconData.help, strings.help,
          () => showSignInHelp(context, strings.help, [strings.phoneHelp])),
    ];
    if (waiting) return SignInPage(menu: menu, children: const []);
    if (saved != null) {
      return SignInPage(menu: menu, children: [
        RememberedSignIn(
            key: ValueKey(saved.account),
            saved: saved,
            signIn: () =>
                ref.read(sessionProvider.notifier).signInWithFingerprint(),
            usePin: () => _start(saved.phone),
            notYou: () =>
                ref.read(otherAccountProvider(_side).notifier).state = true,
            onEnded: (note) => setState(() => _note = note)),
      ]);
    }
    return SignInPage(
        title: strings.signInWelcome,
        subtitle: strings.signInPhonePrompt,
        menu: menu,
        children: [
          PhoneSignInForm(
              side: _side,
              prefill: !other,
              notice: _note == null ? null : MNNote(_note!),
              start: _start),
        ]);
  }
}
