import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/logo.dart';
import '../../shared/widgets/pin.dart';
import '../../shared/widgets/sheet.dart';
import '../office/owner_reference.dart';

enum _Step { current, choose, confirm }

/// Badilisha PIN, to the owner-approved reference (30 October 2026): current
/// PIN, new PIN, new PIN again, then too many tries greys the pad until the
/// server's wait ends. The entries stay in this screen's memory and are sent
/// together in one request, so the server answers for the current PIN only
/// at the end; a wrong one returns to the first step. With [office] it
/// changes the signed-in office (staff) account's PIN instead.
class ChangePinScreen extends ConsumerStatefulWidget {
  final bool office;
  const ChangePinScreen({super.key, this.office = false});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  static const _length = 4;

  var _step = _Step.current;
  var _value = '';
  String? _current;
  String? _new;
  String? _error;
  bool _busy = false;
  AuthFailure? _lockout;
  Timer? _retryTimer;

  @override
  void dispose() {
    _value = '';
    _current = null;
    _new = null;
    _retryTimer?.cancel();
    super.dispose();
  }

  void _digit(int d) {
    if (_busy || _lockout != null) return;
    setState(() {
      _error = null;
      if (_value.length < _length) _value += '$d';
    });
    if (_value.length == _length) _submit(_value);
  }

