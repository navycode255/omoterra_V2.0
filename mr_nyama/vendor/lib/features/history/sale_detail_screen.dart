import '../../shared/widgets/icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/sync_indicator.dart';
import 'history_screen.dart';
import 'history_store.dart';
import 'receipt_print.dart';

final saleDetailProvider = StreamProvider.autoDispose
    .family<SaleDetail?, String>(
        (ref, id) => ref.watch(historyStoreProvider).watchSale(id));

/// Maelezo ya mauzo: reference, lines, totals, payment, time, sync and
/// verification. "Batilisha mauzo haya" appears only when this vendor may void
/// the sale: their own, unverified, from today, not already voided.
class SaleDetailScreen extends ConsumerStatefulWidget {
  final String clientId;
  const SaleDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  /// One void ID per attempt: retries and double taps reuse it, so the
  /// store and the server record at most one void.
  String? _voidId;
  bool _busy = false;

  Future<void> _void(SaleDetail sale, String actorId) async {
    if (_busy) return;
    _busy = true;
    final strings = ref.read(stringsProvider);
    try {
      final reason = await showMNSheet<(VoidReason, String?)>(context,
          builder: (_) => const _ReasonSheet());
      if (reason == null || !mounted) return;
      final yes = await showMNConfirmDialog(context,
          title: strings.voidConfirmTitle,
          message: strings.voidConfirmBody,
          confirmLabel: strings.voidYes,
          cancelLabel: strings.stay,
          destructive: true);
      if (!yes || !mounted) return;
      _voidId ??= const Uuid().v4();
      await ref.read(historyStoreProvider).voidSale(
          voidId: _voidId!,
          saleClientId: sale.entry.clientId,
          reason: reason.$1,
          note: reason.$2,
          actorId: actorId,
          stationKey: switch (ref.read(sessionProvider).valueOrNull) {
            SignedIn(:final profile) => profile.stationKey,
            _ => '',
          },
          now: ref.read(clockProvider)());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.voidDone)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.voidFailed)));
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final detail = ref.watch(saleDetailProvider(widget.clientId));
    final auth = ref.watch(sessionProvider).valueOrNull;
    final actorId = auth is SignedIn ? auth.profile.id : null;
    final sale = detail.valueOrNull;
    final block = sale == null || actorId == null
        ? VoidBlock.notOwner
        : HistoryStore.voidBlock(sale, actorId, ref.watch(clockProvider)());
    return Scaffold(
      backgroundColor: MNColors.pageBackground,
      appBar: MNWorkflowHeader(title: strings.saleDetails),
      body: switch (detail) {
        AsyncData(value: final s?) => _Details(sale: s),
        AsyncData() || AsyncError() => MNErrorState(
            error: detail.error,
            onRetry: () => ref.invalidate(saleDetailProvider(widget.clientId))),
        _ => const MNLoadingState(),
      },
      bottomNavigationBar: block == null ||
              block == VoidBlock.notToday ||
              block == VoidBlock.verified
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
                child: MNButton.destructive(strings.voidAction,
                    onPressed: () async {
                  if (block == null) {
                    await _void(sale!, actorId!);
                    return;
                  }
                  if (!mounted) return;
                  await showMNSheet<void>(context,
                      builder: (context) => MNSheet(children: [
                            const Center(
                                child: MNIcon(MNIconData.lock,
                                    size: 56, color: MNColors.red)),
                            Text(strings.voidLockedTitle,
                                textAlign: TextAlign.center,
                                style: MNText.heading),
                            Text(
                                block == VoidBlock.verified
                                    ? strings.verifiedLocked
                                    : strings.notTodayLocked,
                                textAlign: TextAlign.center,
                                style: MNText.secondary),
                            MNButton.secondary(strings.okay,
                                onPressed: () => Navigator.pop(context)),
                          ]));
                }),
              ),
            )
          : null,
    );
  }
}

