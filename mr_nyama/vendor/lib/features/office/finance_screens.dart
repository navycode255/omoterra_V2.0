import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;

/// The finance books (Phase 12, phase-12-finance-api-contract.md) for
/// finance and the owner: status and posting, accounts, the posting map,
/// periods, the journal and reports. The server posts and computes every
/// figure; nothing is seeded, so the screens say what is not set yet.

// Data ---------------------------------------------------------------------------------

/// Runs [work] with the finance side of the office API.
Future<T> officeFinanceCall<T>(
        WidgetRef ref, Future<T> Function(OfficeFinanceRepository) work) =>
    _finance(ref.read(officeSessionProvider.notifier), work);

Future<T> _finance<T>(OfficeSessionController session,
        Future<T> Function(OfficeFinanceRepository) work) =>
    session.guard((repo) {
      if (repo is! OfficeFinanceRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OfficeFinanceRepository);
    });

final financeStatusProvider = FutureProvider.autoDispose<FinanceStatus>((ref) =>
    _finance(
        ref.read(officeSessionProvider.notifier), (r) => r.financeStatus()));

final financeAccountsProvider =
    FutureProvider.autoDispose<List<FinanceAccount>>((ref) => _finance(
        ref.read(officeSessionProvider.notifier), (r) => r.financeAccounts()));

final postingMapProvider = FutureProvider.autoDispose<List<PostingRule>>(
    (ref) => _finance(
        ref.read(officeSessionProvider.notifier), (r) => r.postingMap()));

final financePeriodsProvider = FutureProvider.autoDispose<List<FinancePeriod>>(
    (ref) => _finance(
        ref.read(officeSessionProvider.notifier), (r) => r.financePeriods()));

typedef JournalKey = ({String from, String to, String? account});

final journalProvider = FutureProvider.autoDispose
    .family<List<JournalEntry>, JournalKey>((ref, k) => _finance(
        ref.read(officeSessionProvider.notifier),
        (r) => r.journal(from: k.from, to: k.to, accountId: k.account)));

final trialBalanceProvider = FutureProvider.autoDispose
    .family<TrialBalance, String>((ref, asOf) => _finance(
        ref.read(officeSessionProvider.notifier),
        (r) => r.trialBalance(asOf: asOf)));

final operatingResultProvider = FutureProvider.autoDispose
    .family<OperatingResult, ({String from, String to})>((ref, k) => _finance(
        ref.read(officeSessionProvider.notifier),
        (r) => r.operatingResult(from: k.from, to: k.to)));

final cashPositionProvider = FutureProvider.autoDispose
    .family<CashPosition, String>((ref, asOf) => _finance(
        ref.read(officeSessionProvider.notifier),
        (r) => r.cashPosition(asOf: asOf)));

/// Finance reads, posts and keeps accounts; the owner also sets the posting
/// map and locks months. The server decides every action.
({bool read, bool owner}) financeAccess(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  final owner = roles.contains(StaffRole.owner);
  return (read: owner || roles.contains(StaffRole.finance), owner: owner);
}

void _afterChange(WidgetRef ref) {
  ref.invalidate(financeStatusProvider);
  ref.invalidate(financeAccountsProvider);
  ref.invalidate(postingMapProvider);
  ref.invalidate(financePeriodsProvider);
  ref.invalidate(journalProvider);
  ref.invalidate(trialBalanceProvider);
  ref.invalidate(operatingResultProvider);
  ref.invalidate(cashPositionProvider);
}

// Formatting ---------------------------------------------------------------------------

/// Shillings, with cents only when there are any.
String financeTsh(num v) {
  final negative = v < 0;
  final abs = v.abs();
  final whole = abs.truncate();
  final cents = ((abs - whole) * 100).round();
  final text = cents == 0
      ? formatTsh(whole)
      : '${formatTsh(whole)}.${cents.toString().padLeft(2, '0')}';
  return negative ? '−$text' : text;
}

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

String _month(Strings s, String ym) {
  final d = DateTime.tryParse('$ym-01');
  return d == null ? ym : s.monthYear(d);
}

