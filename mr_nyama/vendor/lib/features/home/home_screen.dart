import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../notifications/notification_bell.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/business_day.dart';
import '../../core/sync/unsent_age.dart';
import '../closing/closing_store.dart';
import '../sales/sales_store.dart' show mpesaRecipientProvider;
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/format.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/sync_indicator.dart';
import 'dashboard.dart';
import '../supply/supply_request_list.dart';
import 'lead_section.dart';
import 'progress_card.dart';

/// Nyumbani: who is signed in, today's recorded sales and count from the
/// server, the four quick actions and the latest five sales. Sections rise
/// in one after another (`m-rise`, 40 ms apart).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final auth = ref.watch(sessionProvider).valueOrNull;
    final name = auth is SignedIn ? auth.profile.name : '';
    final profileImageUrl =
        auth is SignedIn ? auth.profile.profileImageUrl : null;
    final dashboard = ref.watch(dashboardProvider);
    final shell = StatefulNavigationShell.maybeOf(context);
    return MNReferencePage(
        child: MNRefreshArea(
      color: MNColors.red,
      onRefresh: () {
        ref.invalidate(vendorProgressProvider);
        ref.invalidate(supplyHeldProvider);
        return ref
            .refresh(dashboardProvider.future)
            .then((_) {}, onError: (_) {});
      },
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            MNVendorHeading(
                brand: strings.brand,
                title: strings.home,
                actions: [
                  MNSyncIndicator(
                      status: ref.watch(syncStatusProvider),
                      pendingCount: ref.watch(syncOutstandingCountProvider),
                      onTap: () => context.push(MNRoutes.sync),
                      compact: true),
                  const NotificationBell(office: false),
                  MNPressable(
                      onTap: () => context.push(MNRoutes.profile),
                      semanticLabel: strings.profile,
                      child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                              child: MNPersonPhoto(
                            imageUrl: profileImageUrl,
                            size: 38,
                            color: MNColors.referenceAvatar,
                            initials: Text(MNAvatar.initials(name),
                                style: MNText.referenceBody),
                          )))),
                ]),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayCard(dashboard: dashboard),
                      const ProgressCard(),
                      const SupplyHeldRow(),
                      const SizedBox(height: 12),
                      MNButton(strings.recordSale,
                          icon: MNIconData.plus,
                          onPressed: () => shell?.goBranch(1)),
                      const SizedBox(height: 13),
                      MNReferenceSurface(
                          child: Column(children: [
                        MNReferenceMenuAction(
                            icon: MNIconData.receive,
                            label: strings.referenceReceive,
                            onTap: () => context.push(MNRoutes.receive)),
                        MNReferenceMenuAction(
                            icon: MNIconData.damage,
                            label: strings.damaged,
                            divider: true,
                            onTap: () => context.push(MNRoutes.damaged)),
                        MNReferenceMenuAction(
                            icon: MNIconData.lock,
                            label: strings.referenceCloseDay,
                            divider: true,
                            onTap: () => context.push(MNRoutes.closeDay)),
                        MNReferenceMenuAction(
                            icon: MNIconData.box,
                            label: strings.supplyAsk,
                            divider: true,
                            onTap: () => context.push(MNRoutes.supplyRequests)),
                        MNReferenceMenuAction(
                            icon: MNIconData.more,
                            label: strings.moreActions,
                            divider: true,
                            onTap: () => _openMore(context, strings)),
                      ])),
                      const LeadSection(),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: Semantics(
                                header: true,
                                child: Text(strings.referenceRecentSales,
                                    style: MNText.referenceSection))),
                        MNPressable(
                            onTap: () => context.push(MNRoutes.history),
                            semanticLabel: strings.seeAll,
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Row(children: [
                                  ExcludeSemantics(
                                      child: Text(strings.seeAll,
                                          style: MNText.withWeight(
                                              MNText.referenceCaption,
                                              FontWeight.w500))),
                                  const SizedBox(width: 4),
                                  const MNIcon(MNIconData.chevron,
                                      size: 18, color: MNColors.referenceMuted),
                                ]))),
                      ]),
                    ])),
            _RecentSales(dashboard: dashboard),
          ]),
    ));
  }
}

