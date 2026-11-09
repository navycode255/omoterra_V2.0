import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/device_sign_in.dart';
import '../../core/auth/offline_unlock.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/note.dart';
import 'fingerprint_sign_in.dart';
import 'widgets.dart';

/// Ingiza PIN: signs in, or unlocks after the 12-hour lock or an expired
/// session. On success the router opens Nyumbani. After a lock for
/// inactivity (the session is still kept), a vendor who turned the
/// fingerprint on in Wasifu may use it instead of the PIN: the prompt opens
/// once by itself and the keypad's fingerprint key opens it again. A session
/// the server ended, or a first sign-in, always needs the PIN. From a
/// remembered phone's "Tumia PIN" it greets the vendor by name, its
/// fingerprint key signs in with the saved key, and "Si wewe?" returns to the
/// phone form.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});
  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String? _biometricNote;
  bool _prompted = false, _busy = false;

  Future<void> _biometric() async {
    if (_busy) return;
    final strings = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _biometricNote = null;
    });
    String? note;
    try {
      final ok = await authenticateBiometric(ref, strings.biometricReason);
      if (ok) await ref.read(sessionProvider.notifier).unlockWithBiometric();
      if (!ok) note = strings.biometricFailed;
    } on OfflineUnlockFailure catch (failure) {
      note = switch (failure.refusal) {
        OfflineRefusal.expired => strings.offlineExpired,
        OfflineRefusal.erased => strings.offlineErased,
        _ => strings.errOffline,
      };
    } on AuthFailure catch (failure) {
      note = strings.failure(failure);
    } catch (_) {
      note = strings.biometricFailed;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _biometricNote = note;
      });
    }
  }

  /// The remembered phone's fingerprint, from its PIN pad.
  Future<void> _rememberedFingerprint() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _biometricNote = null;
    });
    final note = await fingerprintSignIn(
        ref, () => ref.read(sessionProvider.notifier).signInWithFingerprint());
    if (mounted) {
      setState(() {
        _busy = false;
        _biometricNote = note;
      });
    }
  }

  void _notYou() {
    ref.read(otherAccountProvider('vendor').notifier).state = true;
    context.canPop() ? context.pop() : context.go(MNRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final auth = ref.watch(sessionProvider).valueOrNull;
    final controller = ref.read(sessionProvider.notifier);
    final phone = controller.currentPhone;
    final locked = auth is Locked ? auth : null;
    final account = locked == null || locked.expired
        ? null
        : biometricAccount('vendor', locked.profile.id);
    final canUseBiometric = account != null &&
        ref.watch(biometricEnabledProvider(account)).valueOrNull == true &&
        ref.watch(biometricAvailableProvider).valueOrNull == true;
    if (canUseBiometric && !locked!.pinRequested && !_prompted) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _biometric();
      });
    }
    final remembered = locked == null
        ? ref.watch(rememberedSignInProvider('vendor')).valueOrNull
        : null;
    final welcome =
        remembered != null && remembered.phone == phone ? remembered : null;
    final notice = locked?.expired == true
        ? MNNote(strings.errExpired)
        : _biometricNote == null
            ? null
            : MNNote(_biometricNote!);
    return AuthPage(
      showBack: locked == null,
      children: [
        PinEntry(
          // The reference's pad (30 October 2026): "Weka PIN" on every
          // PIN sign-in; the name stays on the "Karibu tena" screen.
          busy: _busy,
          title: strings.pinTitle,
          subtitle: strings.pinSubtitle,
          notice: notice,
          onBiometric: welcome != null
              ? _rememberedFingerprint
              : canUseBiometric
                  ? _biometric
                  : null,
          onComplete: (pin) async {
            if (phone == null) return strings.errUnknownPhone;
            try {
              await controller.signIn(phone, pin,
                  remember: ref.read(authFlowProvider).remember);
              return null;
            } on AuthFailure catch (failure) {
              if (failure.kind == AuthFailureKind.locked) rethrow;
              return failure.kind == AuthFailureKind.suspended
                  ? null
                  : strings.failure(failure);
            } on OfflineUnlockFailure catch (failure) {
              // The server could not be reached; the offline unlock answered.
              return switch (failure.refusal) {
                OfflineRefusal.wrongPin =>
                  strings.offlineWrongPin(failure.attemptsLeft ?? 0),
                OfflineRefusal.erased => strings.offlineErased,
                OfflineRefusal.expired => strings.offlineExpired,
                OfflineRefusal.noGrant => strings.errOffline,
              };
            }
          },
          footer: Column(mainAxisSize: MainAxisSize.min, children: [
            MNTextButton(strings.forgotPin,
                onPressed: () => context.push(MNRoutes.forgotPin)),
            if (welcome != null)
              MNTextButton(strings.notYou,
                  color: MNColors.ink, onPressed: _notYou),
          ]),
        ),
      ],
    );
  }
}

