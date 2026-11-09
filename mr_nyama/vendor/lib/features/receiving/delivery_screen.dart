import '../../shared/widgets/radio_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/offline_unlock.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/number_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/select_field.dart';
import '../closing/closing_store.dart';
import '../sales/product_images.dart';
import 'receive_screen.dart';
import 'receiving_store.dart';

final deliveryProvider = StreamProvider.autoDispose
    .family<DeliveryView?, String>(
        (ref, id) => ref.watch(receivingStoreProvider).watchDelivery(id));

/// One delivery: what Omoterra dispatched and what the vendor counted.
/// "Nimepokea" accepts everything as dispatched; "Idadi tofauti" opens the
/// count, where any difference needs a reason. Saving never adds stock:
/// the count goes to the receiving service, which decides.
class DeliveryScreen extends ConsumerStatefulWidget {
  final String consignmentId;
  const DeliveryScreen({super.key, required this.consignmentId});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  DateTime? _receivedAt;
  bool _counting = false;
  bool _busy = false;
  final _counts = <String, int>{};
  final _reasons = <String, DiscrepancyReason>{};
  final _notes = <String, String>{};
  String? _error;
  String? _errorLine;

  /// One idempotency key per attempt; a retry reuses it.
  String? _eventId;
  String? _receiptId;

  int _count(DeliveryLineView l) => _counts[l.lineId] ?? l.dispatched;

