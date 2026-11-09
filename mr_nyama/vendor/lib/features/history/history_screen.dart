import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/filter_sheet.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import 'history_recovery.dart';
import '../sales/sales_store.dart' show mpesaRecipientProvider;
import 'history_store.dart';
import '../sales/product_images.dart';
import '../../shared/widgets/product_card.dart';

final _dayProvider = StreamProvider.autoDispose
    .family<List<HistoryEntry>, (DateTime, int)>((ref, range) {
  final store = ref.watch(historyStoreProvider);
  return Stream.multi((controller) {
    final values = <int, List<HistoryEntry>>{};
    final subscriptions = <StreamSubscription<List<HistoryEntry>>>[];
    for (var i = 0; i < range.$2; i++) {
      final index = i;
      subscriptions.add(store
          .watchDay(range.$1.subtract(Duration(days: i)))
          .listen((entries) {
        values[index] = entries;
        if (values.length == range.$2) {
          final all = values.values.expand((e) => e).toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
          controller.add(all);
        }
      }, onError: controller.addError));
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
});

/// Historia ya mauzo: today by default, any of the last seven business days
/// from the chips. Compact rows, newest first; tap for details.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _daysAgo = 0;
  DateTime? _customDate;
  // Empty means every payment method.
  Set<PaymentMethod> _payments = const {};
  bool _pendingOnly = false;
  bool _showVoided = false;

  /// "Muda" in the filter sheet: today, yesterday, the two days before by
  /// name, this week, this month, or a date from the wheel.
  static const _periodToday = 0,
      _periodWeek = 4,
      _periodMonth = 5,
      _periodCustom = 6;

  Future<void> _filter() async {
    final strings = ref.read(stringsProvider);
    final today = businessDate(ref.read(clockProvider)());
    DateTime ago(int n) => today.subtract(Duration(days: n));
    var period = switch (_daysAgo) {
      1 => 1,
      2 => _periodWeek,
      3 => _periodMonth,
      4 => _customDate == ago(2)
          ? 2
          : _customDate == ago(3)
              ? 3
              : _periodCustom,
      _ => _periodToday,
    };
    var custom = _customDate;
    final payments = {..._payments};
    var pending = _pendingOnly;
    var voided = _showVoided;
    final applied = await showMNSheet<bool>(context,
        builder: (sheetContext) => StatefulBuilder(builder: (context, update) {
              MNFilterOption radio(int value, String label) => MNFilterOption(
                  label: label,
                  mark: MNFilterMark.radio,
                  selected: period == value,
                  onTap: () => update(() => period = value));
              return MNFilterSheet(
                  title: strings.filterSales,
                  applyLabel: strings.applyFilters,
                  onApply: () => Navigator.pop(sheetContext, true),
                  onReset: () => update(() {
                        period = _periodToday;
                        payments.clear();
                        pending = false;
                        voided = false;
                      }),
                  children: [
                    MNFilterGroup(title: strings.filterPeriod, children: [
                      radio(_periodToday, strings.todayLabel),
                      radio(1, strings.yesterdayLabel),
                      radio(2, strings.dayChip(ago(2), 2)),
                      radio(3, strings.dayChip(ago(3), 3)),
                      radio(_periodWeek, strings.thisWeek),
                      radio(_periodMonth, strings.thisMonth),
                      MNFilterOption(
                          label: strings.customDate,
                          mark: MNFilterMark.calendar,
                          selected: period == _periodCustom,
                          detail: period == _periodCustom && custom != null
                              ? strings.date(custom!)
                              : null,
                          onTap: () async {
                            final date = await showMNDateWheelSheet(context,
                                initial: custom ?? today,
                                first: ago(365),
                                last: today);
                            if (date != null) {
                              update(() {
                                custom = date;
                                period = _periodCustom;
                              });
                            }
                          }),
                    ]),
                    MNFilterGroup(title: strings.payMethod, children: [
                      for (final (method, label) in [
                        (PaymentMethod.cash, strings.cash),
                        if (ref.read(mpesaRecipientProvider).valueOrNull !=
                            null)
                          (PaymentMethod.mpesa, strings.mpesaShort),
                        (PaymentMethod.credit, strings.credit),
                      ])
                        MNFilterOption(
                            label: label,
                            mark: MNFilterMark.check,
                            selected: payments.contains(method),
                            onTap: () => update(() => payments.contains(method)
                                ? payments.remove(method)
                                : payments.add(method))),
                    ]),
                    Column(children: [
                      MNFilterSwitch(
                          label: strings.unsyncedOnly,
                          value: pending,
                          onChanged: (v) => update(() => pending = v)),
                      MNFilterSwitch(
                          label: strings.showVoided,
                          value: voided,
                          onChanged: (v) => update(() => voided = v)),
                    ]),
                  ]);
            }));
    if (applied == true && mounted) {
      setState(() {
        switch (period) {
          case 2 || 3:
            _customDate = ago(period);
            _daysAgo = 4;
          case _periodCustom when custom != null:
            _customDate = custom;
            _daysAgo = 4;
          case _periodCustom:
            break;
          case _periodWeek:
            _daysAgo = 2;
          case _periodMonth:
            _daysAgo = 3;
          default:
            _daysAgo = period;
        }
        _payments = payments;
        _pendingOnly = pending;
        _showVoided = voided;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = businessDate(ref.read(clockProvider)());
    final date = await showMNDateWheelSheet(context,
        initial: _customDate ?? now,
        first: now.subtract(const Duration(days: 365)),
        last: now);
    if (date != null && mounted) {
      setState(() {
        _customDate = date;
        _daysAgo = 4;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final today = businessDate(ref.watch(clockProvider)());
    final range = (
      _customDate != null && _daysAgo == 4
          ? _customDate!
          : _daysAgo == 1
              ? today.subtract(const Duration(days: 1))
              : today,
      _daysAgo == 2
          ? today.weekday
          : _daysAgo == 3
              ? today.day
              : 1
    );
    final entries = ref.watch(_dayProvider(range));
    return Scaffold(
      appBar: MNWorkflowHeader(title: strings.historyTitle, actions: [
        IconButton(
            tooltip: strings.filter,
            onPressed: _filter,
            icon: const MNIcon(MNIconData.filter)),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: MNSpace.x2),
          child: MNChipBar(
            labels: [
              strings.todayLabel,
              strings.yesterdayLabel,
              strings.thisWeek,
              strings.thisMonth,
              _customDate == null
                  ? strings.customDate
                  : strings.date(_customDate!)
            ],
            selected: _daysAgo,
            onSelect: (i) =>
                i == 4 ? _pickDate() : setState(() => _daysAgo = i),
          ),
        ),
        const _RecoveryNote(),
        Expanded(
          child: MNAsyncView(
            value: entries,
            isEmpty: (value) => value.isEmpty,
            empty: (_) => MNEmptyState(
                icon: MNIconData.list,
                title: strings.noSalesDay,
                message: strings.recordedHere,
                action: const _RecoverButton()),
            onRetry: () => ref.invalidate(_dayProvider(range)),
            data: (value) {
              final filtered = value
                  .where((e) =>
                      (_payments.isEmpty || _payments.contains(e.payment)) &&
                      (!_pendingOnly || !e.sent) &&
                      (_showVoided || !e.voided))
                  .toList();
              return filtered.isEmpty
                  ? MNEmptyState(
                      icon: MNIconData.list,
                      title: strings.noSalesDay,
                      message: strings.recordedHere)
                  : _DayList(entries: filtered);
            },
          ),
        ),
      ]),
    );
  }
}

/// What the recovery from the server is doing: a calm note while it runs,
/// a retry after a failure, the count once done. Selling never waits on it.
class _RecoveryNote extends ConsumerWidget {
  const _RecoveryNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(historyRecoveryProvider);
    final note = switch (state.status) {
      RecoveryStatus.running =>
        MNNote(strings.recoveringHistory, tone: MNNoteTone.info),
      RecoveryStatus.failed =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MNNote(strings.recoveryFailed),
          const SizedBox(height: 8),
          MNButton.secondary(strings.retry,
              onPressed: () =>
                  ref.read(historyRecoveryProvider.notifier).recover()),
        ]),
      RecoveryStatus.done =>
        MNNote(strings.recoveryDone(state.added), tone: MNNoteTone.info),
      RecoveryStatus.idle => null,
    };
    if (note == null) return const SizedBox.shrink();
    return Padding(
        padding:
            const EdgeInsets.fromLTRB(MNSpace.x4, MNSpace.x2, MNSpace.x4, 0),
        child: note);
  }
}

/// "Rejesha historia": fetch the vendor's records from the server again.
class _RecoverButton extends ConsumerWidget {
  const _RecoverButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final running =
        ref.watch(historyRecoveryProvider).status == RecoveryStatus.running;
    return MNButton.secondary(strings.recoverHistory,
        onPressed: running
            ? null
            : () => ref.read(historyRecoveryProvider.notifier).recover());
  }
}

class _DayList extends ConsumerWidget {
  final List<HistoryEntry> entries;
  const _DayList({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final counted = entries.where((e) => !e.voided);
    final total = counted.fold(0, (sum, e) => sum + e.total);
    return ListView.builder(
      itemCount: entries.length + 2,
      itemBuilder: (context, i) {
        if (i == entries.length + 1) {
          return const Padding(
              padding: EdgeInsets.all(MNSpace.x4), child: _RecoverButton());
        }
        if (i == 0) {
          return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _summary(strings.sales, formatTsh(total))),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _summary(strings.transactions, '${counted.length}')),
                ]),
                if (entries.any((e) => !e.sent)) ...[
                  const SizedBox(height: 12),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: MNColors.iconSurface,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const MNIcon(MNIconData.cloudOff),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(strings.historyPending,
                                style: MNText.meta))
                      ])),
                ],
              ]));
        }
        final e = entries[i - 1];
        return HistoryRow(
            entry: e,
            onTap: () => context.push(MNRoutes.saleDetail(e.clientId)));
      },
    );
  }

  Widget _summary(String label, String value) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: MNColors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: MNText.meta),
        const SizedBox(height: 6),
        Text(value, style: MNText.heading.copyWith(fontSize: 20)),
      ]));
}

