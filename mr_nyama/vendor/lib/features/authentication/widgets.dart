import 'dart:async';
import '../../core/api/vendor_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/logo.dart';
import '../../shared/widgets/pin.dart';

/// The approved photographic background: grilled chicken under a charcoal
/// overlay that darkens towards the bottom, where the form sits.
class PhotoBackdrop extends StatelessWidget {
  final Widget child;
  const PhotoBackdrop({super.key, required this.child});

  static const image = AssetImage('assets/images/grill.png');

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ColoredBox(
          color: MNColors.charcoal,
          child: Stack(fit: StackFit.expand, children: [
            const Image(
                image: image, fit: BoxFit.cover, excludeFromSemantics: true),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [MNColors.overlayTop, MNColors.overlayBottom],
                  stops: [0, .62],
                ),
              ),
            ),
            child,
          ]),
        ),
      );
}

/// The Tanzania flag beside the +255 prefix: green and blue triangles split
/// by a black band edged in yellow.
class TanzaniaFlag extends StatelessWidget {
  const TanzaniaFlag({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: const SizedBox(
            width: 28, height: 19, child: CustomPaint(painter: _FlagPainter())),
      );
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawPath(
        Path()..addPolygon([Offset.zero, Offset(w, 0), Offset(0, h)], true),
        Paint()..color = MNColors.flagGreen);
    canvas.drawPath(
        Path()..addPolygon([Offset(w, 0), Offset(w, h), Offset(0, h)], true),
        Paint()..color = MNColors.flagBlue);
    canvas.drawLine(
        Offset(0, h),
        Offset(w, 0),
        Paint()
          ..color = MNColors.flagYellow
          ..strokeWidth = h * .42);
    canvas.drawLine(
        Offset(0, h),
        Offset(w, 0),
        Paint()
          ..color = MNColors.flagBlack
          ..strokeWidth = h * .26);
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => false;
}

/// White page for the PIN and code screens: optional back button, the logo
/// on screens tall enough for it, and content that scrolls rather than
/// clipping on small phones or large text.
class AuthPage extends ConsumerWidget {
  final List<Widget> children;
  final bool showBack;
  final bool showLogo;
  final Widget? trailing;

