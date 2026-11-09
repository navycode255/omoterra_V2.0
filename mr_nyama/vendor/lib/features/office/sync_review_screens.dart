import 'owner_widgets.dart';
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
import '../../shared/widgets/states.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;

/// Office review of phone records the server kept as conflicts (MN014). The
/// office fixes the cause (for `not_assigned`, the vendor's station on that
/// past date), then tries the record again, or refuses it for good. Every
/// outcome is the server's answer; nothing is shown as accepted before it.

// Data ---------------------------------------------------------------------------------

Future<T> _call<T>(OfficeSessionController session,
        Future<T> Function(OfficeSyncReviewRepository) call) =>
    session.guard((repo) {
      if (repo is! OfficeSyncReviewRepository) {
        throw const OfficeError(OfficeErrorKind.notFound);
      }
      return call(repo as OfficeSyncReviewRepository);
    });

final syncConflictsProvider =
    FutureProvider.autoDispose<List<OfficeSyncConflict>>((ref) => _call(
        ref.read(officeSessionProvider.notifier), (r) => r.syncConflicts()));

/// exceptions.resolve_operational: a supervisor (their stations) or the
/// owner. vendors.manage (a past station day): operations admin or owner.
({bool review, bool assign}) syncReviewAccess(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final profile = auth is OfficeSignedIn ? auth.profile : null;
  return (
    review: profile?.canReviewStock ?? false,
    assign: profile?.canManagePeople ?? false,
  );
}

// Helpers ------------------------------------------------------------------------------

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

String _day(Strings s, String? isoDate) {
  final d = isoDate == null ? null : DateTime.tryParse(isoDate);
  return d == null ? '—' : s.date(d);
}

String _payment(Strings s, String p) => switch (p) {
      'cash' => s.cash,
      'mpesa' => s.mpesa,
      'credit' => s.credit,
      _ => p,
    };

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c) => OwnerStyle.text(c, 14);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c) =>
    OwnerStyle.text(c, 13, weight: 600, color: MNColors.warning);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Card({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
              child: child)));
}

// List ---------------------------------------------------------------------------------

class OfficeSyncConflictsScreen extends ConsumerWidget {
  const OfficeSyncConflictsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allowed = syncReviewAccess(ref).review;
    return OwnerPage(
        title: s.syncConflicts,
        strings: s,
        onRefresh:
            allowed ? () => ref.refresh(syncConflictsProvider.future) : null,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: !allowed
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: ref.watch(syncConflictsProvider),
                    onRetry: () => ref.invalidate(syncConflictsProvider),
                    isEmpty: (rows) => rows.isEmpty,
                    empty: (_) => MNEmptyState(
                        icon: MNIconData.list,
                        image: 'assets/errors/phone_records_state.png',
                        imageWidth: 216,
                        title: s.syncConflictsEmpty),
                    data: (rows) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < rows.length; i++) ...[
                                if (i > 0) _gap(context),
                                _ConflictCard(
                                    conflict: rows[i],
                                    strings: s,
                                    onTap: () => context.push(
                                        MNRoutes.officeSyncConflict(
                                            rows[i].opId))),
                              ]
                            ]))));
  }
}

class _ConflictCard extends StatelessWidget {
  final OfficeSyncConflict conflict;
  final Strings strings;
  final VoidCallback onTap;
  const _ConflictCard(
      {required this.conflict, required this.strings, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    final c = conflict;
    return _Card(
        onTap: onTap,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(c.vendorName, style: _title(context)),
          Text(
              '${s.operationName(c.opType)} · ${_day(s, c.businessDate)}'
              '${c.sale == null ? '' : ' · ${formatTsh(c.sale!.total)}'}',
              style: _body(context)),
          Text(s.conflictReason(c.reason), style: _status(context)),
        ]));
  }
}

// Detail -------------------------------------------------------------------------------

class OfficeSyncConflictScreen extends ConsumerWidget {
  final String opId;
  const OfficeSyncConflictScreen({super.key, required this.opId});

  Future<void> _pastDay(BuildContext context, WidgetRef ref, Strings s,
      OfficeSyncConflict c, OfficeConflictStation station) async {
    final done = await showMNSheet<Object>(context,
        builder: (_) => _ReasonSheet(
            title: s.conflictPastDay,
            body: s.conflictPastDayBody(
                c.vendorName, station.name, _day(s, c.businessDate)),
            action: s.conflictPastDay,
            submit: (reason) => _call(
                ref.read(officeSessionProvider.notifier),
                (r) => r.assignVendorPastDay(
                    vendorId: c.vendorId,
                    stationId: station.id,
                    businessDate: c.businessDate!,
                    reason: reason)).then((_) => true)));
    if (done == true && context.mounted) _toast(context, s.conflictPastDayDone);
  }

