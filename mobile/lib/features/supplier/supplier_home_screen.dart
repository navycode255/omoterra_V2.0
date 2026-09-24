import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/api/repository.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';

class SupplierHome extends ConsumerWidget {
  const SupplierHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return ListView(padding: EdgeInsets.zero, children: [
      SizedBox(
        height: MediaQuery.paddingOf(context).top + 330,
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
              bottom: 65,
              right: 110,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grow Beyond\nthe Farm',
                        style: TextStyle(
                            fontSize: 25,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 8)
                            ])),
                    const SizedBox(height: 12),
                    const Text('Reach more buyers.\nBuild a stronger business.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600)),
                  ])),
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 130,
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
                  title: 'Complete supplier registration',
                  subtitle: 'Add your farm, products and pickup details',
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
                  title: 'Complete supplier registration',
                  subtitle: 'Add your products, production and pickup details',
                  icon: Icons.assignment_ind_outlined,
                  prominent: true,
                  onTap: () => context.push('/register-role/supplier'),
                );
              }
              return _SupplierStatusNotice(profile: profile);
            }),
            ResourceView('/supplier/batches', builder: (data) {
              final batches = (data as List).cast<Map>();
              if (batches.isEmpty) {
                return ResourceView('/supplier/profile', builder: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  return SupplierTile(
                    title: 'Add your current production',
                    subtitle:
                        'Tell us what you have growing or ready to supply',
                    icon: Icons.add_circle_outline,
                    prominent: true,
                    onTap: () => context.push('/batches/new'),
                  );
                });
              }
              final active = batches
                  .where((batch) => !['completed', 'cancelled', 'paused']
                      .contains(batch['status']))
                  .toList();
              if (active.isEmpty) return const SizedBox.shrink();
              final batch = active.first;
              return Surface(
                  color: Colors.white,
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: OColors.forest),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '${label('${batch['category']}')} · ${batch['current_quantity']} ${unitFor('${batch['category']}')}',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                              batch['approved_at'] == null
                                  ? 'Batch awaiting Omoterra review'
                                  : 'Production recorded · ${label('${batch['status']}')}',
                              style: TextStyle(color: OColors.secondary))
                        ])),
                    TextButton(
                        onPressed: () => context.go('/stock'),
                        child: const Text('My Stock'))
                  ]));
            }),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Transform.translate(
                offset: const Offset(0, -42),
                child: Column(children: [
                  SupplierTile(
                      title: 'Market Demand',
                      subtitle: 'See what buyers need and offer your supply',
                      icon: Icons.storefront_outlined,
                      prominent: true,
                      onTap: () => context.go('/supplier-demand')),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: SupplierTile(
                            title: 'Add Stock',
                            subtitle: 'Register livestock ready now',
                            icon: Icons.add_circle,
                            onTap: () => context.push('/stock/new'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: SupplierTile(
                            title: 'My Stock',
                            subtitle: 'Listings and production batches',
                            icon: Icons.inventory_2_outlined,
                            onTap: () => context.go('/stock'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: SupplierTile(
                            title: 'Reservations',
                            subtitle: 'Supply secured for orders',
                            icon: Icons.event_available_outlined,
                            onTap: () => context.go('/supplier-orders'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: SupplierTile(
                            title: 'Payouts',
                            subtitle: 'Track completed earnings',
                            icon: Icons.payments_outlined,
                            onTap: () => context.push('/payouts'))),
                  ]),
                  const SizedBox(height: 12),
                  SupplierTile(
                      title: 'Sales Records',
                      subtitle:
                          'Review completed sales and transaction history',
                      icon: Icons.receipt_long_outlined,
                      prominent: true,
                      onTap: () => context.push('/sales')),
                  const SizedBox(height: 12),
                  const _QuickStats(),
                ]))),
      ],
    ]);
  }
}

class _SupplierStatusNotice extends StatelessWidget {
  final Map profile;
  const _SupplierStatusNotice({required this.profile});

  @override
  Widget build(BuildContext context) {
    final status = profile['status'];
    final (title, message) = switch (status) {
      'under_review' => (
          'Registration under review',
          'We’ll let you know when your supplier account is ready.'
        ),
      'suspended' => (
          'Supplier account paused',
          'Contact Omoterra for help with your account.'
        ),
      'rejected' => (
          'Registration needs an update',
          'Please contact Omoterra to find out what to update.'
        ),
      'new' => (
          'Supplier registration not finished',
          'Complete your supplier details to continue.'
        ),
      _ => (
          'Supplier account status',
          'Contact Omoterra if you need help with your account.'
        ),
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

class SupplierTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool prominent;
  const SupplierTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap,
      this.prominent = false});
  @override
  Widget build(BuildContext context) {
    final copy =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle,
          style: const TextStyle(fontSize: 12, color: OColors.secondary)),
    ]);
    return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        elevation: 2,
        shadowColor: OColors.forest.withValues(alpha: .12),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(19),
            child: Padding(
                padding: EdgeInsets.all(prominent ? 18 : 14),
                child: prominent
                    ? Row(children: [
                        Icon(icon, size: 43, color: const Color(0xFF006747)),
                        const SizedBox(width: 16),
                        Expanded(child: copy),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: OColors.forest),
                      ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Center(
                                child: Icon(icon,
                                    size: 34, color: const Color(0xFF006747))),
                            const SizedBox(height: 10),
                            copy,
                          ]))));
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();
  @override
  Widget build(BuildContext context) =>
      ResourceView('/supplier/stock', builder: (data) {
        final rows = data as List;
        final units = rows.map((r) => '${r['unit_type']}').toSet();
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(19)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('Quick Stats',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800))),
                TextButton(
                    onPressed: () => context.go('/stock'),
                    child: const Text('View stock ›'))
              ]),
              if (rows.isEmpty)
                const Text('Add your first batch to see your stock here.'),
              for (final unit in units) ...[
                if (units.length > 1)
                  Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                          unit == 'kg' ? 'Kilograms' : '${label(unit)}s',
                          style: const TextStyle(
                              fontSize: 12, color: OColors.secondary))),
                Row(children: [
                  for (final stat in [
                    ('Total Stock', 'quantity_total'),
                    ('Reserved', 'quantity_reserved'),
                    ('Available', 'quantity_available')
                  ])
                    Expanded(
                        child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 2),
                            decoration: BoxDecoration(
                                color: OColors.soft,
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(children: [
                              Text(
                                  amount(rows
                                      .where((r) => r['unit_type'] == unit)
                                      .fold<num>(
                                          0,
                                          (sum, r) =>
                                              sum +
                                              (num.tryParse('${r[stat.$2]}') ??
                                                  0))),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: OColors.forest)),
                              Text(stat.$1,
                                  style: const TextStyle(
                                      fontSize: 11, color: OColors.secondary)),
                            ]))),
                ]),
              ],
            ]));
      });
}
