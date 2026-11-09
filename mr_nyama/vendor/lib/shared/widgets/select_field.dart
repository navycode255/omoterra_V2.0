import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'note.dart';
import 'pressable.dart';
import 'product_card.dart';
import 'radio_mark.dart';
import 'rows.dart';
import 'sheet.dart';

/// One choice in an [MNSelectField] sheet. [image] shows a product thumb;
/// a disabled option stays visible with its [caption] explaining why.
class MNSelectOption<T> {
  final T value;
  final String label;
  final String? caption;
  final ImageProvider? image;
  final bool enabled;

  /// Red label for an action row such as "+ new category".
  final bool action;

  const MNSelectOption(
      {required this.value,
      required this.label,
      this.caption,
      this.image,
      this.enabled = true,
      this.action = false});
}

/// The `.field` frame (label above, 56 px, 1.5 px border, 12 px radius) as a
/// button: shows [text] or a muted [placeholder] and a trailing [icon].
/// [onTap] null is the disabled style.
class MNFieldButton extends StatelessWidget {
  final String label;
  final String? text;
  final String placeholder;
  final MNIconData icon;
  final ImageProvider? image;
  final VoidCallback? onTap;

  const MNFieldButton(
      {super.key,
      required this.label,
      required this.text,
      required this.placeholder,
      required this.onTap,
      this.icon = MNIconData.down,
      this.image});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fill = enabled ? MNColors.white : MNColors.disabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: MNText.resolve(context, MNText.label)),
          ),
        ),
        MNPressable(
          onTap: onTap,
          pressedScale: 1,
          colorDuration: MNMotion.instant,
          color: fill,
          pressedColor: MNColors.surface,
          borderRadius: BorderRadius.circular(MNRadius.medium),
          border: Border.all(
              color: MNText.isOffice(context)
                  ? OwnerStyle.line
                  : MNColors.borderStrong,
              width: MNText.isOffice(context) ? 1 : MNSize.borderWidth),
          semanticLabel: '$label, ${text ?? placeholder}',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MNSize.field - 3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.5),
              child: Row(children: [
                if (image != null) ...[
                  MNProductImage.thumb(image: image, size: 32),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: MNSpace.x3),
                    child: Text(text ?? placeholder,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text == null
                            ? MNText.resolve(context, MNText.body)
                                .copyWith(color: MNColors.muted)
                            : MNText.resolve(context, MNText.input).copyWith(
                                color: enabled
                                    ? MNColors.ink
                                    : MNColors.disabledText)),
                  ),
                ),
                const SizedBox(width: MNSpace.x2),
                MNIcon(icon,
                    color: enabled ? MNColors.ink2 : MNColors.disabledText),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// A Mr. Nyama choice field: the field frame opens a sheet of rows with a
/// radio mark (no platform dropdown menu). [onChanged] null disables it.
class MNSelectField<T> extends ConsumerWidget {
  final String label;
  final T? value;
  final List<MNSelectOption<T>> options;

  /// Reads options that may arrive while the choice sheet is already open.
  final List<MNSelectOption<T>> Function(WidgetRef ref)? watchOptions;
  final ValueChanged<T>? onChanged;

  /// Shown in the sheet when [options] is empty.
  final String? emptyText;

  const MNSelectField(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.onChanged,
      this.watchOptions,
      this.emptyText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final currentOptions = watchOptions?.call(ref) ?? options;
    final selected = currentOptions.where((o) => o.value == value).firstOrNull;
    return MNFieldButton(
      label: label,
      text: selected?.label,
      image: selected?.image,
      placeholder: strings.selectPlaceholder,
      onTap: onChanged == null
          ? null
          : () async {
              final picked = await showMNSelectSheet<T>(context,
                  title: label,
                  options: currentOptions,
                  watchOptions: watchOptions,
                  selected: value,
                  emptyText: emptyText ?? strings.nothingToChoose);
              if (picked != null) onChanged!(picked.value);
            },
    );
  }
}

/// Opens the choice sheet. Returns the picked option (wrapped so a null
/// value can still be a choice), or null when dismissed.
Future<({T value})?> showMNSelectSheet<T>(BuildContext context,
        {required String title,
        required List<MNSelectOption<T>> options,
        List<MNSelectOption<T>> Function(WidgetRef ref)? watchOptions,
        T? selected,
        required String emptyText}) =>
    showMNSheet<({T value})>(context,
        builder: (sheet) => Consumer(builder: (_, ref, __) {
              final current = watchOptions?.call(ref) ?? options;
              return MNSheet(title: title, children: [
                if (current.isEmpty)
                  MNNote(emptyText, tone: MNNoteTone.info)
                else
                  MNSelectList<T>(
                      options: current,
                      selected: selected,
                      onPick: (o) => Navigator.pop(sheet, (value: o.value))),
              ]);
            }));

/// The rows of a choice sheet, also used inline by pickers that build their
/// own sheet.
class MNSelectList<T> extends StatelessWidget {
  final List<MNSelectOption<T>> options;
  final T? selected;
  final ValueChanged<MNSelectOption<T>> onPick;
  const MNSelectList(
      {super.key,
      required this.options,
      required this.selected,
      required this.onPick});

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: MNColors.white,
            borderRadius: BorderRadius.circular(MNRadius.medium),
            border: Border.all(color: MNColors.border)),
        child: Column(children: [
          for (final (i, o) in options.indexed)
            MNListRow(
              first: i == 0,
              onTap: o.enabled ? () => onPick(o) : null,
              semanticLabel:
                  o.caption == null ? o.label : '${o.label}, ${o.caption}',
              leading: o.image == null
                  ? null
                  : MNProductImage.thumb(image: o.image, dimmed: !o.enabled),
              title: ExcludeSemantics(
                  child: Text(o.label,
                      style: MNText.resolve(context, MNText.title).copyWith(
                          color: !o.enabled
                              ? MNColors.disabledText
                              : o.action
                                  ? MNColors.red
                                  : MNColors.ink))),
              subtitle: o.caption == null
                  ? null
                  : ExcludeSemantics(
                      child: Text(o.caption!,
                          style: MNText.resolve(context, MNText.meta).copyWith(
                              color: o.enabled
                                  ? MNColors.muted
                                  : MNColors.disabledText))),
              trailing: o.action
                  ? null
                  : ExcludeSemantics(
                      child: MNRadioMark(
                          selected: selected != null && o.value == selected)),
            ),
        ]),
      );
}
