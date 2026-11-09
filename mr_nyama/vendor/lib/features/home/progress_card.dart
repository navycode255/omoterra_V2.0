import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/vendor_reference.dart';
import 'dashboard.dart';

/// The last progress the server sent this session, so a failed refresh
/// (offline) keeps showing it instead of flickering away.
class _Kept {
  VendorProgress? value;
}

final _keptProgressProvider = Provider<_Kept>((ref) {
  ref.watch(sessionProvider.select((s) => switch (s.valueOrNull) {
        SignedIn(:final profile) => profile.id,
        _ => null,
      }));
  return _Kept();
});

/// The vendor's own progress (`GET /vendor/progress`, design §10a). It is
/// asked for again when unsent records go out (sales reach the server) and on
/// pull-to-refresh. Offline, or from a server without it, it is the last
/// answer of this session, else nothing; it never blocks or shows an error.
final vendorProgressProvider = FutureProvider<VendorProgress>((ref) async {
  final kept = ref.watch(_keptProgressProvider);
  ref.watch(syncOutstandingCountProvider);
  final auth = ref.watch(sessionProvider).valueOrNull;
  final repository = ref.read(vendorRepositoryProvider);
  if (auth is! SignedIn || repository is! VendorProgressRepository) {
    return kept.value ?? VendorProgress.none;
  }
  try {
    final value = await ref.read(sessionProvider.notifier).authorised(
        (token) => (repository as VendorProgressRepository).progress(token));
    kept.value = value;
    return value;
  } catch (_) {
    return kept.value ?? VendorProgress.none;
  }
});

/// Chickens today against the target, the next bonus step, today's bonus
/// (estimated or earned), the pay-period total and stars. Hidden while
/// nothing is configured. Never profit, rules beyond the next step, or
/// other vendors.
class ProgressCard extends ConsumerWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(vendorProgressProvider).valueOrNull;
    if (p == null || !p.worthShowing) return const SizedBox.shrink();
    final strings = ref.watch(stringsProvider);
    final step = p.nextStep;
    final total = p.periodTotal;
    final caption =
        MNText.referenceCaption.copyWith(color: MNColors.referenceMuted);
    final strong = MNText.withWeight(MNText.referenceBody, FontWeight.w600);
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: MNReferenceSurface(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(strings.progressTitle, style: caption),
                                  Text(
                                      strings.progressChickens(
                                          p.chickens, p.target),
                                      style: strong),
                                ])),
                            if (p.stars != null) ...[
                              const SizedBox(width: 8),
                              Text(strings.progressStars(p.stars!),
                                  style: strong),
                            ],
                          ]),
                      if (step != null) ...[
                        const SizedBox(height: 2),
                        Text(
                            strings.progressNextStep(
                                step.chickens, formatTsh(step.amount)),
                            style: MNText.referenceCaption),
                      ],
                      const SizedBox(height: 10),
                      const Divider(
                          height: 1,
                          thickness: 1,
                          color: MNColors.referenceLine),
                      const SizedBox(height: 10),
                      _Line(
                          label: strings.progressBonusToday,
                          value: formatTsh(p.bonusToday),
                          state: p.bonusEarned
                              ? strings.progressEarned
                              : strings.progressEstimated,
                          earned: p.bonusEarned),
                      if (total != null && p.payPeriod != null) ...[
                        const SizedBox(height: 6),
                        _Line(
                            label: strings.progressPeriod(p.payPeriod!),
                            value: strings.progressPeriodAmount(
                                formatTsh(total.earned + total.adjustments),
                                total.estimated > 0
                                    ? formatTsh(total.estimated)
                                    : null)),
                      ],
                      if (!p.bonusEarned && p.bonusToday > 0) ...[
                        const SizedBox(height: 8),
                        Text(strings.progressEstimatedNote, style: caption),
                      ],
                    ]))));
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final String? state;
  final bool earned;
  const _Line(
      {required this.label,
      required this.value,
      this.state,
      this.earned = false});

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: MNText.referenceCaption
                    .copyWith(color: MNColors.referenceMuted))),
        const SizedBox(width: 8),
        Flexible(
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: value,
                      style: MNText.withWeight(
                          MNText.referenceCaption, FontWeight.w600)),
                  if (state != null)
                    TextSpan(
                        text: ' · $state',
                        style: MNText.referenceCaption.copyWith(
                            // Earned is a confirmed state; estimated is not.
                            color: earned
                                ? MNColors.success
                                : MNColors.referenceMuted)),
                ]),
                textAlign: TextAlign.end)),
      ]);
}
