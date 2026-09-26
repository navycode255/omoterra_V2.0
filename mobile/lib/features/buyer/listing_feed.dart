import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../shared/models/domain.dart';
import '../../shared/widgets/components.dart';

/// Shared by BuyerHome (category chips only) and ExploreScreen (search and
/// the full filter set). The server does the searching and filtering; this
/// shows its pages newest first and loads the next one as the buyer nears the
/// end of the enclosing scroll view.
class ListingFeed extends ConsumerStatefulWidget {
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

  /// The `GET /listings` parameters for this search.
  Map<String, String?> get query => {
        'category': category,
        'q': search,
        'region': region,
        'ready_by': _date(readyBy),
        'condition': condition,
        'max_price': _number(maxPrice),
        'min_weight': _number(minWeight),
        'max_weight': _number(maxWeight),
      };

  static String? _number(double? value) => value == null
      ? null
      : value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();

  static String? _date(String value) =>
      DateTime.tryParse(value)?.toIso8601String().split('T').first;

  @override
  ConsumerState<ListingFeed> createState() => _ListingFeedState();
}

class _ListingFeedState extends ConsumerState<ListingFeed> {
  /// Distance from the end of the scroll view at which the next page loads.
  static const _nearEnd = 600.0;

  // Pages after the first, for the search and first page they continue.
  String? _key;
  ListingPage? _first;
  final _more = <SupplyListing>[];
  String? _cursor;
  bool _loading = false;
  Object? _error;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_maybeLoadMore);
      _position = position?..addListener(_maybeLoadMore);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_maybeLoadMore);
    super.dispose();
  }

  void _follow(String key, ListingPage first) {
    if (key == _key && identical(first, _first)) return;
    _key = key;
    _first = first;
    _more.clear();
    _cursor = first.nextCursor;
    _loading = false;
    _error = null;
  }

  void _maybeLoadMore() {
    if (!mounted || _cursor == null || _loading || _error != null) return;
    final position = _position;
    if (position != null &&
        position.hasContentDimensions &&
        position.extentAfter > _nearEnd) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    final key = _key, first = _first, cursor = _cursor;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(repositoryProvider)
          .listingPage(Uri.splitQueryString(key!), cursor: cursor);
      // The search changed or was refreshed meanwhile: drop this page.
      if (!mounted || key != _key || !identical(first, _first)) return;
      setState(() {
        _more.addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || key != _key || !identical(first, _first)) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _retryMore() {
    setState(() => _error = null);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final key = listingSearchKey(widget.query);
    final s = ref.s;
    return ref.watch(listingsProvider(key)).when(
        // Keep showing the previous results while a changed search loads.
        skipLoadingOnReload: true,
        data: (first) {
          _follow(key, first);
          final items = [...first.items, ..._more];
          // After this frame: a short list may not fill the screen, so no
          // scroll will come to ask for the next page.
          if (_cursor != null && !_loading && _error == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _maybeLoadMore());
          }
          if (items.isEmpty) {
            // Rows can drop out of a page when their stock just ran out; keep
            // loading rather than claim there is nothing.
            if (_cursor != null && _error == null) {
              return const LoadingSkeleton();
            }
            if (_error == null) return _empty(context, s);
          }
          return Column(children: [
            for (final listing in items)
              ListingCard(listing,
                  key: ValueKey(listing.id),
                  onTap: () => context.push('/listing/${listing.id}')),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OmoterraButton(s.retry,
                      secondary: true, onPressed: _retryMore))
            else if (_loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5)))),
          ]);
        },
        loading: () => const LoadingSkeleton(),
        error: (e, _) =>
            ErrorState(e, retry: () => ref.invalidate(listingsProvider(key))));
  }

  Widget _empty(BuildContext context, Strings s) {
    final search = widget.search.trim();
    final prefill = {
      if (search.isNotEmpty) 'q': search,
      if (widget.category.isNotEmpty) 'category': widget.category,
    };
    final request = Uri(
        path: '/request', queryParameters: prefill.isEmpty ? null : prefill);
    return EmptyState(search.isEmpty ? s.noSupplyTitle : s.noSupplyFor(search),
        s.noSupplyBody,
        action: OmoterraButton(s.requestSupply,
            onPressed: () => context.push(request.toString())));
  }
}
