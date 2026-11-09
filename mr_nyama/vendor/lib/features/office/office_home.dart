import '../notifications/notification_bell.dart';
import '../../core/auth/biometrics.dart';
import '../../shared/widgets/biometric_lock.dart';
import '../../core/theme/theme.dart' show mrNyamaOfficeTheme;
import '../../core/theme/tokens.dart' show MNSpace;
import '../../shared/widgets/account.dart';
import '../../shared/widgets/icon.dart';
import '../../core/theme/icon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/api/office_repository.dart'
    show OfficeMediaRepository, StaffRole, StaffProfile;
import '../../core/format.dart';
import '../../core/l10n/language.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/states.dart' show MNRefreshArea, MNSkeleton;
import 'people_screens.dart';
import 'owner_overview.dart';
import 'owner_reference.dart';
import 'owner_home_tab.dart';
import 'product_screens.dart';
import 'sync_review_screens.dart';
import 'finance_manager_home.dart';

final pickOfficeProfilePhotoProvider =
    Provider<Future<Uint8List?> Function()>((ref) => () async {
          final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 88,
              requestFullMetadata: false);
          if (file == null) return null;
          if (await file.length() > 5 * 1024 * 1024) {
            throw const FormatException();
          }
          return file.readAsBytes();
        });

/// Owner landing screen measured against the approved Muhtasari reference.
class OfficeHomeScreen extends ConsumerStatefulWidget {
  const OfficeHomeScreen({super.key});
  @override
  ConsumerState<OfficeHomeScreen> createState() => _OfficeHomeScreenState();
}

class _OfficeHomeScreenState extends ConsumerState<OfficeHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final tab = ref.watch(ownerHomeTabProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    if (auth is! OfficeSignedIn) return const Scaffold();
    if (!auth.profile.isOwner) {
      if (auth.profile.canManagePeople) {
        return const OfficeManagementScreen();
      }
      if (auth.profile.roles.contains(StaffRole.finance)) {
        return const FinanceManagerHomeScreen();
      }
      return const OwnerAccountScreen();
    }
    double u(double n) => OwnerStyle.px(context, n);
    return Theme(
        data: mrNyamaOfficeTheme(Theme.of(context)),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: OwnerStyle.background,
              systemNavigationBarColor: OwnerStyle.background,
              systemNavigationBarIconBrightness: Brightness.dark),
          child: Scaffold(
              backgroundColor: OwnerStyle.background,
              body: switch (tab) {
                1 => const _OwnerStationsTab(),
                2 => const OwnerAccountScreen(),
                _ => const _OwnerDashboard(),
              },
              bottomNavigationBar: DecoratedBox(
                decoration: const BoxDecoration(
                    color: OwnerStyle.background,
                    border: Border(
                        top: BorderSide(color: OwnerStyle.line, width: .7))),
                child: SafeArea(
                    top: false,
                    child: SizedBox(
                        height: u(
                            MediaQuery.textScalerOf(context).scale(12.5) > 18
                                ? 74
                                : 64),
                        child: Row(children: [
                          for (final (i, item) in [
                            ('home', s.ownerSummary),
                            ('nav-store', s.stations),
                            ('account', s.ownerAccount)
                          ].indexed)
                            Expanded(
                                child: Semantics(
                                    selected: tab == i,
                                    button: true,
                                    child: InkWell(
                                        onTap: () => ref
                                            .read(ownerHomeTabProvider.notifier)
                                            .state = i,
                                        child: Padding(
                                            padding:
                                                EdgeInsets.only(top: u(10)),
                                            child: Column(children: [
                                              OwnerGlyph(item.$1,
                                                  size: 27,
                                                  color: tab == i
                                                      ? OwnerStyle.red
                                                      : OwnerStyle.navMuted),
                                              SizedBox(height: u(5)),
                                              Text(item.$2,
                                                  style: OwnerStyle.text(
                                                      context, 12.5,
                                                      weight: 500,
                                                      color: tab == i
                                                          ? OwnerStyle.red
                                                          : OwnerStyle.muted,
                                                      spacing: -.2)),
                                            ]))))),
                        ]))),
              )),
        ));
  }
}

