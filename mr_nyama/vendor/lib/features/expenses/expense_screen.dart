import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/expense_fields.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/workflow_help.dart';
import '../sales/checkout.dart';
import 'expense_store.dart';

final expenseReviewsRefreshProvider =
    FutureProvider.autoDispose<void>((ref) async {
  final repository = ref.read(vendorRepositoryProvider);
  if (repository is! VendorExpenseRepository) return;
  final auth = ref.read(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return;
  final rows = await ref.read(sessionProvider.notifier).authorised(
      (token) => (repository as VendorExpenseRepository).expenseClaims(token));
  await ref.read(expenseStoreProvider).cacheReviews(auth.profile.id, rows);
});

class VendorExpenseScreen extends ConsumerStatefulWidget {
  const VendorExpenseScreen({super.key});
  @override
  ConsumerState<VendorExpenseScreen> createState() =>
      _VendorExpenseScreenState();
}

class _VendorExpenseScreenState extends ConsumerState<VendorExpenseScreen> {
  @override
  void initState() {
    super.initState();
    // The owner's categories may have changed since the last download: the
    // tabs keep an earlier one alive, so ask again on every visit.
    Future.microtask(() {
      if (mounted) ref.invalidate(catalogRefreshProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final catalog = ref.watch(catalogRefreshProvider);
    final refresh = ref.watch(expenseReviewsRefreshProvider);
    // "Mengineyo" is always there, so an expense can be recorded even before
    // the owner sets categories or the phone downloads them.
    final categories =
        ref.watch(expenseCategoriesProvider).valueOrNull ?? const <String>[];
    final items = ref.watch(expenseItemsProvider).valueOrNull ??
        const <String, List<String>>{};
    final entries = ref.watch(vendorExpensesProvider);
    ref.listen(syncEngineProvider, (before, after) {
      if (before?.running == true && !after.running) {
        ref.invalidate(expenseReviewsRefreshProvider);
      }
    });
    return Scaffold(
      appBar: MNWorkflowHeader(title: strings.moneyExpenses, actions: [
        MNWorkflowHelp(messages: [strings.vendorExpenseApprovalNote])
      ]),
      body: MNRefreshArea(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(catalogRefreshProvider.future),
              ref.refresh(expenseReviewsRefreshProvider.future),
            ]).catchError((_) => <void>[]);
          },
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (refresh.hasError) ...[
                            const SizedBox(height: 12),
                            MNNote(strings.vendorExpenseOffline),
                          ],
                          if (catalog.hasError) ...[
                            const SizedBox(height: 12),
                            MNNote(strings.expenseCategoriesRefreshFailed),
                            MNTextButton(strings.retry,
                                onPressed: () =>
                                    ref.invalidate(catalogRefreshProvider)),
                          ],
                          const SizedBox(height: 16),
                          MNButton(strings.moneyAddExpense,
                              icon: MNIconData.plus, onPressed: () async {
                            final saved = await showMNSheet<bool>(context,
                                builder: (_) => _VendorExpenseForm(
                                    categories: categories, items: items));
                            if (saved == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(strings.vendorExpenseSaved)));
                            }
                          }),
                        ])),
                ...switch (entries) {
                  AsyncData(:final value) when value.isEmpty => [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(strings.moneyNoExpenses,
                              style: MNText.secondary))
                    ],
                  AsyncData(:final value) => [
                      for (final (i, expense) in value.indexed)
                        MNListRow(
                            first: i == 0,
                            title: Text(
                                strings.expenseLabel(
                                    expense.category, expense.item),
                                style: MNText.title),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(strings.date(eatClock(expense.spentAt)),
                                      style: MNText.meta),
                                  Text(
                                      strings
                                          .vendorExpenseState(expense.status),
                                      style: MNText.meta),
                                  if (expense.note != null)
                                    Text(expense.note!, style: MNText.body),
                                ]),
                            trailing: Text(formatTsh(expense.amount),
                                style: MNText.title))
                    ],
                  AsyncError(:final error) => [
                      MNErrorState(
                          error: error,
                          onRetry: () => ref.invalidate(vendorExpensesProvider))
                    ],
                  _ => [const SizedBox(height: 240, child: MNLoadingState())],
                },
              ])),
    );
  }
}

class _VendorExpenseForm extends ConsumerStatefulWidget {
  final List<String> categories;
  final Map<String, List<String>> items;
  const _VendorExpenseForm({required this.categories, required this.items});
  @override
  ConsumerState<_VendorExpenseForm> createState() => _VendorExpenseFormState();
}

class _VendorExpenseFormState extends ConsumerState<_VendorExpenseForm> {
  final _amount = TextEditingController(),
      _note = TextEditingController(),
      _written = TextEditingController();
  String? _category, _item, _id, _error;
  bool _busy = false;
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _written.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final strings = ref.read(stringsProvider);
    final amount = int.tryParse(_amount.text.trim());
    final auth = ref.read(sessionProvider).valueOrNull;
    if (_category == null) {
      setState(() => _error = strings.moneyCategoryRequired);
      return;
    }
    final item = expenseItemFor(
        category: _category,
        items: ref.read(expenseItemsProvider).valueOrNull ?? widget.items,
        chosen: _item,
        written: _written.text);
    if (item.missing) {
      setState(() => _error = strings.expenseItemRequired);
      return;
    }
    if (amount == null ||
        amount <= 0 ||
        amount > 100000000 ||
        auth is! SignedIn) {
      setState(() => _error = strings.moneyAmountInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _id ??= const Uuid().v4();
      await ref.read(expenseStoreProvider).submit(
          id: _id!,
          vendorId: auth.profile.id,
          stationKey: auth.profile.stationKey,
          category: _category!,
          item: item.item,
          amount: amount,
          spentAt: ref.read(clockProvider)(),
          note: _note.text);
      ref.read(syncEngineProvider.notifier).requestSync();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveNotDone);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final catalog = ref.watch(catalogRefreshProvider);
    final categories =
        ref.watch(expenseCategoriesProvider).valueOrNull ?? widget.categories;
    return MNSheet(title: strings.moneyAddExpense, children: [
      if (catalog.isLoading && categories.isEmpty)
        MNNote(strings.expenseCategoriesLoading),
      if (catalog.hasError) ...[
        MNNote(strings.expenseCategoriesRefreshFailed),
        MNTextButton(strings.retry,
            onPressed: () => ref.invalidate(catalogRefreshProvider)),
      ],
      Text(strings.date(businessDate(ref.read(clockProvider)())),
          style: MNText.meta),
      ExpenseItemFields(
          // The latest download, also when it arrives with the form open.
          categories: categories,
          watchCategories: (ref) =>
              ref.watch(expenseCategoriesProvider).valueOrNull ??
              widget.categories,
          watchItems: (ref) =>
              ref.watch(expenseItemsProvider).valueOrNull ?? widget.items,
          items: ref.watch(expenseItemsProvider).valueOrNull ?? widget.items,
          category: _category,
          item: _item,
          written: _written,
          enabled: !_busy,
          onCategory: (v) => setState(() {
                _category = v;
                _item = null;
              }),
          onItem: (v) => setState(() => _item = v)),
      MNTextField(
          label: strings.moneyAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9)
          ]),
      MNTextField(
          label: strings.noteOptional,
          controller: _note,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(200)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(strings.saveWorkflow,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
