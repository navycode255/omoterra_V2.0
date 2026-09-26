import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import '../../shared/widgets/rating.dart';

/// The supplier's own reputation and what buyers said, without who said it.
/// Separate from resourceProvider so a failure here never shows an error on
/// Supplier Home, where the summary tile simply stays hidden.
final supplierReputationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(repositoryProvider).read('/supplier/reputation');
  return Map<String, dynamic>.from(data as Map);
});

String reputationSummary(Map<String, dynamic> r, Strings s) {
  final average = (r['rating'] as num?)?.toDouble();
  final count = (r['ratings'] as num?)?.toInt() ?? 0;
  if (average != null) {
    return s.ratingSummary(average.toStringAsFixed(1), count);
  }
  final needed = ((r['minimum_ratings'] as num?)?.toInt() ?? 3) - count;
  return count == 0 ? s.noRatingsYetDelivery : s.ratingsSoFar(count, needed);
}

class SupplierReviewsScreen extends ConsumerWidget {
  const SupplierReviewsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierReputationProvider);
    final s = ref.s;
    final about = s.aboutRatingsBody;
    return Scaffold(
        // The leaves sit behind the title, so the page runs under the bar.
        extendBodyBehindAppBar: true,
        appBar: OmoterraAppBar(
            backgroundColor: Colors.transparent,
            title: Text(s.buyerRatingsTitle,
                style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: OColors.ink,
                    letterSpacing: -.5)),
            actions: [
              InfoButton(
                  color: OColors.forest,
                  title: s.aboutYourRatings,
                  message: state.valueOrNull == null
                      ? about
                      : '${reputationSummary(state.value!, s)}.\n\n$about'),
              const SizedBox(width: 8),
            ]),
        body: Stack(children: [
          Positioned(
              right: 30,
              top: MediaQuery.paddingOf(context).top - 6,
              child: const LeafSprig(
                  size: 64, angle: .15, color: Color(0xFFD7E8DB))),
          const Positioned(
              right: -10, top: 250, child: LeafSprig(size: 58, angle: .35)),
          RefreshIndicator(
            onRefresh: () => ref.refresh(supplierReputationProvider.future),
            child: ListView(
                padding: EdgeInsets.fromLTRB(
                    // Below the status bar and the (transparent) top bar.
                    16,
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 14,
                    16,
                    24),
                children: [
                  ...state.when(
                      loading: () => const [LoadingSkeleton()],
                      error: (e, _) => [
                            ErrorState(e,
                                retry: () =>
                                    ref.invalidate(supplierReputationProvider))
                          ],
                      data: (r) {
                        final reviews = List<Map<String, dynamic>>.from(
                            (r['reviews'] as List? ?? const []).map(
                                (e) => Map<String, dynamic>.from(e as Map)));
                        return [
                          ReputationStrip(r),
                          Padding(
                              padding:
                                  const EdgeInsets.only(top: 26, bottom: 14),
                              child: Text(s.whatBuyersSaid,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: OColors.ink,
                                      letterSpacing: -.4))),
                          if (reviews.isEmpty)
                            EmptyState(s.noRatingsYet, s.noRatingsYetBody)
                          else
                            for (final review in reviews)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Surface(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Row(children: [
                                          StarRow(
                                              (review['stars'] as num)
                                                  .toDouble(),
                                              size: 18),
                                          const Spacer(),
                                          Text(s.dateText(review['created_at']),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: OColors.secondary)),
                                        ]),
                                        if ('${review['comment'] ?? ''}'
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text('${review['comment']}'),
                                        ],
                                      ]))),
                        ];
                      }),
                ]),
          ),
        ]));
  }
}
