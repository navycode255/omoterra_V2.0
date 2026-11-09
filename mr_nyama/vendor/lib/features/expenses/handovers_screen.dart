import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/workflow_header.dart';

/// The vendor's own handovers of the last 31 days (`GET /vendor/handovers`).
/// Read-only: it is what the office recorded in this vendor's name. A failed
/// load is the page's error; a swipe asks again.
final vendorHandoversProvider =
    FutureProvider.autoDispose<List<VendorHandover>>((ref) async {
  final auth = ref.watch(sessionProvider).valueOrNull;
  final repository = ref.read(vendorRepositoryProvider);
  if (auth is! SignedIn || repository is! VendorHandoverRepository) {
    return const [];
  }
  return ref.read(sessionProvider.notifier).authorised(
      (token) => (repository as VendorHandoverRepository).handovers(token));
});

final vendorMoneySummaryProvider =
    FutureProvider.autoDispose<VendorMoneySummary>((ref) async {
  final auth = ref.watch(sessionProvider).valueOrNull;
  final repository = ref.read(vendorRepositoryProvider);
  if (auth is! SignedIn) {
    throw const AuthFailure(AuthFailureKind.sessionExpired);
  }
  if (repository is! VendorMoneyRepository) {
    throw const AuthFailure(AuthFailureKind.notConfigured);
  }
  return ref.read(sessionProvider.notifier).authorised(
      (token) => (repository as VendorMoneyRepository).moneyBalance(token));
});

class VendorHandoversScreen extends ConsumerWidget {
  const VendorHandoversScreen({super.key});

  Color _statusColor(String status) => switch (status) {
        'confirmed' => MNColors.success,
        'reversed' => MNColors.muted,
        _ => MNColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handovers = ref.watch(vendorHandoversProvider);
    final summary = ref.watch(vendorMoneySummaryProvider);
    return Scaffold(
      appBar: MNWorkflowHeader(title: s.handoversTitle),
      body: MNRefreshArea(
          onRefresh: () async {
            try {
              ref.invalidate(vendorHandoversProvider);
              ref.invalidate(vendorMoneySummaryProvider);
              await Future.wait([
                ref.read(vendorHandoversProvider.future),
                ref.read(vendorMoneySummaryProvider.future),
              ]);
            } catch (_) {
              // The page shows its own error.
            }
          },
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(s.vendorMoneySummaryTitle, style: MNText.title),
                          const SizedBox(height: 8),
                          ...switch (summary) {
                            AsyncData(:final value) => [
                                _moneyLine(
                                    s.vendorMoneyOwed, formatTsh(value.owed)),
                                _moneyLine(s.vendorMoneyCredit,
                                    formatTsh(value.credit)),
                                _moneyLine(s.vendorMoneyUnverifiedSales,
                                    formatTsh(value.unverifiedCashSales)),
                                _moneyLine(s.vendorMoneyUnconfirmedHandovers,
                                    formatTsh(value.unconfirmedHandovers)),
                                _moneyLine(s.vendorMoneyPendingExpenses,
                                    formatTsh(value.pendingVendorExpenses)),
                                const SizedBox(height: 8),
                                MNNote(s.vendorMoneyNote,
                                    tone: MNNoteTone.info),
                              ],
                            AsyncError(:final error) => [
                                MNErrorState(
                                    error: error,
                                    onRetry: () => ref
                                        .invalidate(vendorMoneySummaryProvider))
                              ],
                            _ => [
                                const SizedBox(
                                    height: 96, child: MNLoadingState())
                              ],
                          },
                        ])),
                ...switch (handovers) {
                  AsyncData(:final value) => [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(s.handoversReadOnly,
                              style: MNText.secondary)),
                      if (value.isEmpty)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child:
                                Text(s.handoversEmpty, style: MNText.secondary))
                      else
                        for (final (i, h) in value.indexed)
                          MNListRow(
                              first: i == 0,
                              title: Text(formatTsh(h.amount),
                                  style: MNText.title),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (h.receivedAt != null)
                                      Text(
                                          s.handoverAt(
                                              s.hhmm(eatClock(h.receivedAt!)),
                                              s.date(eatClock(h.receivedAt!))),
                                          style: MNText.meta),
                                    if (h.receiver.isNotEmpty)
                                      Text(s.handoverReceiver(h.receiver),
                                          style: MNText.meta),
                                    if (h.note != null)
                                      Text(h.note!, style: MNText.body),
                                  ]),
                              trailing: Text(s.handoverStatus(h.status),
                                  style: MNText.meta.copyWith(
                                      color: _statusColor(h.status)))),
                    ],
                  AsyncError(:final error) => [
                      MNErrorState(
                          error: error,
                          onRetry: () =>
                              ref.invalidate(vendorHandoversProvider))
                    ],
                  _ => [const SizedBox(height: 240, child: MNLoadingState())],
                },
              ])),
    );
  }

  Widget _moneyLine(String label, String amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: MNText.secondary)),
        const SizedBox(width: 12),
        Text(amount, style: MNText.body),
      ]));
}