String _error(Strings s, Object error) => switch (error) {
      OfficeError(kind: OfficeErrorKind.invalid) => s.moneyInvalid,
      _ => officeErrorText(s, error),
    };

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c, {Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, 14, color: color);
TextStyle _strong(BuildContext c) => OwnerStyle.text(c, 15, weight: 600);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

const _pageSize = 10;

/// Shows [count] items ten at a time, with "Zaidi" for the next ten.
class _Paged extends ConsumerStatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  const _Paged({required this.count, required this.itemBuilder});
  @override
  ConsumerState<_Paged> createState() => _PagedState();
}

class _PagedState extends ConsumerState<_Paged> {
  int _limit = _pageSize;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < math.min(_limit, widget.count); i++) ...[
        if (i > 0) _gap(context),
        widget.itemBuilder(context, i),
      ],
      if (widget.count > _limit) ...[
        _gap(context),
        MNButton.secondary(s.moreRows,
            onPressed: () => setState(() => _limit += _pageSize)),
      ],
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

/// The page frame every finance screen shares: notAllowed for others.
Widget _page(BuildContext context, WidgetRef ref,
    {required String title,
    required Widget Function() body,
    Future<void> Function()? onRefresh,
    VoidCallback? onAdd,
    String? addLabel,
    List<String> help = const [],
    bool showBack = true}) {
  final s = ref.watch(stringsProvider);
  final access = financeAccess(ref);
  return OwnerPage(
      title: title,
      strings: s,
      showBack: showBack,
      onRefresh: access.read ? onRefresh : null,
      onAdd: access.read ? onAdd : null,
      addLabel: addLabel,
      trailing: access.read && help.isNotEmpty
          ? MNWorkflowHelp(title: title, messages: help)
          : null,
      child: Padding(
          padding: _pad(context),
          child: access.read ? body() : MNNote(s.notAllowed)));
}

/// "Pakua"-style entry row where finance and the owner reach money.
class FinanceBooksEntry extends ConsumerWidget {
  const FinanceBooksEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerMenuRow(
        label: s.financeBooks,
        subtitle: s.financeBooksCaption,
        onTap: () => context.push(MNRoutes.officeFinance));
  }
}

// Home: status and posting ---------------------------------------------------------------

class OfficeFinanceScreen extends ConsumerWidget {
  final bool showBack;
  const OfficeFinanceScreen({super.key, this.showBack = true});

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final today = businessDate(ref.read(clockProvider)());
    final until = await showMNDateSheet(context,
        title: s.financePostUntil,
        initial: today,
        first: DateTime.utc(today.year - 2),
        last: today);
    if (until == null || !context.mounted) return;
    final day = DateTime.utc(until.year, until.month, until.day);
    final yes = await showMNConfirmDialog(context,
        title: s.financePostConfirmTitle(s.date(day)),
        message: s.financePostConfirmBody,
        confirmLabel: s.financePost,
        cancelLabel: s.cancel);
    if (!yes || !context.mounted) return;
    try {
      final result = await officeFinanceCall(
          ref, (r) => r.postToBooks(until: moneyDateKey(day)));
      _afterChange(ref);
      if (context.mounted) {
        _toast(
            context,
            result.entries == 0
                ? s.financePostedNothing
                : s.financePosted(result.entries));
      }
    } catch (error) {
      if (context.mounted) _toast(context, _error(s, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _page(context, ref,
        title: s.financeBooks,
        showBack: showBack,
        help: [
          s.financeConfirmNote,
          s.financeMapCaption,
          s.financePeriodsCaption,
          s.financeJournalCaption,
          s.financeReportsCaption
        ],
        onRefresh: () => ref.refresh(financeStatusProvider.future),
        body: () =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OwnerAsyncView(
                  value: ref.watch(financeStatusProvider),
                  onRetry: () => ref.invalidate(financeStatusProvider),
                  loadingRows: 2,
                  data: (status) => _StatusCard(status: status)),
              _gap(context),
              MNButton(s.financePost, onPressed: () => _post(context, ref)),
              _gap(context, 20),
              OwnerCard(
                  child: _FinanceLinks(children: [
                OwnerMenuRow(
                    label: s.financeAccounts,
                    onTap: () => context.push(MNRoutes.officeFinanceAccounts)),
                OwnerMenuRow(
                    label: s.financeMap,
                    onTap: () => context.push(MNRoutes.officeFinanceMap)),
                OwnerMenuRow(
                    label: s.financePeriods,
                    onTap: () => context.push(MNRoutes.officeFinancePeriods)),
                OwnerMenuRow(
                    label: s.financeJournal,
                    onTap: () => context.push(MNRoutes.officeFinanceJournal)),
                OwnerMenuRow(
                    label: s.financeReports,
                    onTap: () => context.push(MNRoutes.officeFinanceReports)),
              ])),
            ]));
  }
}