class _OwnerDashboard extends ConsumerWidget {
  const _OwnerDashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final state = ref.watch(ownerOverviewProvider);
    final data = state.valueOrNull ?? const OwnerOverview();
    final loading = state.isLoading;
    double u(double n) => OwnerStyle.px(context, n);
    String amount(int? value) => value == null ? '—' : groupDigits(value);
    final today = businessDate(ref.read(clockProvider)());
    final day = ref.watch(ownerDayProvider) ?? today;
    final daysAgo = today.difference(day).inDays;
    final comparison =
        daysAgo == 0 ? s.ownerComparedYesterday : s.ownerComparedDayBefore;
    Future<void> pickDay() async {
      final picked = await showMNDateSheet(context,
          initial: day,
          first: today.subtract(const Duration(days: 365)),
          last: today,
          title: s.ownerChooseDay);
      if (picked != null) {
        ref.read(ownerDayProvider.notifier).state =
            picked == today ? null : picked;
      }
    }

    Widget divider() => Padding(
        padding: EdgeInsets.symmetric(horizontal: u(20)),
        child: const Divider(height: 1, thickness: .7, color: OwnerStyle.line));
    return SafeArea(
        bottom: false,
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: MNRefreshArea(
            onRefresh: () => refreshOwnerDay(ref),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: u(16)),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                    height: u(60),
                    child: Row(children: [
                      const OwnerGlyph('brand', size: 32),
                      SizedBox(width: u(10)),
                      Text(s.brand,
                          style: OwnerStyle.text(context, 17, weight: 700)),
                      const Spacer(),
                      const NotificationBell(office: true),
                    ])),
                Row(children: [
                  Expanded(
                      child: Semantics(
                          header: true,
                          child: Text(s.ownerSummary,
                              style: OwnerStyle.text(context, 34,
                                  weight: 700, spacing: -1.1)))),
                  Material(
                      color: OwnerStyle.line.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(u(24)),
                      child: InkWell(
                          onTap: pickDay,
                          borderRadius: BorderRadius.circular(u(24)),
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  minHeight: 48, minWidth: 48),
                              child: Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: u(16)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            switch (daysAgo) {
                                              0 => s.ownerToday,
                                              1 => s.yesterdayLabel,
                                              _ => s.dayMonth(day)
                                            },
                                            style: OwnerStyle.text(context, 16,
                                                weight: 500)),
                                        SizedBox(width: u(12)),
                                        const OwnerGlyph('down', size: 13),
                                      ]))))),
                ]),
                SizedBox(height: u(14)),
                OwnerCard(
                    radius: 15,
                    child: Padding(
                        padding: EdgeInsets.all(u(16)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  switch (daysAgo) {
                                    0 => s.ownerSalesToday,
                                    1 => s.ownerSalesYesterday,
                                    _ => s.ownerSalesOn(day)
                                  },
                                  style: OwnerStyle.text(context, 15,
                                      color: OwnerStyle.muted)),
                              SizedBox(height: u(6)),
                              InkWell(
                                  onTap: () =>
                                      context.push(MNRoutes.officeMoneyReport),
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 48),
                                      child: Row(children: [
                                        Text(s.ownerCurrency,
                                            style: OwnerStyle.text(context, 20,
                                                weight: 600)),
                                        SizedBox(width: u(7)),
                                        Expanded(
                                            child: loading
                                                ? Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Semantics(
                                                        label: s.loading,
                                                        liveRegion: true,
                                                        child: MNSkeleton(
                                                            width: u(150),
                                                            height: u(34))))
                                                : FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                        amount(data.sales),
                                                        style: OwnerStyle.text(
                                                            context, 30,
                                                            weight: 600,
                                                            spacing: -1)))),
                                        const OwnerGlyph('chevron',
                                            size: 12,
                                            color: OwnerStyle.secondary),
                                      ]))),
                              if (loading)
                                MNSkeleton(width: u(140), height: u(18))
                              else if (data.sales == 0)
                                Text(s.ownerNoSalesYet,
                                    style: OwnerStyle.text(context, 15,
                                        color: OwnerStyle.muted))
                              else if (data.sales != null &&
                                  data.changePercent != null)
                                OwnerOverviewTrend(
                                    percent: data.changePercent!,
                                    comparison: comparison)
                              else
                                Text('—',
                                    style: OwnerStyle.text(context, 15,
                                        color: OwnerStyle.muted)),
                              SizedBox(height: u(12)),
                              const Divider(
                                  height: 1,
                                  thickness: .7,
                                  color: OwnerStyle.line),
                              SizedBox(height: u(12)),
                              // Faida ghafi and the money-differences row stay
                              // hidden until they read reliable figures
                              // (owner decision 31 October 2026).
                              _Metric(
                                  label: s.ownerSupervisorFunds,
                                  value:
                                      '${s.ownerCurrency} ${amount(data.supervisorFunds)}',
                                  loading: loading,
                                  caption: (data.supervisorFunds ?? 0) > 0
                                      ? s.supervisorFundsCaption
                                      : null,
                                  trend: data.supervisorFunds == null ||
                                          data.supervisorFunds == 0
                                      ? null
                                      : data.supervisorFundsChangePercent),
                            ]))),
                SizedBox(height: u(12)),
                OwnerCard(
                    radius: 15,
                    child: Column(children: [
                      _OverviewRow(
                          label: s.ownerStationsOpen,
                          icon: const OwnerGlyph('store', size: 26),
                          subtitle: s.ownerOpenStationsCount(
                              data.openStations, data.totalStations),
                          detail: data.openStations == 0
                              ? s.ownerNoStationsOpen
                              : null,
                          onTap: () => context.push(MNRoutes.officeStations)),
                      divider(),
                      _OverviewRow(
                          label: s.money,
                          subtitle: s.moneyCaption,
                          icon: const MNIcon(MNIconData.cash,
                              size: 27, color: OwnerStyle.ink),
                          onTap: () => context.push(MNRoutes.officeMoney)),
                      divider(),
                      _OverviewRow(
                          label: s.verification,
                          icon: const OwnerGlyph('verify', size: 26),
                          onTap: () =>
                              context.push(MNRoutes.officeVerification)),
                    ])),
                SizedBox(height: u(16)),
                OwnerCard(
                    radius: 15,
                    child: Column(children: [
                      _OverviewRow(
                          label: s.ownerReports,
                          subtitle: s.ownerReportsCaption,
                          icon: const OwnerGlyph('reports', size: 26),
                          onTap: () =>
                              context.push(MNRoutes.officeMoneyReport)),
                      divider(),
                      _OverviewRow(
                          label: s.opTitle,
                          subtitle: s.ownerPerformanceCaption,
                          icon: const MNIcon(MNIconData.overviewStar,
                              size: 28, color: OwnerStyle.ink),
                          onTap: () =>
                              context.push(MNRoutes.officePerformance)),
                      divider(),
                      _OverviewRow(
                          label: s.bonusTitle,
                          subtitle: s.ownerBonusesCaption,
                          icon: const MNIcon(MNIconData.overviewGift,
                              size: 27, color: OwnerStyle.ink),
                          onTap: () => context.push(MNRoutes.officeBonuses)),
                      divider(),
                      _OverviewRow(
                          label: s.ownerManagement,
                          subtitle: s.ownerManagementCaption,
                          icon: const OwnerGlyph('manage', size: 25),
                          onTap: () => context.push(MNRoutes.officeManagement)),
                    ])),
                if (state.hasError)
                  Padding(
                      padding: EdgeInsets.only(top: u(12)),
                      child: MNNote(s.errorBody, error: true)),
                SizedBox(height: u(20)),
              ],
            ),
          ),
        )));
  }
}