  Future<void> _submit(DeliveryView d, {required bool all}) async {
    if (_busy) return;
    final strings = ref.read(stringsProvider);
    final auth = ref.read(sessionProvider).valueOrNull;
    if (auth is! SignedIn) return;
    final counts = [
      for (final l in d.lines)
        all
            ? LineCount(l.lineId, l.dispatched)
            : LineCount(l.lineId, _count(l),
                _count(l) == l.dispatched ? null : _reasons[l.lineId]),
    ];
    try {
      ReceivingStore.validate(d, counts);
    } on ReceiptRefused catch (e) {
      setState(() {
        _error = strings.receiptBlock(e.block.name);
        _errorLine = e.lineId;
      });
      return;
    }
    _busy = true;
    try {
      final yes = await showMNConfirmDialog(context,
          title: all ? strings.confirmAllTitle : strings.confirmCountTitle,
          message: strings.confirmReceiptBody,
          confirmLabel: strings.yesConfirm,
          cancelLabel: strings.stay);
      if (!yes || !mounted) return;
      _eventId ??= const Uuid().v4();
      _receiptId ??= const Uuid().v4();
      await ref.read(receivingStoreProvider).submitReceipt(
          receiptId: _receiptId!,
          eventId: _eventId!,
          consignmentId: d.consignmentId,
          consignmentVersion: d.version,
          sessionStationKey: auth.profile.stationKey,
          actorId: auth.profile.id,
          receivedAt: _receivedAt ?? ref.read(clockProvider)(),
          recordedAt: ref.read(clockProvider)(),
          counts: counts,
          notes: _notes);
      if (mounted) {
        context.pushReplacement(MNRoutes.receiptSaved(d.consignmentId));
      }
    } on ReceiptRefused catch (e) {
      if (mounted) {
        setState(() {
          _error = strings.receiptBlock(e.block.name);
          _errorLine = e.lineId;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveNotDone);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final delivery = ref.watch(deliveryProvider(widget.consignmentId));
    // Opened directly (not from the list): fetch manifests too.
    final refreshing = ref.watch(deliveriesRefreshProvider).isLoading;
    final auth = ref.watch(sessionProvider).valueOrNull;
    final stationKey = auth is SignedIn ? auth.profile.stationKey : '';
    final d = delivery.valueOrNull;
    final ownStation = d != null && d.stationKey == stationKey;
    final canReceive = ownStation && d.status == ReceivingStatus.pending;
    return Scaffold(
      backgroundColor: MNColors.pageBackground,
      appBar: MNWorkflowHeader(title: strings.receive, actions: [
        MNWorkflowHelp(messages: [
          // Only while stock is still to come: not for a conflict or a
          // refusal, where nothing is added.
          if (d == null ||
              d.status == ReceivingStatus.pending ||
              d.status == ReceivingStatus.savedOnPhone)
            strings.stockAfterAcceptance,
          if (d != null && d.status == ReceivingStatus.accepted)
            strings.acceptedNote
        ])
      ]),
      body: switch (delivery) {
        AsyncData(value: final d?) =>
          ListView(padding: const EdgeInsets.all(16), children: [
            ..._header(strings, d, ownStation),
            MNReferenceSurface(
                child: Column(children: [
              for (final (i, l) in d.lines.indexed)
                _LineRow(
                  line: l,
                  first: i == 0,
                  counting: _counting,
                  count: _count(l),
                  reason: _reasons[l.lineId],
                  note: _notes[l.lineId],
                  onNote: (v) => setState(() => _notes[l.lineId] = v),
                  error: _errorLine == l.lineId,
                  onCount: (v) => setState(() {
                    _counts[l.lineId] = v;
                    _error = null;
                    _errorLine = null;
                  }),
                  onReason: (r) => setState(() {
                    _reasons[l.lineId] = r;
                    _error = null;
                    _errorLine = null;
                  }),
                ),
            ])),
            if (_counting && canReceive)
              Padding(
                padding: const EdgeInsets.all(MNSpace.x4),
                child: MNFieldButton(
                  label: strings.actualReceiptDate,
                  text:
                      '${strings.date(businessDate(_receivedAt ?? ref.read(clockProvider)()))} · ${strings.hhmm(eatClock(_receivedAt ?? ref.read(clockProvider)()))}',
                  placeholder: strings.dateLabel,
                  icon: MNIconData.calendar,
                  onTap: _busy
                      ? null
                      : () async {
                          final current =
                              _receivedAt ?? ref.read(clockProvider)();
                          final now = ref.read(clockProvider)();
                          final date = await showMNDateSheet(context,
                              initial: businessDate(current),
                              first: DateTime.utc(2020),
                              last: businessDate(now));
                          if (date == null || !context.mounted) return;
                          final time = await showMNTimeSheet(context,
                              hour: eatClock(current).hour,
                              minute: eatClock(current).minute);
                          if (time == null || !mounted) return;
                          final selected = businessDayRange(date).$1.add(
                              Duration(hours: time.hour, minutes: time.minute));
                          if (selected.isAfter(now)) {
                            setState(() => _error = strings.detailsInvalid);
                            return;
                          }
                          setState(() => _receivedAt = selected);
                        },
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(MNSpace.x4),
                child: MNNote(_error!, error: true),
              ),
            const SizedBox(height: MNSpace.x4),
          ]),
        AsyncData() when refreshing => const MNLoadingState(),
        AsyncData() => MNEmptyState(
            icon: MNIconData.truck,
            image: 'assets/errors/delivery_state.png',
            imageWidth: 196,
            title: strings.noDeliveries,
            action: MNButton.secondary(strings.retry,
                onPressed: () => ref.invalidate(deliveriesRefreshProvider))),
        AsyncError(:final error) => MNErrorState(
            error: error,
            onRetry: () =>
                ref.invalidate(deliveryProvider(widget.consignmentId))),
        _ => const MNLoadingState(),
      },
      bottomNavigationBar: canReceive
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // A receipt starts the new day's stock: yesterday is
                  // closed first (owner decision 26 October 2026).
                  if (ref.watch(offlineRecordingStoppedProvider).valueOrNull ==
                      true) ...[
                    MNNote(strings.offlineRecordingStopped),
                  ] else if (ref.watch(yesterdayClosingProvider).valueOrNull ==
                      YesterdayClosing.open) ...[
                    MNNote(strings.closeYesterdayBody(strings.date(
                        businessDate(ref.read(clockProvider)())
                            .subtract(const Duration(days: 1))))),
                    const SizedBox(height: 8),
                    MNButton(strings.closeYesterdayAction,
                        onPressed: () => context.push(MNRoutes.closeDay)),
                  ] else if (!_counting) ...[
                    MNButton(strings.receiveGoodsAction,
                        onPressed: () => setState(() => _counting = true)),
                  ] else ...[
                    MNButton(strings.saveWorkflow,
                        onPressed: d.lines.any((l) =>
                                _count(l) != l.dispatched &&
                                (_reasons[l.lineId] == null ||
                                    (_notes[l.lineId]?.trim().isEmpty ?? true)))
                            ? null
                            : () => _submit(d, all: false)),
                    MNTextButton(strings.cancel,
                        color: MNColors.ink2,
                        onPressed: () => setState(() {
                              _counting = false;
                              _counts.clear();
                              _reasons.clear();
                              _notes.clear();
                              _error = null;
                              _errorLine = null;
                            })),
                  ],
                ]),
              ),
            )
          : null,
    );
  }

  List<Widget> _header(Strings strings, DeliveryView d, bool ownStation) {
    final note = !ownStation && d.status == ReceivingStatus.pending
        ? MNNote(strings.wrongStationNote, error: true)
        : switch (d.status) {
            ReceivingStatus.savedOnPhone || ReceivingStatus.accepted => null,
            ReceivingStatus.conflict => MNNote(strings.conflictNote),
            ReceivingStatus.rejected =>
              MNNote(strings.refusedNote, error: true),
            ReceivingStatus.pending => null,
          };
    final sent = eatClock(d.dispatchedAt);
    final (status, color) =
        receivingStatus(strings, d, otherStation: !ownStation);
    return [
      MNReferenceSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.sender, style: MNText.heading),
              Text(d.reference, style: MNText.meta),
            ])),
        MNInfoRow(
            first: true, label: strings.station, value: Text(d.stationName)),
        MNInfoRow(
            label: strings.dispatchedOn,
            value: Text('${strings.hhmm(sent)} · ${strings.date(sent)}')),
        MNInfoRow(
            label: strings.statusLabel,
            value: Text(status, style: MNText.title.copyWith(color: color))),
      ])),
      if (note != null)
        Padding(
            padding: const EdgeInsets.fromLTRB(
                MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x2),
            child: note),
      const SizedBox(height: 16),
    ];
  }
}

