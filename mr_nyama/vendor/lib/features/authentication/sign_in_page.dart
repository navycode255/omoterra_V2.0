import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_flow.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/device_sign_in.dart';
import '../../core/l10n/language.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/filter_sheet.dart' show MNCheckMark;
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/logo.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/radio_mark.dart';
import '../../shared/widgets/sheet.dart';
import 'widgets.dart';

/// One row of the sign-in page's three-dot menu.
class SignInMenuItem {
  final MNIconData icon;
  final String label;
  final VoidCallback onTap;
  const SignInMenuItem(this.icon, this.label, this.onTap);
}

/// The sign-in page of the owner-approved reference (30 October 2026): the
/// three-dot menu top right, the logo, the heading and its line, the form,
/// and the language at the bottom. With the keyboard open only the heading
/// and the form stay.
class SignInPage extends ConsumerWidget {
  final String? title;
  final String? subtitle;
  final List<SignInMenuItem> menu;
  final List<Widget> children;
  const SignInPage(
      {super.key,
      this.title,
      this.subtitle,
      required this.menu,
      required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final router = GoRouter.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tall = MediaQuery.sizeOf(context).height >= 700;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: MNColors.pageBackground,
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: MNSize.appBar,
              child: Row(children: [
                if (router.canPop())
                  Padding(
                    padding: const EdgeInsets.only(left: MNSpace.x1),
                    child: MNIconButton(MNIconData.back,
                        label: s.back,
                        color: MNColors.ink,
                        onPressed: () => router.pop()),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: MNSpace.x3),
                  child: _MenuButton(menu: menu),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    MNSpace.x6, 0, MNSpace.x6, MNSpace.x6),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!keyboard) ...[
                            Center(
                                child: MNLogo(
                                    height: tall ? 150 : 104,
                                    semanticLabel: s.brand)),
                            const SizedBox(height: MNSpace.x2),
                          ] else
                            const SizedBox(height: MNSpace.x4),
                          if (title != null)
                            Semantics(
                                header: true,
                                child: Text(title!,
                                    textAlign: TextAlign.center,
                                    style: MNText.resolve(
                                        context, MNText.brandTitle))),
                          if (subtitle != null && !keyboard) ...[
                            const SizedBox(height: MNSpace.x2),
                            Text(subtitle!,
                                textAlign: TextAlign.center,
                                style: MNText.resolve(context, MNText.body)
                                    .copyWith(color: MNColors.muted)),
                          ],
                          SizedBox(
                              height: title == null
                                  ? MNSpace.x4
                                  : keyboard
                                      ? MNSpace.x6
                                      : MNSpace.x7),
                          ...children,
                        ]),
                  ),
                ),
              ),
            ),
            if (!keyboard)
              const Padding(
                padding:
                    EdgeInsets.fromLTRB(MNSpace.x5, 0, MNSpace.x5, MNSpace.x3),
                child: Align(
                    alignment: Alignment.centerLeft, child: _LanguageButton()),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The grey round "⋯" button; its sheet lists [menu].
class _MenuButton extends ConsumerWidget {
  final List<SignInMenuItem> menu;
  const _MenuButton({required this.menu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // A 36 px grey circle inside the 48 px tap target.
    return MNPressable(
      onTap: () => showMNSheet<void>(context,
          builder: (sheet) => MNSheet(children: [
                for (final item in menu)
                  _MenuRow(item: item, close: () => Navigator.pop(sheet)),
              ])),
      pressedScale: MNMotion.pressChip,
      semanticLabel: s.moreOptions,
      child: SizedBox(
        width: MNSize.minTouch,
        height: MNSize.minTouch,
        child: Center(
          child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: MNColors.referenceAvatar),
              // The reference's dots lie flat: ⋯.
              child: const Center(
                  child: RotatedBox(
                      quarterTurns: 1,
                      child: MNIcon(MNIconData.more,
                          size: 20, color: MNColors.ink)))),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final SignInMenuItem item;
  final VoidCallback close;
  const _MenuRow({required this.item, required this.close});

  @override
  Widget build(BuildContext context) => MNPressable(
        onTap: () {
          close();
          item.onTap();
        },
        color: MNColors.pageBackground,
        pressedColor: MNColors.surfacePressed,
        borderRadius: BorderRadius.circular(MNRadius.medium),
        semanticLabel: item.label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MNSize.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
            child: ExcludeSemantics(
              child: Row(children: [
                MNIcon(item.icon, color: MNColors.ink2),
                const SizedBox(width: MNSpace.x3),
                Expanded(
                    child: Text(item.label,
                        style: MNText.resolve(context, MNText.body))),
                const MNIcon(MNIconData.chevron,
                    size: 18, color: MNColors.muted),
              ]),
            ),
          ),
        ),
      );
}

/// "Kiswahili ⌄" at the bottom; opens "Chagua lugha".
class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final current = ref.watch(languageProvider);
    return MNPressable(
      onTap: () => _showLanguageChoice(context, ref),
      color: Colors.transparent,
      pressedColor: MNColors.textPressed,
      borderRadius: BorderRadius.circular(MNRadius.medium),
      semanticLabel: '${s.language}: ${s.languageName(current)}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MNSize.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MNSpace.x2),
          child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const MNIcon(MNIconData.accountGlobe,
                  size: 18, color: MNColors.ink2),
              const SizedBox(width: MNSpace.x2),
              Text(s.languageName(current),
                  style: MNText.resolve(context, MNText.meta)
                      .copyWith(color: MNColors.ink2)),
              const SizedBox(width: MNSpace.x1),
              const MNIcon(MNIconData.down, size: 16, color: MNColors.ink2),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Chagua lugha": the languages with radio marks, applied on "Imekamilika".
Future<void> _showLanguageChoice(BuildContext context, WidgetRef ref) {
  var picked = ref.read(languageProvider);
  return showMNSheet<void>(context,
      builder: (sheet) => StatefulBuilder(builder: (context, setState) {
            final s = ref.read(stringsProvider);
            return MNSheet(title: s.chooseLanguage, children: [
              Column(children: [
                for (final (i, code) in supportedLanguages.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: MNColors.border),
                  MNPressable(
                    onTap: () => setState(() => picked = code),
                    color: Colors.transparent,
                    pressedScale: 1,
                    selected: picked == code,
                    semanticLabel: s.languageName(code),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: MNSize.button),
                      child: ExcludeSemantics(
                        child: Row(children: [
                          Expanded(
                              child: Text(s.languageName(code),
                                  style: MNText.resolve(context, MNText.body))),
                          MNRadioMark(selected: picked == code),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
              MNButton(s.languageDone, onPressed: () async {
                Navigator.pop(sheet);
                await setLanguage(ref, picked);
              }),
            ]);
          }));
}

/// "Namba ya simu" over the white field: flag, +255, a divider, the number
/// grouped as 746 484 666, and a clear button once something is typed.
/// [error] outlines it red with the message below.
class PhoneNumberField extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  const PhoneNumberField(
      {super.key,
      required this.controller,
      required this.focusNode,
      required this.onChanged,
      required this.onSubmitted,
      this.error,
      this.enabled = true});

  /// Format example, not copy.
  static const _hint = 'XXX XXX XXX';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final input = MNText.resolve(context, MNText.input);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.phoneLabel,
          style: MNText.resolve(context, MNText.meta)
              .copyWith(color: MNColors.ink2)),
      const SizedBox(height: MNSpace.x2),
      Container(
        constraints: const BoxConstraints(minHeight: MNSize.field),
        padding: const EdgeInsets.only(left: MNSpace.x4),
        decoration: BoxDecoration(
            color: MNColors.white,
            borderRadius: BorderRadius.circular(MNRadius.medium),
            border: Border.all(
                color: error == null ? MNColors.white : MNColors.error,
                width: 1.5)),
        child: Row(children: [
          Semantics(
              label: '${s.phoneLabel}, ${s.countryCode}',
              child: const TanzaniaFlag()),
          const SizedBox(width: MNSpace.x3),
          ExcludeSemantics(child: Text(s.countryCode, style: input)),
          const SizedBox(width: MNSpace.x3),
          Container(width: 1, height: 24, color: MNColors.border),
          const SizedBox(width: MNSpace.x3),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [GroupedPhoneFormatter()],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: input,
              cursorColor: MNColors.ink,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: MNSpace.x4),
                hintText: _hint,
                hintStyle: input.copyWith(color: MNColors.disabledText),
              ),
            ),
          ),
          if (controller.text.isNotEmpty && enabled)
            MNPressable(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              pressedScale: MNMotion.pressChip,
              semanticLabel: s.clearPhone,
              child: SizedBox(
                width: MNSize.minTouch,
                height: MNSize.minTouch,
                child: Center(
                  child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: MNColors.referenceAvatar),
                      child: const Center(
                          child: MNIcon(MNIconData.x,
                              size: 14, color: MNColors.ink))),
                ),
              ),
            )
          else
            const SizedBox(width: MNSpace.x4),
        ]),
      ),
      if (error != null) ...[
        const SizedBox(height: MNSpace.x2),
        Text(error!,
            style: MNText.resolve(context, MNText.meta)
                .copyWith(color: MNColors.error)),
      ],
    ]);
  }

  /// What is wrong with [text], or null for a valid number: nine digits
  /// after +255 first, then a Tanzanian mobile number.
  static String? problem(Strings s, String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return s.phoneNineDigits;
    return normaliseTanzanianPhone(text) == null ? s.phoneInvalid : null;
  }
}