class _FinanceLinks extends StatelessWidget {
  final List<Widget> children;
  const _FinanceLinks({required this.children});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0)
            Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: OwnerStyle.px(context, 16)),
                child: const Divider(
                    height: 1, thickness: .7, color: OwnerStyle.line)),
          child,
        ],
      ]);
}

class _StatusCard extends ConsumerWidget {
  final FinanceStatus status;
  const _StatusCard({required this.status});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    void details() => showMNSheet<void>(context,
        builder: (_) => MNSheet(title: s.financeStatusTitle, children: [
              Text(
                  status.totalUnposted == 0
                      ? s.financeAllPosted
                      : s.financeUnposted(status.totalUnposted),
                  style: _strong(context)),
              for (final event in financeEvents)
                if ((status.unposted[event] ?? 0) > 0)
                  Text(
                      s.financeEventCount(
                          s.financeEventName(event), status.unposted[event]!),
                      style: _body(context)),
              if (status.unconfigured.isNotEmpty) ...[
                Text(s.financeUnconfigured(status.unconfigured.length),
                    style: _strong(context)),
                Text(status.unconfigured.map(s.financeEventName).join(', '),
                    style: _body(context)),
              ],
              Text(
                  status.lastPostedAt == null
                      ? s.financeNeverPosted
                      : s.financeLastPosted(_when(s, status.lastPostedAt)),
                  style: _meta(context)),
            ]));
    return OwnerCard(
        child: _FinanceLinks(children: [
      OwnerMenuRow(
          label: s.financeStatusTitle,
          value: status.totalUnposted == 0
              ? s.financeAllPosted
              : s.financeWaitingSummary(status.totalUnposted),
          valueSize: 14,
          valueWeight: 400,
          valueColor:
              status.totalUnposted == 0 ? OwnerStyle.muted : MNColors.warning,
          onTap: details),
      if (status.unconfigured.isNotEmpty)
        OwnerMenuRow(
            label: s.financeSetupSummary(status.unconfigured.length),
            labelColor: MNColors.warning,
            onTap: details),
    ]));
  }
}

// Accounts -------------------------------------------------------------------------------

class OfficeFinanceAccountsScreen extends ConsumerWidget {
  const OfficeFinanceAccountsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final done =
        await showMNSheet<bool>(context, builder: (_) => const _AccountSheet());
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.financeAccountSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _page(context, ref,
        title: s.financeAccounts,
        help: [s.financeConfirmNote],
        onRefresh: () => ref.refresh(financeAccountsProvider.future),
        onAdd: () => _add(context, ref),
        addLabel: s.financeAddAccount,
        body: () =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OwnerAsyncView(
                  value: ref.watch(financeAccountsProvider),
                  onRetry: () => ref.invalidate(financeAccountsProvider),
                  isEmpty: (rows) => rows.isEmpty,
                  empty: (_) =>
                      MNNote(s.financeNoAccounts, tone: MNNoteTone.info),
                  data: (rows) => _Paged(
                      count: rows.length,
                      itemBuilder: (_, i) => _AccountCard(account: rows[i]))),
            ]));
  }
}

