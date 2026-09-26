import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import 'supplier_batch_screen.dart';

/// Which filter chip a listing falls under (see [batchPhase] for batches).
String listingPhase(Map row) => switch ('${row['listing_status']}') {
      'live' => 'live',
      'sold_out' || 'paused' => 'completed',
      _ => 'pending',
    };

class StockList extends StatelessWidget {
  /// '' shows every listing; otherwise one [listingPhase].
  final String phase;
  const StockList({super.key, this.phase = ''});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ResourceView('/supplier/stock', builder: (rows) {
      final list = (rows as List)
          .where((r) => phase.isEmpty || listingPhase(r) == phase)
          .toList();
      if (list.isEmpty) {
        // Pending/Completed tabs just show their batches; no empty card.
        if (phase == 'pending' || phase == 'completed') {
          return const SizedBox.shrink();
        }
        return EmptyState(s.noLiveListingsYet, '',
            action: TextButton(
                onPressed: () => context.push('/stock/new'),
                child: Text(s.addStock)));
      }
      return Column(children: [
        for (final row in list)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StockCard(row))
      ]);
    });
  }
}

class _StockCard extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _StockCard(this.row);

  static Color _statusColor(String status) =>
      ['cancelled', 'failed', 'rejected'].contains(status)
          ? OColors.error
          : ['needs_confirmation', 'pending_review'].contains(status)
              ? const Color(0xFFC77C12)
              : OColors.positive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = '${row['listing_status']}';
    final s = ref.s;
    return DecorCard(
        onTap: () => context.push('/stock/${row['id']}'),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Stack(children: [
          const Positioned(
              right: -6,
              bottom: -16,
              child: LeafSprig(size: 52, angle: .25, color: Color(0xFFE6F1E9))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                    width: 78,
                    height: 78,
                    child: ProductImage(List<String>.from(row['photos'] ?? []),
                        category: row['category'], height: 78))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SizedBox(height: 4),
                  Text(s.label(row['category']),
                      style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: OColors.ink)),
                  const SizedBox(height: 6),
                  Text(
                      s.availableReserved(amount(row['quantity_available']),
                          amount(row['quantity_reserved'])),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: OColors.secondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _statusColor(status),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(s.status(status),
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _statusColor(status))),
                  ]),
                ])),
            SizedBox(
                width: 34,
                height: 34,
                child: PopupMenuButton<String>(
                    tooltip: s.stockActions,
                    padding: EdgeInsets.zero,
                    iconSize: 30,
                    icon: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F2), shape: BoxShape.circle),
                        child: const Icon(Icons.more_horiz,
                            size: 20, color: OColors.ink)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (route) => context.push(route),
                    itemBuilder: (context) => [
                          PopupMenuItem(
                              value: '/stock/${row['id']}',
                              child: Text(s.viewDetails)),
                          PopupMenuItem(
                              value: '/stock/${row['id']}/correct',
                              child: Text(s.correctStockCount)),
                          PopupMenuItem(
                              value: '/stock/${row['id']}/add',
                              child: Text(s.addStockReceived)),
                        ])),
          ]),
        ]));
  }
}

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});
  @override
  ConsumerState<StockScreen> createState() => _StockState();
}

class _StockState extends ConsumerState<StockScreen> {
  String phase = '';
  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    final batches = ref.watch(resourceProvider('/supplier/batches'));
    final stock = ref.watch(resourceProvider('/supplier/stock'));
    if (batches.hasError || stock.hasError) {
      final error = batches.hasError ? batches.error! : stock.error!;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorState(
            error,
            retry: () {
              if (batches.hasError) {
                ref.invalidate(resourceProvider('/supplier/batches'));
              }
              if (stock.hasError) {
                ref.invalidate(resourceProvider('/supplier/stock'));
              }
            },
          ),
        ],
      );
    }
    return Stack(children: [
      const Positioned.fill(child: PageLeaves()),
      ListView(padding: const EdgeInsets.fromLTRB(16, 28, 16, 24), children: [
        Row(children: [
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(s.myStockTitle,
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: OColors.ink,
                          letterSpacing: -.8)))),
          const SizedBox(width: 12),
          _NewBatchButton(s.newBatch,
              onTap: () => context.push('/batches/new')),
        ]),
        const SizedBox(height: 18),
        const _ConfirmDueBanner(),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final (value, label) in [
                ('', s.all),
                ('live', s.live),
                ('pending', s.pending),
                ('completed', s.completed),
              ])
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(label,
                        selected: phase == value,
                        onTap: () => setState(() => phase = value))),
            ])),
        const SizedBox(height: 18),
        SupplierBatchList(phase: phase),
        const SizedBox(height: 4),
        StockList(phase: phase)
      ]),
    ]);
  }
}

/// The dark "+ New batch" button beside the title.
class _NewBatchButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NewBatchButton(this.label, {required this.onTap});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [
        BoxShadow(
            color: OColors.forest.withValues(alpha: .28),
            blurRadius: 12,
            offset: const Offset(0, 5))
      ]),
      child: Material(
          color: OColors.forest,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, size: 22, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                  ])))));
}

/// Status filter chip: selected is pale green with a check in a circle.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, {required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: selected ? const Color(0xFFD6EBDD) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFFD6EBDD)
                          : const Color(0xFFDDE6E0))),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: OColors.ink)))));
}

/// Stock that is hidden from buyers, or soon will be, until the supplier
/// confirms it. Kept apart from resourceProvider so a failure here never
/// replaces the Stock tab with an error; the banner just stays away.
final _dueProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async =>
    await ref.watch(repositoryProvider).read('/supplier/stock/due') as List);

/// "N listings need confirming → Everything is still available": the whole
/// 48-hour routine in one tap. Hidden when nothing is due.
class _ConfirmDueBanner extends ConsumerStatefulWidget {
  const _ConfirmDueBanner();
  @override
  ConsumerState<_ConfirmDueBanner> createState() => _ConfirmDueBannerState();
}

class _ConfirmDueBannerState extends ConsumerState<_ConfirmDueBanner> {
  bool busy = false;
  Object? error;

  Future<void> confirmAll() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(repositoryProvider)
          .write('/supplier/stock/confirm-due', {}, key: newKey());
      ref.invalidate(_dueProvider);
      ref.invalidate(resourceProvider('/supplier/stock'));
      if (mounted) {
        final count = result['confirmed'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref.read(stringsProvider).confirmedListings(
                count is int ? count : int.tryParse('$count') ?? 0))));
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = ref.watch(_dueProvider).valueOrNull ?? const [];
    if (due.isEmpty) return const SizedBox.shrink();
    final n = due.length;
    final s = ref.s;
    return Container(
        key: const Key('confirm_due_banner'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1D9A6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.listingsNeedConfirming(n),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(s.confirmDueBody, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 10),
          OmoterraButton(s.everythingStillAvailable,
              icon: Icons.check_circle_outline,
              busy: busy,
              onPressed: confirmAll),
          if (error != null) ErrorState(error!),
          const SizedBox(height: 4),
          Text(s.somethingChanged,
              style: const TextStyle(fontSize: 11.5, color: OColors.secondary)),
        ]));
  }
}
