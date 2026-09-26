import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/supply_art.dart';

/// Business types a buyer can ask for a setup plan for; the copy for each
/// is [Strings.business].
const businesses = [
  'chicken_shop',
  'butchery',
  'fish_shop',
  'meat_delivery',
  'egg_reseller',
  'local_chicken_business',
  'goat_meat_business',
  'restaurant_grill',
];

class BusinessScreen extends StatelessWidget {
  final String? type;
  final bool request;
  const BusinessScreen({super.key, this.type, this.request = false});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final entry = businesses.contains(type) ? s.business(type!) : null;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(entry == null ? s.startBusinessTitle : entry.$1)),
        body: ListView(
            padding: const EdgeInsets.all(20),
            children: entry == null
                ? [
                    Consumer(builder: (context, ref, _) {
                      final s = ref.s;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.startBusinessIntro,
                                style: const TextStyle(
                                    color: OColors.secondary, height: 1.5)),
                            const SizedBox(height: 20),
                            for (final key in businesses)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                      onTap: () =>
                                          context.push('/business/$key'),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: OColors.border)),
                                          child: Row(children: [
                                            ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: SizedBox(
                                                    width: 58,
                                                    child: BrandImage(
                                                        'business_$key',
                                                        fallbackArt: key,
                                                        height: 58))),
                                            const SizedBox(width: 13),
                                            Expanded(
                                                child: Text(s.business(key).$1,
                                                    style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                            const Icon(Icons.chevron_right,
                                                color: OColors.muted),
                                          ]))))
                          ]);
                    })
                  ]
                : request
                    ? [
                        Text(s.planIntro),
                        const SizedBox(height: 24),
                        DataForm(
                            path: '/business-opportunities',
                            fixed: {'business_type': type},
                            fields: [
                              FormFieldSpec('area', s.area),
                              FormFieldSpec('budget_range', s.budgetRangeTzs),
                              FormFieldSpec('has_premises', s.havePremisesQ,
                                  options: const ['no', 'yes']),
                              FormFieldSpec('wants_stock', s.needStartingStockQ,
                                  options: const ['yes', 'no']),
                              FormFieldSpec('target_start_date', s.whenStart,
                                  options: const [
                                    'within_2_weeks',
                                    'within_1_month',
                                    'within_3_months',
                                    'still_planning'
                                  ])
                            ],
                            transform: (d) => {
                                  ...d,
                                  'has_premises': d['has_premises'] == 'yes',
                                  'wants_stock': d['wants_stock'] == 'yes'
                                },
                            button: s.requestASetupPlan,
                            onSuccess: (_) => context.go('/business-submitted'))
                      ]
                    : [
                        Consumer(builder: (context, ref, _) {
                          final s = ref.s;
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BrandImage('business_$type',
                                        fallbackArt: type!, height: 176)),
                                const SizedBox(height: 18),
                                Text(entry.$1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                SectionHeader(s.whatYouNeed),
                                Text(entry.$2,
                                    style: const TextStyle(height: 1.5)),
                                SectionHeader(s.howOmoterraHelps),
                                Text(entry.$3,
                                    style: const TextStyle(height: 1.5)),
                                const SizedBox(height: 28),
                                OmoterraButton(s.requestSetupPlan,
                                    onPressed: () =>
                                        context.push('/business/$type/request'))
                              ]);
                        })
                      ]));
  }
}

class RequestSubmitted extends StatelessWidget {
  final String id;
  const RequestSubmitted(this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 52),
      const Center(child: SupplyArt('request', size: 130)),
      const SizedBox(height: 24),
      Text(s.sourcingTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text(s.referenceNo(id.substring(0, 8).toUpperCase()),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Text(s.teamWillReview, textAlign: TextAlign.center),
      const SizedBox(height: 32),
      OmoterraButton(s.viewRequestLower,
          onPressed: () => context.go('/requests/$id')),
      const SizedBox(height: 12),
      OmoterraButton(s.backHome,
          secondary: true, onPressed: () => context.go('/buyer')),
    ])));
  }
}

class SourcingProgress extends StatelessWidget {
  final String status;
  const SourcingProgress(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') return const StatusText('cancelled');
    const steps = [
      'open',
      'partially_matched',
      'fully_matched',
      'confirmed',
      'fulfilling',
      'completed'
    ];
    final s = context.s;
    final normalized = switch (status) {
      'submitted' => 'open',
      'sourcing' => 'partially_matched',
      'supply_found' => 'fully_matched',
      _ => status,
    };
    final current = steps.indexOf(normalized);
    return Column(children: [
      for (int i = 0; i < steps.length; i++)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Icon(i <= current ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: i <= current
                      ? const Color(0xFF123D2D)
                      : const Color(0xFF909A94)),
              const SizedBox(width: 14),
              Text(
                  steps[i] == 'fulfilling'
                      ? s.preparingInTransit
                      : s.requestStep(steps[i]),
                  style: TextStyle(
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w400)),
            ]))
    ]);
  }
}