class _AccountCard extends ConsumerWidget {
  final FinanceAccount account;
  const _AccountCard({required this.account});

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _AccountSheet(renaming: account));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.financeAccountSaved);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final a = account;
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title: a.active ? s.financeDeactivate : s.financeActivate,
            note: s.financeDeactivateNote,
            actionLabel: a.active ? s.financeDeactivate : s.financeActivate,
            send: (reason) => officeFinanceCall(
                ref,
                (r) => r.updateFinanceAccount(a.id,
                    active: !a.active, reason: reason))));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.financeAccountSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final a = account;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(a.label, style: _title(context)),
      Text(s.financeKindName(a.kind), style: _meta(context)),
      _gap(context, 4),
      Text(s.financeBalance(financeTsh(a.balance)), style: _body(context)),
      if (!a.active)
        Text(s.financeInactive, style: _status(context, OwnerStyle.muted)),
      _gap(context, 8),
      MNButton.secondary(s.financeRename,
          onPressed: () => _rename(context, ref)),
      _gap(context, 8),
      MNButton.secondary(a.active ? s.financeDeactivate : s.financeActivate,
          onPressed: () => _toggle(context, ref)),
    ]));
  }
}

/// A new account (code, name, kind), or a new name for [renaming].
class _AccountSheet extends ConsumerStatefulWidget {
  final FinanceAccount? renaming;
  const _AccountSheet({this.renaming});
  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _code = TextEditingController();
  late final _name = TextEditingController(text: widget.renaming?.name ?? '');
  String? _kind, _message;
  bool _busy = false;

  static final _codePattern = RegExp(r'^[A-Za-z0-9.\-]{1,20}$');

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final renaming = widget.renaming;
    final code = _code.text.trim();
    final name = _name.text.trim();
    String? problem;
    if (renaming == null && !_codePattern.hasMatch(code)) {
      problem = s.financeAccountCodeInvalid;
    } else if (name.length < 2 || name.length > 80) {
      problem = s.financeAccountNameInvalid;
    } else if (renaming == null && _kind == null) {
      problem = s.financeAccountKindMissing;
    }
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (renaming == null) {
        await officeFinanceCall(
            ref,
            (r) => r.createFinanceAccount(
                code: code,
                name: name,
                kind: _kind!,
                reason: s.financeReasonNewAccount(code)));
      } else {
        await officeFinanceCall(
            ref,
            (r) => r.updateFinanceAccount(renaming.id,
                name: name, reason: s.financeReasonRename(renaming.code)));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = _error(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final renaming = widget.renaming;
    return MNSheet(
        title: renaming == null ? s.financeAddAccount : s.financeRename,
        children: [
          if (renaming == null) ...[
            MNNote(s.financeConfirmNote, tone: MNNoteTone.info),
            MNTextField(
                label: s.financeAccountCode,
                controller: _code,
                enabled: !_busy,
                inputFormatters: [LengthLimitingTextInputFormatter(20)]),
          ] else
            Text(renaming.code, style: _strong(context)),
          MNTextField(
              label: s.financeAccountName,
              controller: _name,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(80)]),
          if (renaming == null)
            MNSelectField<String>(
                label: s.financeAccountKind,
                value: _kind,
                options: [
                  for (final k in financeAccountKinds)
                    MNSelectOption(value: k, label: s.financeKindName(k)),
                ],
                onChanged: _busy ? null : (k) => setState(() => _kind = k)),
          if (_message != null) MNNote(_message!, error: true),
          MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
        ]);
  }
}

// Posting map -------------------------------------------------------------------------------

