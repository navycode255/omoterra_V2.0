import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/sync_indicator.dart';
import 'delivery_screen.dart';
import 'receiving_store.dart';

/// "Upokeaji umehifadhiwa": read back from the phone's database. It says
/// where the count really is: saved on the phone and waiting, or accepted
/// by the office, never more than the server has confirmed.
class ReceiptSavedScreen extends ConsumerWidget {
  final String consignmentId;
  const ReceiptSavedScreen({super.key, required this.consignmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final delivery = ref.watch(deliveryProvider(consignmentId)).valueOrNull;
    final receipt = delivery?.receipt;
    // A refused or conflicting receipt is not a success: no check, no "saved".
    final failed = receipt?.status == ReceivingStatus.conflict ||
        receipt?.status == ReceivingStatus.rejected;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(MNRoutes.receive);
      },
      child: Scaffold(
        backgroundColor: MNColors.white,
        body: SafeArea(
          child: receipt == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(MNSpace.x6),
                  child: Column(children: [
                    Align(
                        alignment: Alignment.centerRight,
                        child: MNWorkflowHelp(messages: [
                          if (delivery!.status == ReceivingStatus.pending ||
                              delivery.status == ReceivingStatus.savedOnPhone)
                            strings.stockAfterAcceptance,
                          if (delivery.status == ReceivingStatus.accepted)
                            strings.acceptedNote
                        ])),
                    const SizedBox(height: MNSpace.x6),
                    Container(
                      width: MNSize.hero,
                      height: MNSize.hero,
                      decoration: const BoxDecoration(
                          color: MNColors.surface, shape: BoxShape.circle),
                      child: Center(
                          child: MNIcon(
                              receipt.status == ReceivingStatus.conflict
                                  ? MNIconData.clock
                                  : failed
                                      ? MNIconData.box
                                      : MNIconData.check,
                              size: 48)),
                    ),
                    const SizedBox(height: MNSpace.x6),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                          receipt.status == ReceivingStatus.conflict
                              ? strings.statusNeedsReview
                              : receipt.status == ReceivingStatus.rejected
                                  ? strings.statusRefused
                                  : strings.receiptSaved,
                          textAlign: TextAlign.center, style: MNText.heading),
                    ),
                    const SizedBox(height: MNSpace.x2),
                    Text(
                        strings.receivedOf(
                            delivery.receivedUnits, delivery.dispatchedUnits),
                        textAlign: TextAlign.center,
                        style: MNText.body.copyWith(color: MNColors.ink2)),
                    const SizedBox(height: MNSpace.x5),
                    if (receipt.status == ReceivingStatus.accepted)
                      Text(strings.acceptedNote,
                          style: MNText.status, textAlign: TextAlign.center)
                    else if (!failed) ...[
                      Text(strings.savedOnPhone,
                          style: MNText.status.copyWith(color: MNColors.ink2)),
                      const SizedBox(height: MNSpace.x1),
                      const MNSyncIndicator(status: MNSyncStatus.waiting),
                    ],
                  ]),
                ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              MNButton(strings.backToList,
                  onPressed: () => context.go(MNRoutes.receive)),
              const SizedBox(height: MNSpace.x2),
              MNButton.secondary(strings.backHome,
                  onPressed: () => context.go(MNRoutes.home)),
            ]),
          ),
        ),
      ),
    );
  }
}