/// Digits only, nine after +255 grouped 3-3-3 ("746 484 666"). A leading 0
/// or a pasted 255 is dropped.
class GroupedPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('255') && digits.length > 9) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 9) digits = digits.substring(0, 9);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// "Kumbuka namba hii" under the phone field. Ticked, the number is kept on
/// this phone for next time and, where the phone can check a fingerprint,
/// the fingerprint signs in after the PIN (owner decision 30 October 2026).
class RememberNumberTick extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const RememberNumberTick(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Semantics(
      container: true,
      checked: value,
      label: s.rememberNumber,
      child: MNPressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        button: false,
        pressedScale: 1,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MNSize.minTouch),
            child: Row(children: [
              MNCheckMark(selected: value, color: MNColors.ink),
              const SizedBox(width: MNSpace.x3),
              Expanded(
                  child: Text(s.rememberNumber,
                      style: MNText.resolve(context, MNText.meta)
                          .copyWith(color: MNColors.ink))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Help behind "Msaada" in the three-dot menu.
void showSignInHelp(BuildContext context, String title, List<String> lines) =>
    showMNSheet<void>(context,
        builder: (_) => MNSheet(title: title, children: [
              for (final line in lines)
                Text(line, style: MNText.resolve(context, MNText.body)),
            ]));

/// The phone form of the reference states: Endelea stays disabled until
/// nine digits are typed; leaving the field with a wrong number outlines it
/// red with the reason; while the server answers, the field, the tick and
/// the button wait. [start] asks the server and opens the next screen, and
/// returns the error to show, if any; its `remember` is true only where the
/// phone can check a fingerprint.
class PhoneSignInForm extends ConsumerStatefulWidget {
  final String side;
  final Future<String?> Function(String phone, {required bool remember}) start;

  /// Starts with the number "Kumbuka namba hii" kept (not after "Si wewe?").
  final bool prefill;

  /// A note above the field, such as an ended fingerprint sign-in.
  final Widget? notice;
  const PhoneSignInForm(
      {super.key,
      required this.side,
      required this.start,
      this.prefill = true,
      this.notice});
  @override
  ConsumerState<PhoneSignInForm> createState() => _PhoneSignInFormState();
}

class _PhoneSignInFormState extends ConsumerState<PhoneSignInForm> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false, _remember = false;
  String? _fieldError, _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_blurred);
    if (widget.prefill) _restore();
  }

  Future<void> _restore() async {
    final kept =
        await ref.read(deviceSignInStoreProvider).rememberedNumber(widget.side);
    if (!mounted || kept == null || _controller.text.isNotEmpty) return;
    final local = kept.replaceFirst('+255', '');
    setState(() {
      _controller.text = GroupedPhoneFormatter()
          .formatEditUpdate(
              TextEditingValue.empty, TextEditingValue(text: local))
          .text;
      _remember = true;
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_blurred);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Validation after blur: only once something was typed.
  void _blurred() {
    if (_focus.hasFocus || _controller.text.isEmpty || !mounted) return;
    setState(() => _fieldError =
        PhoneNumberField.problem(ref.read(stringsProvider), _controller.text));
  }

  bool get _valid =>
      PhoneNumberField.problem(ref.read(stringsProvider), _controller.text) ==
      null;

  Future<void> _continue() async {
    if (_busy) return;
    final problem =
        PhoneNumberField.problem(ref.read(stringsProvider), _controller.text);
    if (problem != null) {
      setState(() => _fieldError = problem);
      return;
    }
    final phone = normaliseTanzanianPhone(_controller.text)!;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final remember = _remember;
    final fingerprint = remember &&
        await ref
            .read(biometricAvailableProvider.future)
            .catchError((_) => false);
    final error = await widget.start(phone, remember: fingerprint);
    if (error == null) {
      await ref
          .read(deviceSignInStoreProvider)
          .keepNumber(widget.side, remember ? phone : null);
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.notice != null) ...[
        widget.notice!,
        const SizedBox(height: MNSpace.x4),
      ],
      PhoneNumberField(
        controller: _controller,
        focusNode: _focus,
        enabled: !_busy,
        error: _fieldError,
        onChanged: (_) => setState(() {
          _fieldError = null;
          _error = null;
        }),
        onSubmitted: (_) => _continue(),
      ),
      const SizedBox(height: MNSpace.x2),
      RememberNumberTick(
          value: _remember,
          onChanged: _busy ? null : (v) => setState(() => _remember = v)),
      if (_error != null) ...[
        const SizedBox(height: MNSpace.x2),
        MNNote(_error!, error: true),
      ],
      const SizedBox(height: MNSpace.x4),
      // Sending: the red fades while the spinner turns (reference state 4).
      AnimatedOpacity(
        opacity: _busy ? .7 : 1,
        duration: MNMotion.of(context, MNMotion.small),
        child: MNButton(s.continueLabel,
            busy: _busy, onPressed: _busy || !_valid ? null : _continue),
      ),
    ]);
  }
}