class OfficeFinanceMapScreen extends ConsumerWidget {
  const OfficeFinanceMapScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final owner = financeAccess(ref).owner;
    return _page(context, ref,
        title: s.financeMap,
        help: [
          s.financeConfirmNote,
          owner ? s.financeRuleNote : s.financeOwnerOnly
        ],
        onRefresh: () => ref.refresh(postingMapProvider.future),
        body: () =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OwnerAsyncView(
                  value: ref.watch(postingMapProvider),
                  onRetry: () => ref.invalidate(postingMapProvider),
                  isEmpty: (rows) => rows.isEmpty,
                  empty: (_) => MNNote(s.financeNoRows),
                  data: (rows) => _Paged(
                      count: rows.length,
                      itemBuilder: (_, i) =>
                          _RuleCard(rule: rows[i], editable: owner))),
            ]));
  }
}

class _RuleCard extends ConsumerWidget {
  final PostingRule rule;
  final bool editable;
  const _RuleCard({required this.rule, required this.editable});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _RuleSheet(rule: rule));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.financeRuleSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = rule;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.financeEventName(r.event), style: _title(context)),
      Text(s.financeEventCaption(r.event), style: _meta(context)),
      _gap(context, 6),
      Text('${s.financeDebit}: ${r.debit?.label ?? s.financeNotSet}',
          style: _body(context,
              color: r.debit == null ? MNColors.warning : OwnerStyle.ink)),
      Text('${s.financeCredit}: ${r.credit?.label ?? s.financeNotSet}',
          style: _body(context,
              color: r.credit == null ? MNColors.warning : OwnerStyle.ink)),
      if (r.setBy != null)
        Text(s.financeRuleBy(r.setBy!.name, _when(s, r.setAt)),
            style: _meta(context)),
      if (editable) ...[
        _gap(context, 8),
        MNButton.secondary(s.financeMap, onPressed: () => _edit(context, ref)),
      ],
    ]));
  }
}

class _RuleSheet extends ConsumerStatefulWidget {
  final PostingRule rule;
  const _RuleSheet({required this.rule});
  @override
  ConsumerState<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<_RuleSheet> {
  late String? _debit = widget.rule.debit?.id;
  late String? _credit = widget.rule.credit?.id;
  final _reason = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    String? problem;
    if (_debit == null || _credit == null) {
      problem = s.financeRuleChooseBoth;
    } else if (_debit == _credit) {
      problem = s.financeRuleSameAccount;
    } else if (reason.length < 3 || reason.length > 500) {
      problem = s.decisionReasonInvalid;
    }
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await officeFinanceCall(
          ref,
          (r) => r.setPostingRule(widget.rule.event,
              debitAccountId: _debit!,
              creditAccountId: _credit!,
              reason: reason));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = _error(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final accounts = [
      for (final a in ref.watch(financeAccountsProvider).valueOrNull ??
          const <FinanceAccount>[])
        if (a.active) a
    ];
    List<MNSelectOption<String>> options() => [
          for (final a in accounts)
            MNSelectOption(
                value: a.id,
                label: a.label,
                caption: s.financeKindName(a.kind)),
        ];
    return MNSheet(title: s.financeEventName(widget.rule.event), children: [
      Text(s.financeEventCaption(widget.rule.event), style: _meta(context)),
      if (accounts.isEmpty)
        MNNote(s.financeNeedAccounts, tone: MNNoteTone.info)
      else ...[
        MNSelectField<String>(
            label: s.financeDebit,
            value: _debit,
            options: options(),
            onChanged: _busy ? null : (v) => setState(() => _debit = v)),
        MNSelectField<String>(
            label: s.financeCredit,
            value: _credit,
            options: options(),
            onChanged: _busy ? null : (v) => setState(() => _credit = v)),
      ],
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      MNNote(s.financeRuleNote, tone: MNNoteTone.info),
      if (_message != null) MNNote(_message!, error: true),
      MNButton(s.financeSaveRule,
          busy: _busy, onPressed: _busy || accounts.isEmpty ? null : _save),
    ]);
  }
}

// Periods ----------------------------------------------------------------------------------

class OfficeFinancePeriodsScreen extends ConsumerWidget {
  const OfficeFinancePeriodsScreen({super.key});