  const AuthPage(
      {super.key,
      required this.children,
      this.showBack = true,
      this.showLogo = true,
      this.trailing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final router = GoRouter.of(context);
    final tall = MediaQuery.sizeOf(context).height >= 700;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: MNColors.pageBackground,
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: (showBack && router.canPop()) || trailing != null
                  ? MNSize.appBar
                  : MNSpace.x3,
              child: Row(children: [
                if (showBack && router.canPop())
                  Padding(
                    padding: const EdgeInsets.only(left: MNSpace.x1),
                    child: MNIconButton(MNIconData.back,
                        label: strings.back,
                        color: MNColors.ink,
                        onPressed: () => router.pop()),
                  ),
                const Spacer(),
                if (trailing != null) trailing!,
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    MNSpace.x6, 0, MNSpace.x6, MNSpace.x6),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(children: [
                      if (showLogo) ...[
                        MNLogo(
                            height: tall ? 80 : 56,
                            semanticLabel: strings.brand),
                        SizedBox(height: tall ? MNSpace.x3 : MNSpace.x2),
                      ],
                      ...children,
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A PIN (4 dots) or staff code (6 boxes) with the large keypad. When the
/// last digit is entered it calls [onComplete], which returns an error
/// message or null. While waiting, the keypad is disabled and a spinner
/// shows; on error the indicators turn red and shake, and the next key
/// starts over. Digits stay in this widget's memory only and are cleared
/// on every error and on dispose.
class PinEntry extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? notice;
  final int length;
  final bool codeBoxes;
  final Future<String?> Function(String value) onComplete;
  final Widget? footer;
  final VoidCallback? onBiometric;
  final bool busy;

  const PinEntry(
      {super.key,
      required this.title,
      this.subtitle,
      this.notice,
      this.length = 4,
      this.codeBoxes = false,
      required this.onComplete,
      this.footer,
      this.onBiometric,
      this.busy = false});

  @override
  ConsumerState<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends ConsumerState<PinEntry> {
  String _value = '';
  String? _error;
  bool _busy = false;
  AuthFailure? _lockout;
  Timer? _retryTimer;

  @override
  void dispose() {
    _value = '';
    _retryTimer?.cancel();
    super.dispose();
  }

  void _digit(int d) {
    if (_busy || widget.busy || _lockout != null) return;
    setState(() {
      if (_error != null) {
        _error = null;
        _value = '';
      }
      if (_value.length < widget.length) _value += '$d';
    });
    if (_value.length == widget.length) _submit();
  }

  void _backspace() {
    if (_busy || widget.busy || _lockout != null) return;
    setState(() {
      if (_error != null) {
        _error = null;
        _value = '';
      } else if (_value.isNotEmpty) {
        _value = _value.substring(0, _value.length - 1);
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || widget.busy || _lockout != null) return;
    setState(() => _busy = true);
    final value = _value;
    String? error;
    try {
      error = await widget.onComplete(value);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure.kind == AuthFailureKind.locked) {
        _lockout = failure;
        _retryTimer?.cancel();
        if (failure.retryAfter != null) {
          _retryTimer = Timer.periodic(MNMotion.retryCountdownTick, (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            setState(() {
              if (!DateTime.now().isBefore(failure.retryAfter!)) {
                _lockout = null;
                timer.cancel();
              }
            });
          });
        }
      }
      error = ref.read(stringsProvider).failure(failure);
    } catch (_) {
      error = ref.read(stringsProvider).errOffline;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      // Keep the indicators full while they show the error; the digits
      // themselves are no longer needed.
      _value = '';
    });
    if (error != null) HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final hasError = _error != null;
    // Too many tries: the pad stays, greyed, with the server's wait
    // counting down (owner-approved reference, 30 October 2026).
    final lockout = _lockout;
    final until = lockout?.retryAfter;
    final seconds = until?.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    final countdown = seconds == null
        ? null
        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final subtitleStyle =
        MNText.resolve(context, MNText.body).copyWith(color: MNColors.ink2);
    return Column(children: [
      Semantics(
        header: true,
        child: Text(lockout != null ? strings.pinWait : widget.title,
            textAlign: TextAlign.center,
            style:
                MNText.resolve(context, MNText.title).copyWith(fontSize: 22)),
      ),
      if (lockout != null) ...[
        const SizedBox(height: MNSpace.x2),
        Semantics(
          liveRegion: true,
          child: countdown == null
              ? Text(strings.errLocked(null),
                  textAlign: TextAlign.center, style: subtitleStyle)
              : Text.rich(
                  TextSpan(text: '${strings.pinRetryAfter} ', children: [
                    TextSpan(
                        text: countdown,
                        style: MNText.withWeight(
                            subtitleStyle.copyWith(color: MNColors.ink),
                            FontWeight.w700)),
                  ]),
                  textAlign: TextAlign.center,
                  style: subtitleStyle),
        ),
      ] else if (widget.subtitle != null) ...[
        const SizedBox(height: MNSpace.x2),
        Text(widget.subtitle!,
            textAlign: TextAlign.center, style: subtitleStyle),
      ],
      if (widget.notice != null && lockout == null) ...[
        const SizedBox(height: MNSpace.x4),
        widget.notice!,
      ],
      const SizedBox(height: MNSpace.x6),
      if (widget.codeBoxes)
        MNCodeBoxes(
            length: widget.length,
            value: hasError ? '' : _value,
            error: hasError)
      else
        MNPinDots(
            length: widget.length,
            filled: hasError ? 0 : _value.length,
            error: hasError),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Center(
          child: _busy || widget.busy
              ? Semantics(
                  label: strings.loading,
                  child: const MNSpinner(color: MNColors.ink))
              : hasError && lockout == null
                  ? Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: MNSpace.x2),
                        child: _ErrorLines(_error!),
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: MNPinKeypad(
            tiles: true,
            enabled: !_busy && !widget.busy && lockout == null,
            onDigit: _digit,
            onBackspace: _backspace,
            onBiometric: widget.onBiometric),
      ),
      if (lockout != null && widget.onBiometric != null) ...[
        const SizedBox(height: MNSpace.x4),
        Text(strings.biometricPaused,
            textAlign: TextAlign.center,
            style: MNText.resolve(context, MNText.meta)),
      ],
      if (widget.footer != null) ...[
        const SizedBox(height: MNSpace.x3),
        AbsorbPointer(absorbing: _busy || widget.busy, child: widget.footer!),
      ],
    ]);
  }
}

/// A PIN error under the dots: "PIN si sahihi." in red, and the tries left
/// (or any second sentence) in grey under it.
class _ErrorLines extends ConsumerWidget {
  final String message;
  const _ErrorLines(this.message);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrong = ref.watch(stringsProvider).pinWrong;
    final split = message.startsWith(wrong) && message.length > wrong.length;
    final first = split ? wrong : message;
    final rest = split ? message.substring(wrong.length).trim() : null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(first,
          textAlign: TextAlign.center,
          style: MNText.resolve(context, MNText.status)
              .copyWith(color: MNColors.error)),
      if (rest != null)
        Text(rest,
            textAlign: TextAlign.center,
            style: MNText.resolve(context, MNText.meta)),
    ]);
  }
}
