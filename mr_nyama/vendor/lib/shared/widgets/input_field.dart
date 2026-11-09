import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';
import 'icon.dart';

/// `.field` with `.flabel` above and `.ferr` below: 56 px, 1.5 px border,
/// 2 px ink border when focused, 2 px red border with a message on error.
///
/// Pass [focusNode] to move focus from outside (the caller owns and disposes
/// it); otherwise the field keeps its own.
class MNTextField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? error;
  final MNIconData? icon;
  final Widget? prefix;

  /// Shown after the text, inside the field (e.g. a contacts button).
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final Iterable<String>? autofillHints;

  const MNTextField(
      {super.key,
      required this.label,
      this.controller,
      this.hint,
      this.error,
      this.icon,
      this.prefix,
      this.suffix,
      this.keyboardType,
      this.inputFormatters,
      this.onChanged,
      this.onSubmitted,
      this.textInputAction,
      this.maxLines = 1,
      this.enabled = true,
      this.focusNode,
      this.autofocus = false,
      this.autofillHints});

  @override
  State<MNTextField> createState() => _MNTextFieldState();
}

class _MNTextFieldState extends State<MNTextField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant MNTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bad = widget.error != null;
    final focused = _focus.hasFocus;
    final borderColor = bad
        ? MNColors.error
        : focused
            ? MNColors.ink
            : MNText.isOffice(context)
                ? OwnerStyle.line
                : MNColors.borderStrong;
    final width = bad || focused
        ? MNSize.focusBorderWidth
        : MNText.isOffice(context)
            ? 1.0
            : MNSize.borderWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(widget.label,
                    style: MNText.resolve(context, MNText.label)),
              ),
              AnimatedContainer(
                duration: MNMotion.of(context, MNMotion.cardPress),
                constraints: const BoxConstraints(minHeight: MNSize.field),
                padding: EdgeInsets.symmetric(horizontal: 14 - (width - 1.5)),
                decoration: BoxDecoration(
                    color: widget.enabled ? MNColors.white : MNColors.disabled,
                    borderRadius: BorderRadius.circular(MNRadius.medium),
                    border: Border.all(color: borderColor, width: width)),
                child: Row(children: [
                  if (widget.icon != null) ...[
                    MNIcon(widget.icon!, color: MNColors.muted),
                    const SizedBox(width: 10),
                  ],
                  if (widget.prefix != null) ...[
                    widget.prefix!,
                    const SizedBox(width: 10)
                  ],
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      autofillHints: widget.autofillHints,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      textInputAction: widget.textInputAction,
                      maxLines: widget.maxLines,
                      minLines: 1,
                      style: MNText.resolve(context, MNText.input),
                      cursorColor: MNColors.ink,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: MNSpace.x4),
                        hintText: widget.hint,
                        hintStyle: MNText.resolve(context, MNText.body)
                            .copyWith(color: MNColors.muted),
                      ),
                    ),
                  ),
                  if (widget.suffix != null) widget.suffix!,
                ]),
              ),
            ],
          ),
        ),
        if (bad)
          Padding(
            padding: const EdgeInsets.only(top: MNSpace.x2),
            child: Semantics(
              liveRegion: true,
              child: Row(children: [
                const MNIcon(MNIconData.error,
                    size: MNSize.iconSmall, color: MNColors.error),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(widget.error!,
                        style: MNText.resolve(context, MNText.status)
                            .copyWith(color: MNColors.error))),
              ]),
            ),
          ),
      ],
    );
  }
}