  void _backspace() {
    if (_busy || _lockout != null || _value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  void _back() {
    if (_busy) return;
    if (_lockout != null || _step == _Step.current) {
      context.pop();
      return;
    }
    setState(() {
      _value = '';
      _error = null;
      if (_step == _Step.confirm) {
        _new = null;
        _step = _Step.choose;
      } else {
        _current = null;
        _step = _Step.current;
      }
    });
  }

  void _fail(String error, {_Step? step}) {
    HapticFeedback.heavyImpact();
    setState(() {
      _value = '';
      _error = error;
      if (step != null) _step = step;
    });
  }

  void _lock(AuthFailure failure) {
    HapticFeedback.heavyImpact();
    _retryTimer?.cancel();
    final until = failure.retryAfter;
    if (until != null) {
      _retryTimer = Timer.periodic(MNMotion.retryCountdownTick, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (!DateTime.now().isBefore(until)) {
            _lockout = null;
            timer.cancel();
          }
        });
      });
    }
    setState(() {
      _lockout = failure;
      _value = '';
      _error = null;
      _current = null;
      _new = null;
      _step = _Step.current;
    });
  }

  Future<void> _submit(String pin) async {
    final strings = ref.read(stringsProvider);
    switch (_step) {
      case _Step.current:
        setState(() {
          _current = pin;
          _value = '';
          _step = _Step.choose;
        });
      case _Step.choose:
        if (isWeakPin(pin)) return _fail(strings.pinWeak);
        setState(() {
          _new = pin;
          _value = '';
          _step = _Step.confirm;
        });
      case _Step.confirm:
        if (pin != _new) return _fail(strings.changePinMismatch);
        setState(() => _busy = true);
        try {
          if (widget.office) {
            await ref
                .read(officeSessionProvider.notifier)
                .guard((r) => r.changePin(currentPin: _current!, newPin: pin));
          } else {
            await ref.read(sessionProvider.notifier).changePin(_current!, pin);
          }
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(strings.pinChanged)));
            context.pop();
          }
        } on AuthFailure catch (failure) {
          if (!mounted) return;
          setState(() => _busy = false);
          switch (failure.kind) {
            case AuthFailureKind.locked:
              _lock(failure);
            case AuthFailureKind.wrongPin:
              _current = null;
              _new = null;
              _fail(strings.changePinWrong, step: _Step.current);
            case AuthFailureKind.weakPin:
              _new = null;
              _fail(strings.pinWeak, step: _Step.choose);
            default:
              _fail(strings.failure(failure));
          }
        } catch (_) {
          if (!mounted) return;
          setState(() => _busy = false);
          _fail(strings.errOffline);
        }
    }
  }

  Future<void> _forgot() async {
    final s = ref.read(stringsProvider);
    await showMNSheet<void>(context,
        builder: (_) => MNSheet(title: s.forgotPinTitle, children: [
              Text(widget.office ? s.officeForgotBody : s.forgotPinBody,
                  style: _style(context, 15, color: OwnerStyle.pinSubtitle)),
            ]));
  }

  /// Inter through `OwnerStyle` in office mode, Manrope in the vendor app.
  TextStyle _style(BuildContext context, double size,
      {double weight = 400,
      Color color = OwnerStyle.pinTitle,
      double height = 1.2}) {
    final style = MNText.withWeight(
        MNText.title.copyWith(fontSize: size, color: color, height: height),
        FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)]);
    return widget.office
        ? style.copyWith(
            fontFamily: OwnerStyle.fontFamily(Theme.of(context).platform, size),
            letterSpacing: -.2)
        : style;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lockout = _lockout;
    final until = lockout?.retryAfter;
    final seconds = until?.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    final countdown = seconds == null
        ? null
        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final title = lockout != null
        ? s.pinWait
        : switch (_step) {
            _Step.current => s.changePinCurrent,
            _Step.choose => s.changePinNew,
            _Step.confirm => s.changePinConfirm,
          };
    final subtitle =
        lockout != null ? s.changePinLocked : s.changePinStep(_step.index + 1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: MNColors.pageBackground,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            // Every height is the reference's at its 786 pt tall safe area,
            // tightened on shorter phones; large text may still scroll.
            final k = (box.maxHeight / 786).clamp(.62, 1.0);
            double v(double n) => n * k;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Stack(children: [
                  Positioned(
                    top: v(23),
                    left: 8,
                    child: OwnerIconButton('back-bold',
                        size: 26, label: s.back, onTap: _back),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(height: v(60)),
                          MNLogo(
                              height: v(110),
                              full: true,
                              semanticLabel: s.brand),
                          SizedBox(height: v(25)),
                          Semantics(
                            header: true,
                            child: Text(title,
                                textAlign: TextAlign.center,
                                style: _style(context, 25, weight: 700)),
                          ),
                          SizedBox(height: v(11)),
                          Semantics(
                            liveRegion: lockout != null,
                            child: Text(subtitle,
                                textAlign: TextAlign.center,
                                style: _style(context, 15,
                                    color: OwnerStyle.pinSubtitle)),
                          ),
                          SizedBox(height: v(51)),
                          MNPinDots(
                              length: _length,
                              filled: _value.length,
                              error: _error != null,
                              gap: 26,
                              emptyScale: 1,
                              emptyBorder: OwnerStyle.pinDot),
                          SizedBox(height: v(12)),
                          SizedBox(
                            height: v(40),
                            child: Center(
                              child: _busy
                                  ? Semantics(
                                      label: s.loading,
                                      child: const MNSpinner(
                                          color: OwnerStyle.pinTitle))
                                  : lockout != null
                                      ? Text(s.changePinPaused,
                                          textAlign: TextAlign.center,
                                          style: _style(context, 13,
                                              color: OwnerStyle.pinSubtitle))
                                      : _error != null
                                          ? Semantics(
                                              liveRegion: true,
                                              child: Text(_error!,
                                                  textAlign: TextAlign.center,
                                                  style: _style(context, 14,
                                                      weight: 600,
                                                      color: MNColors.red)))
                                          : null,
                            ),
                          ),
                          SizedBox(height: v(28)),
                          MNPinKeypad(
                              tiles: true,
                              tileHeight: (v(70)).clamp(48.0, 70.0),
                              tileGap: v(10),
                              tileRadius: 15,
                              digitStyle: _style(context, 28, weight: 600),
                              backspaceSize: 34,
                              disabledKey: OwnerStyle.pinLockedKey,
                              disabledGlyph: OwnerStyle.pinLockedDigit,
                              enabled: !_busy && lockout == null,
                              onDigit: _digit,
                              onBackspace: _backspace),
                          SizedBox(height: v(31)),
                          SizedBox(
                            height: 48,
                            child: Center(
                              child: lockout != null
                                  ? Semantics(
                                      liveRegion: true,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Text(
                                            countdown == null
                                                ? s.errLocked(null)
                                                : '${s.pinRetryAfter} $countdown',
                                            textAlign: TextAlign.center,
                                            style: _style(context, 14,
                                                weight: 500,
                                                color: OwnerStyle.pinLink)),
                                      ),
                                    )
                                  : _step == _Step.current
                                      ? _ForgotLink(
                                          label: s.forgotPin,
                                          style: _style(context, 14,
                                              weight: 500,
                                              color: OwnerStyle.pinLink),
                                          onTap: _busy ? null : _forgot)
                                      : null,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// The reference's grey link, ruled off with a line under it.
class _ForgotLink extends StatelessWidget {
  final String label;
  final TextStyle style;
  final VoidCallback? onTap;
  const _ForgotLink(
      {required this.label, required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: OwnerStyle.pinDot, width: 1))),
                child: Text(label, style: style),
              ),
            ),
          ),
        ),
      );
}