class _Details extends ConsumerWidget {
  final SaleDetail sale;
  const _Details({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final e = sale.entry;
    final v = sale.voidRecord;
    final (status, _, statusColor) = saleStatus(strings, e);
    final strike = e.voided ? TextDecoration.lineThrough : null;
    final muted = e.voided ? MNColors.muted : null;
    final recorded = eatClock(e.recordedAt);
    return ListView(padding: const EdgeInsets.all(16), children: [
      MNReferenceSurface(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: Text(
                      '${strings.hhmm(recorded)} · ${strings.date(recorded)}',
                      style: MNText.meta)),
              if (e.voided)
                Flexible(
                    child: Text(status,
                        textAlign: TextAlign.right,
                        style: MNText.status.copyWith(color: statusColor))),
            ])),
        MNInfoRow(
            first: true,
            label: strings.paymentLabel,
            value: Text(strings.paymentMethodName(e.payment.name,
                customer: e.customer))),
        MNInfoRow(
            label: strings.syncInfo,
            value: MNSyncIndicator(
                status: e.sent ? MNSyncStatus.sent : MNSyncStatus.waiting)),
        MNInfoRow(label: strings.reference, value: Text(e.reference)),
      ])),
      const SizedBox(height: 20),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              Text(strings.itemsCount(sale.lines.length), style: MNText.title)),
      if (v != null && v.state != VoidState.rejected)
        _pad(MNNote(
            strings.voidedAt(
                eatClock(v.requestedAt),
                e.cancelledByOffice
                    ? strings.statusCancelledByOffice
                    : strings.voidReason(v.reason.code)),
            tone: MNNoteTone.info,
            icon: MNIconData.voidSale)),
      if (v?.note != null && !e.cancelledByOffice)
        _pad(Text(v!.note!, style: MNText.body)),
      if (v?.state == VoidState.pending)
        _pad(MNNote(strings.voidWaiting,
            tone: MNNoteTone.info, icon: MNIconData.clock)),
      if (v?.state == VoidState.rejected)
        _pad(MNNote(strings.voidRejected(v!.rejectionReason))),
      const SizedBox(height: 12),
      MNReferenceSurface(
          child: Column(children: [
        for (final (i, l) in sale.lines.indexed)
          MNListRow(
            first: i == 0,
            title: Text(l.productName,
                style: MNText.title.copyWith(color: muted, decoration: strike)),
            subtitle: Text(
                strings.qtyTimesPrice(l.quantity, formatTsh(l.unitPrice)),
                style: MNText.meta),
            trailing: Text(groupDigits(l.lineTotal),
                style:
                    MNText.amount.copyWith(color: muted, decoration: strike)),
          ),
        MNInfoRow(
            label: strings.total,
            value: Text(formatTsh(e.total),
                style: MNText.title.copyWith(decoration: strike))),
      ])),
      const SizedBox(height: MNSpace.x4),
      MNReferenceSurface(
          child: MNInfoRow(
              first: true,
              label: strings.verification,
              value: Text(
                  e.verified ? strings.statusVerified : strings.unverified,
                  style: MNText.title.copyWith(
                      color: e.verified ? MNColors.success : MNColors.ink2)))),
      Padding(
          padding: const EdgeInsets.all(16),
          child: MNButton.secondary(strings.printReceipt, onPressed: () async {
            try {
              await ref.read(receiptPrinterProvider)(sale, strings);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(strings.printFailed)));
              }
            }
          })),
      const SizedBox(height: MNSpace.x6),
    ]);
  }

  Widget _pad(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(MNSpace.x4, 0, MNSpace.x4, MNSpace.x3),
      child: child);
}

/// Choose why the sale is being voided; the reason goes to the office.
class _ReasonSheet extends ConsumerStatefulWidget {
  const _ReasonSheet();

  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  VoidReason? _reason;
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return MNSheet(title: strings.voidReasonTitle, children: [
      Column(children: [
        for (final r in VoidReason.values)
          MNPressable(
            onTap: () => setState(() => _reason = r),
            pressedScale: 1,
            color: MNColors.white,
            pressedColor: MNColors.surface,
            semanticLabel: strings.voidReason(r.code),
            selected: _reason == r,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MNSize.menuRow),
              child: Row(children: [
                AnimatedContainer(
                  duration: MNMotion.of(context, MNMotion.radio),
                  curve: MNMotion.spring,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            _reason == r ? MNColors.ink : MNColors.borderStrong,
                        width: _reason == r ? 7 : 2),
                  ),
                ),
                const SizedBox(width: MNSpace.x3),
                Expanded(
                  child: ExcludeSemantics(
                      child:
                          Text(strings.voidReason(r.code), style: MNText.body)),
                ),
              ]),
            ),
          ),
      ]),
      Text(
          _reason == VoidReason.other
              ? strings.additionalNoteRequired
              : strings.additionalNoteOptional,
          style: MNText.label),
      TextField(
          controller: _note,
          maxLength: 100,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(hintText: strings.voidNoteHint),
          onChanged: (_) => setState(() {})),
      MNButton(strings.continueAction,
          onPressed: _reason == null ||
                  (_reason == VoidReason.other && _note.text.trim().isEmpty)
              ? null
              : () => Navigator.of(context).pop((
                    _reason!,
                    _note.text.trim().isEmpty ? null : _note.text.trim()
                  ))),
    ]);
  }
}