/// The two jobs that are not daily, in a themed sheet.
void _openMore(BuildContext context, Strings strings) {
  showMNSheet<void>(context,
      builder: (sheet) => MNSheet(children: [
            MNReferenceSurface(
                child: Column(children: [
              MNReferenceMenuAction(
                  icon: MNIconData.cash,
                  label: strings.moneyExpenses,
                  onTap: () {
                    Navigator.pop(sheet);
                    context.push(MNRoutes.expenses);
                  }),
              MNReferenceMenuAction(
                  icon: MNIconData.user,
                  label: strings.creditCustomers,
                  divider: true,
                  onTap: () {
                    Navigator.pop(sheet);
                    context.push(MNRoutes.credit);
                  }),
            ])),
          ]));
}

/// The slate "Mauzo ya Leo" card: total and count as the server reports them.
class _TodayCard extends ConsumerWidget {
  final AsyncValue<DashboardSummary> dashboard;
  const _TodayCard({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return switch (dashboard) {
      AsyncData(:final value) => MNReferenceSurface(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(strings.referenceTodaySales,
                              style: MNText.referenceBody
                                  .copyWith(color: MNColors.referenceMuted))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(strings.transactionCount(value.saleCount),
                              style: MNText.referenceCaption,
                              textAlign: TextAlign.end)),
                    ]),
                    const SizedBox(height: 1),
                    Semantics(
                        label: formatTsh(value.todayTotal),
                        child: ExcludeSemantics(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(strings.tzs,
                                              style: MNText.referenceCurrency),
                                          const SizedBox(width: 5),
                                          Text(groupDigits(value.todayTotal),
                                              style: MNText.referenceAmount),
                                        ]))))),
                    const SizedBox(height: 6),
                    const Divider(
                        height: 1, thickness: 1, color: MNColors.referenceLine),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Expanded(
                              child: _PaymentTotal(
                                  label: strings.cash,
                                  total: value.cashTotal ??
                                      (value.saleCount == 0 ? 0 : null))),
                          // Past M-Pesa sales stay visible; otherwise it
                          // shows only once a receiving number exists.
                          if (ref.watch(mpesaRecipientProvider).valueOrNull !=
                                  null ||
                              (value.mpesaTotal ?? 0) > 0) ...[
                            const VerticalDivider(
                                width: 30,
                                thickness: 1,
                                color: MNColors.referenceLine),
                            Expanded(
                                child: _PaymentTotal(
                                    label: strings.mpesaShort,
                                    total: value.mpesaTotal ??
                                        (value.saleCount == 0 ? 0 : null))),
                          ],
                        ])),
                    // Credit is revenue, not cash in hand (MN018): shown
                    // apart, only on a day with credit sales.
                    if ((value.creditTotal ?? 0) > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                          strings.creditSalesNotCash(
                              formatTsh(value.creditTotal!)),
                          style: MNText.meta),
                    ],
                    // Yesterday not closed: part of today's card.
                    if (_YesterdayRow.shows(ref)) ...[
                      const SizedBox(height: 12),
                      const Divider(
                          height: 1,
                          thickness: 1,
                          color: MNColors.referenceLine),
                      const _YesterdayRow(),
                    ],
                    if (_UnsentRow.shows(ref)) ...[
                      const SizedBox(height: 12),
                      const Divider(
                          height: 1,
                          thickness: 1,
                          color: MNColors.referenceLine),
                      const _UnsentRow(),
                    ],
                  ]))),
      AsyncError(:final error) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _failure(strings, error, ref),
          if (_YesterdayRow.shows(ref) || _UnsentRow.shows(ref)) ...[
            const SizedBox(height: 12),
            MNReferenceSurface(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      if (_YesterdayRow.shows(ref)) const _YesterdayRow(),
                      if (_UnsentRow.shows(ref)) const _UnsentRow(),
                    ]))),
          ],
        ]),
      _ => const MNSkeleton(height: 112, radius: MNRadius.medium),
    };
  }

  Widget _failure(Strings strings, Object error, WidgetRef ref) {
    final failure = error is AuthFailure ? error : null;
    if (failure?.kind == AuthFailureKind.offline) {
      return MNNote(strings.offlineDashboard);
    }
    return MNErrorState(
        message: failure == null ? null : strings.failure(failure),
        onRetry: () => ref.invalidate(dashboardProvider));
  }
}

