import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/device_sign_in.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/pressable.dart';

/// The phone's fingerprint check, then [signIn] exchanges the saved key with
/// the server (MN024). Returns what to tell the user, or null once signed in.
/// A key the server ended is forgotten by [signIn]; the PIN is asked next.
Future<String?> fingerprintSignIn(
    WidgetRef ref, Future<void> Function() signIn) async {
  final s = ref.read(stringsProvider);
  try {
    if (!await authenticateBiometric(ref, s.biometricReason)) {
      return s.biometricFailed;
    }
    await signIn();
    return null;
  } on AuthFailure catch (failure) {
    return switch (failure.kind) {
      AuthFailureKind.offline => s.failure(failure),
      AuthFailureKind.suspended => s.failure(failure),
      _ => s.fingerprintKeyEnded,
    };
  } catch (_) {
    return s.biometricFailed;
  }
}

/// A remembered phone's sign-in (owner decision 30 October 2026, "like a bank
/// app"): "Karibu tena", the fingerprint asked for once by itself, "Tumia
/// PIN" for the PIN pad with the phone already known, and "Si wewe?" for the
/// phone form. [onEnded] gets the note when the server ended the key, as
/// this view then gives way to the phone form.
class RememberedSignIn extends ConsumerStatefulWidget {
  final SavedDeviceSignIn saved;
  final Future<void> Function() signIn;
  final Future<String?> Function() usePin;
  final VoidCallback notYou;
  final ValueChanged<String> onEnded;
  const RememberedSignIn(
      {super.key,
      required this.saved,
      required this.signIn,
      required this.usePin,
      required this.notYou,
      required this.onEnded});
  @override
  ConsumerState<RememberedSignIn> createState() => _RememberedSignInState();
}

class _RememberedSignInState extends ConsumerState<RememberedSignIn> {
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fingerprint();
    });
  }

  Future<void> _fingerprint() async {
    if (_busy) return;
    final ended = ref.read(stringsProvider).fingerprintKeyEnded;
    setState(() {
      _busy = true;
      _note = null;
    });
    final note = await fingerprintSignIn(ref, widget.signIn);
    if (!mounted) return;
    if (note == ended) widget.onEnded(note!);
    setState(() {
      _busy = false;
      _note = note;
    });
  }

  Future<void> _usePin() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final note = await widget.usePin();
    if (mounted) {
      setState(() {
        _busy = false;
        _note = note;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final saved = widget.saved;
    // First name only, so the greeting stays on one line.
    final first = saved.name.trim().split(RegExp(r'\s+')).first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
          header: true,
          child: Text(
              first.isEmpty ? s.fingerprintSignIn : s.welcomeBack(first),
              textAlign: TextAlign.center,
              style: MNText.resolve(context, MNText.heading))),
      if (saved.phone.isNotEmpty) ...[
        const SizedBox(height: MNSpace.x1),
        Text(displayPhone(saved.phone),
            textAlign: TextAlign.center,
            style: MNText.resolve(context, MNText.body)
                .copyWith(color: MNColors.muted)),
      ],
      const SizedBox(height: MNSpace.x6),
      // The circle is the fingerprint button (the prompt also opens by
      // itself); it darkens and shrinks while pressed.
      Center(
        child: MNPressable(
          onTap: _busy ? null : _fingerprint,
          color: MNColors.referenceAvatar,
          pressedColor: MNColors.borderStrong,
          pressedScale: MNMotion.pressKey,
          borderRadius: BorderRadius.circular(48),
          semanticLabel: s.fingerprintSignIn,
          child: const SizedBox(
              width: 96,
              height: 96,
              child: Icon(Icons.fingerprint, size: 48, color: MNColors.ink2)),
        ),
      ),
      const SizedBox(height: MNSpace.x2),
      ExcludeSemantics(
        child: GestureDetector(
          onTap: _busy ? null : _fingerprint,
          child: Text(s.fingerprintTapHint,
              textAlign: TextAlign.center,
              style: MNText.resolve(context, MNText.meta)),
        ),
      ),
      // Only after a failed or cancelled attempt, in the quiet grey style.
      if (_note != null) ...[
        const SizedBox(height: MNSpace.x4),
        Semantics(
          liveRegion: true,
          child: Text(_note!,
              textAlign: TextAlign.center,
              style: MNText.resolve(context, MNText.body)
                  .copyWith(color: MNColors.ink2)),
        ),
      ],
      const SizedBox(height: MNSpace.x6),
      // The one action button: the PIN.
      MNButton(s.biometricUsePin,
          busy: _busy, onPressed: _busy ? null : _usePin),
      const SizedBox(height: MNSpace.x2),
      MNTextButton(s.notYou,
          color: MNColors.ink2, onPressed: _busy ? null : widget.notYou),
    ]);
  }
}