/// First activation (or PIN reset): the 6-digit code a supervisor issued.
class ActivationScreen extends ConsumerWidget {
  /// Length of staff-issued codes. To be confirmed with the backend.
  static const codeLength = 6;
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final controller = ref.read(sessionProvider.notifier);
    return AuthPage(children: [
      PinEntry(
        title: strings.activationTitle,
        subtitle: strings.activationHelp,
        length: codeLength,
        codeBoxes: true,
        onComplete: (code) async {
          final phone = controller.currentPhone;
          if (phone == null) return strings.errUnknownPhone;
          final flow = ref.read(authFlowProvider);
          try {
            final token =
                await controller.verifyCode(phone, code, reset: flow.reset);
            ref.read(authFlowProvider.notifier).state =
                flow.copyWith(setupToken: token);
            if (context.mounted) context.push(MNRoutes.createPin);
            return null;
          } on AuthFailure catch (failure) {
            return strings.failure(failure);
          }
        },
      ),
    ]);
  }
}

/// Chagua PIN mpya, then Rudia PIN. The first entry is held in memory only
/// until the second matches; a mismatch starts over.
class CreatePinScreen extends ConsumerWidget {
  final bool confirm;
  const CreatePinScreen({super.key, this.confirm = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final flowNotifier = ref.read(authFlowProvider.notifier);
    final mismatch = !confirm && ref.watch(authFlowProvider).mismatch;
    return AuthPage(children: [
      PinEntry(
        key: ValueKey(confirm),
        title: confirm ? strings.confirmPin : strings.createPin,
        notice: mismatch ? MNNote(strings.pinMismatch, error: true) : null,
        onComplete: (pin) async {
          final flow = ref.read(authFlowProvider);
          if (!confirm) {
            if (isWeakPin(pin)) return strings.pinWeak;
            flowNotifier.state = flow.copyWith(newPin: pin, mismatch: false);
            context.push(MNRoutes.confirmPin);
            return null;
          }
          if (pin != flow.newPin) {
            flowNotifier.state = flow.withoutPin(mismatch: true);
            if (context.mounted) context.pop();
            return null;
          }
          try {
            await ref
                .read(sessionProvider.notifier)
                .setPin(flow.setupToken ?? '', pin, remember: flow.remember);
            flowNotifier.state = const AuthFlow();
            return null;
          } on AuthFailure catch (failure) {
            return strings.failure(failure);
          }
        },
      ),
    ]);
  }
}

/// Umesahau PIN? Explains the reset and continues to the code screen.
class ForgotPinScreen extends ConsumerWidget {
  const ForgotPinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return AuthPage(children: [
      SizedBox(
        height: 320,
        child: MNEmptyState(
            icon: MNIconData.key,
            title: strings.forgotPinTitle,
            message: strings.forgotPinBody),
      ),
      MNButton(strings.haveCode, onPressed: () {
        ref.read(authFlowProvider.notifier).state = AuthFlow(
            reset: true, remember: ref.read(authFlowProvider).remember);
        context.push(MNRoutes.activate);
      }),
    ]);
  }
}

/// The server reports the account as suspended. Nothing else is reachable.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return AuthPage(showBack: false, children: [
      SizedBox(
        height: 360,
        child: MNEmptyState(
            icon: MNIconData.lock,
            circle: MNColors.errorSurface,
            iconColor: MNColors.error,
            title: strings.suspendedTitle,
            message: strings.suspendedBody),
      ),
      MNButton.secondary(strings.startOver,
          onPressed: () => ref.read(sessionProvider.notifier).signOut()),
    ]);
  }
}