/// A directional comparison is neutral; red denotes an actual money alert.
class OwnerOverviewTrend extends StatelessWidget {
  final double percent;
  final String? comparison;
  const OwnerOverviewTrend({super.key, required this.percent, this.comparison});
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      label:
          '${percent < 0 ? '−' : percent > 0 ? '+' : ''}${percent.abs().toStringAsFixed(0)}%${comparison == null ? '' : ' $comparison'}',
      child: ExcludeSemantics(
          child: Row(children: [
        if (percent != 0) ...[
          MNIcon(percent < 0 ? MNIconData.overviewDown : MNIconData.overviewUp,
              size: OwnerStyle.px(context, 17), color: OwnerStyle.ink),
          SizedBox(width: OwnerStyle.px(context, 6)),
        ],
        Flexible(
            child: Text('${percent.abs().toStringAsFixed(0)}%',
                style: OwnerStyle.text(context, 15, weight: 500))),
        if (comparison != null) ...[
          SizedBox(width: OwnerStyle.px(context, 6)),
          Flexible(
              child: Text(comparison!,
                  style:
                      OwnerStyle.text(context, 14, color: OwnerStyle.muted))),
        ],
      ])));
}

class _Metric extends StatelessWidget {
  final String label, value;
  final bool loading;
  final double? trend;

