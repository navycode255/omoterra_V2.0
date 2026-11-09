import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/biometrics.dart';
import '../../core/auth/device_sign_in.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/routing/router.dart';
import '../../core/routing/routes.dart';
import 'logo.dart';
import 'icon.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'account.dart';
import 'buttons.dart';
import 'note.dart';

/// Account-scoped, opt-in lock. The routed subtree is retained but neither
/// painted nor exposed to accessibility while locked (including dialogs).
/// Once open it stays open until [biometricIdleLock] passes with no touch or
/// away from the app, so leaving briefly to choose a photo needs no unlock.
class BiometricLock extends ConsumerStatefulWidget {
  final Widget child;
  const BiometricLock({super.key, required this.child});
  @override
  ConsumerState<BiometricLock> createState() => _BiometricLockState();
}

class _BiometricLockState extends ConsumerState<BiometricLock>
    with WidgetsBindingObserver {
  String? _account;
  String? _pendingUnlockAccount;
  int? _pendingUnlockEpoch;
  bool _unlocked = false, _busy = false, _failed = false;
  AppLifecycleState? _lifecycle;
  DateTime? _leftAt;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    super.dispose();
  }

  /// Open for this account (a preference that is off shows no lock at all).
  bool get _open =>
      _account != null &&
      (_unlocked || ref.read(biometricUnlockedAccountProvider) == _account);

  void _lock() {
    _idle?.cancel();
    _idle = null;
    _leftAt = null;
    ref.read(biometricLockEpochProvider.notifier).state++;
    ref.read(biometricUnlockedAccountProvider.notifier).state = null;
    setState(() {
      _unlocked = false;
      _pendingUnlockAccount = null;
      _pendingUnlockEpoch = null;
    });
  }

  /// Every touch starts the wait again.
  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(biometricIdleLock, () {
      _idle = null;
      // In the background the time away decides, on return.
      if (mounted &&
          _leftAt == null &&
          _open &&
          (_lifecycle == null || _lifecycle == AppLifecycleState.resumed)) {
        _lock();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    // Android/iOS may deliver the prompt result before the resumed event.
    // Keep that result private until resumed; backgrounding invalidates it.
    if (state == AppLifecycleState.resumed && _pendingUnlockAccount != null) {
      setState(() {
        _unlocked = _pendingUnlockAccount == _account &&
            _pendingUnlockEpoch == ref.read(biometricLockEpochProvider);
        _failed = !_unlocked;
        _pendingUnlockAccount = null;
        _pendingUnlockEpoch = null;
      });
    }
    final leaving = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state != AppLifecycleState.resumed &&
            !ref.read(biometricPromptActiveProvider));
    if (leaving) {
      if (_open) {
        _leftAt ??= ref.read(clockProvider)();
      } else {
        // Still locked: a prompt in progress does not survive leaving.
        _lock();
      }
    } else if (state == AppLifecycleState.resumed) {
      final leftAt = _leftAt;
      _leftAt = null;
      if (leftAt != null && _open) {
        final away = ref.read(clockProvider)().difference(leftAt);
        if (away >= biometricIdleLock) {
          _lock();
        } else {
          _restartIdle();
        }
      }
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    final account = _account;
    final epoch = ref.read(biometricLockEpochProvider);
    setState(() {
      _busy = true;
      _failed = false;
      _pendingUnlockAccount = null;
      _pendingUnlockEpoch = null;
    });
    var ok = false;
    try {
      ok = await authenticateBiometric(
          ref, ref.read(stringsProvider).biometricReason);
    } catch (_) {
      // Plugin and secure-storage failures never unlock the app.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      final valid = ok &&
          account != null &&
          account == _account &&
          epoch == ref.read(biometricLockEpochProvider);
      _unlocked = valid &&
          (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);
      if (valid && _lifecycle == AppLifecycleState.inactive) {
        _pendingUnlockAccount = account;
        _pendingUnlockEpoch = epoch;
      }
      _failed = !_unlocked && _pendingUnlockAccount == null;
    });
  }

  Future<void> _usePin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final office = ref.read(officeSessionProvider).valueOrNull;
      if (office is OfficeSignedIn && !office.viaLead) {
        await ref.read(officeSessionProvider.notifier).lockForPin();
        if (mounted) ref.read(routerProvider).go(MNRoutes.officePin);
      } else {
        await ref.read(sessionProvider.notifier).lockForPin();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final office = ref.watch(officeSessionProvider).valueOrNull;
    final vendor = ref.watch(sessionProvider).valueOrNull;
    final account = office is OfficeSignedIn && !office.viaLead
        ? biometricAccount('staff', office.profile.id)
        : vendor is SignedIn
            ? biometricAccount('vendor', vendor.profile.id)
            : null;
    if (_account != account) {
      _account = account;
      _pendingUnlockAccount = null;
      _pendingUnlockEpoch = null;
      _unlocked = false;
      _failed = false;
    }
    final preference =
        account == null ? null : ref.watch(biometricEnabledProvider(account));
    // Loading/error is fail-closed; absent preference is opt-out.
    final locked = account != null &&
        (preference?.valueOrNull != false) &&
        !_unlocked &&
        ref.watch(biometricUnlockedAccountProvider) != account;
    // The wait runs only while a lock would take effect.
    final guarded = !locked && preference?.valueOrNull == true;
    if (!guarded) {
      _idle?.cancel();
      _idle = null;
    } else if (_idle == null && _leftAt == null) {
      _restartIdle();
    }
    final s = ref.watch(stringsProvider);
    final tall = MediaQuery.sizeOf(context).height >= 700;
    return Stack(fit: StackFit.expand, children: [
      Offstage(
          offstage: locked,
          child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: guarded ? (_) => _restartIdle() : null,
              child: widget.child)),
      if (locked)
        PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: MNColors.pageBackground,
              body: SafeArea(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            // The owner-approved lock (30 October 2026): the big
                            // logo, "Imefungwa" or "Haikuweza kufunguka", the
                            // biometric button and "Tumia PIN".
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MNLogo(
                                      height: tall ? 260 : 140,
                                      semanticLabel: s.brand),
                                  const SizedBox(height: 20),
                                  Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _failed
                                              ? MNColors.errorSurface
                                              : MNColors.referenceAvatar),
                                      child: Center(
                                          child: _busy
                                              ? const Icon(Icons.fingerprint,
                                                  size: 34,
                                                  color: MNColors.ink2)
                                              : _failed
                                                  ? Text('!',
                                                      style: accountText(
                                                          context, 34,
                                                          weight: 800,
                                                          color:
                                                              MNColors.error))
                                                  : const MNIcon(
                                                      MNIconData.lock,
                                                      size: 30,
                                                      color: MNColors.ink2))),
                                  const SizedBox(height: 16),
                                  Text(
                                      _failed
                                          ? s.lockFailedTitle
                                          : s.biometricLocked,
                                      textAlign: TextAlign.center,
                                      style: accountText(context, 24,
                                          weight: 700)),
                                  const SizedBox(height: 6),
                                  Text(
                                      _failed
                                          ? s.biometricFailed
                                          : s.lockSecurity,
                                      textAlign: TextAlign.center,
                                      style: accountText(context, 15,
                                          color: MNColors.referenceMuted)),
                                  const SizedBox(height: 24),
                                  MNButton(
                                      _failed
                                          ? s.lockTryAgain
                                          : s.biometricUnlock,
                                      busy: _busy,
                                      onPressed: _busy ? null : _unlock),
                                  const SizedBox(height: 12),
                                  MNTextButton(s.biometricUsePin,
                                      onPressed: _busy ? null : _usePin),
                                ])),
                      ))),
            )),
    ]);
  }
}

