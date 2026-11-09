import '../../features/office/approval_screens.dart';
import '../../features/office/closing_case_screens.dart';
import '../../features/office/lost_sale_screens.dart';
import '../../features/notifications/message_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/office/menu_screens.dart';
import '../../features/office/vendor_pay_pages.dart';
import '../../features/credit/credit_screen.dart';
import '../../features/office/credit_screens.dart';
import '../../features/office/setup_screens.dart';
import '../../features/expenses/expense_screen.dart';
import '../../features/expenses/handovers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../dev/showcase.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/pin_screens.dart';
import '../../features/authentication/splash_screen.dart';
import '../../features/closing/closing_screen.dart';
import '../../features/closing/closing_status.dart';
import '../../features/damage/damage_report_screen.dart';
import '../../features/damage/damage_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/sale_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/change_pin_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/sync_screen.dart';
import '../../features/receiving/delivery_screen.dart';
import '../../features/receiving/receipt_saved_screen.dart';
import '../../features/receiving/receive_screen.dart';
import '../../features/sales/cart_screen.dart';
import '../../features/sales/sale_saved_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/stock/stock_screen.dart';
import '../../features/supply/supply_request_form.dart';
import '../../features/supply/supply_request_list.dart';
import '../../features/office/asset_forms.dart';
import '../../features/office/asset_screens.dart';
import '../../features/office/supply_request_screens.dart';
import '../../features/office/office_home.dart';
import '../../features/office/office_sign_in.dart';
import '../../features/office/people_screens.dart';
import '../../features/office/station_screen.dart';
import '../../features/office/person_screens.dart';
import '../../features/office/product_screens.dart';
import '../../features/office/staff_stations_screen.dart';
import '../../features/office/balance_screens.dart';
import '../../features/office/finance_screens.dart';
import '../../features/office/money_screens.dart';
import '../../features/office/verification_screens.dart';
import '../../features/office/stock_screens.dart';
import '../../features/office/sync_review_screens.dart';
import '../../features/office/production_screens.dart';
import '../../features/owner/bonus_screens.dart';
import '../../features/owner/money_report_screen.dart';
import '../../features/owner/performance_screens.dart';
import '../../features/owner/performance_settings_screen.dart';
import '../auth/office_session.dart';
import '../auth/session.dart';
import '../theme/motion.dart';
import 'routes.dart';

/// A secondary screen with the design system's push/pop transition
/// (220 ms in, 140 ms out), or none under reduced motion.
GoRoute mnRoute(
        {required String path,
        required Widget Function(BuildContext, GoRouterState) builder}) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) {
        final child = builder(context, state);
        if (MNMotion.reduced(context)) {
          return NoTransitionPage<void>(key: state.pageKey, child: child);
        }
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: MNMotion.page,
          reverseTransitionDuration: MNMotion.exit,
          child: child,
          transitionsBuilder: (context, animation, secondary, child) =>
              MNPageTransition(
                  animation: animation,
                  secondaryAnimation: secondary,
                  child: child),
        );
      },
    );

/// Sign-in screens cross-fade (`m-in-fade` 200 ms / `m-out-fade` 120 ms),
/// so the photographic login dissolves into the PIN screen.
GoRoute mnFadeRoute(
        {required String path,
        required Widget Function(BuildContext, GoRouterState) builder}) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) {
        final child = builder(context, state);
        if (MNMotion.reduced(context)) {
          return NoTransitionPage<void>(key: state.pageKey, child: child);
        }
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: MNMotion.fadeIn,
          reverseTransitionDuration: MNMotion.fadeOut,
          child: child,
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
              opacity: CurvedAnimation(
                  parent: animation,
                  curve: MNMotion.easeOut,
                  reverseCurve: MNMotion.easeIn),
              child: child),
        );
      },
    );

/// Tab roots switch without a page transition; the shell plays `m-tab-in`.
GoRoute _tabRoot(String path, Widget screen) => GoRoute(
    path: path,
    pageBuilder: (_, state) =>
        NoTransitionPage<void>(key: state.pageKey, child: screen));