  Future<void> _review(BuildContext context, WidgetRef ref, Strings s,
      OfficeSyncConflict c, bool retry) async {
    final outcome = await showMNSheet<Object>(context,
        builder: (_) => _ReasonSheet(
            title: retry ? s.conflictRetry : s.conflictReject,
            body: retry ? s.conflictRetryBody : s.conflictRejectBody,
            action: retry ? s.conflictRetry : s.conflictReject,
            destructive: !retry,
            submit: (reason) => _call(
                ref.read(officeSessionProvider.notifier),
                (r) => retry
                    ? r.retryConflict(c.opId, reason: reason)
                    : r.rejectConflict(c.opId, reason: reason))));
    if (outcome is! OfficeConflictOutcome || !context.mounted) return;
    ref.invalidate(syncConflictsProvider);
    switch (outcome.status) {
      case 'accepted':
        _toast(context, s.conflictAccepted);
        context.pop();
      case 'rejected':
        _toast(context, s.conflictRejected);
        context.pop();
      default:
        _toast(context,
            s.conflictStillWaiting(s.conflictReason(outcome.reason ?? '')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = syncReviewAccess(ref);
    return OwnerPage(
        title: s.syncConflicts,
        strings: s,
        onRefresh: access.review
            ? () => ref.refresh(syncConflictsProvider.future)
            : null,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: !access.review
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: ref.watch(syncConflictsProvider),
                    onRetry: () => ref.invalidate(syncConflictsProvider),
                    isEmpty: (rows) => !rows.any((c) => c.opId == opId),
                    empty: (_) =>
                        MNNote(s.syncConflictGone, tone: MNNoteTone.info),
                    data: (rows) {
                      final c = rows.firstWhere((c) => c.opId == opId);
                      final station = c.suggestedStation;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Card(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Text('${c.vendorName} · ${c.vendorCode}',
                                      style: _title(context)),
                                  Text(
                                      '${s.operationName(c.opType)} · '
                                      '${_day(s, c.businessDate)}',
                                      style: _body(context)),
                                  OwnerDetails(
                                      title: s.recordDetails,
                                      children: [
                                        Text(
                                            s.conflictRecordedAt(_when(
                                                s,
                                                c.sale?.recordedAt ??
                                                    c.phoneCreatedAt)),
                                            style: _meta(context)),
                                        if (c.station != null)
                                          Text(
                                              s.conflictPhoneStation(
                                                  c.station!.name),
                                              style: _meta(context)),
                                        if (c.vendorStation != null)
                                          Text(
                                              s.conflictVendorStation(
                                                  c.vendorStation!.name),
                                              style: _meta(context)),
                                      ]),
                                  _gap(context, 8),
                                  Text(s.conflictReason(c.reason),
                                      style: _status(context)),
                                  if (c.sale != null) ...[
                                    _gap(context, 8),
                                    for (final l in c.sale!.lines)
                                      Text(
                                          '${l.name ?? l.productKey} × ${l.quantity}'
                                          ' · ${formatTsh(l.quantity * l.unitPrice)}',
                                          style: _body(context)),
                                    Text(
                                        '${formatTsh(c.sale!.total)} · '
                                        '${_payment(s, c.sale!.paymentMethod)}',
                                        style: _title(context)),
                                  ],
                                ])),
                            if (c.reviews.isNotEmpty) ...[
                              _gap(context),
                              _Card(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    Text(s.conflictHistory,
                                        style: _title(context)),
                                    for (final r in c.reviews) ...[
                                      _gap(context, 6),
                                      Text(
                                          s.conflictReviewLine(
                                              r.action,
                                              r.decidedBy,
                                              _when(s, r.decidedAt)),
                                          style: _meta(context)),
                                      Text(r.reason, style: _body(context)),
                                    ],
                                  ])),
                            ],
                            _gap(context, 20),
                            if (c.reason == 'not_assigned' &&
                                access.assign) ...[
                              if (station == null || c.businessDate == null)
                                MNNote(s.conflictPastDayNoStation,
                                    tone: MNNoteTone.info)
                              else
                                MNButton.secondary(s.conflictPastDay,
                                    onPressed: () =>
                                        _pastDay(context, ref, s, c, station)),
                              _gap(context),
                            ],
                            MNButton(s.conflictRetry,
                                onPressed: () =>
                                    _review(context, ref, s, c, true)),
                            _gap(context),
                            MNButton.destructive(s.conflictReject,
                                onPressed: () =>
                                    _review(context, ref, s, c, false)),
                          ]);
                    })));
  }
}

/// A decision that needs a written reason (3–500 characters). Pops with
/// what [submit] returns; a refusal stays in the sheet with its reason.
class _ReasonSheet extends ConsumerStatefulWidget {
  final String title, body, action;
  final bool destructive;
  final Future<Object> Function(String reason) submit;
  const _ReasonSheet(
      {required this.title,
      required this.body,
      required this.action,
      required this.submit,
      this.destructive = false});
  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _error;
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
      setState(() => _error = s.decisionReasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.submit(reason);
      if (mounted) Navigator.of(context).pop(result);
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
      MNNote(widget.body,
          tone: widget.destructive ? MNNoteTone.warning : MNNoteTone.info),
      MNTextField(
          label: s.decisionReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      widget.destructive
          ? MNButton.destructive(widget.action,
              busy: _busy, onPressed: _busy ? null : _save)
          : MNButton(widget.action,
              busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
