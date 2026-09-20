import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/supply_art.dart';
import 'listing_feed.dart';

class BuyerHome extends ConsumerStatefulWidget {
  const BuyerHome({super.key});
  @override
  ConsumerState<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends ConsumerState<BuyerHome> {
  String chip = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final s = ref.s;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(s.greeting(user?.name.split(' ').first ?? ''),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(s.whatToday, style: const TextStyle(color: OColors.secondary)),
          const SizedBox(height: 18),
          const _BuySupplyBanner(),
          const SizedBox(height: 12),
          // Intrinsic height keeps the two cards equal without the unbounded
          // height that CrossAxisAlignment.stretch forces inside a ListView.
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Expanded(
                    child: _entry(context, s.requestSupply,
                        s.requestSupplyBody, Icons.assignment_outlined, '/request')),
                const SizedBox(width: 12),
                Expanded(
                    child: _entry(context, s.startBusiness, s.startBusinessBody,
                        Icons.storefront_outlined, '/business')),
              ])),
          SectionHeader(s.availableToday,
              action: s.viewAll, onTap: () => context.go('/explore')),
          SizedBox(
              height: 36,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: ['', ...categories]
                      .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CategoryChip(
                              label: c.isEmpty ? s.all : label(c),
                              selected: c == chip,
                              onTap: () => setState(() => chip = c))))
                      .toList())),
          const SizedBox(height: 16),
          ListingFeed(category: chip),
        ]);
  }

  Widget _entry(BuildContext context, String title, String subtitle,
          IconData icon, String route) =>
      InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OColors.border)),
                  child: Stack(children: [
                    const Positioned(
                        right: -18,
                        bottom: -18,
                        child: LeafWatermark(size: 76)),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: OColors.soft,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(icon,
                                      size: 19, color: OColors.forest)),
                              const SizedBox(height: 12),
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(subtitle,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: OColors.secondary,
                                      height: 1.35))
                            ])),
                  ]))));

}

/// The Buy Supply card: a real photo, a diagonal forest scrim, the "Quality
/// From Our Farmers" mark baked into dashboard_banner.jpg, a pill button and
/// carousel dots. There is only one banner in V1, so the dots are a static
/// design element rather than a working carousel.
class _BuySupplyBanner extends ConsumerWidget {
  const _BuySupplyBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return InkWell(
        onTap: () => context.go('/explore'),
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(children: [
                  const Positioned.fill(
                      child: BrandImage('dashboard_banner',
                          fallbackArt: 'broilers')),
                  Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: const [0, .55, 1],
                                  colors: [
                                OColors.forest,
                                OColors.forest.withValues(alpha: .82),
                                OColors.forest.withValues(alpha: .25),
                              ])))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.buySupplyCard,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            SizedBox(
                                width: 190,
                                child: Text(s.buySupplyCardBody,
                                    style: const TextStyle(
                                        color: Color(0xFFD6E5DA),
                                        fontSize: 13,
                                        height: 1.4))),
                            const Spacer(),
                            InkWell(
                                onTap: () => context.go('/explore'),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 11),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(24)),
                                    child: Text(s.exploreNow,
                                        style: const TextStyle(
                                            color: OColors.forest,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5)))),
                          ])),
                  Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Container(
                                  width: i == 0 ? 16 : 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: i == 0 ? 1 : .5),
                                      borderRadius: BorderRadius.circular(3))),
                          ])),
                ]))));
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: selected ? OColors.forest : OColors.soft,
                  borderRadius: BorderRadius.circular(18)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : OColors.secondary)))));
}
