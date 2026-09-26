import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';

class SupplierHome extends ConsumerWidget {
  const SupplierHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    final profileState = ref.watch(resourceProvider('/supplier/profile'));
    final profile = profileState.hasValue ? profileState.value : null;
    final isUnderReview = profile is Map && profile['status'] == 'under_review';
    // Pending suppliers cannot use inventory features yet. Avoid requesting
    // those resources so access restrictions don't surface as dashboard errors.
    final batchesState =
        isUnderReview ? null : ref.watch(resourceProvider('/supplier/batches'));
    final stockState =
        isUnderReview ? null : ref.watch(resourceProvider('/supplier/stock'));
    if (profileState.hasError ||
        (!isUnderReview && (batchesState!.hasError || stockState!.hasError))) {
      final error = profileState.hasError
          ? profileState.error!
          : batchesState!.hasError
              ? batchesState.error!
              : stockState!.error!;
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          // Supplier Home sits behind the shared transparent app bar. Keep
          // the notice and error below that chrome in the error-only layout.
          SizedBox(height: MediaQuery.paddingOf(context).top + 64),
          if (profile is Map && profile['status'] != 'approved')
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: _SupplierStatusNotice(profile: profile),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: ErrorState(
              error,
              retry: () {
                if (profileState.hasError) {
                  ref.invalidate(resourceProvider('/supplier/profile'));
                }
                if (batchesState?.hasError == true) {
                  ref.invalidate(resourceProvider('/supplier/batches'));
                }
                if (stockState?.hasError == true) {
                  ref.invalidate(resourceProvider('/supplier/stock'));
                }
              },
            ),
          ),
        ],
      );
    }
    // paddingOf().top already includes the top bar here (the body sits
    // behind it), so this puts Market Demand where the design has it.
    final heroHeight = MediaQuery.paddingOf(context).top + 219;
    // The cards overlap the bottom of the photo. The photo extends down
    // behind them rather than the cards being shifted up: a list routes taps
    // by each item's own box, so shifted cards lost taps on their top part.
    const overlap = 42.0;
    // The headline fills the space beside the hen, and shrinks on narrow phones.
    final headline = (MediaQuery.sizeOf(context).width * .08).clamp(24.0, 34.0);
    return ListView(padding: EdgeInsets.zero, children: [
      SizedBox(
        height: heroHeight - overlap,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: heroHeight,
              child: Stack(fit: StackFit.expand, children: [
                const BrandImage('supplier-home-hero-v1',
                    extension: 'png',
                    fallbackArt: 'broilers',
                    alignment: Alignment(.35, 0)),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0x550B2E21), Colors.transparent]))),
                Positioned(
                    left: 24,
                    bottom: 46,
                    right: 110,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.supplierHeroTitle,
                              style: TextStyle(
                                  fontSize: headline,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black26, blurRadius: 8)
                                  ])),
                          const SizedBox(height: 6),
                          Text(s.supplierHeroBody,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: headline * .5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w500,
                                  shadows: const [
                                    Shadow(color: Colors.black26, blurRadius: 6)
                                  ])),
                        ])),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 110,
                    child: IgnorePointer(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                          Colors.transparent,
                          OColors.background.withValues(alpha: .12),
                          OColors.background.withValues(alpha: .62),
                          OColors.background,
                        ],
                                    stops: const [
                          0,
                          .52,
                          .82,
                          1
                        ]))))),
              ])),
        ]),
      ),
      if (isUnderReview)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: _SupplierStatusNotice(profile: profile),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Column(children: [
            ResourceView('/supplier/profile', builder: (profile) {
              if (profile == null) {
                return SupplierTile(
                  title: s.completeSupplierRegistration,
                  subtitle: s.completeSupplierRegistrationBody,
                  icon: Icons.assignment_ind_outlined,
                  prominent: true,
                  onTap: () => context.push('/register-role/supplier'),
                );
              }
              if (profile['status'] == 'approved') {
                return const SizedBox.shrink();
              }
              if (profile['status'] == 'new') {
                return SupplierTile(
                  title: s.completeSupplierRegistration,
                  subtitle: s.completeSupplierProductsBody,
                  icon: Icons.assignment_ind_outlined,
                  prominent: true,
                  onTap: () => context.push('/register-role/supplier'),
                );
              }
              return _SupplierStatusNotice(profile: profile);
            }),
            ResourceView('/supplier/batches', builder: (data) {
              final batches = (data as List).cast<Map>();
              final active = batches
                  .where((batch) => !['completed', 'cancelled', 'paused']
                      .contains(batch['status']))
                  .toList();
              if (active.isEmpty) return const SizedBox.shrink();
              return _BatchSummary(active.first);
            }),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: Column(children: [
              SupplierTile(
                  title: s.marketDemand,
                  icon: Icons.storefront_outlined,
                  feature: true,
                  onTap: () => context.go('/supplier-demand')),
              const SizedBox(height: 11),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: SupplierTile(
                        title: s.payouts,
                        icon: Icons.payments_outlined,
                        leading: const MoneyStackIcon(size: 25),
                        onTap: () => context.push('/payouts'))),
                const SizedBox(width: 9),
                Expanded(
                    child: SupplierTile(
                        title: s.sales,
                        icon: Icons.receipt_long_outlined,
                        onTap: () => context.push('/sales'))),
              ]),
              // Stock matters most day to day, so it comes before ratings.
              const SizedBox(height: 10),
              const _QuickStats(),
              const _RatingTile(),
            ])),
      ],
    ]);
  }
}

