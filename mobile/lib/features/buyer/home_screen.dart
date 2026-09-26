import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import 'listing_feed.dart';

class BuyerHome extends ConsumerStatefulWidget {
  const BuyerHome({super.key});
  @override
  ConsumerState<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends ConsumerState<BuyerHome> {
  String chip = '';
  Timer? _greetingTimer;
  bool _showGreeting = false;
  DateTime? _scheduledDeadline;

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  void _syncGreeting(DateTime? deadline) {
    if (deadline == _scheduledDeadline) return;
    _scheduledDeadline = deadline;
    _greetingTimer?.cancel();
    final remaining = deadline?.difference(DateTime.now());
    final visible = remaining != null && remaining > Duration.zero;
    if (_showGreeting != visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showGreeting != visible) {
          setState(() => _showGreeting = visible);
        }
      });
    }
    if (visible) {
      _greetingTimer = Timer(remaining, () {
        if (mounted) setState(() => _showGreeting = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final s = ref.s;
    _syncGreeting(ref.watch(greetingUntilProvider));
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_showGreeting) ...[
            Text(s.greeting(user?.name.split(' ').first ?? ''),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
          ],
          Text(s.whatToday,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: OColors.ink,
                  letterSpacing: -.2)),
          const SizedBox(height: 14),
          const _BuySupplyBanner(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _entry(context, s.requestSupply,
                    Icons.assignment_outlined, '/request')),
            const SizedBox(width: 10),
            Expanded(
                child: _entry(context, s.startBusiness,
                    Icons.storefront_outlined, '/business')),
          ]),
          Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 12),
              child: Row(children: [
                Expanded(
                    child: Text(s.availableToday,
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: OColors.ink,
                            letterSpacing: -.4))),
                TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0B5E3F),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => context.go('/explore'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.viewAll,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ])),
              ])),
          SizedBox(
              height: 34,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: ['', ...categories]
                      .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CategoryChip(
                              label: c.isEmpty ? s.all : s.label(c),
                              selected: c == chip,
                              onTap: () => setState(() => chip = c))))
                      .toList())),
          const SizedBox(height: 16),
          ListingFeed(category: chip),
        ]);
  }

  /// A compact half-width action in the supplier-home card style: soft green
  /// wash with the wave, a plain coloured icon, the title and a chevron.
  Widget _entry(
          BuildContext context, String title, IconData icon, String route) =>
      DecorCard(
          onTap: () => context.push(route),
          wave: true,
          waveColor: const Color(0xFFDCEDE2),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFEDF6F0)]),
          padding: const EdgeInsets.fromLTRB(14, 15, 8, 15),
          child: Row(children: [
            Icon(icon, size: 26, color: const Color(0xFF0B5E3F)),
            const SizedBox(width: 10),
            Expanded(
                // Long titles (Swahili) shrink slightly instead of wrapping.
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        maxLines: 1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: OColors.ink,
                            letterSpacing: -.2)))),
            const Icon(Icons.chevron_right, size: 20, color: OColors.ink),
          ]));
}

/// The Buy Supply card: rotating full-width photography with a single call to
/// action overlaid on the open lower-left area of each image.
class _BuySupplyBanner extends ConsumerStatefulWidget {
  const _BuySupplyBanner();

  @override
  ConsumerState<_BuySupplyBanner> createState() => _BuySupplyBannerState();
}

class _BuySupplyBannerState extends ConsumerState<_BuySupplyBanner> {
  static const _slides = [
    ('chicken_banner', 'png', 'broilers'),
    ('goats_banner', 'png', 'goats'),
    ('logistics_banner', 'png', 'cattle'),
  ];
  Timer? _rotationTimer;
  int _activeSlide = 0;

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _activeSlide = (_activeSlide + 1) % _slides.length);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_activeSlide];
    return InkWell(
        onTap: () => context.go('/explore'),
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
                aspectRatio: 8 / 3,
                child: Stack(children: [
                  Positioned.fill(
                      child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: BrandImage(slide.$1,
                              key: ValueKey(slide.$1),
                              extension: slide.$2,
                              fallbackArt: slide.$3))),
                  // Each slide's artwork carries its own headline and call
                  // to action, so nothing is overlaid but the dots.
                  Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _slides.length; i++)
                              Container(
                                  width: i == _activeSlide ? 16 : 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                          alpha: i == _activeSlide ? 1 : .5),
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
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: selected ? OColors.forest : const Color(0xFFF1F5F2),
                  borderRadius: BorderRadius.circular(18)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : OColors.secondary)))));
}
