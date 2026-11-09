import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/notifications.dart';
import '../../core/api/providers.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';

/// How often an open app asks the server for new notifications (push, step
/// 13B, will make this a fallback).
const notificationRefreshEvery = Duration(minutes: 2);

/// Whose notifications: the office account while signed in there, else the
/// vendor's. Offline, the last list stays (the bell keeps its dot).
final notificationsProvider =
    FutureProvider.autoDispose<NotificationPage>((ref) async {
  final lang = ref.watch(languageProvider);
  final office = ref.watch(officeSessionProvider).valueOrNull;
  // A lead session is the seller's: the seller feed stays (never staff).
  if (office is OfficeSignedIn && !office.viaLead) {
    if (ref.read(officeRepositoryProvider) is! OfficeNotificationsRepository) {
      return NotificationPage.empty;
    }
    return ref.read(officeSessionProvider.notifier).guard(
        (r) => (r as OfficeNotificationsRepository).notifications(lang: lang));
  }
  final auth = ref.watch(sessionProvider).valueOrNull;
  final repository = ref.read(vendorRepositoryProvider);
  if (auth is! SignedIn || repository is! VendorNotificationsRepository) {
    return NotificationPage.empty;
  }
  return ref.read(sessionProvider.notifier).authorised((token) =>
      (repository as VendorNotificationsRepository)
          .notifications(token, lang: lang));
});

/// Unread notifications exist (the bell's dot; never a counter, AGENTS.md §3).
final notificationsUnreadProvider = Provider.autoDispose<bool>(
    (ref) => (ref.watch(notificationsProvider).valueOrNull?.unread ?? 0) > 0);

/// Older notifications after [before], for "Onyesha zaidi".
Future<NotificationPage> olderNotifications(WidgetRef ref, String before) {
  final lang = ref.read(languageProvider);
  final office = ref.read(officeSessionProvider).valueOrNull;
  if (office is OfficeSignedIn && !office.viaLead) {
    return ref.read(officeSessionProvider.notifier).guard((r) =>
        (r as OfficeNotificationsRepository)
            .notifications(lang: lang, before: before));
  }
  final repository = ref.read(vendorRepositoryProvider);
  return ref.read(sessionProvider.notifier).authorised((token) =>
      (repository as VendorNotificationsRepository)
          .notifications(token, lang: lang, before: before));
}

/// Tells the server [ids] were read (all when null). False when it could not
/// be told: it stays unread and is marked next time.
Future<bool> sendNotificationsRead(
    T Function<T>(ProviderListenable<T>) read, List<String>? ids) async {
  try {
    final office = read(officeSessionProvider).valueOrNull;
    if (office is OfficeSignedIn && !office.viaLead) {
      await read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeNotificationsRepository).markNotificationsRead(ids));
    } else {
      final repository = read(vendorRepositoryProvider);
      if (repository is! VendorNotificationsRepository) return false;
      await read(sessionProvider.notifier).authorised((token) =>
          (repository as VendorNotificationsRepository)
              .markNotificationsRead(token, ids));
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Marks [ids] read (all when null), then refreshes the list.
Future<void> markNotificationsRead(WidgetRef ref, List<String>? ids) async {
  if (await sendNotificationsRead(ref.read, ids)) {
    ref.invalidate(notificationsProvider);
  }
}

/// Supply request notices (`supply_*` kinds) open the request they are about.
/// Those that ask the reader to act (a request waiting, spending to confirm)
/// open the office page; the others open the requester's own page. Null when
/// [kind] is not a supply notice.
String? supplyNotificationRoute(String kind, String? sourceId,
    {required bool office}) {
  const forOffice = {
    'supply_request_waiting',
    'supply_request_funding',
    'supply_settlement_recorded',
  };
  const forRequester = {
    'supply_request_step_approved',
    'supply_request_approved',
    'supply_request_rejected',
    'supply_advance_given',
    'supply_settlement_confirmed',
  };
  if (forOffice.contains(kind)) {
    return sourceId == null
        ? MNRoutes.officeSupplyRequests
        : MNRoutes.officeSupplyRequest(sourceId);
  }
  if (!forRequester.contains(kind)) return null;
  if (office) {
    return sourceId == null
        ? MNRoutes.officeSupplyRequests
        : MNRoutes.officeSupplyRequest(sourceId);
  }
  return sourceId == null
      ? MNRoutes.supplyRequests
      : MNRoutes.supplyRequest(sourceId);
}

/// The screen a notification's target opens (null: the list itself).
String? routeForTarget(String? target, {required bool office}) => office
    ? switch (target) {
        'office_supply_requests' || 'supply_requests' =>
          MNRoutes.officeSupplyRequests,
        'office_expenses' || 'office_handovers' => MNRoutes.officeMoney,
        'office_reviews' => MNRoutes.officeSyncConflicts,
        'office_approvals' => MNRoutes.officeApprovals,
        'office_home' => MNRoutes.office,
        'office_closings' || 'office_problems' => MNRoutes.officeVerification,
        _ => null,
      }
    : switch (target) {
        'receive' => MNRoutes.receive,
        'expenses' => MNRoutes.expenses,
        'handovers' => MNRoutes.handovers,
        'damage' => MNRoutes.damaged,
        'sync' => MNRoutes.sync,
        'credit' => MNRoutes.credit,
        'supply_requests' => MNRoutes.supplyRequests,
        'office_supply_requests' => MNRoutes.officeSupplyRequests,
        'products' => MNRoutes.products,
        'home' || 'closing' => MNRoutes.home,
        _ => null,
      };

/// Opens a notification: marks it read and goes to its screen.
Future<void> openNotification(
    BuildContext context, WidgetRef ref, AppNotification n,
    {required bool office}) async {
  final route = supplyNotificationRoute(n.kind, n.sourceId, office: office) ??
      routeForTarget(n.target, office: office);
  if (!n.read) unawaited(markNotificationsRead(ref, [n.id]));
  if (route == null || !context.mounted) return;
  MNRoutes.tabs.contains(route) ? context.go(route) : context.push(route);
}
