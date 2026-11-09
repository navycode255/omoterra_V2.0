import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_sale_cancel.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/dialogs.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText, officeStaffProvider;

/// Sale cancellations (MN034) on a station's verification screen. One person
/// asks, a different finance person or the owner decides; the server checks
/// both. Nothing here changes a sale: it is cancelled only when the server says
/// the request was approved.

/// The open requests at a station.
final saleCancellationsProvider = FutureProvider.autoDispose
    .family<List<SaleCancellation>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => (r as OfficeSaleCancelRepository)
            .saleCancellations(stationId: stationId, status: 'open')));

/// Finance and the owner decide (`sales.cancel_decide`); the server checks.
bool canDecideCancellations(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  return roles.any({'finance', 'business_owner'}.contains);
}

/// Whether the signed-in owner asking has nobody who could decide: no other active
/// finance person or owner. False until the list is known (only the owner reads it here).
bool noOtherDecider(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  if (auth is! OfficeSignedIn || !auth.profile.isOwner) return false;
  final staff = ref.watch(officeStaffProvider).valueOrNull;
  if (staff == null) return false;
  return !staff.any((p) =>
      p.id != auth.profile.id &&
      !p.suspended &&
      !p.left &&
      p.roles.any({'finance', 'business_owner'}.contains));
}

/// Opens the reason sheet; true once the request was saved on the server.
Future<bool> askToCancelSale(BuildContext context, String saleId) async =>
    await showMNSheet<bool>(context,
        builder: (_) => _AskSheet(saleId: saleId)) ??
    false;

class _AskSheet extends ConsumerStatefulWidget {
  final String saleId;
  const _AskSheet({required this.saleId});
  @override
  ConsumerState<_AskSheet> createState() => _AskState();
}

class _AskState extends ConsumerState<_AskSheet> {
  // One id per request; kept while the wording is unchanged so a retry is safe.
  String _clientId = const Uuid().v4();
  String? _sentAs, _error;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (_sentAs != null && _sentAs != reason) _clientId = const Uuid().v4();
    _sentAs = reason;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeSaleCancelRepository).askToCancelSale(
              clientId: _clientId, saleId: widget.saleId, reason: reason));
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
    return MNSheet(title: s.cancelAskTitle, children: [
      MNNote(s.cancelAskHelp, tone: MNNoteTone.info),
      if (noOtherDecider(ref))
        MNNote(s.cancelNoDecider, tone: MNNoteTone.warning),
      MNTextField(
          label: s.cancelReasonLabel,
          controller: _reason,
          enabled: !_busy,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.cancelSend,
          busy: _busy,
          onPressed: _reason.text.trim().length >= 3 && !_busy ? _save : null),
    ]);
  }
}

/// "Maombi ya kubatilisha": open requests at the station, only while there are some.
class SaleCancelRequestsSection extends ConsumerWidget {
  final String stationId;
  final VoidCallback onChanged;
  const SaleCancelRequestsSection(
      {super.key, required this.stationId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(saleCancellationsProvider(stationId));
    double u(double n) => OwnerStyle.px(context, n);
    // A failed load says so; hiding it would look like there is no request.
    if (value.hasError && !value.hasValue) {
      return Padding(
          padding: EdgeInsets.fromLTRB(u(12), u(8), u(12), u(8)),
          child: OwnerAsyncView<List<SaleCancellation>>(
              value: value,
              onRetry: () =>
                  ref.invalidate(saleCancellationsProvider(stationId)),
              data: (_) => const SizedBox.shrink()));
    }
    final rows = value.valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    return Padding(
        padding: EdgeInsets.fromLTRB(u(12), u(8), u(12), u(8)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.cancelSectionTitle,
              style: OwnerStyle.text(context, 17, weight: 600)),
          SizedBox(height: u(8)),
          for (final row in rows) ...[
            _RequestCard(row: row, stationId: stationId, onChanged: onChanged),
            SizedBox(height: u(8)),
          ],
        ]));
  }
}

class _RequestCard extends ConsumerWidget {
  final SaleCancellation row;
  final String stationId;
  final VoidCallback onChanged;
  const _RequestCard(
      {required this.row, required this.stationId, required this.onChanged});

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecideSheet(row: row, approve: approve));
    if (done != true) return;
    ref.invalidate(saleCancellationsProvider(stationId));
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.cancelDecided)));
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final yes = await showMNConfirmDialog(context,
        title: s.cancelWithdraw,
        message: s.cancelWithdrawBody,
        confirmLabel: s.cancelWithdrawYes,
        cancelLabel: s.cancel,
        sheet: true);
    if (!yes || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    String message = s.cancelWithdrawn;
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeSaleCancelRepository).withdrawSaleCancellation(row.id));
      ref.invalidate(saleCancellationsProvider(stationId));
      onChanged();
    } catch (error) {
      message = officeErrorText(s, error);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final body = OwnerStyle.text(context, 14);
    final meta = OwnerStyle.text(context, 13, color: OwnerStyle.muted);
    final decider = canDecideCancellations(ref);
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(u(14)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${row.vendorName} · ${row.businessDate}',
                      style: OwnerStyle.text(context, 16, weight: 600)),
                  for (final l in row.lines)
                    Text('${l.quantity} × ${l.name} · ${formatTsh(l.amount)}',
                        style: body),
                  Text(formatTsh(row.total),
                      style: OwnerStyle.text(context, 15, weight: 600)),
                  if (row.requestedBy != null)
                    Text(s.cancelRequestedBy(row.requestedBy!.name),
                        style: meta),
                  Text(row.reason, style: body),
                  SizedBox(height: u(8)),
                  if (row.requestedByMe) ...[
                    MNNote(s.cancelOtherWillDecide, tone: MNNoteTone.info),
                    SizedBox(height: u(8)),
                    MNButton.secondary(s.cancelWithdraw,
                        onPressed: () => _withdraw(context, ref)),
                  ] else if (decider) ...[
                    MNNote(s.cancelWarning),
                    SizedBox(height: u(8)),
                    MNButton(s.cancelApprove,
                        onPressed: () => _decide(context, ref, true)),
                    SizedBox(height: u(8)),
                    MNButton.secondary(s.cancelReject,
                        onPressed: () => _decide(context, ref, false)),
                  ],
                ])));
  }
}

class _DecideSheet extends ConsumerStatefulWidget {
  final SaleCancellation row;
  final bool approve;
  const _DecideSheet({required this.row, required this.approve});
  @override
  ConsumerState<_DecideSheet> createState() => _DecideState();
}

class _DecideState extends ConsumerState<_DecideSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeSaleCancelRepository).decideSaleCancellation(
              widget.row.id,
              approve: widget.approve,
              reason: _reason.text.trim()));
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
    final label = widget.approve ? s.cancelApprove : s.cancelReject;
    return MNSheet(title: label, children: [
      if (widget.approve) MNNote(s.cancelWarning),
      MNTextField(
          label: s.cancelDecisionReason,
          controller: _reason,
          enabled: !_busy,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(label,
          busy: _busy,
          onPressed: _reason.text.trim().length >= 3 && !_busy ? _save : null),
    ]);
  }
}