/// One product: photo, name, dispatched, and either the received count or,
/// while counting, large − / + controls (tap the number to type) and the
/// reason when it differs.
class _LineRow extends ConsumerWidget {
  final DeliveryLineView line;
  final bool first;
  final bool counting;
  final int count;
  final DiscrepancyReason? reason;
  final String? note;
  final ValueChanged<String> onNote;
  final bool error;
  final ValueChanged<int> onCount;
  final ValueChanged<DiscrepancyReason> onReason;

  const _LineRow(
      {required this.line,
      required this.first,
      required this.counting,
      required this.count,
      required this.reason,
      required this.note,
      required this.onNote,
      required this.error,
      required this.onCount,
      required this.onReason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final image = productImageFor(line.imageKey, productName: line.productName);
    final received = line.received;
    final differs = count != line.dispatched;
    return Material(
        color: MNColors.white,
        child: Container(
          decoration: BoxDecoration(
              border: first
                  ? null
                  : const Border(top: BorderSide(color: MNColors.border))),
          padding: const EdgeInsets.fromLTRB(
              MNSpace.x4, MNSpace.x3, MNSpace.x4, MNSpace.x3),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (image != null) ...[
                MNProductImage.thumb(image: image, size: MNSize.thumbLarge),
                const SizedBox(width: MNSpace.x3),
              ],
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.productName, style: MNText.title),
                      Text(strings.dispatchedCount(line.dispatched),
                          style: MNText.meta),
                      if (received != null && !counting)
                        Text(
                            strings.receivedCount(received.accepted) +
                                (received.reason == null
                                    ? ''
                                    : ' · ${strings.discrepancy(received.reason!.code)}'),
                            style: MNText.status.copyWith(
                                color: received.reason == null
                                    ? MNColors.ink
                                    : MNColors.warning)),
                    ]),
              ),
            ]),
            if (counting) ...[
              const SizedBox(height: MNSpace.x3),
              Row(children: [
                Expanded(
                  child: Text(strings.receivedLabel, style: MNText.label),
                ),
                MNQuantityButton(
                    icon: MNIconData.minus,
                    label: '${strings.decrease} ${line.productName}',
                    large: true,
                    onPressed: count > 0 ? () => onCount(count - 1) : null),
                MNPressable(
                  onTap: () async {
                    final v = await showNumberSheet(context,
                        title: line.productName,
                        initial: count,
                        max: line.dispatched);
                    if (v != null) onCount(v);
                  },
                  pressedScale: MNMotion.pressChip,
                  semanticLabel:
                      '${strings.enterCount}, ${line.productName}, $count',
                  child: SizedBox(
                    width: 72,
                    height: MNSize.quantityLarge,
                    child: Center(
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MNRollingNumber(count,
                              style: MNText.quantityLarge),
                        ),
                      ),
                    ),
                  ),
                ),
                MNQuantityButton(
                    icon: MNIconData.plus,
                    label: '${strings.increase} ${line.productName}',
                    large: true,
                    onPressed: count < line.dispatched
                        ? () => onCount(count + 1)
                        : null),
              ]),
              if (differs) ...[
                const SizedBox(height: MNSpace.x2),
                Container(
                    padding: const EdgeInsets.all(10),
                    color: MNColors.roseSurface,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(strings.differenceLabel,
                              style: MNText.meta.copyWith(color: MNColors.red)),
                          Text('${line.dispatched - count}',
                              style:
                                  MNText.title.copyWith(color: MNColors.red)),
                        ])),
                const SizedBox(height: 12),
                Text(strings.differenceReasonRequired, style: MNText.label),
                for (final r in DiscrepancyReason.values)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: MNRadioMark(selected: reason == r),
                      title:
                          Text(strings.discrepancy(r.code), style: MNText.body),
                      onTap: () => onReason(r)),
              ],
              const SizedBox(height: 12),
              Text(differs ? strings.noteRequired : strings.noteOptional,
                  style: MNText.label),
              const SizedBox(height: 8),
              TextFormField(
                  initialValue: note,
                  maxLength: 100,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: strings.noteHint),
                  onChanged: onNote),
            ],
            if (!counting && received?.note != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(received!.note!, style: MNText.body)),
          ]),
        ));
  }
}
