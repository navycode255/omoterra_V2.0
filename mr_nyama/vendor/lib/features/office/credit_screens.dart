import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/contact_phone_picker.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText, officeStationsProvider;
import 'removal_sheet.dart';

/// Credit customers in the office (MN018, owner decisions 25 October 2026).
/// The office registers customers per station; the owner sets each limit;
/// repayments are taken at the station or here; finance or the owner write
/// off what will not be paid. Every figure is the server's.

Future<T> officeCreditCall<T>(
        WidgetRef ref, Future<T> Function(OfficeCreditRepository) work) =>
    ref.read(officeSessionProvider.notifier).guard((repo) {
      if (repo is! OfficeCreditRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OfficeCreditRepository);
    });

final officeCreditCustomersProvider = FutureProvider.autoDispose
    .family<List<OfficeCreditCustomer>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((repo) => (repo as OfficeCreditRepository)
            .creditCustomers(stationId: stationId)));

final officeCreditStatementProvider = FutureProvider.autoDispose
    .family<OfficeCreditStatement, String>((ref, id) => ref
        .read(officeSessionProvider.notifier)
        .guard((repo) => (repo as OfficeCreditRepository).creditStatement(id)));

/// What the signed-in account may plausibly do; the server decides.
({bool manage, bool limit, bool record, bool settle}) creditAccess(
    WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  bool any(Set<String> set) => roles.any(set.contains);
  return (
    // credit.manage
    manage:
        any({StaffRole.supervisor, StaffRole.operationsAdmin, StaffRole.owner}),
    // thresholds.manage
    limit: roles.contains(StaffRole.owner),
    // handovers.record
    record: any({StaffRole.supervisor, StaffRole.finance, StaffRole.owner}),
    // handovers.reverse and writeoffs.approve
    settle: any({StaffRole.finance, StaffRole.owner}),
  );
}

String creditOfficeCaption(Strings s, OfficeCreditCustomer c) {
  if (c.suspended) return s.creditSuspended;
  if (c.creditLimit == null) return s.creditNoLimit;
  return s.creditLimitOf(formatTsh(c.creditLimit!));
}

Widget _divided(List<Widget> rows) => Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: OwnerStyle.line)),
        rows[i],
      ]
    ]);

Widget _section(BuildContext context, Strings s, String title,
        {VoidCallback? onAdd}) =>
    Padding(
        padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 4),
            OwnerStyle.px(context, 22), 0, OwnerStyle.px(context, 8)),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title,
                      style: OwnerStyle.text(context, 17, weight: 600)))),
          if (onAdd != null)
            TextButton(
                onPressed: onAdd,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const OwnerGlyph('plus', size: 20, color: OwnerStyle.muted),
                  const SizedBox(width: 6),
                  Text(s.stationAdd,
                      style: OwnerStyle.text(context, 16,
                          color: OwnerStyle.muted)),
                ])),
        ]));

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

// A station's customers --------------------------------------------------------------

class OfficeCreditCustomersScreen extends ConsumerWidget {
  final String stationId;
  const OfficeCreditCustomersScreen({super.key, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = creditAccess(ref);
    final station = ref
        .watch(officeStationsProvider)
        .valueOrNull
        ?.where((x) => x.id == stationId)
        .firstOrNull;
    final customers = ref.watch(officeCreditCustomersProvider(stationId));
    Future<void> add() async {
      final created = await showMNSheet<bool>(context,
          builder: (_) => _NewCustomerSheet(stationId: stationId));
      if (created == true) {
        ref.invalidate(officeCreditCustomersProvider(stationId));
      }
    }

    return OwnerPage(
        title: s.creditCustomers,
        strings: s,
        subtitle: station == null
            ? null
            : Text(station.name,
                style: OwnerStyle.text(context, 15, color: OwnerStyle.muted)),
        onRefresh: () =>
            ref.refresh(officeCreditCustomersProvider(stationId).future),
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 13)),
            child: OwnerAsyncView(
                value: customers,
                onRetry: () =>
                    ref.invalidate(officeCreditCustomersProvider(stationId)),
                data: (rows) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OwnerCard(
                              child: OwnerMenuRow(
                                  label: s.creditTotalOwed,
                                  value: formatTsh(rows.fold<int>(
                                      0, (sum, c) => sum + c.owed)),
                                  showChevron: false)),
                          _section(context, s, s.creditCustomers,
                              onAdd: access.manage ? add : null),
                          if (rows.isEmpty)
                            MNNote(s.creditNoCustomers, tone: MNNoteTone.info)
                          else
                            OwnerCard(
                                child: _divided([
                              for (final c in rows)
                                OwnerMenuRow(
                                    label: c.name,
                                    subtitle: creditOfficeCaption(s, c),
                                    value: formatTsh(c.owed),
                                    valueColor: c.overLimit
                                        ? MNColors.error
                                        : OwnerStyle.ink,
                                    valueSize: 15,
                                    onTap: () => context.push(
                                        MNRoutes.officeCreditCustomer(c.id))),
                            ])),
                        ]))));
  }
}