  Future<void> _lock(BuildContext context, WidgetRef ref, String month) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            title: s.financeLockTitle(_month(s, month)),
            note: s.financeLockRule,
            actionLabel: s.financeLockMonth,
            send: (reason) => officeFinanceCall(
                ref, (r) => r.lockFinancePeriod(month, reason: reason))));
    if (done != true) return;
    _afterChange(ref);
    if (context.mounted) _toast(context, s.financeLocked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final owner = financeAccess(ref).owner;
    final current =
        moneyDateKey(businessDate(ref.read(clockProvider)())).substring(0, 7);
    return _page(context, ref,
        title: s.financePeriods,
        help: [s.financeLockRule],
        onRefresh: () => ref.refresh(financePeriodsProvider.future),
        body: () =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OwnerAsyncView(
                  value: ref.watch(financePeriodsProvider),
                  onRetry: () => ref.invalidate(financePeriodsProvider),
                  isEmpty: (rows) => rows.isEmpty,
                  empty: (_) =>
                      MNNote(s.financeNoPeriods, tone: MNNoteTone.info),
                  data: (rows) {
                    // Only the oldest open month before this one can lock.
                    final next = rows
                        .where(
                            (p) => !p.locked && p.month.compareTo(current) < 0)
                        .map((p) => p.month)
                        .fold<String?>(null,
                            (a, m) => a == null || m.compareTo(a) < 0 ? m : a);
                    return _Paged(
                        count: rows.length,
                        itemBuilder: (_, i) {
                          final p = rows[i];
                          return _Card(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(_month(s, p.month),
                                    style: _title(context)),
                                Text(
                                    p.locked
                                        ? s.financeMonthLocked
                                        : s.financeMonthOpen,
                                    style: _status(
                                        context,
                                        p.locked
                                            ? OwnerStyle.muted
                                            : MNColors.success)),
                                if (p.lockedBy != null)
                                  Text(
                                      s.financeLockedBy(p.lockedBy!.name,
                                          _when(s, p.lockedAt)),
                                      style: _meta(context)),
                                if (p.reason != null)
                                  Text(s.reasonText(p.reason!),
                                      style: _meta(context)),
                                if (owner && p.month == next) ...[
                                  _gap(context, 8),
                                  MNButton.secondary(s.financeLockMonth,
                                      onPressed: () =>
                                          _lock(context, ref, p.month)),
                                ],
                              ]));
                        });
                  }),
            ]));
  }
}

// Journal ----------------------------------------------------------------------------------

class OfficeFinanceJournalScreen extends ConsumerStatefulWidget {
  const OfficeFinanceJournalScreen({super.key});
  @override
  ConsumerState<OfficeFinanceJournalScreen> createState() => _JournalState();
}

class _JournalState extends ConsumerState<OfficeFinanceJournalScreen> {
  late final DateTime _today = businessDate(ref.read(clockProvider)());
  late DateTime _from = DateTime.utc(_today.year, _today.month);
  late DateTime _to = _today;
  String? _account;

  JournalKey get _key =>
      (from: moneyDateKey(_from), to: moneyDateKey(_to), account: _account);

  Future<void> _pickRange() async {
    final s = ref.read(stringsProvider);
    final picked = await showMNDateRangeSheet(context,
        title: s.financeRange,
        start: _from,
        end: _to,
        first: DateTime.utc(_today.year - 2),
        last: _today);
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.$1;
      _to = picked.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final accounts = ref.watch(financeAccountsProvider).valueOrNull ??
        const <FinanceAccount>[];
    return _page(context, ref,
        title: s.financeJournal,
        onRefresh: () => ref.refresh(journalProvider(_key).future),
        body: () =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              MNFieldButton(
                  label: s.financeRange,
                  text: '${s.date(_from)} – ${s.date(_to)}',
                  placeholder: s.financeRange,
                  icon: MNIconData.calendar,
                  onTap: _pickRange),
              _gap(context, 8),
              MNSelectField<String?>(
                  label: s.financeAccounts,
                  value: _account,
                  options: [
                    MNSelectOption(value: null, label: s.financeAllAccounts),
                    for (final a in accounts)
                      MNSelectOption(value: a.id, label: a.label),
                  ],
                  onChanged: (v) => setState(() => _account = v)),
              _gap(context),
              OwnerAsyncView(
                  value: ref.watch(journalProvider(_key)),
                  onRetry: () => ref.invalidate(journalProvider(_key)),
                  isEmpty: (rows) => rows.isEmpty,
                  empty: (_) =>
                      MNNote(s.financeJournalEmpty, tone: MNNoteTone.info),
                  data: (rows) => _Paged(
                      count: rows.length,
                      itemBuilder: (_, i) => _EntryCard(entry: rows[i]))),
            ]));
  }
}