/// Settings stay within the existing account groups in both modes.
class BiometricSetting extends ConsumerStatefulWidget {
  final String account;
  const BiometricSetting({super.key, required this.account});
  @override
  ConsumerState<BiometricSetting> createState() => _BiometricSettingState();
}

class _BiometricSettingState extends ConsumerState<BiometricSetting> {
  bool _busy = false, _retried = false;
  String? _error;

  /// Whether this account is the office side (else the vendor side).
  bool get _isOffice {
    final office = ref.read(officeSessionProvider).valueOrNull;
    return office is OfficeSignedIn &&
        !office.viaLead &&
        biometricAccount('staff', office.profile.id) == widget.account;
  }

  Future<void> _rememberDevice() => _isOffice
      ? ref.read(officeSessionProvider.notifier).rememberDevice()
      : ref.read(sessionProvider.notifier).rememberDevice();

  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    final account = widget.account;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pinVerified = ref.read(biometricUnlockedAccountProvider) == account;
      if (!(enabled && pinVerified) &&
          !await ref.read(biometricAuthenticatorProvider).available()) {
        if (mounted) setState(() => _error = s.biometricUnavailable);
        return;
      }
      if (!(enabled && pinVerified) &&
          !await authenticateBiometric(ref, s.biometricReason)) {
        if (mounted) setState(() => _error = s.biometricFailed);
        return;
      }
      if (!mounted || account != widget.account) return;
      final preferences = ref.read(biometricPreferencesProvider);
      if (enabled) {
        await preferences.clear(account);
        _isOffice
            ? await ref.read(officeSessionProvider.notifier).forgetDevice()
            : await ref.read(sessionProvider.notifier).forgetDevice();
      } else {
        await preferences.enable(account);
        ref.read(biometricUnlockedAccountProvider.notifier).state = account;
        // A sign-in key, so the fingerprint also signs in after sign-out.
        await _rememberDevice();
      }
      ref.invalidate(biometricEnabledProvider(account));
    } catch (_) {
      if (mounted) setState(() => _error = s.biometricFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final state = ref.watch(biometricEnabledProvider(widget.account));
    final enabled = state.valueOrNull == true;
    // On, but this phone has no sign-in key (the server could not give one):
    // say so truthfully, and ask the server again once per visit.
    final saved =
        ref.watch(savedDeviceSignInProvider(_isOffice ? 'staff' : 'vendor'));
    final keyMissing = enabled &&
        !_busy &&
        saved.hasValue &&
        saved.valueOrNull?.account != widget.account;
    if (keyMissing && !_retried) {
      _retried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rememberDevice();
      });
    }
    return Column(children: [
      MNAccountRow(
          title: s.biometricTitle,
          value: enabled ? s.biometricOn : s.biometricOff,
          icon: MNIconData.lock,
          onTap: () {
            if (!_busy && !state.isLoading) _toggle(enabled);
          }),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.all(16),
            child: MNNote(_error!, error: true))
      else if (keyMissing)
        Padding(
            padding: const EdgeInsets.all(16),
            child: MNNote(s.fingerprintSignInPending)),
    ]);
  }
}