class _NewCustomerSheet extends ConsumerStatefulWidget {
  final String stationId;
  const _NewCustomerSheet({required this.stationId});
  @override
  ConsumerState<_NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends ConsumerState<_NewCustomerSheet> {
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    if (_name.text.trim().length < 2) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeCreditCall(
          ref,
          (r) => r.createCreditCustomer(
              stationId: widget.stationId,
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              note: _note.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.creditAddCustomer, children: [
      MNTextField(
          label: s.creditCustomerName,
          controller: _name,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(80)]),
      MNTextField(
          label: s.creditCustomerPhone,
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          inputFormatters: [LengthLimitingTextInputFormatter(16)],
          suffix: MNContactPickButton(
              enabled: !_busy, onPicked: (phone) => _phone.text = phone)),
      MNTextField(
          label: s.creditCustomerNote,
          controller: _note,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(200)]),
      Text(s.creditLimitOwnerOnly, style: MNText.resolve(context, MNText.meta)),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// One customer -------------------------------------------------------------------------

class OfficeCreditCustomerScreen extends ConsumerWidget {
  final String customerId;
  const OfficeCreditCustomerScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = creditAccess(ref);
    final value = ref.watch(officeCreditStatementProvider(customerId));
    final name = value.valueOrNull?.customer.name;

    Future<void> act(Widget sheet) async {
      final done = await showMNSheet<bool>(context, builder: (_) => sheet);
      if (done != true) return;
      ref.invalidate(officeCreditStatementProvider(customerId));
      final station = value.valueOrNull?.customer.stationId;
      if (station != null) {
        ref.invalidate(officeCreditCustomersProvider(station));
      }
      if (context.mounted) _toast(context, s.creditSaved);
    }

    return OwnerPage(
        title: name ?? s.creditCustomers,
        strings: s,
        onRefresh: () =>
            ref.refresh(officeCreditStatementProvider(customerId).future),
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 13)),
            child: OwnerAsyncView(
                value: value,
                onRetry: () =>
                    ref.invalidate(officeCreditStatementProvider(customerId)),
                data: (st) {
                  final c = st.customer;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            [c.stationName, if (c.phone != null) c.phone!]
                                .join(' · '),
                            style: OwnerStyle.text(context, 14,
                                color: OwnerStyle.muted)),
                        SizedBox(height: OwnerStyle.px(context, 12)),
                        OwnerCard(
                            child: _divided([
                          OwnerMenuRow(
                              label: s.creditOwed,
                              value: formatTsh(c.owed),
                              valueColor:
                                  c.overLimit ? MNColors.error : OwnerStyle.ink,
                              valueSize: 20,
                              valueWeight: 700,
                              showChevron: false),
                          OwnerMenuRow(
                              label: s.creditSold,
                              value: formatTsh(c.creditSales),
                              valueSize: 15,
                              showChevron: false),
                          OwnerMenuRow(
                              label: s.creditRepaid,
                              value: formatTsh(c.repaid),
                              valueSize: 15,
                              showChevron: false),
                          if (c.writtenOff > 0)
                            OwnerMenuRow(
                                label: s.creditWrittenOff,
                                value: formatTsh(c.writtenOff),
                                valueSize: 15,
                                showChevron: false),
                        ])),
                        SizedBox(height: OwnerStyle.px(context, 14)),
                        OwnerCard(
                            child: _divided([
                          OwnerMenuRow(
                              label: s.creditLimit,
                              value: c.creditLimit == null
                                  ? s.creditLimitNotSet
                                  : formatTsh(c.creditLimit!),
                              valueColor: c.creditLimit == null
                                  ? OwnerStyle.muted
                                  : null,
                              valueSize: 15,
                              showChevron: access.limit,
                              onTap: access.limit
                                  ? () => act(_LimitSheet(customer: c))
                                  : null),
                          OwnerMenuRow(
                              label: s.creditStatus,
                              value: c.suspended
                                  ? s.creditSuspended
                                  : s.creditActive,
                              valueColor: c.suspended ? MNColors.warning : null,
                              valueSize: 15,
                              showChevron: access.manage,
                              onTap: access.manage
                                  ? () => act(_ReasonSheet(
                                      title: c.suspended
                                          ? s.creditReactivate
                                          : s.creditSuspend,
                                      send: (reason, _, __) => officeCreditCall(
                                          ref,
                                          (r) => r.setCreditStatus(c.id,
                                              suspended: !c.suspended,
                                              reason: reason))))
                                  : null),
                        ])),
                        if (c.creditLimit == null) ...[
                          SizedBox(height: OwnerStyle.px(context, 8)),
                          Text(s.creditLimitHelp,
                              style: OwnerStyle.text(context, 13,
                                  color: OwnerStyle.muted)),
                        ],
                        SizedBox(height: OwnerStyle.px(context, 16)),
                        if (access.record && c.owed > 0) ...[
                          MNButton.secondary(s.creditOfficeRepayment,
                              onPressed: () => act(_ReasonSheet(
                                  title: s.creditOfficeRepayment,
                                  amountLabel: s.creditRepaymentAmount,
                                  most: c.owed,
                                  withMethod: true,
                                  reasonRequired: false,
                                  send: (note, amount, method) =>
                                      officeCreditCall(
                                          ref,
                                          (r) => r.recordCreditRepayment(c.id,
                                              amount: amount!,
                                              method: method!,
                                              note: note))))),
                          SizedBox(height: OwnerStyle.px(context, 8)),
                        ],
                        if (access.settle && c.owed > 0)
                          MNTextButton(s.creditWriteOff,
                              onPressed: () => act(_ReasonSheet(
                                  title: s.creditWriteOff,
                                  help: s.creditWriteOffHelp,
                                  amountLabel: s.creditWriteOffAmount,
                                  most: c.owed,
                                  send: (reason, amount, _) => officeCreditCall(
                                      ref,
                                      (r) => r.writeOffCredit(c.id,
                                          amount: amount!, reason: reason))))),
                        // Added by mistake: nothing bought or repaid yet.
                        if (access.manage && st.entries.isEmpty)
                          MNTextButton(s.deleteCustomer, onPressed: () async {
                            final done = await showRemovalSheet(context,
                                title: s.deleteCustomer,
                                body: s.deleteCustomerBody,
                                name: c.name,
                                run: (r, reason) => r.deleteCreditCustomer(c.id,
                                    reason: reason));
                            if (!done) return;
                            ref.invalidate(
                                officeCreditCustomersProvider(c.stationId));
                            if (!context.mounted) return;
                            _toast(context, s.deletedToast);
                            context.pop();
                          }),
                        _section(context, s, s.creditHistory),
                        if (st.entries.isEmpty)
                          MNNote(s.creditNoHistory, tone: MNNoteTone.info)
                        else
                          OwnerCard(
                              child: _divided([
                            for (final e in st.entries)
                              _EntryRow(
                                  entry: e,
                                  onReverse: access.settle && e.reversible
                                      ? () => act(_ReasonSheet(
                                          title: s.creditReverseTitle,
                                          send: (reason, _, __) =>
                                              officeCreditCall(
                                                  ref,
                                                  (r) =>
                                                      r.reverseCreditRepayment(
                                                          e.id,
                                                          reason: reason))))
                                      : null),
                          ])),
                        SizedBox(height: OwnerStyle.px(context, 24)),
                      ]);
                })));
  }
}

