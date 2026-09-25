import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/rating.dart';

/// The supplier's own reputation and what buyers said, without who said it.
/// Separate from resourceProvider so a failure here never shows an error on
/// Supplier Home, where the summary tile simply stays hidden.
final supplierReputationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(repositoryProvider).read('/supplier/reputation');
  return Map<String, dynamic>.from(data as Map);
});

String reputationSummary(Map<String, dynamic> r) {
  final average = (r['rating'] as num?)?.toDouble();
  final count = (r['ratings'] as num?)?.toInt() ?? 0;
  if (average != null) {
    return '${average.toStringAsFixed(1)} of 5 from $count buyer ratings';
  }
  final needed = ((r['minimum_ratings'] as num?)?.toInt() ?? 3) - count;
  return count == 0
      ? 'No ratings yet. Buyers rate orders after delivery.'
      : '$count rating${count == 1 ? '' : 's'} so far; your average shows after $needed more';
}

class SupplierReviewsScreen extends ConsumerWidget {
  const SupplierReviewsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierReputationProvider);
    return Scaffold(
        appBar: const OmoterraAppBar(title: Text('Buyer ratings')),
        body: RefreshIndicator(
            onRefresh: () => ref.refresh(supplierReputationProvider.future),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              ...state.when(
                  loading: () => const [LoadingSkeleton()],
                  error: (e, _) => [
                        ErrorState(e,
                            retry: () =>
                                ref.invalidate(supplierReputationProvider))
                      ],
                  data: (r) {
                    final reviews = List<Map<String, dynamic>>.from(
                        (r['reviews'] as List? ?? const [])
                            .map((e) => Map<String, dynamic>.from(e as Map)));
                    return [
                      Text(reputationSummary(r),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ReputationStrip(r),
                      const SizedBox(height: 8),
                      const Text(
                          'Buyers see your average once you have enough ratings, with your deliveries and quality results. They never see comments, and you never see who wrote them.',
                          style: TextStyle(
                              fontSize: 12, color: OColors.secondary)),
                      const SectionHeader('What buyers said'),
                      if (reviews.isEmpty)
                        const EmptyState('No ratings yet',
                            'After Omoterra delivers your supply, buyers can rate the order.')
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
                                          (review['stars'] as num).toDouble(),
                                          size: 18),
                                      const Spacer(),
                                      Text(_date('${review['created_at']}'),
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
            ])));
  }

  static String _date(String iso) {
    final at = DateTime.tryParse(iso)?.toLocal();
    return at == null ? '' : DateFormat('d MMM yyyy').format(at);
  }
}