/// One sale: time, first product (and how many more), payment and status,
/// amount. A voided sale is muted and struck through; no badges.
class HistoryRow extends ConsumerWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  const HistoryRow({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final e = entry;
    final (status, icon, color) = saleStatus(strings, e);
    final recovered = ref.watch(recoveredSalesProvider
        .select((ids) => ids.valueOrNull?.contains(e.clientId) ?? false));
    final entered = ref.watch(officeEnteredSalesProvider
        .select((ids) => ids.valueOrNull?.contains(e.clientId) ?? false));
    final payment =
        strings.paymentMethodName(e.payment.name, customer: e.customer) +
            (entered
                ? ' · ${strings.lostEnteredByOffice}'
                : recovered
                    ? ' · ${strings.recoveredFromOffice}'
                    : '');
    final title = strings.quantityOf(e.firstProduct, e.firstQuantity) +
        (e.lineCount > 1 ? ' ${strings.moreProducts(e.lineCount - 1)}' : '');
    final muted = e.voided ? MNColors.muted : null;
    final strike = e.voided ? TextDecoration.lineThrough : null;
    final time = strings.hhmm(eatClock(e.recordedAt));
    return MNListRow(
      onTap: onTap,
      semanticLabel: '$time, $title, ${formatTsh(e.total)}, $payment, $status',
      leading: SizedBox(
          width: 44,
          child: ExcludeSemantics(child: Text(time, style: MNText.meta))),
      title: Row(children: [
        if (productImageFor(null, productName: e.firstProduct) != null) ...[
          MNProductImage.thumb(
              image: productImageFor(null, productName: e.firstProduct),
              size: 36),
          const SizedBox(width: 8),
        ],
        Expanded(
            child: ExcludeSemantics(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MNText.body.copyWith(color: muted, decoration: strike)),
        )),
      ]),
      subtitle: Text(payment, style: MNText.meta),
      trailing: SizedBox(
          width: 116,
          child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Expanded(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(formatTsh(e.total),
                          style: MNText.amount
                              .copyWith(color: muted, decoration: strike)))),
              const SizedBox(width: 8),
              MNIcon(icon, size: 16, color: color),
            ]),
          )),
    );
  }
}