  /// A short note under the figure (for example that it is not confirmed).
  final String? caption;
  const _Metric(
      {required this.label,
      required this.value,
      this.loading = false,
      this.trend,
      this.caption});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
        SizedBox(height: OwnerStyle.px(context, 5)),
        if (loading)
          MNSkeleton(
              width: OwnerStyle.px(context, 96),
              height: OwnerStyle.px(context, 24))
        else
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style:
                      OwnerStyle.text(context, 19, weight: 600, spacing: -.5))),
        if (!loading && caption != null) ...[
          SizedBox(height: OwnerStyle.px(context, 4)),
          Text(caption!,
              style: OwnerStyle.text(context, 12, color: OwnerStyle.muted)),
        ],
        if (!loading && trend != null) ...[
          SizedBox(height: OwnerStyle.px(context, 6)),
          OwnerOverviewTrend(percent: trend!),
        ],
      ]);
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String? subtitle, detail;
  final Widget icon;
  final VoidCallback? onTap;
  const _OverviewRow(
      {required this.label,
      required this.icon,
      this.subtitle,
      this.detail,
      this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minHeight: OwnerStyle.px(context, subtitle == null ? 52 : 54)
                .clamp(48, 120)),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: OwnerStyle.px(context, 20),
              vertical: OwnerStyle.px(context, 8)),
          child: Row(children: [
            SizedBox(
                width: OwnerStyle.px(context, 28), child: Center(child: icon)),
            SizedBox(width: OwnerStyle.px(context, 22)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label, style: OwnerStyle.text(context, 16, weight: 400)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: OwnerStyle.text(context, 12.5,
                            color: OwnerStyle.muted)),
                  if (detail != null)
                    Text(detail!,
                        style: OwnerStyle.text(context, 12.5,
                            color: OwnerStyle.muted)),
                ])),
            if (onTap != null) ...[
              SizedBox(width: OwnerStyle.px(context, 10)),
              const OwnerGlyph('chevron',
                  size: 12, color: OwnerStyle.secondary),
            ],
          ]),
        ),
      ));
}