/// The supplier's current batch: what it is, how many, where it stands.
class _BatchSummary extends StatelessWidget {
  final Map batch;
  const _BatchSummary(this.batch);
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final category = '${batch['category']}';
    final quantity = num.tryParse('${batch['current_quantity']}');
    return DecorCard(
        onTap: () => context.go('/stock'),
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined,
              size: 30, color: OColors.forest),
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s.label(category),
                    style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: OColors.ink)),
                const SizedBox(height: 2),
                Text(
                    '${amount(quantity ?? 0)} ${s.unit(unitFor(category), quantity)}',
                    style: const TextStyle(fontSize: 16, color: OColors.ink)),
                const SizedBox(height: 4),
                Text(
                    batch['approved_at'] == null
                        ? s.awaitingReview
                        : s.status('${batch['status']}'),
                    style: const TextStyle(
                        fontSize: 13.5, color: OColors.secondary)),
              ])),
          Text(s.myStock,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0B5E3F))),
          const Icon(Icons.chevron_right, size: 22, color: Color(0xFF0B5E3F)),
        ]));
  }
}

class _SupplierStatusNotice extends StatelessWidget {
  final Map profile;
  const _SupplierStatusNotice({required this.profile});

  @override
  Widget build(BuildContext context) {
    final status = profile['status'];
    final s = context.s;
    final (title, message) = switch (status) {
      'under_review' => (s.statusUnderReviewTitle, s.statusUnderReviewBody),
      'suspended' => (s.statusSuspendedTitle, s.statusSuspendedBody),
      'rejected' => (s.statusRejectedTitle, s.statusRejectedBody),
      'new' => (s.statusNewTitle, s.statusNewBody),
      _ => (s.statusOtherTitle, s.statusOtherBody),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OColors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: OColors.forest),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: OColors.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(message,
                    style: const TextStyle(color: OColors.ink, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The mockup's three card styles: [feature] (Market Demand: pale green,
/// round dark › button), prominent rows (Buyer Ratings, registration prompts),
/// and compact half-width cards (Payouts, Sales Records).
class SupplierTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? leading;
  final VoidCallback onTap;
  final bool prominent;
  final bool feature;
  const SupplierTile(
      {super.key,
      required this.title,
      this.subtitle,
      required this.icon,
      this.leading,
      required this.onTap,
      this.prominent = false,
      this.feature = false});

  static const _green = Color(0xFF0B5E3F);

  @override
  Widget build(BuildContext context) {
    final big = feature || prominent;
    final copy =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Half-width cards shrink a long title slightly instead of cutting it.
      FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title,
              maxLines: 1,
              style: TextStyle(
                  fontSize: big ? 16.5 : 14.5,
                  fontWeight: FontWeight.w800,
                  color: OColors.ink,
                  letterSpacing: -.2))),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle!,
            style: const TextStyle(fontSize: 12, color: OColors.secondary)),
      ],
    ]);
    final trailing = feature
        ? Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: OColors.forest, shape: BoxShape.circle),
            child:
                const Icon(Icons.chevron_right, color: Colors.white, size: 22))
        : Icon(Icons.chevron_right, color: OColors.ink, size: big ? 24 : 18);
    return DecorCard(
        onTap: onTap,
        wave: true,
        waveColor: feature ? const Color(0xFFD5EADC) : const Color(0xFFE6F2EA),
        gradient: feature
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFEAF5EE), Color(0xFFF6FBF8)])
            : null,
        padding: EdgeInsets.symmetric(
            horizontal: big ? 17 : 13, vertical: feature ? 10 : (big ? 8 : 14)),
        child: Row(children: [
          // A fixed icon slot keeps paired cards exactly the same height.
          SizedBox(
              height: feature ? 36 : (big ? 30 : 26),
              child: Center(
                  child: leading ??
                      Icon(icon,
                          size: feature ? 36 : (big ? 30 : 24),
                          color: _green))),
          SizedBox(width: big ? 14 : 11),
          Expanded(child: copy),
          SizedBox(width: big ? 6 : 2),
          trailing,
        ]));
  }
}

