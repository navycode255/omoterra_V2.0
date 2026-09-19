import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/photo_picker.dart';
import '../../shared/widgets/supply_art.dart';

class RequestSupplyScreen extends StatefulWidget {
  const RequestSupplyScreen({super.key});
  @override
  State<RequestSupplyScreen> createState() => _RequestSupplyState();
}

class _RequestSupplyState extends State<RequestSupplyScreen> {
  List<String> photos = [];
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: OmoterraAppBar(title: const Text('Request Supply')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('The supply you need.\nSourced by Omoterra.',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
            'Tell us your requirements. Our team will follow up when suitable supply is found.'),
        const SizedBox(height: 24),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Add a reference photo (optional)',
                style: TextStyle(fontSize: 14)),
            children: [
              PhotoPicker(
                  photos: photos,
                  limit: 1,
                  onChanged: (value) => setState(() => photos = value)),
              const SizedBox(height: 16)
            ]),
        const SizedBox(height: 24),
        DataForm(
            path: '/requests',
            fields: [
              const FormFieldSpec('category', 'Category', options: categories),
              const FormFieldSpec('quantity', 'Quantity', numeric: true),
              const FormFieldSpec(
                  'weight_or_size_requirement', 'Preferred weight or size',
                  optional: true),
              const FormFieldSpec(
                  'live_dressed_or_cut', 'Live, dressed or preferred cut',
                  optional: true),
              FormFieldSpec('needed_by_date', 'Needed by (YYYY-MM-DD)',
                  initial: DateTime.now()
                      .add(const Duration(days: 1))
                      .toIso8601String()
                      .split('T')
                      .first),
              const FormFieldSpec('delivery_area', 'Delivery area'),
              const FormFieldSpec('notes', 'Additional notes',
                  optional: true, multiline: true)
            ],
            transform: (data) => {
                  ...data,
                  'unit_type': unitFor(data['category']),
                  'reference_photo': photos.isEmpty ? null : photos.first
                },
            button: 'Submit request',
            onSuccess: (data) => context.go('/request-submitted/${data['id']}'))
      ]));
}

class RequestDetail extends StatelessWidget {
  final String id;
  const RequestDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: OmoterraAppBar(title: const Text('Supply request')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/requests/$id',
            builder: (data) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('We’re on it.',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 12),
                  Text('Request #${id.substring(0, 8).toUpperCase()}'),
                  const SizedBox(height: 24),
                  StatusText(data['status']),
                  const SizedBox(height: 16),
                  SourcingProgress(data['status']),
                  const SizedBox(height: 24),
                  MoneySummary({
                    'Supply': label(data['category']),
                    'Quantity':
                        '${amount(data['quantity'])} ${data['unit_type']}',
                    'Needed by': data['needed_by_date'],
                    'Delivery area': data['delivery_area']
                  }),
                  const SizedBox(height: 24),
                  const Text(
                      'Omoterra will contact you to confirm availability and delivery.'),
                  if (data['converted_order_id'] != null) ...[
                    const SizedBox(height: 24),
                    OmoterraButton('Track your order',
                        onPressed: () =>
                            context.go('/order/${data['converted_order_id']}'))
                  ]
                ]))
      ]));
}

const businesses = {
  'chicken_shop': [
    'Chicken Shop',
    'A suitable selling space, safe handling and cold storage.',
    'We help you source chicken stock and coordinate supply.'
  ],
  'butchery': [
    'Butchery',
    'Suitable premises, hygienic preparation space and refrigeration.',
    'We help you find meat supply for your opening stock.'
  ],
  'fish_shop': [
    'Fish Shop',
    'Cold storage, hygienic display and a suitable location.',
    'Our team can discuss your plan. Fish supply is subject to availability.'
  ],
  'meat_delivery': [
    'Chicken / Meat Delivery',
    'Safe insulated transport and a clear delivery area.',
    'We help source your starting supply and coordinate collection.'
  ],
  'egg_reseller': [
    'Egg Reseller',
    'Safe dry storage, protective trays and local customers.',
    'Our team can discuss sourcing options for your plan.'
  ],
  'local_chicken_business': [
    'Local Chicken Business',
    'Appropriate holding space and a clear target market.',
    'We help source available local chicken.'
  ],
  'goat_meat_business': [
    'Goat Meat Business',
    'Hygienic premises, storage and a handling plan.',
    'We help coordinate goat or goat meat supply.'
  ],
  'restaurant_grill': [
    'Small Restaurant / Grill',
    'Suitable premises, food preparation equipment and storage.',
    'We help source the livestock and meat your menu needs.'
  ],
};

class BusinessScreen extends StatelessWidget {
  final String? type;
  final bool request;
  const BusinessScreen({super.key, this.type, this.request = false});
  @override
  Widget build(BuildContext context) {
    final entry = businesses[type];
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(entry == null ? 'Start a Business' : entry[0])),
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
                            for (final e in businesses.entries)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                      onTap: () =>
                                          context.push('/business/${e.key}'),
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
                                                        'business_${e.key}',
                                                        fallbackArt: e.key,
                                                        height: 58))),
                                            const SizedBox(width: 13),
                                            Expanded(
                                                child: Text(e.value[0],
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
                        const Text(
                            'Tell us a little about your plan. We’ll use your account details to get in touch.'),
                        const SizedBox(height: 24),
                        DataForm(
                            path: '/business-opportunities',
                            fixed: {'business_type': type},
                            fields: const [
                              FormFieldSpec('area', 'Area'),
                              FormFieldSpec(
                                  'budget_range', 'Budget range (TZS)'),
                              FormFieldSpec(
                                  'has_premises', 'Do you have premises?',
                                  options: ['no', 'yes']),
                              FormFieldSpec(
                                  'wants_stock', 'Do you need starting stock?',
                                  options: ['yes', 'no']),
                              FormFieldSpec('target_start_date',
                                  'When would you like to start?', options: [
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
                            button: 'Request a setup plan',
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
                                Text(entry[0],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                SectionHeader(s.whatYouNeed),
                                Text(entry[1],
                                    style: const TextStyle(height: 1.5)),
                                SectionHeader(s.howOmoterraHelps),
                                Text(entry[2],
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
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 52),
        const Center(child: SupplyArt('request', size: 130)),
        const SizedBox(height: 24),
        Text('We’re sourcing this for you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text('Reference #${id.substring(0, 8).toUpperCase()}',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Text(
            'The Omoterra team will review your requirements and follow up with suitable supply.',
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        OmoterraButton('View request',
            onPressed: () => context.go('/requests/$id')),
        const SizedBox(height: 12),
        OmoterraButton('Back to Home',
            secondary: true, onPressed: () => context.go('/buyer')),
      ])));
}

class SourcingProgress extends StatelessWidget {
  final String status;
  const SourcingProgress(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') return const StatusText('cancelled');
    const steps = ['submitted', 'sourcing', 'supply_found', 'confirmed'];
    return Column(children: [
      for (int i = 0; i < steps.length; i++)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Icon(
                  i <= steps.indexOf(status)
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: i <= steps.indexOf(status)
                      ? const Color(0xFF123D2D)
                      : const Color(0xFF909A94)),
              const SizedBox(width: 14),
              Text(label(steps[i]),
                  style: TextStyle(
                      fontWeight: steps[i] == status
                          ? FontWeight.w700
                          : FontWeight.w400)),
            ]))
    ]);
  }
}