class _PaymentTotal extends StatelessWidget {
  final String label;
  final int? total;
  const _PaymentTotal({required this.label, required this.total});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: MNText.referenceCaption),
        const SizedBox(height: 2),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(total == null ? '—' : groupDigits(total!),
                style: MNText.referencePayment)),
      ]);
}

/// The latest five sales, compact; or one quiet line when there are none.
class _RecentSales extends ConsumerWidget {
  final AsyncValue<DashboardSummary> dashboard;
  const _RecentSales({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return switch (dashboard) {
      AsyncData(:final value) when value.recent.isEmpty => Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: MNSpace.x4, vertical: 24),
          child: Center(
              child: Text(strings.referenceNoSales,
                  style: MNText.referenceBody
                      .copyWith(color: MNColors.referenceMuted))),
        ),
      AsyncData(:final value) => Column(children: [
          for (final (i, sale) in value.recent.take(5).indexed)
            MNTransactionRow(
              first: i == 0,
              compact: true,
              time: strings.hhmm(sale.recordedAt),
              product: sale.product,
              quantity: sale.quantity,
              paymentMethod: strings.paymentMethodName(sale.payment.name,
                  customer: sale.customer),
              mobileMoney: sale.payment == PaymentMethod.mpesa,
              amount: sale.amount,
              voided: sale.voided,
            ),
        ]),
      AsyncError() => const SizedBox.shrink(),
      _ =>
        const SizedBox(height: 3 * MNSize.row, child: MNLoadingState(rows: 3)),
    };
  }
}

/// Yesterday worked but not closed (owner decision 26 October 2026): one
/// quiet row in today's card. While nothing has been done today it opens
/// Funga Siku; once today's work has begun the office handles that count.
class _YesterdayRow extends ConsumerWidget {
  const _YesterdayRow();

  static bool shows(WidgetRef ref) =>
      switch (ref.watch(yesterdayClosingProvider).valueOrNull) {
        YesterdayClosing.open || YesterdayClosing.missed => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final open = ref.watch(yesterdayClosingProvider).valueOrNull ==
        YesterdayClosing.open;
    final day = strings.date(businessDate(ref.read(clockProvider)())
        .subtract(const Duration(days: 1)));
    final caption = open
        ? strings.yesterdayCloseCaption(day)
        : strings.yesterdayMissedCaption(day);
    return MNPressable(
        onTap: open ? () => context.push(MNRoutes.closeDay) : null,
        semanticLabel: '${strings.yesterdayNotClosed}. $caption',
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ExcludeSemantics(
                    child: Row(children: [
                  const MNIcon(MNIconData.warn,
                      size: 22, strokeWidth: 1.4, color: MNColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(strings.yesterdayNotClosed,
                            style: MNText.withWeight(
                                    MNText.referenceBody, FontWeight.w600)
                                .copyWith(color: MNColors.warning)),
                        Text(caption, style: MNText.referenceCaption),
                      ])),
                  if (open) ...[
                    const SizedBox(width: 8),
                    const MNIcon(MNIconData.chevron,
                        size: 18, color: MNColors.referenceMuted),
                  ],
                ])))));
  }
}

/// Records unsent for more than one business day (a fixed rule): one quiet
/// row in today's card that opens Usawazishaji. Status colour only.
class _UnsentRow extends ConsumerWidget {
  const _UnsentRow();

  static bool shows(WidgetRef ref) => ref.watch(unsentWarningProvider) != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final since = ref.watch(unsentWarningProvider);
    if (since == null) return const SizedBox.shrink();
    final label = strings.unsentSince(strings.date(since));
    return MNPressable(
        onTap: () => context.push(MNRoutes.sync),
        semanticLabel: label,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ExcludeSemantics(
                    child: Row(children: [
                  const MNIcon(MNIconData.warn,
                      size: 22, strokeWidth: 1.4, color: MNColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(label,
                          style: MNText.withWeight(
                                  MNText.referenceBody, FontWeight.w600)
                              .copyWith(color: MNColors.warning))),
                  const SizedBox(width: 8),
                  const MNIcon(MNIconData.chevron,
                      size: 18, color: MNColors.referenceMuted),
                ])))));
  }
}