class _EntryCard extends ConsumerWidget {
  final JournalEntry entry;
  const _EntryCard({required this.entry});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final e = entry;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.financeEventName(e.event), style: _title(context)),
      Text(
          '${e.entryDate == null ? '—' : s.date(e.entryDate!)} · ${financeTsh(e.total)}',
          style: _body(context)),
      if (e.originalDate != null)
        Text(s.financeOriginalDate(s.date(e.originalDate!)),
            style: _meta(context)),
      if (e.reversesEntryId != null)
        Text(s.financeReversal, style: _status(context, MNColors.warning)),
      if (e.memo != null) Text(e.memo!, style: _meta(context)),
      _gap(context, 6),
      for (final l in e.lines) ...[
        Text(l.account?.label ?? '—', style: _body(context)),
        Text(s.financeLineAmounts(financeTsh(l.debit), financeTsh(l.credit)),
            style: _meta(context)),
      ],
      if (e.postedBy != null) ...[
        _gap(context, 4),
        Text(s.financeEntryBy(e.postedBy!.name, _when(s, e.postedAt)),
            style: _meta(context)),
      ],
    ]));
  }
}

// Reports ----------------------------------------------------------------------------------

class OfficeFinanceReportsScreen extends ConsumerStatefulWidget {
  const OfficeFinanceReportsScreen({super.key});
  @override
  ConsumerState<OfficeFinanceReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<OfficeFinanceReportsScreen> {
  late final DateTime _today = businessDate(ref.read(clockProvider)());
  late DateTime _from = DateTime.utc(_today.year, _today.month);
  late DateTime _to = _today;
  int _report = 0;

  Future<void> _pick() async {
    final s = ref.read(stringsProvider);
    if (_report == 1) {
      final picked = await showMNDateRangeSheet(context,
          title: s.financeRange,
          start: _from,
          end: _to,
          first: DateTime.utc(_today.year - 2),
          last: _today);
      if (picked == null || !mounted) return;
      setState(() {
        _from = picked.$1;
        _to = picked.$2;
      });
      return;
    }
    final picked = await showMNDateSheet(context,
        initial: _to, first: DateTime.utc(_today.year - 2), last: _today);
    if (picked == null || !mounted) return;
    setState(() => _to = DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _refresh() {
    final to = moneyDateKey(_to);
    return switch (_report) {
      1 => ref.refresh(
          operatingResultProvider((from: moneyDateKey(_from), to: to)).future),
      2 => ref.refresh(cashPositionProvider(to).future),
      _ => ref.refresh(trialBalanceProvider(to).future),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final to = moneyDateKey(_to);
    return _page(context, ref,
        title: s.financeReports,
        onRefresh: _refresh,
        body: () =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              MNChipBar(
                  labels: [
                    s.financeTrialBalance,
                    s.financeOperatingResult,
                    s.financeCashPosition
                  ],
                  selected: _report,
                  onSelect: (i) => setState(() => _report = i)),
              _gap(context, 8),
              MNFieldButton(
                  label: s.financeRange,
                  text: _report == 1
                      ? '${s.date(_from)} – ${s.date(_to)}'
                      : s.financeAsOf(s.date(_to)),
                  placeholder: s.financeRange,
                  icon: MNIconData.calendar,
                  onTap: _pick),
              _gap(context),
              switch (_report) {
                1 => OwnerAsyncView(
                    value: ref.watch(operatingResultProvider(
                        (from: moneyDateKey(_from), to: to))),
                    onRetry: () => ref.invalidate(operatingResultProvider),
                    loadingRows: 3,
                    data: (r) => _OperatingResultView(result: r)),
                2 => OwnerAsyncView(
                    value: ref.watch(cashPositionProvider(to)),
                    onRetry: () => ref.invalidate(cashPositionProvider),
                    loadingRows: 2,
                    data: (r) => _AmountsCard(rows: r.rows)),
                _ => OwnerAsyncView(
                    value: ref.watch(trialBalanceProvider(to)),
                    onRetry: () => ref.invalidate(trialBalanceProvider),
                    loadingRows: 3,
                    data: (r) => _TrialBalanceView(balance: r)),
              },
            ]));
  }
}

class _TrialBalanceView extends ConsumerWidget {
  final TrialBalance balance;
  const _TrialBalanceView({required this.balance});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final b = balance;
    if (b.rows.isEmpty) return MNNote(s.financeNoRows, tone: MNNoteTone.info);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
          child: Text(
              s.financeTotals(
                  financeTsh(b.totalDebit), financeTsh(b.totalCredit)),
              style: _strong(context))),
      _gap(context),
      _Paged(
          count: b.rows.length,
          itemBuilder: (_, i) {
            final r = b.rows[i];
            return _Card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(r.account?.label ?? '—', style: _title(context)),
                  if (r.kind.isNotEmpty)
                    Text(s.financeKindName(r.kind), style: _meta(context)),
                  Text(
                      s.financeLineAmounts(
                          financeTsh(r.debit), financeTsh(r.credit)),
                      style: _body(context)),
                  Text(s.financeBalance(financeTsh(r.balance)),
                      style: _strong(context)),
                ]));
          }),
    ]);
  }
}

