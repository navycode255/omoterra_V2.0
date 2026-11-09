import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import 'input_field.dart';
import 'select_field.dart';

/// "Mengineyo" (others) is always there, after the owner's categories; the
/// item bought is written, not chosen (owner decision 25 October 2026). The
/// server stores this exact name whatever the app's language.
const expenseOther = 'Mengineyo';
const maxExpenseItemLength = 60;

/// The owner's items under [category]; empty for Mengineyo or a category
/// without items.
List<String> expenseItemsOf(
        Map<String, List<String>> items, String? category) =>
    category == null || category == expenseOther
        ? const []
        : items[category] ?? const [];

/// The item to send for the chosen [category], or why there is none yet:
/// Mengineyo needs the written item, a category with items needs one.
({String? item, bool missing}) expenseItemFor(
    {required String? category,
    required Map<String, List<String>> items,
    required String? chosen,
    required String written}) {
  if (category == expenseOther) {
    final text = written.trim();
    return (item: text.isEmpty ? null : text, missing: text.isEmpty);
  }
  final listed = expenseItemsOf(items, category);
  if (listed.isEmpty) return (item: null, missing: false);
  return (
    item: listed.contains(chosen) ? chosen : null,
    missing: !listed.contains(chosen)
  );
}

/// Category, then what was bought: the category's items to choose from, or
/// for Mengineyo a field to write it in.
class ExpenseItemFields extends ConsumerWidget {
  final List<String> categories;
  final List<String> Function(WidgetRef ref)? watchCategories;
  final Map<String, List<String>> Function(WidgetRef ref)? watchItems;
  final Map<String, List<String>> items;
  final String? category, item;
  final TextEditingController written;
  final bool enabled;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onItem;
  const ExpenseItemFields(
      {super.key,
      required this.categories,
      required this.items,
      required this.category,
      required this.item,
      required this.written,
      required this.onCategory,
      required this.onItem,
      this.watchCategories,
      this.watchItems,
      this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final listed = expenseItemsOf(items, category);
    List<MNSelectOption<String>> categoryOptions(List<String> names) => [
          for (final c in names)
            if (c != expenseOther) MNSelectOption(value: c, label: c),
          MNSelectOption(
              value: expenseOther,
              label: s.expenseOtherLabel,
              caption: s.expenseOtherCaption),
        ];
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MNSelectField<String>(
              label: s.moneyCategory,
              value: category,
              options: categoryOptions(categories),
              watchOptions: watchCategories == null
                  ? null
                  : (ref) => categoryOptions(watchCategories!(ref)),
              onChanged: enabled ? onCategory : null),
          if (listed.isNotEmpty) ...[
            const SizedBox(height: 16),
            MNSelectField<String>(
                label: s.expenseItem,
                value: listed.contains(item) ? item : null,
                options: [
                  for (final i in listed) MNSelectOption(value: i, label: i)
                ],
                watchOptions: watchItems == null
                    ? null
                    : (ref) => [
                          for (final i
                              in expenseItemsOf(watchItems!(ref), category))
                            MNSelectOption(value: i, label: i),
                        ],
                onChanged: enabled ? onItem : null),
          ] else if (category == expenseOther) ...[
            const SizedBox(height: 16),
            MNTextField(
                label: s.expenseWhatBought,
                controller: written,
                enabled: enabled,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxExpenseItemLength)
                ]),
          ],
        ]);
  }
}