/// The one status a sale shows, most important first: voided, verified,
/// waiting on the phone, sent.
(String, MNIconData, Color) saleStatus(Strings strings, HistoryEntry e,
        {bool short = false}) =>
    switch (e) {
      HistoryEntry(voidState: VoidState.accepted, cancelledByOffice: true) => (
          strings.statusCancelledByOffice,
          MNIconData.voidSale,
          MNColors.muted
        ),
      HistoryEntry(voidState: VoidState.accepted) => (
          strings.statusVoided,
          MNIconData.voidSale,
          MNColors.muted
        ),
      HistoryEntry(voidState: VoidState.pending) => (
          short ? strings.statusVoided : strings.statusVoidPending,
          MNIconData.voidSale,
          MNColors.muted
        ),
      HistoryEntry(syncStatus: 'rejected' || 'conflict') => (
          strings.statusSaleRefused,
          MNIconData.warn,
          MNColors.warning
        ),
      HistoryEntry(verified: true) => (
          strings.statusVerified,
          MNIconData.okCircle,
          MNColors.success
        ),
      HistoryEntry(sent: false) => (
          short ? strings.statusWaitingShort : strings.syncWaiting,
          MNIconData.clock,
          MNColors.warning
        ),
      _ => (
          short ? strings.statusSentShort : strings.syncSent,
          MNIconData.cloudOk,
          MNColors.ink2
        ),
    };
