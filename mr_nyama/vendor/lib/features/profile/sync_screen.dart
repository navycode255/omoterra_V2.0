import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/sync/sync_engine.dart';
import '../../core/sync/unsent_age.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/sync_indicator.dart';
import '../home/dashboard.dart';

/// Usawazishaji: what is waiting, what the office kept for review, and the
/// last attempt. No dialogs; syncing happens on its own, and "Sawazisha
/// sasa" only asks for it sooner.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final engine = ref.watch(syncEngineProvider);
    final counts = ref.watch(queueCountsProvider).valueOrNull;
    final attention =
        ref.watch(attentionOperationsProvider).valueOrNull ?? const [];
    final pending = counts?.pending ?? 0;
    final oldest =
        pending > 0 ? ref.watch(oldestUnsentProvider).valueOrNull : null;
    return Scaffold(
      backgroundColor: MNColors.pageBackground,
      appBar: MNWorkflowHeader(title: strings.syncTitle, actions: [
        MNWorkflowHelp(messages: [strings.correctionsByOffice])
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MNReferenceSurface(
          child: Padding(
            padding: const EdgeInsets.all(MNSpace.x4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MNSyncIndicator(
                    compact: true,
                    status: ref.watch(syncStatusProvider),
                    pendingCount: ref.watch(syncOutstandingCountProvider)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        pending > 0
                            ? strings.queuedCount(pending)
                            : (counts?.needsReview ?? 0) > 0
                                ? strings.syncReviewCount(counts!.needsReview)
                                : ref.watch(syncStatusProvider) ==
                                        MNSyncStatus.sent
                                    ? strings.allSent
                                    : strings.syncUnknown,
                        style: MNText.title)),
              ]),
              if (oldest != null) ...[
                const SizedBox(height: MNSpace.x2),
                Text(
                    strings.unsentWaited(
                        ref.read(clockProvider)().difference(oldest)),
                    style: MNText.meta),
                const SizedBox(height: MNSpace.x1),
                Text(strings.unsentConsequence,
                    style: MNText.meta.copyWith(color: MNColors.warning)),
              ],
              if (engine.lastAttemptAt != null) ...[
                const SizedBox(height: MNSpace.x1),
                Text(
                    '${strings.lastAttempt(eatClock(engine.lastAttemptAt!))} · '
                    '${strings.syncOutcome(engine.lastOutcome ?? '')}',
                    style: MNText.meta),
              ],
            ]),
          ),
        ),
        if (attention.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x2),
            child: Semantics(
                header: true,
                child: Text(strings.needsReviewTitle, style: MNText.title)),
          ),
          MNReferenceSurface(
              child: Column(children: [
            for (final (i, op) in attention.indexed)
              MNListRow(
                first: i == 0,
                title:
                    Text(strings.operationName(op.opType), style: MNText.title),
                subtitle: Text(
                    '${strings.hhmm(eatClock(op.createdAt))} · '
                    '${strings.date(eatClock(op.createdAt))}\n'
                    '${strings.operationProblem(op.opType, op.resultReason, status: op.status)}',
                    style: MNText.meta.copyWith(color: MNColors.ink2)),
              ),
          ])),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
          child: MNButton.secondary(strings.syncNow,
              busy: engine.running,
              // Also asks again about records waiting for office review.
              onPressed:
                  pending == 0 && !attention.any((o) => o.status == 'conflict')
                      ? null
                      : () => ref
                          .read(syncEngineProvider.notifier)
                          .requestSync(recheck: true)),
        ),
      ),
    );
  }
}