class _EntryRow extends ConsumerWidget {
  final OfficeCreditEntry entry;
  final VoidCallback? onReverse;
  const _EntryRow({required this.entry, this.onReverse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final e = entry;
    final when = e.at == null ? '' : s.date(eatClock(e.at!));
    final detail = [
      when,
      if (e.method != null) s.paymentMethodName(e.method!),
      if (e.items != null) e.items!,
      if (e.by != null) s.creditBy(e.by!),
    ].where((t) => t.isNotEmpty).join(' · ');
    final sign = e.kind == 'sale' ? '' : '−';
    return Padding(
        padding: EdgeInsets.symmetric(
            horizontal: OwnerStyle.px(context, 16),
            vertical: OwnerStyle.px(context, 12)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(s.creditEntry(e.kind),
                    style: OwnerStyle.text(context, 15, weight: 600))),
            Text(
                e.status == 'voided'
                    ? formatTsh(e.amount)
                    : '$sign${formatTsh(e.amount)}',
                style: OwnerStyle.text(context, 15,
                    weight: 600,
                    color: e.status == 'voided' || e.reversed
                        ? OwnerStyle.muted
                        : OwnerStyle.ink)),
          ]),
          if (detail.isNotEmpty)
            Text(detail,
                style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
          if (e.reason != null)
            Text(s.reasonText(e.reason!),
                style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
          if (e.note != null)
            Text(s.noteText(e.note!),
                style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
          if (e.status == 'voided' || e.reversed)
            Text(e.reversed ? s.creditReversed : s.statusVoided,
                style: OwnerStyle.text(context, 13,
                    weight: 600, color: OwnerStyle.muted)),
          if (onReverse != null)
            Align(
                alignment: Alignment.centerRight,
                child: MNTextButton(s.creditReverse, onPressed: onReverse)),
        ]));
  }
}