/// Where the sessions allow the user to be. Returns null to stay.
///
/// Office (staff) mode is separate from the vendor app: a signed-in office
/// account sees only `/ofisi` screens, and the office sign-in screens are
/// reachable only while no vendor is signed in. A lead office session (a
/// seller who is an Outlet Lead) is not office mode: see below.
String? sessionRedirect(AsyncValue<AuthState> session, String path,
    {OfficeAuth? office}) {
  if (path.startsWith('/dev/')) return null;
  final inOffice =
      path == MNRoutes.office || path.startsWith('${MNRoutes.office}/');
  if (office is OfficeSignedIn && office.viaLead) {
    // A lead session belongs to the seller: vendor rules apply, and only the
    // lead's office pages open (never the office sign-in or home).
    if (inOffice) {
      final allowed = MNRoutes.isLeadOfficePath(path);
      if (allowed && session.valueOrNull is SignedIn) return null;
      return sessionRedirect(session, MNRoutes.home) ?? MNRoutes.home;
    }
  } else if (office is OfficeSignedIn) {
    // Only the owner registers assets; everyone else reads the register.
    if (path == MNRoutes.officeAssetNew && !office.profile.isOwner) {
      return MNRoutes.officeAssets;
    }
    return inOffice && !MNRoutes.officeSignInFlow.contains(path)
        ? null
        : MNRoutes.office;
  }
  if (inOffice) {
    final vendorIn =
        session.valueOrNull is SignedIn || session.valueOrNull is Locked;
    if (MNRoutes.officeSignInFlow.contains(path) && !vendorIn) return null;
    return vendorIn ? MNRoutes.home : MNRoutes.officeSignIn;
  }
  if (session.isLoading && !session.hasValue) {
    return path == MNRoutes.splash ? null : MNRoutes.splash;
  }
  final auth = session.valueOrNull ?? const SignedOut();
  final inSignIn = MNRoutes.signInFlow.contains(path);
  return switch (auth) {
    SignedIn() =>
      inSignIn || path == MNRoutes.splash || path == MNRoutes.suspended
          ? MNRoutes.home
          : null,
    Locked() => inSignIn && path != MNRoutes.login ? null : MNRoutes.pin,
    SignedOut() => inSignIn ? null : MNRoutes.login,
    Suspended() => path == MNRoutes.suspended ? null : MNRoutes.suspended,
  };
}

/// Adds the development component showcase. Defaults to
/// [devShowcaseEnabled], which is always false in release builds.
final showcaseRouteProvider = Provider<bool>((ref) => devShowcaseEnabled);