class OfficeManagementScreen extends ConsumerWidget {
  const OfficeManagementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final allowed = auth is OfficeSignedIn && auth.profile.canManagePeople;
    // The owner reaches verification from Muhtasari.
    final verify = auth is OfficeSignedIn &&
        auth.profile.canVerify &&
        !auth.profile.isOwner;
    final money = auth is OfficeSignedIn &&
        auth.profile.canHandleMoney &&
        !auth.profile.isOwner;
    final owner = auth is OfficeSignedIn && auth.profile.isOwner;
    final review = allowed && syncReviewAccess(ref).review;
    final conflicts =
        review ? ref.watch(syncConflictsProvider).valueOrNull : null;
    final stations =
        allowed ? ref.watch(officeStationsProvider).valueOrNull : null;
    final products =
        allowed ? ref.watch(officeProductsProvider).valueOrNull : null;
    final staff = allowed ? ref.watch(officeStaffProvider).valueOrNull : null;
    final vendors =
        allowed ? ref.watch(officeVendorsProvider).valueOrNull : null;
    final missingVendors = stations?.where((x) => !x.hasVendor).length;
    final missingPrices = products?.where((x) => x.price == null).length;
    Widget row(String label, String caption, String route,
            {String? value, bool alert = false}) =>
        OwnerMenuRow(
            label: label,
            subtitle: caption,
            value: value,
            valueSize: 13,
            valueWeight: 400,
            valueMaxWidth: 125,
            valueColor: alert ? OwnerStyle.assignAction : OwnerStyle.muted,
            height: 64,
            onTap: () => context.push(route));
    Widget group(String title, List<Widget> rows) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 10),
                  OwnerStyle.px(context, 20), 0, OwnerStyle.px(context, 8)),
              child: Text(title.toUpperCase(),
                  style: OwnerStyle.text(context, 12,
                      weight: 600, color: OwnerStyle.muted))),
          OwnerCard(
              child: Column(children: [
            for (final (index, child) in rows.indexed) ...[
              if (index > 0)
                Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: OwnerStyle.px(context, 16)),
                    child: const Divider(
                        height: 1, thickness: .7, color: OwnerStyle.line)),
              child,
            ],
          ])),
        ]);
    return OwnerPage(
        title: s.ownerManagement,
        strings: s,
        trailing: owner ? null : const NotificationBell(office: true),
        contentGap: 0,
        headingSize: 32,
        headingTopGap: 5,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 13)),
            child: allowed
                ? Column(children: [
                    group(s.managementSetup, [
                      row(s.stations, s.ownerStationsCaption,
                          MNRoutes.officeStations,
                          value: missingVendors == null
                              ? null
                              : stations!.isEmpty
                                  ? s.managementNoStations
                                  : missingVendors == 0
                                      ? s.managementAllHaveVendors
                                      : s.ownerMissingVendors(missingVendors),
                          alert: (missingVendors ?? 0) > 0),
                      row(s.vendors, s.ownerVendorsCaption,
                          MNRoutes.officeVendors,
                          value: vendors == null
                              ? null
                              : s.ownerVendorCount(vendors.length)),
                      row(s.manageProducts, s.ownerProductsCaption,
                          MNRoutes.officeProducts,
                          value: missingPrices == null || missingPrices == 0
                              ? null
                              : s.ownerMissingPrices(missingPrices),
                          alert: (missingPrices ?? 0) > 0),
                      row(s.staffMembers, s.ownerStaffCaption,
                          MNRoutes.officeStaff,
                          value: staff == null
                              ? null
                              : s.ownerStaffCount(staff.length)),
                      if (owner)
                        row(s.openingTitle, s.openingCaption,
                            MNRoutes.officeOpening),
                    ]),
                    if (owner || money)
                      group(s.money, [
                        if (owner)
                          row(s.moneySettings, s.moneySettingsCaption,
                              MNRoutes.officeMoneySettings),
                        if (money)
                          row(s.money, s.moneyCaption, MNRoutes.officeMoney),
                      ]),
                    group(s.managementKitchen, [
                      row(s.kitchensTitle, s.kitchensCaption,
                          MNRoutes.officeKitchens),
                      row(s.recipes, s.recipesCaption, MNRoutes.officeRecipes),
                      row(s.production, s.productionCaption,
                          MNRoutes.officeProduction),
                    ]),
                    if (auth.profile.canSeeAssets)
                      group(s.assetsTitle, [
                        row(s.assetsTitle, s.assetsCaption,
                            MNRoutes.officeAssets),
                      ]),
                    if (review || verify)
                      group(s.managementAdministration, [
                        if (review)
                          row(
                              s.managementPendingReview,
                              s.managementPendingCaption,
                              MNRoutes.officeSyncConflicts,
                              value: conflicts == null || conflicts.isEmpty
                                  ? null
                                  : s.managementPendingCount(conflicts.length),
                              alert: (conflicts?.length ?? 0) > 0),
                        if (verify)
                          row(s.verification, s.verification,
                              MNRoutes.officeVerification),
                      ]),
                    group(s.ownerAccount, [
                      row(s.ownerAccount, s.ownerAccountCaption,
                          MNRoutes.officeAccount),
                    ]),
                    SizedBox(height: OwnerStyle.px(context, 28)),
                  ])
                : MNNote(s.notAllowed)));
  }
}

