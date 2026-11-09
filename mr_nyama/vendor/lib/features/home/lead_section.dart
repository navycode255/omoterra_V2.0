import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/vendor_reference.dart';

/// "Kituo" on Nyumbani, only for an Outlet Lead whose lead office session is
/// present. Each row opens the existing office page for his own station
/// (the station comes from the cached vendor profile). The office pages
/// themselves show their own load error when offline.
class LeadSection extends ConsumerWidget {
  const LeadSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final office = ref.watch(officeSessionProvider).valueOrNull;
    final auth = ref.watch(sessionProvider).valueOrNull;
    final station = auth is SignedIn ? auth.profile.outletLead?.stationId : null;
    if (office is! OfficeSignedIn || !office.viaLead || station == null) {
      return const SizedBox.shrink();
    }
    final strings = ref.watch(stringsProvider);
    Widget row(MNIconData icon, String label, String path,
            {bool divider = true}) =>
        MNReferenceMenuAction(
            icon: icon,
            label: label,
            divider: divider,
            onTap: () => context.push(path));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Semantics(
          header: true,
          child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Text(strings.leadSection, style: MNText.referenceSection))),
      MNReferenceSurface(
          child: Column(children: [
        row(MNIconData.cash, strings.leadHandovers,
            MNRoutes.officeMoneyStation(station),
            divider: false),
        row(MNIconData.receive, strings.leadDeliveries,
            '${MNRoutes.officeStock(station)}?section=deliveries'),
        row(MNIconData.box, strings.leadStationStock,
            MNRoutes.officeStock(station)),
        row(MNIconData.accountWallet, strings.leadExpenses,
            '${MNRoutes.officeMoneyStation(station)}?section=expenses'),
        row(MNIconData.damage, strings.leadDamage,
            '${MNRoutes.officeVerificationStation(station)}?section=damage'),
        row(MNIconData.lock, strings.leadClosings,
            MNRoutes.officeClosingCases(station)),
        row(MNIconData.box, strings.supplyTitle, MNRoutes.officeSupplyRequests),
        row(MNIconData.box, strings.leadAssets,
            '${MNRoutes.officeAssets}?station=$station'),
      ])),
    ]);
  }
}
