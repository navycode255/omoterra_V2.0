import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/providers.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/reference_card.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/filter_sheet.dart';
import '../../shared/widgets/sheet.dart';
import 'receiving_store.dart';

/// Fetches manifests for the vendor's station and caches them. Failure
/// (offline, no API) leaves the cache as it is.
final deliveriesRefreshProvider = FutureProvider.autoDispose<void>((ref) async {
  final repository = ref.read(vendorRepositoryProvider);
  final manifests = await ref
      .read(sessionProvider.notifier)
      .authorised((token) => repository.deliveries(token));
  await ref.read(receivingStoreProvider).replaceDeliveries(manifests);
});

final deliveriesProvider = StreamProvider.autoDispose<List<DeliveryView>>(
    (ref) => ref.watch(receivingStoreProvider).watchDeliveries());

/// Pokea Bidhaa: deliveries waiting to be counted, and those already
/// counted with where each count stands.
class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  int _tab = 0;
  DateTime? _date;

  Future<void> _filter() async {
    final strings = ref.read(stringsProvider);
    var selected = _date;
    var tab = _tab;
    final today = businessDate(ref.read(clockProvider)());
    final applied = await showMNSheet<bool>(context,
        builder: (sheetContext) => StatefulBuilder(
            builder: (context, update) => MNFilterSheet(
                    title: strings.filterGoods,
                    applyLabel: strings.applyFilters,
                    onApply: () => Navigator.pop(sheetContext, true),
                    onReset: () => update(() {
                          selected = null;
                          tab = 0;
                        }),
                    children: [
                      MNFilterGroup(title: strings.dateLabel, children: [
                        MNFilterOption(
                            label: strings.allRecords,
                            mark: MNFilterMark.radio,
                            selected: selected == null,
                            onTap: () => update(() => selected = null)),
                        MNFilterOption(
                            label: strings.customDate,
                            mark: MNFilterMark.calendar,
                            selected: selected != null,
                            detail: selected == null
                                ? null
                                : strings.date(selected!),
                            onTap: () async {
                              final date = await showMNDateWheelSheet(context,
                                  initial: selected ?? today,
                                  first: DateTime.utc(2020),
                                  last: today);
                              if (date != null) update(() => selected = date);
                            }),
                      ]),
                      MNFilterGroup(title: strings.statusLabel, children: [
                        for (var i = 0; i < 2; i++)
                          MNFilterOption(
                              label: i == 0
                                  ? strings.pendingTab
                                  : strings.receivedTab,
                              mark: MNFilterMark.radio,
                              selected: tab == i,
                              onTap: () => update(() => tab = i)),
                      ]),
                    ])));
    if (applied == true && mounted) {
      setState(() {
        _date = selected;
        _tab = tab;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final refresh = ref.watch(deliveriesRefreshProvider);
    final deliveries = ref.watch(deliveriesProvider);
    return Scaffold(
      appBar: MNWorkflowHeader(title: strings.receive, actions: [
        MNWorkflowHelp(title: strings.receiveHelpTitle, messages: [
          strings.receivePurchaseHelp,
          strings.receiveTransferHelp,
          strings.receiveMissingHelp
        ]),
      ]),
      bottomNavigationBar: MNBottomNav(
          items: [
            MNNavItem(MNIconData.home, strings.home),
            MNNavItem(MNIconData.bag, strings.sales),
            MNNavItem(MNIconData.box, strings.products)
          ],
          currentIndex: 2,
          onSelect: (i) => context
              .go([MNRoutes.home, MNRoutes.sales, MNRoutes.products][i])),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                  child: Semantics(
                      selected: _tab == i,
                      button: true,
                      child: Material(
                        color: _tab == i
                            ? MNColors.roseSurface
                            : MNColors.iconSurface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                            onTap: () => setState(() => _tab = i),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  border: _tab == i
                                      ? const Border(
                                          bottom: BorderSide(
                                              color: MNColors.red, width: 3))
                                      : null),
                              child: Text(
                                  i == 0
                                      ? strings.pendingTab
                                      : strings.receivedTab,
                                  style: MNText.chip.copyWith(
                                      color: _tab == i
                                          ? MNColors.red
                                          : MNColors.ink)),
                            )),
                      ))),
            ],
            const SizedBox(width: 10),
            Container(
                decoration: referenceSurface(radius: 10),
                child: IconButton(
                    tooltip: strings.filter,
                    onPressed: _filter,
                    icon:
                        const MNIcon(MNIconData.filter, color: MNColors.ink2))),
          ]),
        ),
        Expanded(
          child: switch (deliveries) {
            AsyncData(:final value) => _list(
                strings,
                value
                    .where((d) =>
                        (d.status == ReceivingStatus.pending) == (_tab == 0) &&
                        (_date == null ||
                            (eatClock(d.dispatchedAt).year == _date!.year &&
                                eatClock(d.dispatchedAt).month ==
                                    _date!.month &&
                                eatClock(d.dispatchedAt).day == _date!.day)))
                    .toList(),
                refreshing: refresh.isLoading,
                offline: refresh.hasError),
            AsyncError(:final error) => MNErrorState(
                error: error,
                onRetry: () => ref.invalidate(deliveriesProvider)),
            _ => const MNLoadingState(),
          },
        ),
      ]),
    );
  }

  Widget _list(Strings strings, List<DeliveryView> items,
      {required bool refreshing, required bool offline}) {
    if (items.isEmpty) {
      if (refreshing) return const MNLoadingState();
      return LayoutBuilder(
          builder: (context, constraints) => MNRefreshArea(
              onRefresh: () async {
                try {
                  ref.invalidate(deliveriesRefreshProvider);
                  await ref.read(deliveriesRefreshProvider.future);
                } catch (_) {}
              },
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                        height: constraints.maxHeight,
                        child: MNEmptyState(
                          icon: MNIconData.truck,
                          image: 'assets/errors/delivery_state.png',
                          imageWidth: 196,
                          title: _tab == 0
                              ? strings.noDeliveries
                              : strings.noReceived,
                          // An empty list that could not be refreshed says so.
                          message: _tab == 0 && offline
                              ? strings.notConnected
                              : null,
                        ))
                  ])));
    }
    final stationKey = switch (ref.watch(sessionProvider).valueOrNull) {
      SignedIn(:final profile) => profile.stationKey,
      _ => '',
    };
    return MNRefreshArea(
        onRefresh: () async {
          try {
            ref.invalidate(deliveriesRefreshProvider);
            await ref.read(deliveriesRefreshProvider.future);
          } catch (_) {}
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final d = items[i];
            final (status, color) = receivingStatus(strings, d,
                otherStation: d.stationKey != stationKey);
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MNListRow(
                  first: i == 0,
                  onTap: () => context.push(MNRoutes.delivery(d.consignmentId)),
                  semanticLabel: '${d.sender}, ${d.reference}, $status',
                  title: Text(d.sender, style: MNText.title),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d.reference} · ${strings.date(d.dispatchedAt)}',
                            style: MNText.meta),
                        if (d.status != ReceivingStatus.pending &&
                            d.status != ReceivingStatus.accepted)
                          Text(status,
                              style: MNText.meta.copyWith(color: color)),
                      ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // How many products: quantities of different products
                    // (Maini, Ndizi) do not add up to one number.
                    Column(children: [
                      Text('${d.lines.length}', style: MNText.title),
                      Text(strings.deliveryProducts(d.lines.length),
                          style: MNText.meta),
                    ]),
                    const SizedBox(width: 16),
                    MNIcon(
                        d.status == ReceivingStatus.accepted
                            ? MNIconData.check
                            : MNIconData.chevron,
                        color: d.status == ReceivingStatus.accepted
                            ? MNColors.success
                            : MNColors.ink2),
                  ]),
                ));
          },
        ));
  }
}

/// The one status a delivery shows. "Accepted" only when the server said
/// so; a count that exists only on the phone says "saved on phone".
(String, Color) receivingStatus(Strings strings, DeliveryView d,
        {bool otherStation = false}) =>
    switch (d.status) {
      ReceivingStatus.pending when otherStation => (
          strings.statusOtherStation,
          MNColors.warning
        ),
      ReceivingStatus.pending => (strings.statusAwaitingReceipt, MNColors.ink2),
      ReceivingStatus.savedOnPhone => (strings.savedOnPhone, MNColors.warning),
      ReceivingStatus.accepted => (
          strings.statusAcceptedByOffice,
          MNColors.success
        ),
      ReceivingStatus.conflict => (strings.statusNeedsReview, MNColors.error),
      ReceivingStatus.rejected => (strings.statusRefused, MNColors.error),
    };