/// Stacked banknotes with a coin, drawn to match the Payouts icon in the
/// design (Material Icons has no equivalent).
class MoneyStackIcon extends StatelessWidget {
  final double size;
  const MoneyStackIcon({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size * 1.2, size), painter: _MoneyStackPainter());
}

class _MoneyStackPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    const dark = Color(0xFF0B5E3F);
    final stroke = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .055
      ..strokeJoin = StrokeJoin.round;
    // Three banknotes, each drawn as a thick slab (top face + front edge).
    for (final (dy, face) in [
      (.3, const Color(0xFF2F8A5E)),
      (.16, const Color(0xFF45A372)),
      (0.02, const Color(0xFF63BA8A)),
    ]) {
      final top = Path()
        ..moveTo(w * .04, h * (.42 + dy))
        ..lineTo(w * .56, h * (.12 + dy))
        ..lineTo(w * .96, h * (.34 + dy))
        ..lineTo(w * .44, h * (.64 + dy))
        ..close();
      final edge = Path()
        ..moveTo(w * .04, h * (.42 + dy))
        ..lineTo(w * .44, h * (.64 + dy))
        ..lineTo(w * .96, h * (.34 + dy))
        ..lineTo(w * .96, h * (.44 + dy))
        ..lineTo(w * .44, h * (.74 + dy))
        ..lineTo(w * .04, h * (.52 + dy))
        ..close();
      c.drawPath(edge, Paint()..color = const Color(0xFF1F6E49));
      c.drawPath(edge, stroke);
      c.drawPath(top, Paint()..color = face);
      c.drawPath(top, stroke);
    }
    final coin = Rect.fromCenter(
        center: Offset(w * .5, h * .4), width: w * .24, height: h * .15);
    c.drawOval(coin, Paint()..color = const Color(0xFFD3EEDC));
    c.drawOval(coin, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tiles = [
      (s.totalStock, 'quantity_total', const Color(0xFFEDF5F0)),
      (s.reservedStat, 'quantity_reserved', const Color(0xFFEEF2F4)),
      (s.availableStat, 'quantity_available', const Color(0xFFEDF5F0)),
    ];
    return ResourceView('/supplier/stock', builder: (data) {
      // Figures only mean something once Omoterra has approved some stock.
      final rows = (data as List)
          .where((r) =>
              !['pending_review', 'rejected'].contains(r['listing_status']))
          .toList();
      final units = rows.map((r) => '${r['unit_type']}').toSet();
      return DecorCard(
          padding: EdgeInsets.fromLTRB(
              16, rows.isEmpty ? 14 : 0, 10, rows.isEmpty ? 14 : 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.quickStats,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OColors.ink,
                            letterSpacing: -.2)),
                    if (rows.isEmpty) ...[
                      const SizedBox(height: 3),
                      Text(s.statsAfterApproval,
                          style: const TextStyle(
                              fontSize: 14, color: OColors.secondary)),
                    ],
                  ])),
              TextButton(
                  // Compact, so the figures start sooner under the title.
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0B5E3F),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6)),
                  onPressed: () => context.go('/stock'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.viewStock,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, size: 20),
                  ]))
            ]),
            for (final unit in units) ...[
              if (units.length > 1)
                Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                        unit == 'kg' ? s.kilograms : s.label('${unit}s'),
                        style: const TextStyle(
                            fontSize: 12, color: OColors.secondary))),
              Row(children: [
                for (final (i, stat) in tiles.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 2),
                          decoration: BoxDecoration(
                              color: stat.$3,
                              borderRadius: BorderRadius.circular(14)),
                          child: Column(children: [
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    amount(rows
                                        .where((r) => r['unit_type'] == unit)
                                        .fold<num>(
                                            0,
                                            (sum, r) =>
                                                sum +
                                                (num.tryParse(
                                                        '${r[stat.$2]}') ??
                                                    0))),
                                    // Available is what a supplier can sell,
                                    // so only it carries full emphasis.
                                    style: TextStyle(
                                        fontSize: 22,
                                        height: 1.1,
                                        fontWeight:
                                            stat.$2 == 'quantity_available'
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                        color: stat.$2 == 'quantity_available'
                                            ? OColors.forest
                                            : const Color(0xFF4A5A52),
                                        letterSpacing: -.3))),
                            const SizedBox(height: 2),
                            Text(stat.$1,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: OColors.secondary)),
                          ]))),
                ],
              ]),
            ],
          ]));
    });
  }
}

/// Buyer ratings at a glance; hidden until it loads, and if it cannot.
class _RatingTile extends ConsumerWidget {
  const _RatingTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SupplierTile(
            title: ref.s.buyerRatings,
            icon: Icons.star_border,
            prominent: true,
            onTap: () => context.push('/supplier-reviews')));
  }
}