class _OfficeProfilePhotoAction extends ConsumerStatefulWidget {
  final StaffProfile profile;
  const _OfficeProfilePhotoAction({required this.profile});

  @override
  ConsumerState<_OfficeProfilePhotoAction> createState() =>
      _OfficeProfilePhotoActionState();
}

class _OfficeProfilePhotoActionState
    extends ConsumerState<_OfficeProfilePhotoAction> {
  bool _busy = false;
  String? _error;

  Future<void> _changePhoto() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final strings = ref.read(stringsProvider);
    try {
      final bytes = await ref.read(pickOfficeProfilePhotoProvider)();
      if (bytes == null) return;
      final url = await ref.read(officeSessionProvider.notifier).guard((repo) {
        final mediaRepository = repo is OfficeMediaRepository
            ? repo as OfficeMediaRepository
            : null;
        if (mediaRepository == null) {
          throw StateError('Profile photo upload is not configured.');
        }
        return mediaRepository.uploadOwnProfileImage(bytes);
      });
      await ref.read(officeSessionProvider.notifier).updateProfileImageUrl(url);
    } catch (_) {
      if (mounted) setState(() => _error = strings.photoFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Column(children: [
      MNButton.secondary(strings.changeProfilePhoto,
          busy: _busy, onPressed: _busy ? null : _changePhoto),
      if (_error != null) ...[
        const SizedBox(height: MNSpace.x2),
        MNNote(_error!, error: true),
      ],
    ]);
  }
}

class OwnerAccountScreen extends ConsumerWidget {
  const OwnerAccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    if (auth is! OfficeSignedIn) return const SizedBox.shrink();
    final profile = auth.profile;
    final business = <Widget>[
      if (profile.canVerify && !profile.isOwner && !profile.canManagePeople)
        MNAccountRow(
            title: s.verification,
            icon: MNIconData.check,
            onTap: () => context.push(MNRoutes.officeVerification)),
      if (profile.canHandleMoney &&
          !profile.isOwner &&
          !profile.canManagePeople)
        MNAccountRow(
            title: s.money,
            icon: MNIconData.cash,
            onTap: () => context.push(MNRoutes.officeMoney)),
      if (profile.roles.contains(StaffRole.supervisor))
        MNAccountRow(
            title: s.stations,
            icon: MNIconData.bag,
            onTap: () => context.push(MNRoutes.officeStations)),
      if (profile.roles.contains(StaffRole.finance) && !profile.isOwner)
        MNAccountRow(
            title: s.openingTitle,
            subtitle: s.openingCaption,
            icon: MNIconData.bag,
            onTap: () => context.push(MNRoutes.officeOpening)),
      if (profile.isOwner || profile.roles.contains(StaffRole.finance)) ...[
        MNAccountRow(
            title: s.vendorPayTitle,
            subtitle: s.accountPaymentsCaption,
            icon: MNIconData.cash,
            onTap: () => context.push(MNRoutes.officeVendorPayments)),
        MNAccountRow(
            title: s.financeBooks,
            subtitle: s.accountBooksCaption,
            icon: MNIconData.accountBook,
            onTap: () => context.push(MNRoutes.officeFinance)),
      ],
      if (profile.roles.contains(StaffRole.kitchen) &&
          !profile.isOwner &&
          !profile.canManagePeople)
        MNAccountRow(
            title: s.production,
            icon: MNIconData.food,
            onTap: () => context.push(MNRoutes.officeProduction)),
      if (profile.canVerify)
        MNAccountRow(
            title: s.approvalsTitle,
            subtitle: s.approvalsCaption,
            icon: MNIconData.check,
            onTap: () => context.push(MNRoutes.officeApprovals)),
      if (profile.isOwner)
        MNAccountRow(
            title: s.alertSettingsTitle,
            subtitle: s.alertSettingsCaption,
            icon: MNIconData.warn,
            onTap: () => context.push(MNRoutes.officeAlertSettings)),
      if (profile.canSeeAssets && !profile.canManagePeople)
        MNAccountRow(
            title: s.assetsTitle,
            icon: MNIconData.box,
            onTap: () => context.push(MNRoutes.officeAssets)),
      if (profile.canHandleMoney)
        MNAccountRow(
            title: s.moneyExpenses,
            subtitle: s.accountExpensesCaption,
            icon: MNIconData.accountWallet,
            onTap: () =>
                context.push('${MNRoutes.officeMoney}?section=expenses')),
    ];
    return OwnerPage(
        title: s.ownerAccount,
        strings: s,
        showBack: GoRouter.of(context).canPop(),
        // Supervisors and finance land here; the owner's bell is on Muhtasari.
        trailing: profile.isOwner ? null : const NotificationBell(office: true),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MNAccountIdentity(
                      name: profile.name,
                      subtitle: profile.roles.map(s.roleName).join(' · '),
                      imageUrl: profile.profileImageUrl),
                  const SizedBox(height: MNSpace.x3),
                  _OfficeProfilePhotoAction(profile: profile),
                  if (business.isNotEmpty) ...[
                    MNAccountSectionTitle(s.accountBusiness),
                    MNAccountGroup(children: business),
                  ],
                  MNAccountSectionTitle(s.accountSettings),
                  MNAccountGroup(children: [
                    MNAccountRow(
                        title: s.language,
                        subtitle: s.accountLanguageCaption,
                        value: s.languageName(s.code),
                        icon: MNIconData.accountGlobe,
                        onTap: () => showLanguageSheet(context, ref)),
                    BiometricSetting(
                        account: biometricAccount('staff', profile.id)),
                    MNAccountRow(
                        title: s.changePin,
                        icon: MNIconData.lock,
                        onTap: () => context.push(MNRoutes.officeChangePin)),
                    MNAccountRow(
                        title: s.vendorSignIn,
                        subtitle: s.accountVendorCaption,
                        icon: MNIconData.accountUserPlus,
                        onTap: () async {
                          try {
                            await ref
                                .read(officeSessionProvider.notifier)
                                .signOut();
                            if (context.mounted) context.go(MNRoutes.login);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(s.accountSignOutFailed)));
                            }
                          }
                        }),
                  ]),
                  const SizedBox(height: 32),
                  MNAccountSignOut(
                      onSignOut: () =>
                          ref.read(officeSessionProvider.notifier).signOut()),
                  const SizedBox(height: 24),
                ])));
  }
}

class _OwnerStationsTab extends StatelessWidget {
  const _OwnerStationsTab();
  @override
  Widget build(BuildContext context) =>
      const OfficeStationsScreen(showBack: false);
}