/// The owner's limit for one customer; empty removes it.
class _LimitSheet extends ConsumerStatefulWidget {
  final OfficeCreditCustomer customer;
  const _LimitSheet({required this.customer});
  @override
  ConsumerState<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends ConsumerState<_LimitSheet> {
  late final _amount = TextEditingController(
      text: widget.customer.creditLimit?.toString() ?? '');
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final limit = remove ? null : int.tryParse(_amount.text.trim());
    if ((!remove && (limit == null || limit <= 0)) ||
        _reason.text.trim().length < 3) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeCreditCall(
          ref,
          (r) => r.setCreditLimit(widget.customer.id,
              limit: limit, reason: _reason.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.creditLimit, children: [
      Text(s.creditLimitHelp, style: MNText.resolve(context, MNText.secondary)),
      MNTextField(
          label: s.priceAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9)
          ]),
      MNTextField(label: s.changeReason, controller: _reason, enabled: !_busy),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
      if (widget.customer.creditLimit != null)
        MNTextButton(s.creditRemoveLimit,
            onPressed: _busy ? null : () => _save(remove: true)),
    ]);
  }
}

/// A reason (or an optional note), and when asked an amount and how it was
/// paid, then one server call.
class _ReasonSheet extends ConsumerStatefulWidget {
  final String title;
  final String? help, amountLabel;
  final int? most;
  final bool withMethod, reasonRequired;
  final Future<Object?> Function(String text, int? amount, String? method) send;
  const _ReasonSheet(
      {required this.title,
      required this.send,
      this.help,
      this.amountLabel,
      this.most,
      this.withMethod = false,
      this.reasonRequired = true});
  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _amount = TextEditingController(), _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    int? amount;
    if (widget.amountLabel != null) {
      amount = int.tryParse(_amount.text.trim());
      if (amount == null || amount <= 0) {
        setState(() => _error = s.moneyAmountInvalid);
        return;
      }
      if (widget.most != null && amount > widget.most!) {
        setState(
            () => _error = s.creditRepaymentTooMuch(formatTsh(widget.most!)));
        return;
      }
    }
    final text = _text.text.trim();
    if (widget.reasonRequired && text.length < 3) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(text, amount, widget.withMethod ? 'cash' : null);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      if (widget.help != null)
        Text(widget.help!, style: MNText.resolve(context, MNText.secondary)),
      if (widget.amountLabel != null)
        MNTextField(
            label: widget.amountLabel!,
            controller: _amount,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9)
            ]),
      MNTextField(
          label: widget.reasonRequired ? s.changeReason : s.noteOptional,
          controller: _text,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(200)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(widget.title, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
