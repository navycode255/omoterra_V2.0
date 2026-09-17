import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/photo_picker.dart';

class RequestSupplyScreen extends StatefulWidget {
  const RequestSupplyScreen({super.key});
  @override
  State<RequestSupplyScreen> createState() => _RequestSupplyState();
}

class _RequestSupplyState extends State<RequestSupplyScreen> {
  List<String> photos = [];
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Request Supply')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('The supply you need.\nSourced by Omoterra.',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
            'Tell us your requirements. Our team will follow up when suitable supply is found.'),
        const SizedBox(height: 24),
        PhotoPicker(
            photos: photos,
            limit: 1,
            onChanged: (value) => setState(() => photos = value)),
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
            onSuccess: (data) => context.go('/requests/${data['id']}'))
      ]));
}

class RequestDetail extends StatelessWidget {
  final String id;
  const RequestDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Supply request')),
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
                  const Text('Submitted → Sourcing → Supply Found → Confirmed'),
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
        appBar:
            AppBar(title: Text(entry == null ? 'Start a Business' : entry[0])),
        body: ListView(
            padding: const EdgeInsets.all(20),
            children: entry == null
                ? [
                    Text('Your next chapter\nstarts here.',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 12),
                    const Text(
                        'Explore a business idea. Let Omoterra help with your supply.'),
                    const SizedBox(height: 24),
                    for (final e in businesses.entries)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Surface(
                              child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.value[0]),
                                  trailing: const Icon(Icons.arrow_forward),
                                  onTap: () =>
                                      context.push('/business/${e.key}'))))
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
                                  'When would you like to start?')
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
                        const Icon(Icons.storefront_outlined, size: 64),
                        const SectionHeader('What you’ll need'),
                        Text(entry[1]),
                        const SectionHeader('How Omoterra helps'),
                        Text(entry[2]),
                        const SizedBox(height: 32),
                        OmoterraButton('Request a Setup Plan',
                            onPressed: () =>
                                context.push('/business/$type/request'))
                      ]));
  }
}
