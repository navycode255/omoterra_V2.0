import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/theme.dart';
import '../sales/sales_store.dart' show mpesaRecipientProvider;
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/workflow_header.dart';
import 'credit_sheets.dart';
import 'credit_store.dart';

/// Wateja wa mkopo (MN018): the station's credit customers, what each owes
/// (the server's figure plus what this phone has not sent), and taking a
/// repayment. The office registers customers and the owner sets limits.
class CreditCustomersScreen extends ConsumerWidget {
  const CreditCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    ref.watch(creditRefreshProvider);
    // Sent records are in the server's figures: download them again.
    ref.listen(syncEngineProvider, (before, after) {
      if (before?.running == true && !after.running) {
        ref.invalidate(creditRefreshProvider);
      }
    });
    final customers = ref.watch(creditCustomersProvider);
    return Scaffold(
      appBar: MNWorkflowHeader(title: s.creditCustomers),
      body: MNRefreshArea(
          onRefresh: () =>
              ref.refresh(creditRefreshProvider.future).catchError((_) {}),
          child: switch (customers) {
            AsyncData(:final value) when value.isEmpty => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: MNEmptyState(
                            icon: MNIconData.user,
                            title: s.creditCustomers,
                            message: s.creditNoCustomers)),
                  ]),
            AsyncData(:final value) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(children: [
                          Expanded(
                              child: Text(s.creditTotalOwed,
                                  style: MNText.secondary)),
                          Text(
                              formatTsh(value.fold<int>(0,
                                  (sum, c) => sum + (c.owed > 0 ? c.owed : 0))),
                              style: MNText.title),
                        ])),
                    for (final (i, c) in value.indexed)
                      MNListRow(
                          first: i == 0,
                          title: Text(c.name, style: MNText.title),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(creditCaption(s, c), style: MNText.meta),
                                if (c.unsentCount > 0)
                                  Text(s.creditUnsent(c.unsentCount),
                                      style: MNText.meta
                                          .copyWith(color: MNColors.warning)),
                              ]),
                          trailing: Text(formatTsh(c.owed > 0 ? c.owed : 0),
                              style: MNText.title),
                          onTap: () => _repay(context, ref, c)),
                  ]),
            AsyncError(:final error) => MNErrorState(
                error: error,
                onRetry: () => ref.invalidate(creditCustomersProvider)),
            _ => const MNLoadingState(),
          }),
    );
  }

  Future<void> _repay(
      BuildContext context, WidgetRef ref, CreditCustomer customer) async {
    final s = ref.read(stringsProvider);
    final saved = await showMNSheet<bool>(context,
        builder: (_) => _RepaymentSheet(customer: customer));
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.creditRepaymentSaved)));
    }
  }
}

/// A repayment the customer made at the station: how much and how.
class _RepaymentSheet extends ConsumerStatefulWidget {
  final CreditCustomer customer;
  const _RepaymentSheet({required this.customer});
  @override
  ConsumerState<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends ConsumerState<_RepaymentSheet> {
  final _amount = TextEditingController(), _note = TextEditingController();
  String _method = 'cash';
  String? _id, _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final amount = int.tryParse(_amount.text.trim());
    final owed = widget.customer.owed;
    final auth = ref.read(sessionProvider).valueOrNull;
    if (amount == null || amount <= 0 || auth is! SignedIn) {
      setState(() => _error = s.moneyAmountInvalid);
      return;
    }
    if (amount > owed) {
      setState(() => _error = s.creditRepaymentTooMuch(formatTsh(owed)));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // One id per attempt: a retry after a failure saves nothing twice.
      _id ??= const Uuid().v4();
      await ref.read(creditStoreProvider).submitRepayment(
          id: _id!,
          vendorId: auth.profile.id,
          stationKey: auth.profile.stationKey,
          customerId: widget.customer.id,
          amount: amount,
          method: _method,
          receivedAt: ref.read(clockProvider)(),
          note: _note.text);
      ref.read(syncEngineProvider.notifier).requestSync();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = s.saveNotDone);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final c = widget.customer;
    // The number can be taken away after M-Pesa was chosen: back to cash.
    ref.listen(mpesaRecipientProvider, (_, next) {
      if (next.hasValue && next.value == null && _method != 'cash') {
        setState(() => _method = 'cash');
      }
    });
    return MNSheet(title: c.name, children: [
      Text(creditCaption(s, c), style: MNText.secondary),
      if (c.owed <= 0)
        MNNote(s.creditNoneOwed, tone: MNNoteTone.info)
      else ...[
        MNTextField(
            label: s.creditRepaymentAmount,
            controller: _amount,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9)
            ]),
        // With no receiving number, a repayment is cash: nothing to choose.
        if (ref.watch(mpesaRecipientProvider).valueOrNull != null)
          MNSelectField<String>(
              label: s.creditRepaymentHow,
              value: _method,
              options: [
                MNSelectOption(value: 'cash', label: s.cash),
                MNSelectOption(value: 'mpesa', label: s.mpesa),
              ],
              onChanged: _busy ? null : (v) => setState(() => _method = v)),
        if (_method == 'cash')
          Text(s.creditRepaymentCashNote, style: MNText.meta),
        MNTextField(
            label: s.noteOptional,
            controller: _note,
            enabled: !_busy,
            inputFormatters: [LengthLimitingTextInputFormatter(200)]),
        if (_error != null) MNNote(_error!, error: true),
        MNButton(s.creditRecordRepayment,
            busy: _busy, onPressed: _busy ? null : _save),
      ],
    ]);
  }
}