final routerProvider = Provider<GoRouter>((ref) {
  final showcase = ref.watch(showcaseRouteProvider);
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.listen(officeSessionProvider, (_, __) => refresh.value++);
  final router = GoRouter(
    initialLocation:
        devShowcaseEnabled && showcase ? MNRoutes.showcase : MNRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final vendor = ref.read(sessionProvider);
      final office = ref.read(officeSessionProvider);
      // Restore both independent sessions before choosing the startup route.
      // Only gate startup: ordinary navigation never replays the splash.
      if (state.uri.path == MNRoutes.splash &&
          ((vendor.isLoading && !vendor.hasValue) ||
              (office.isLoading && !office.hasValue))) {
        return null;
      }
      return sessionRedirect(vendor, state.uri.path,
          office: office.valueOrNull);
    },
    routes: [
      GoRoute(
          path: MNRoutes.splash,
          pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey, child: const SplashScreen())),
      mnFadeRoute(
          path: MNRoutes.login, builder: (_, __) => const LoginScreen()),
      mnFadeRoute(path: MNRoutes.pin, builder: (_, __) => const PinScreen()),
      mnRoute(
          path: MNRoutes.activate,
          builder: (_, __) => const ActivationScreen()),
      mnRoute(
          path: MNRoutes.createPin,
          builder: (_, __) => const CreatePinScreen()),
      mnRoute(
          path: MNRoutes.confirmPin,
          builder: (_, __) => const CreatePinScreen(confirm: true)),
      mnRoute(
          path: MNRoutes.forgotPin,
          builder: (_, __) => const ForgotPinScreen()),
      // Office (staff) mode.
      mnFadeRoute(
          path: MNRoutes.officeSignIn,
          builder: (_, __) => const OfficeSignInScreen()),
      mnRoute(
          path: MNRoutes.officePin,
          builder: (_, __) => const OfficePinScreen()),
      mnRoute(
          path: MNRoutes.officeForgotPin,
          builder: (_, __) => const OfficeForgotPinScreen()),
      mnRoute(
          path: MNRoutes.officeChangePin,
          builder: (_, __) => const ChangePinScreen(office: true)),
      mnRoute(
          path: MNRoutes.officeCode,
          builder: (_, __) => const OfficeCodeScreen()),
      mnRoute(
          path: MNRoutes.officeCreatePin,
          builder: (_, __) => const OfficeCreatePinScreen()),
      mnRoute(
          path: MNRoutes.officeConfirmPin,
          builder: (_, __) => const OfficeCreatePinScreen(confirm: true)),
      mnFadeRoute(
          path: MNRoutes.office, builder: (_, __) => const OfficeHomeScreen()),
      mnRoute(
          path: MNRoutes.officeManagement,
          builder: (_, __) => const OfficeManagementScreen()),
      mnRoute(
          path: MNRoutes.officeAccount,
          builder: (_, __) => const OwnerAccountScreen()),
      mnRoute(
          path: MNRoutes.officeNewProduct,
          builder: (_, __) => const OfficeNewProductScreen()),
      mnRoute(
          path: MNRoutes.officeVendors,
          builder: (_, __) => const OfficeVendorsScreen()),
      mnRoute(
          path: MNRoutes.officeNewVendor,
          builder: (_, __) => const OfficeNewVendorScreen()),
      mnRoute(
          path: MNRoutes.officeStaff,
          builder: (_, __) => const OfficeStaffScreen()),
      mnRoute(
          path: MNRoutes.officeNewStaff,
          builder: (_, __) => const OfficeNewStaffScreen()),
      // After the `mpya` routes, which they would otherwise match.
      mnRoute(
          path: MNRoutes.officeVendorPattern,
          builder: (_, state) =>
              OfficeVendorScreen(vendorId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeLostSalesPattern,
          builder: (_, state) =>
              LostSalesScreen(vendorId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeLostSaleNewPattern,
          builder: (_, state) =>
              LostSaleFormScreen(vendorId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeStaffMemberPattern,
          builder: (_, state) =>
              OfficeStaffMemberScreen(staffId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeMenuImport,
          builder: (_, __) => const MenuImportScreen()),
      mnRoute(
          path: '/ofisi/vituo/:id/menyu',
          builder: (_, state) =>
              StationMenuScreen(stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeProducts,
          builder: (_, __) => const OfficeProductsScreen()),
      mnRoute(
          path: MNRoutes.officeProductPattern,
          builder: (_, state) =>
              OfficeProductScreen(code: state.pathParameters['code']!)),
      mnRoute(
          path: MNRoutes.officeStaffStationsPattern,
          builder: (_, state) =>
              StaffStationsScreen(staffId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeStationPattern,
          builder: (_, state) =>
              OfficeStationScreen(stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeStationVendorPattern,
          builder: (_, state) => StationVendorScreen(
              stationId: state.pathParameters['id']!,
              vendorId: state.pathParameters['vendor']!)),
      mnRoute(
          path: MNRoutes.officeStations,
          builder: (_, __) => const OfficeStationsScreen()),
      mnRoute(
          path: MNRoutes.officeVerification,
          builder: (_, __) => const OfficeVerificationScreen()),
      mnRoute(
          path: MNRoutes.officeVerificationStationPattern,
          builder: (_, state) => OfficeVerificationStationScreen(
              stationId: state.pathParameters['id']!,
              openDamage: state.uri.queryParameters['section'] == 'damage')),
      mnRoute(
          path: MNRoutes.officeVerificationProblemsPattern,
          builder: (_, state) => OfficeVerificationProblemsScreen(
              stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeClosingCasesPattern,
          builder: (_, state) =>
              ClosingCasesScreen(stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeClosingCasePattern,
          builder: (_, state) => ClosingCaseScreen(
              caseId: state.pathParameters['id']!,
              stationId: state.uri.queryParameters['kituo'])),
      mnRoute(
          path: MNRoutes.officeSyncConflicts,
          builder: (_, __) => const OfficeSyncConflictsScreen()),
      mnRoute(
          path: MNRoutes.officeNotifications,
          builder: (_, __) => const OfficeNotificationsScreen()),
      mnRoute(
          path: MNRoutes.officeNewMessage,
          builder: (_, __) => const OfficeMessageScreen()),
      mnRoute(
          path: MNRoutes.officeApprovals,
          builder: (_, __) => const OfficeApprovalsScreen()),
      mnRoute(
          path: MNRoutes.officeAlertSettings,
          builder: (_, __) => const OwnerAlertSettingsScreen()),
      mnRoute(
          path: MNRoutes.officeSyncConflictPattern,
          builder: (_, state) =>
              OfficeSyncConflictScreen(opId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeFinance,
          builder: (_, __) => const OfficeFinanceScreen()),
      mnRoute(
          path: MNRoutes.officeFinanceAccounts,
          builder: (_, __) => const OfficeFinanceAccountsScreen()),
      mnRoute(
          path: MNRoutes.officeFinanceMap,
          builder: (_, __) => const OfficeFinanceMapScreen()),
      mnRoute(
          path: MNRoutes.officeFinancePeriods,
          builder: (_, __) => const OfficeFinancePeriodsScreen()),
      mnRoute(
          path: MNRoutes.officeFinanceJournal,
          builder: (_, __) => const OfficeFinanceJournalScreen()),
      mnRoute(
          path: MNRoutes.officeFinanceReports,
          builder: (_, __) => const OfficeFinanceReportsScreen()),
      mnRoute(
          path: MNRoutes.officeVendorPayments,
          builder: (_, __) => const VendorPaymentsScreen()),
      mnRoute(
          path: MNRoutes.officeVendorPayPattern,
          builder: (_, state) => VendorPaymentStatementScreen(
              vendor: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeBonuses,
          builder: (_, __) => const OwnerBonusesScreen()),
      mnRoute(
          path: MNRoutes.officeVendorBonusPattern,
          builder: (_, state) => OwnerVendorBonusScreen(
              vendorId: state.pathParameters['vendor']!,
              period: state.uri.queryParameters['period'],
              date: state.uri.queryParameters['date'],
              selectedDay: state.uri.queryParameters['day'])),
      mnRoute(
          path: MNRoutes.officeVerifiedSalesPattern,
          builder: (_, state) => OwnerVerifiedSalesScreen(
              stationId: state.pathParameters['station']!,
              date: state.uri.queryParameters['date'])),
      mnRoute(
          path: MNRoutes.officePerformanceSettings,
          builder: (_, __) => const OwnerPerformanceSettingsScreen()),
      mnRoute(
          path: MNRoutes.officePerformance,
          builder: (_, __) => const OwnerPerformanceScreen()),
      mnRoute(
          path: MNRoutes.officePerformanceAttentionPath,
          builder: (_, state) {
            final extra = state.extra;
            final labels = extra is Map<String, String> ? extra : const {};
            return OwnerPerformanceAttentionScreen(
                kind: state.uri.queryParameters['kind'] ?? '',
                stationId: state.uri.queryParameters['station'] ?? '',
                vendorId: state.uri.queryParameters['vendor'] ?? '',
                stationName: labels['station'],
                vendorName: labels['vendor'],
                recordId: state.uri.queryParameters['record'],
                date: state.uri.queryParameters['date'],
                lastSyncedAt: state.uri.queryParameters['last_synced_at']);
          }),
      mnRoute(
          path: MNRoutes.officePerformanceVendorPattern,
          builder: (_, state) => OwnerVendorScorecardScreen(
              vendorId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officePerformanceStaffPattern,
          builder: (_, state) =>
              OwnerStaffScorecardScreen(staffId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officePerformanceStationPattern,
          builder: (_, state) => OwnerStationPerformanceScreen(
              stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeMoneyReport,
          builder: (_, __) => const OwnerMoneyReportScreen()),
      mnRoute(
          path: MNRoutes.officeMoney,
          builder: (_, state) => OfficeMoneyScreen(
              openExpenses:
                  state.uri.queryParameters['section'] == 'expenses')),
      // Before the station pattern, which would otherwise match it.
      mnRoute(
          path: MNRoutes.officeMoneySettings,
          builder: (_, __) => const OfficeMoneySettingsScreen()),
      mnRoute(
          path: MNRoutes.officeMoneyStationPattern,
          builder: (_, state) => OfficeMoneyStationScreen(
              stationId: state.pathParameters['id']!,
              openExpenses:
                  state.uri.queryParameters['section'] == 'expenses')),
      mnRoute(
          path: MNRoutes.officeVendorMoneyPattern,
          builder: (_, state) => OfficeVendorMoneyScreen(
              vendorId: state.pathParameters['vendor']!)),
      mnRoute(
          path: MNRoutes.officeMoneyVendorDayPattern,
          builder: (_, state) => OfficeMoneyVendorDayScreen(
              stationId: state.pathParameters['id']!,
              date: state.pathParameters['date']!,
              vendorId: state.pathParameters['vendor']!)),
      mnRoute(
          path: MNRoutes.officeCreditPattern,
          builder: (_, state) => OfficeCreditCustomersScreen(
              stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeCreditCustomerPattern,
          builder: (_, state) => OfficeCreditCustomerScreen(
              customerId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeStockPattern,
          builder: (_, state) =>
              OfficeStockScreen(
                  stationId: state.pathParameters['id']!,
                  openDeliveries:
                      state.uri.queryParameters['section'] == 'deliveries')),
      mnRoute(
          path: MNRoutes.officeStockReturnPattern,
          builder: (_, state) =>
              OfficeStockReturnScreen(stationId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeRecipes,
          builder: (_, __) => const OfficeRecipesScreen()),
      mnRoute(
          path: MNRoutes.officeRecipePattern,
          builder: (_, state) =>
              OfficeRecipeScreen(recipeId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeRecipeNewVersionPattern,
          builder: (_, state) =>
              OfficeRecipeVersionScreen(recipeId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeOpening,
          builder: (_, __) => const OfficeOpeningStockScreen()),
      mnRoute(
          path: MNRoutes.officeOpeningNew,
          builder: (_, __) => const OfficeOpeningFormScreen()),
      mnRoute(
          path: MNRoutes.officeKitchens,
          builder: (_, __) => const OfficeKitchensScreen()),
      mnRoute(
          path: MNRoutes.officeProduction,
          builder: (_, __) => const OfficeProductionScreen()),
      // Before the run pattern, which would otherwise match it.
      mnRoute(
          path: MNRoutes.officeProductionNew,
          builder: (_, __) => const OfficeProductionRunForm()),
      mnRoute(
          path: MNRoutes.officeProductionRunPattern,
          builder: (_, state) =>
              OfficeProductionRunScreen(runId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeIssuedCode,
          builder: (_, state) =>
              OfficeIssuedCodeScreen(args: state.extra! as IssuedCodeArgs)),
      mnFadeRoute(
          path: MNRoutes.suspended,
          builder: (_, __) => const SuspendedScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MNShell(shell: shell),
        branches: [
          StatefulShellBranch(
              routes: [_tabRoot(MNRoutes.home, const HomeScreen())]),
          StatefulShellBranch(
              routes: [_tabRoot(MNRoutes.sales, const SalesScreen())]),
          StatefulShellBranch(
              routes: [_tabRoot(MNRoutes.products, const StockScreen())]),
        ],
      ),
      mnRoute(
          path: MNRoutes.expenses,
          builder: (_, __) => const VendorExpenseScreen()),
      mnRoute(
          path: MNRoutes.handovers,
          builder: (_, __) => const VendorHandoversScreen()),
      mnRoute(
          path: MNRoutes.credit,
          builder: (_, __) => const CreditCustomersScreen()),
      mnRoute(
          path: MNRoutes.receive, builder: (_, __) => const ReceiveScreen()),
      mnRoute(
          path: MNRoutes.deliveryPattern,
          builder: (_, state) =>
              DeliveryScreen(consignmentId: state.pathParameters['id']!)),
      mnFadeRoute(
          path: MNRoutes.receiptSavedPattern,
          builder: (_, state) =>
              ReceiptSavedScreen(consignmentId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.supplyRequests,
          builder: (_, __) => const SupplyRequestListScreen()),
      mnRoute(
          path: MNRoutes.supplyRequestNew,
          builder: (_, __) => const SupplyRequestFormScreen()),
      mnRoute(
          path: MNRoutes.supplyRequestPattern,
          builder: (_, state) =>
              SupplyRequestScreen(id: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeSupplyRequests,
          builder: (_, __) => const OfficeSupplyRequestsScreen()),
      mnRoute(
          path: MNRoutes.officeSupplyRequestPattern,
          builder: (_, state) =>
              OfficeSupplyRequestScreen(id: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.officeAssets,
          builder: (_, state) => OfficeAssetsScreen(
              stationId: state.uri.queryParameters['station'])),
      mnRoute(
          path: MNRoutes.officeAssetNew,
          builder: (_, __) => const OfficeAssetRegisterScreen()),
      mnRoute(
          path: MNRoutes.officeAssetPattern,
          builder: (_, state) =>
              OfficeAssetScreen(id: state.pathParameters['id']!)),
      mnRoute(path: MNRoutes.damaged, builder: (_, __) => const DamageScreen()),
      mnRoute(
          path: MNRoutes.newDamage,
          builder: (_, __) => const DamageReportScreen()),
      mnRoute(
          path: MNRoutes.history, builder: (_, __) => const HistoryScreen()),
      mnRoute(
          path: MNRoutes.saleDetailPattern,
          builder: (_, state) =>
              SaleDetailScreen(clientId: state.pathParameters['id']!)),
      mnRoute(
          path: MNRoutes.closeDay, builder: (_, __) => const ClosingScreen()),
      mnFadeRoute(
          path: MNRoutes.dayClosed,
          builder: (_, __) => const DayClosedScreen()),
      mnRoute(
          path: MNRoutes.profile, builder: (_, __) => const ProfileScreen()),
      mnRoute(
          path: MNRoutes.changePin,
          builder: (_, __) => const ChangePinScreen()),
      mnRoute(path: MNRoutes.sync, builder: (_, __) => const SyncScreen()),
      mnRoute(
          path: MNRoutes.notifications,
          builder: (_, __) => const NotificationsScreen()),
      mnRoute(path: MNRoutes.cart, builder: (_, __) => const CartScreen()),
      mnFadeRoute(
          path: MNRoutes.saleSavedPattern,
          builder: (_, state) =>
              SaleSavedScreen(clientId: state.pathParameters['id']!)),
      // The constant check lets release builds drop the showcase entirely.
      if (devShowcaseEnabled && showcase)
        mnRoute(
            path: MNRoutes.showcase,
            builder: (_, __) => const ShowcaseScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
