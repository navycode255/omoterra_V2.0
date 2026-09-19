import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../shared/widgets/components.dart';

/// Shared by BuyerHome (unfiltered chip row) and ExploreScreen (full filter
/// set), so there is one place that turns listings + filters into cards.
class ListingFeed extends ConsumerWidget {
  final String category, search, region, readyBy, condition;
  final double? maxPrice, minWeight, maxWeight;
  const ListingFeed(
      {super.key,
      this.category = '',
      this.search = '',
      this.region = '',
      this.readyBy = '',
      this.condition = '',
      this.minWeight,
      this.maxWeight,
      this.maxPrice});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(listingsProvider(category)).when(
          data: (list) {
            final matches = list
                .where((l) =>
                    label(l.category)
                        .toLowerCase()
                        .contains(search.toLowerCase()) &&
                    l.region.toLowerCase().contains(region.toLowerCase()) &&
                    (maxPrice == null || double.parse(l.price) <= maxPrice!) &&
                    (readyBy.isEmpty ||
                        ((l.specs['ready_date'] ??
                                    l.specs['slaughter_date'] ??
                                    '')
                                .toString()
                                .isNotEmpty &&
                            (l.specs['ready_date'] ?? l.specs['slaughter_date'])
                                    .toString()
                                    .compareTo(readyBy) <=
                                0)) &&
                    (condition.isEmpty ||
                        l.specs['live_or_dressed'] == condition ||
                        l.specs['chilled_or_frozen'] == condition) &&
                    weightMatches(l.specs, minWeight, maxWeight))
                .toList();
            if (matches.isEmpty) {
              return EmptyState('No supply available right now',
                  'Tell Omoterra what you need and we’ll help source it.',
                  action: OmoterraButton('Request Supply',
                      onPressed: () => context.push('/request')));
            }
            return Column(
                children: matches
                    .map((l) => ListingCard(l,
                        onTap: () => context.push('/listing/${l.id}')))
                    .toList());
          },
          loading: () => const LoadingSkeleton(),
          error: (e, _) => ErrorState(e,
              retry: () => ref.invalidate(listingsProvider(category))));
}

bool weightMatches(
    Map<String, dynamic> specs, double? minimum, double? maximum) {
  if (minimum == null && maximum == null) return true;
  final raw = '${specs['avg_weight_kg'] ?? specs['weight_range'] ?? ''}';
  final weights = RegExp(r'\d+(?:\.\d+)?')
      .allMatches(raw)
      .map((m) => double.parse(m.group(0)!))
      .toList();
  if (weights.isEmpty) return false;
  final low = weights.first,
      high = weights.length > 1 ? weights.last : weights.first;
  return (minimum == null || high >= minimum) &&
      (maximum == null || low <= maximum);
}
