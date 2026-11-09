import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/language.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/icon_data.dart';
import '../../core/theme/theme.dart' show mrNyamaOfficeTheme;
import '../../shared/widgets/account.dart';
import '../../shared/widgets/biometric_lock.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../notifications/notification_bell.dart';
import 'approval_screens.dart' show approvalsProvider;
import 'finance_screens.dart' show OfficeFinanceScreen;
import 'owner_reference.dart';
import 'setup_screens.dart' show openingEntriesProvider;
import 'vendor_pay_data.dart' show vendorPayOverviewProvider;
import 'vendor_pay_pages.dart' show VendorPaymentsScreen;

final financeManagerTabProvider = StateProvider<int>((ref) => 0);

class FinanceManagerHomeScreen extends ConsumerStatefulWidget {
  const FinanceManagerHomeScreen({super.key});

  @override
  ConsumerState<FinanceManagerHomeScreen> createState() =>
      _FinanceManagerHomeScreenState();
}

class _FinanceManagerHomeScreenState
    extends ConsumerState<FinanceManagerHomeScreen> {
  late final Set<int> _builtTabs = {ref.read(financeManagerTabProvider)};

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final s = ref.watch(stringsProvider);
    if (auth is! OfficeSignedIn ||
        auth.profile.isOwner ||
        auth.profile.canManagePeople ||
        !auth.profile.roles.contains(StaffRole.finance)) {
      return OwnerPage(
          title: s.financeTasks, strings: s, child: MNNote(s.notAllowed));
    }

    final tab = ref.watch(financeManagerTabProvider);
    final pages = <Widget>[
      _FinanceTasksTab(onSelectTab: _selectTab),
      if (_builtTabs.contains(1))
        const VendorPaymentsScreen(showBack: false, financeWorkspace: true)
      else
        const SizedBox.shrink(),
      if (_builtTabs.contains(2))
        const OfficeFinanceScreen(showBack: false)
      else
        const SizedBox.shrink(),
      if (_builtTabs.contains(3))
        const _FinanceAccountTab()
      else
        const SizedBox.shrink(),
    ];

    double u(double n) => OwnerStyle.px(context, n);
    final destinations = [
      ('verify', s.financeTasks),
      ('store', s.financePaymentsTab),
      ('reports', s.financeBooksTab),
      ('account', s.ownerAccount),
    ];
    return Theme(
      data: mrNyamaOfficeTheme(Theme.of(context)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: OwnerStyle.background,
            systemNavigationBarColor: OwnerStyle.background,
            systemNavigationBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: OwnerStyle.background,
          body: IndexedStack(index: tab, children: pages),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
                color: OwnerStyle.background,
                border:
                    Border(top: BorderSide(color: OwnerStyle.line, width: .7))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: u(MediaQuery.textScalerOf(context).scale(12.5) > 18
                    ? 74
                    : 64),
                child: Row(
                  children: [
                    for (final (index, destination) in destinations.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: tab == index,
                          label: destination.$2,
                          child: InkWell(
                            onTap: () {
                              _selectTab(index);
                            },
                            child: Padding(
                              padding: EdgeInsets.only(top: u(10)),
                              child: Column(
                                children: [
                                  OwnerGlyph(destination.$1,
                                      size: 24,
                                      color: tab == index
                                          ? OwnerStyle.red
                                          : OwnerStyle.navMuted),
                                  SizedBox(height: u(5)),
                                  Text(destination.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OwnerStyle.text(context, 12.5,
                                          weight: 500,
                                          color: tab == index
                                              ? OwnerStyle.red
                                              : OwnerStyle.muted,
                                          spacing: -.2)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _builtTabs.add(index));
    ref.read(financeManagerTabProvider.notifier).state = index;
  }
}

class _FinanceTasksTab extends ConsumerWidget {
  final ValueChanged<int> onSelectTab;
  const _FinanceTasksTab({required this.onSelectTab});

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait<void>([
      ref.refresh(approvalsProvider.future).then<void>((_) {}),
      ref.refresh(vendorPayOverviewProvider.future).then<void>((_) {}),
      ref.refresh(openingEntriesProvider.future).then<void>((_) {}),
    ]);
  }

  int? _dueVendorCount(Map<String, dynamic>? snapshot) {
    final rows = snapshot?['vendors'];
    if (rows is! List) return null;
    var count = 0;
    for (final row in rows) {
      if (row is! Map) return null;
      final due = row['due'];
      if (due != null && due is! num) return null;
      if (row['frequency'] != null && due == null) return null;
      if (due is num && due > 0) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    if (auth is! OfficeSignedIn) return const SizedBox.shrink();

    final approvals = ref.watch(approvalsProvider);
    final payments = ref.watch(vendorPayOverviewProvider);
    final openings = ref.watch(openingEntriesProvider);
    final paymentCount = _dueVendorCount(payments.valueOrNull);
    final openingRows = openings.valueOrNull;
    final hasUnavailableCounts = approvals.hasError ||
        payments.hasError ||
        openings.hasError ||
        (payments.hasValue && paymentCount == null);
    final approvalCount =
        approvals.valueOrNull?.where((item) => item.canDecide).length;
    final openingDraftCount =
        openingRows?.where((OfficeOpeningEntry entry) => entry.isDraft).length;

    Widget divider() => Padding(
        padding: EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 16)),
        child: const Divider(height: 1, thickness: .7, color: OwnerStyle.line));

    return OwnerPage(
      title: s.financeTasks,
      strings: s,
      showBack: false,
      trailing: const NotificationBell(office: true),
      header: Padding(
        padding: EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 19)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const OwnerGlyph('brand', size: 32),
              SizedBox(width: OwnerStyle.px(context, 10)),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.financeBrand,
                          style: OwnerStyle.text(context, 16, weight: 700)),
                      Text(s.roleName(StaffRole.finance),
                          style: OwnerStyle.text(context, 13,
                              color: OwnerStyle.muted)),
                    ]),
              ),
            ]),
            SizedBox(height: OwnerStyle.px(context, 14)),
            Semantics(
                header: true,
                child: Text(s.financeTasks,
                    style: OwnerStyle.text(context, 34,
                        weight: 700, color: OwnerStyle.ink))),
          ],
        ),
      ),
      headingTopGap: 0,
      contentGap: 12,
      onRefresh: () => _refresh(ref),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 13)),
        child: Column(
          children: [
            if (hasUnavailableCounts) ...[
              MNNote(s.financeTaskCountsUnavailable, error: true),
              SizedBox(height: OwnerStyle.px(context, 10)),
            ],
            OwnerCard(
              child: Column(children: [
                OwnerMenuRow(
                    label: s.approvalsTitle,
                    icon: 'verify',
                    value: approvalCount?.toString(),
                    onTap: () => context.push(MNRoutes.officeApprovals)),
                divider(),
                OwnerMenuRow(
                    label: s.vendorPayTitle,
                    icon: 'store',
                    subtitle: s.financeRecordCompletedPayment,
                    value: paymentCount?.toString(),
                    onTap: () => onSelectTab(1)),
                divider(),
                OwnerMenuRow(
                    label: s.financeBooks,
                    icon: 'reports',
                    onTap: () => onSelectTab(2)),
                divider(),
                OwnerMenuRow(
                    label: s.openingTitle,
                    icon: 'stock-box',
                    subtitle: s.financeOpeningDraftsCaption,
                    value: openingDraftCount?.toString(),
                    onTap: () => context.push(MNRoutes.officeOpening)),
                divider(),
                OwnerMenuRow(
                    label: s.opCashShortTitle,
                    icon: 'warning',
                    subtitle: s.financeCashShortUnavailable,
                    labelColor: OwnerStyle.muted,
                    showChevron: false),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceAccountTab extends ConsumerWidget {
  const _FinanceAccountTab();

  void _showSyncInfo(BuildContext context, Strings s) {
    showMNSheet<void>(context,
        builder: (_) => MNSheet(
            title: s.syncInfo, children: [Text(s.financeSyncUnavailable)]));
  }

  void _showAbout(BuildContext context, Strings s) {
    showMNSheet<void>(context,
        builder: (_) => MNSheet(
            title: s.financeAbout, children: [Text(s.financeAboutBody)]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    if (auth is! OfficeSignedIn) return const SizedBox.shrink();
    final profile = auth.profile;

    return OwnerPage(
      title: s.ownerAccount,
      strings: s,
      showBack: false,
      trailing: const NotificationBell(office: true),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MNAccountIdentity(
                name: profile.name,
                subtitle: s.roleName(StaffRole.finance),
                imageUrl: profile.profileImageUrl),
            SizedBox(height: OwnerStyle.px(context, 20)),
            MNAccountSectionTitle(s.accountSettings),
            MNAccountGroup(children: [
              MNAccountRow(
                  title: s.financeLoginSecurity,
                  icon: MNIconData.lock,
                  onTap: () => context.push(MNRoutes.officeChangePin)),
              BiometricSetting(account: biometricAccount('staff', profile.id)),
              MNAccountRow(
                  title: s.notificationsTitle,
                  icon: MNIconData.info,
                  onTap: () => context.push(MNRoutes.officeNotifications)),
              MNAccountRow(
                  title: s.syncInfo,
                  subtitle: s.financeSyncUnavailable,
                  icon: MNIconData.cloudOff,
                  onTap: () => _showSyncInfo(context, s)),
              MNAccountRow(
                  title: s.language,
                  subtitle: s.accountLanguageCaption,
                  value: s.languageName(s.code),
                  icon: MNIconData.accountGlobe,
                  onTap: () => showLanguageSheet(context, ref)),
              MNAccountRow(
                  title: s.financeAbout,
                  icon: MNIconData.info,
                  onTap: () => _showAbout(context, s)),
            ]),
            SizedBox(height: OwnerStyle.px(context, 28)),
            MNAccountSignOut(
                onSignOut: () =>
                    ref.read(officeSessionProvider.notifier).signOut()),
            SizedBox(height: OwnerStyle.px(context, 24)),
          ],
        ),
      ),
    );
  }
}