class _OperatingResultView extends ConsumerWidget {
  final OperatingResult result;
  const _OperatingResultView({required this.result});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = result;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (r.provisional) ...[
          Text(s.financeProvisional, style: _status(context, MNColors.warning)),
          Text(s.financeProvisionalNote(r.unposted), style: _meta(context)),
          _gap(context, 6),
        ],
        Text('${s.financeTotalIncome}: ${financeTsh(r.totalIncome)}',
            style: _body(context)),
        Text('${s.financeTotalExpenses}: ${financeTsh(r.totalExpenses)}',
            style: _body(context)),
        Text('${s.financeResult}: ${financeTsh(r.result)}',
            style: _strong(context)),
      ])),
      _gap(context),
      Text(s.financeIncome, style: _title(context)),
      _gap(context, 8),
      _AmountsCard(rows: r.income),
      _gap(context),
      Text(s.financeExpenses, style: _title(context)),
      _gap(context, 8),
      _AmountsCard(rows: r.expenses),
    ]);
  }
}

class _AmountsCard extends ConsumerWidget {
  final List<AccountAmount> rows;
  const _AmountsCard({required this.rows});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (rows.isEmpty) return MNNote(s.financeNoRows, tone: MNNoteTone.info);
    return _Paged(
        count: rows.length,
        itemBuilder: (_, i) => _Card(
                child: Row(children: [
              Expanded(
                  child: Text(rows[i].account?.label ?? '—',
                      style: _body(context))),
              const SizedBox(width: 12),
              Text(financeTsh(rows[i].amount), style: _strong(context)),
            ])));
  }
}

// A reason, then the action ----------------------------------------------------------------

class _ReasonSheet extends ConsumerStatefulWidget {
  final String title, note, actionLabel;
  final Future<void> Function(String reason) send;
  const _ReasonSheet(
      {required this.title,
      required this.note,
      required this.actionLabel,
      required this.send});
  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (reason.length < 3 || reason.length > 500) {
      setState(() => _message = s.decisionReasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.send(reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = _error(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      MNNote(widget.note, tone: MNNoteTone.warning),
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_message != null) MNNote(_message!, error: true),
      MNButton(widget.actionLabel,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
