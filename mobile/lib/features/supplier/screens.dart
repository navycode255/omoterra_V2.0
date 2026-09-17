import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/photo_picker.dart';

class SupplierHome extends ConsumerWidget {
  const SupplierHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text(
            'Hello, ${ref.watch(sessionProvider).valueOrNull?.name.split(' ').first ?? 'there'}',
            style: const TextStyle(color: OColors.secondary)),
        const SizedBox(height: 8),
        Text('Your supply.\nNew possibilities.',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 24),
        ResourceView('/supplier/stock', builder: (rows) {
          num sum(String key) => (rows as List)
              .fold<num>(0, (sum, r) => sum + num.parse('${r[key]}'));
          return Column(children: [
            Surface(
                color: OColors.soft,
                child: Row(children: [
                  for (final e in {
                    'Available': 'quantity_available',
                    'Reserved': 'quantity_reserved',
                    'Sold': 'quantity_sold'
                  }.entries)
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(amount(sum(e.value)),
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          Text(e.key,
                              style: const TextStyle(
                                  fontSize: 12, color: OColors.secondary))
                        ]))
                ])),
            for (final row in rows)
              if (row['listing_status'] == 'needs_confirmation')
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Surface(
                        color: OColors.pale,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Confirm your stock',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                  'Are ${amount(row['quantity_available'])} ${label(row['category']).toLowerCase()} still available?'),
                              TextButton(
                                  onPressed: () =>
                                      context.push('/stock/${row['id']}'),
                                  child: const Text('Confirm availability'))
                            ])))
          ]);
        }),
        SectionHeader('Expected payment',
            action: 'View payouts', onTap: () => context.push('/payouts')),
        ResourceView('/supplier/payouts',
            builder: (rows) => InkWell(
                onTap: () => context.push('/payouts'),
                child: MoneySummary({
                  'Pending': tsh((rows as List)
                      .where((r) => r['status'] == 'pending')
                      .fold<num>(
                          0, (s, r) => s + num.parse('${r['total_payable']}')))
                }))),
        const SizedBox(height: 24),
        OmoterraButton('+ Add Stock',
            onPressed: () => context.push('/stock/new')),
        SectionHeader('Your stock',
            action: 'View all', onTap: () => context.go('/stock')),
        const StockList()
      ]);
}

class StockList extends StatelessWidget {
  final String status;
  const StockList({super.key, this.status = ''});
  @override
  Widget build(BuildContext context) =>
      ResourceView('/supplier/stock', builder: (rows) {
        final list = (rows as List)
            .where((r) => status.isEmpty || r['listing_status'] == status)
            .toList();
        if (list.isEmpty) {
          return EmptyState('No stock listed yet',
              'Add your available livestock and Omoterra will review it before it goes live.',
              action: OmoterraButton('Add Stock',
                  onPressed: () => context.push('/stock/new')));
        }
        return Column(children: [
          for (final row in list)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                    onTap: () => context.push('/stock/${row['id']}'),
                    child: Surface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(label(row['category']),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                              '${amount(row['quantity_available'])} ${row['unit_type']} available · ${amount(row['quantity_reserved'])} reserved'),
                          const SizedBox(height: 8),
                          StatusText(row['listing_status'])
                        ]))))
        ]);
      });
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockState();
}

class _StockState extends State<StockScreen> {
  String status = '';
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        SectionHeader('My stock',
            action: '+ Add', onTap: () => context.push('/stock/new')),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: [
              '',
              'live',
              'pending_review',
              'needs_confirmation',
              'paused',
              'sold_out'
            ]
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(s.isEmpty ? 'All stock' : label(s)),
                            selected: status == s,
                            onSelected: (_) => setState(() => status = s))))
                    .toList())),
        const SizedBox(height: 24),
        StockList(status: status)
      ]);
}

class StockDetail extends ConsumerWidget {
  final String id;
  const StockDetail(this.id, {super.key});
  Future<void> action(BuildContext context, WidgetRef ref,
      Map<String, dynamic> row, String action) async {
    await omoterraSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              action == 'confirm'
                  ? 'Confirm your stock'
                  : action == 'pause'
                      ? 'Pause listing'
                      : 'Update quantity',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(action == 'confirm'
              ? 'Are ${amount(row['quantity_available'])} ${label(row['category']).toLowerCase()} still available?'
              : action == 'pause'
                  ? 'Buyers will no longer be able to reserve this stock.'
                  : 'Enter the original total, including reserved and sold stock.'),
          const SizedBox(height: 24),
          DataForm(
              path: '/supplier/stock/$id',
              method: 'PATCH',
              fixed: {'action': action},
              fields: action == 'update'
                  ? [
                      FormFieldSpec('quantity_total', 'Total quantity',
                          numeric: true,
                          initial:
                              amount(row['quantity_total']).replaceAll(',', ''))
                    ]
                  : [],
              button: action == 'confirm'
                  ? 'Confirm ${amount(row['quantity_available'])}'
                  : 'Save',
              onSuccess: (_) {
                ref.invalidate(resourceProvider('/supplier/stock/$id'));
                ref.invalidate(resourceProvider('/supplier/stock'));
                Navigator.pop(context);
              })
        ]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('Stock details')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/supplier/stock/$id',
            builder: (row) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ProductImage(List<String>.from(row['photos'])),
                  const SizedBox(height: 24),
                  Text(label(row['category']),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  StatusText(row['listing_status']),
                  const SizedBox(height: 24),
                  MoneySummary({
                    'Original quantity': amount(row['quantity_total']),
                    'Available': amount(row['quantity_available']),
                    'Reserved': amount(row['quantity_reserved']),
                    'Sold': amount(row['quantity_sold']),
                    'Your asking price':
                        '${tsh(row['farmer_asking_price_per_unit'])} / ${row['unit_type']}'
                  }),
                  const SizedBox(height: 16),
                  MoneySummary(Map<String, dynamic>.from(row['specs'])
                      .map((k, v) => MapEntry(label(k), '$v'))),
                  const SizedBox(height: 24),
                  OmoterraButton('Update quantity',
                      onPressed: () => action(context, ref, row, 'update')),
                  if (!['pending_review', 'rejected']
                      .contains(row['listing_status'])) ...[
                    const SizedBox(height: 12),
                    OmoterraButton('Confirm availability',
                        secondary: true,
                        onPressed: () => action(context, ref, row, 'confirm')),
                    TextButton(
                        onPressed: () => action(context, ref, row, 'pause'),
                        child: const Text('Pause listing'))
                  ]
                ]))
      ]));
}

class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key});
  @override
  ConsumerState<AddStockScreen> createState() => _AddStockState();
}

class _AddStockState extends ConsumerState<AddStockScreen> {
  String category = 'broilers';
  int step = 0;
  Map<String, dynamic>? preview;
  List<String> photos = [];
  final controllers = <String, TextEditingController>{};
  final form = GlobalKey<FormState>();
  final key = newKey();
  bool busy = false;
  Object? error;
  TextEditingController field(String key, [String initial = '']) =>
      controllers.putIfAbsent(key, () => TextEditingController(text: initial));
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get specKeys => switch (unitFor(category)) {
        'bird' => [
            'avg_weight_kg',
            'breed_type',
            'age_weeks',
            'live_or_dressed',
            'ready_date'
          ],
        'animal' => [
            'weight_range',
            'breed',
            'sex',
            'approx_age',
            'ready_date'
          ],
        _ => ['cut_type', 'chilled_or_frozen', 'slaughter_date']
      };
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final row = await ref
          .read(repositoryProvider)
          .write('/supplier/stock', preview!, key: key);
      ref.invalidate(resourceProvider('/supplier/stock'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Stock submitted — Omoterra will review it before it appears to buyers.')));
        context.go('/stock/${row['id']}');
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Add Stock')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/supplier/profile', builder: (profile) {
          if (profile == null) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('First, your pickup details',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  const Text(
                      'These details are for Omoterra operations only. Buyers never see your legal name or pickup address.'),
                  const SizedBox(height: 24),
                  DataForm(
                      path: '/supplier/profile',
                      method: 'PUT',
                      fields: const [
                        FormFieldSpec('legal_name', 'Legal name'),
                        FormFieldSpec('internal_pickup_address',
                            'Internal pickup address',
                            multiline: true)
                      ],
                      button: 'Save & add stock',
                      onSuccess: (_) =>
                          ref.invalidate(resourceProvider('/supplier/profile')))
                ]);
          }
          return Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        [
                          'Choose a category',
                          'Stock details',
                          'Price & location',
                          'Photos',
                          'Review your stock'
                        ][step],
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                        value: (step + 1) / 5, minHeight: 3),
                    const SizedBox(height: 24),
                    if (step == 0)
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories
                              .map((c) => ChoiceChip(
                                  label: Text(label(c)),
                                  selected: category == c,
                                  onSelected: (_) =>
                                      setState(() => category = c)))
                              .toList()),
                    if (step == 1) ...[
                      OmoterraTextField('Quantity (${unitFor(category)})',
                          field('quantity_total'),
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true)),
                      for (final k in specKeys)
                        OmoterraTextField(
                            label(k) +
                                (k.endsWith('date') ? ' (YYYY-MM-DD)' : ''),
                            field(
                                k,
                                k.endsWith('date')
                                    ? DateTime.now()
                                        .toIso8601String()
                                        .split('T')
                                        .first
                                    : k == 'live_or_dressed'
                                        ? 'live'
                                        : k == 'chilled_or_frozen'
                                            ? 'chilled'
                                            : ''))
                    ],
                    if (step == 2) ...[
                      OmoterraTextField(
                          'Your asking price per ${unitFor(category)} (TZS)',
                          field('farmer_asking_price_per_unit'),
                          keyboard: TextInputType.number),
                      OmoterraTextField(
                          'General region',
                          field(
                              'region',
                              ref.read(sessionProvider).valueOrNull?.region ??
                                  '')),
                      const Text(
                          'Omoterra reviews your asking price before the stock becomes available to buyers.')
                    ],
                    if (step == 3)
                      PhotoPicker(
                          photos: photos,
                          onChanged: (value) => setState(() => photos = value)),
                    if (step == 4) ...[
                      MoneySummary({
                        'Category': label(category),
                        'Quantity':
                            '${preview!['quantity_total']} ${unitFor(category)}',
                        'Asking price':
                            tsh(preview!['farmer_asking_price_per_unit']),
                        'Region': preview!['region']
                      }),
                      const SizedBox(height: 12),
                      MoneySummary(Map<String, dynamic>.from(preview!['specs'])
                          .map((k, v) => MapEntry(label(k), '$v')))
                    ],
                    if (error != null) ErrorState(error!),
                    const SizedBox(height: 24),
                    OmoterraButton(step == 4 ? 'Submit for review' : 'Continue',
                        busy: busy, onPressed: () {
                      if (step == 4) {
                        submit();
                        return;
                      }
                      if (!form.currentState!.validate()) return;
                      setState(() {
                        if (step == 3) {
                          preview = {
                            'category': category,
                            'unit_type': unitFor(category),
                            'quantity_total':
                                field('quantity_total').text.trim(),
                            'farmer_asking_price_per_unit':
                                field('farmer_asking_price_per_unit')
                                    .text
                                    .trim(),
                            'region': field('region').text.trim(),
                            'specs': {
                              for (final k in specKeys) k: field(k).text.trim()
                            },
                            'photos': photos
                          };
                        }
                        step++;
                      });
                    }),
                    if (step > 0)
                      TextButton(
                          onPressed: busy ? null : () => setState(() => step--),
                          child: const Text('Back'))
                  ]));
        })
      ]));
}

class SupplierOrders extends StatelessWidget {
  final String? id;
  const SupplierOrders({super.key, this.id});
  @override
  Widget build(BuildContext context) {
    final body = ListView(padding: const EdgeInsets.all(20), children: [
      Text(id == null ? 'Orders & reservations' : 'Collection details',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
      ResourceView(id == null ? '/supplier/orders' : '/supplier/orders/$id',
          builder: (data) {
        final rows = id == null ? data as List : [data];
        if (rows.isEmpty) {
          return const EmptyState('No reservations yet',
              'When buyers reserve your approved stock, collection details will appear here.');
        }
        return Column(children: [
          for (final row in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                    onTap: id == null
                        ? () => context.push('/supplier-orders/${row['id']}')
                        : null,
                    child: Surface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              'Reservation #${row['id'].toString().substring(0, 8).toUpperCase()}'),
                          const SizedBox(height: 8),
                          Text(
                              '${label(row['category'])} · ${amount(row['quantity'])} ${row['unit_type']}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(row['expected_collection_date'] == null
                              ? 'Collection to be confirmed'
                              : 'Collection expected ${row['expected_collection_date']}'),
                          const SizedBox(height: 8),
                          StatusText(row['status']),
                          if (id != null) ...[
                            const SizedBox(height: 16),
                            Text(row['instructions']),
                            for (final p in row['settlements'])
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      'Settlement ${tsh(p['total_payable'])}'),
                                  subtitle: StatusText(p['status']),
                                  onTap: () =>
                                      context.push('/payouts/${p['id']}'))
                          ]
                        ]))))
        ]);
      })
    ]);
    return id == null ? body : Scaffold(appBar: AppBar(), body: body);
  }
}

class PayoutScreen extends StatelessWidget {
  final String? id;
  const PayoutScreen({super.key, this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          AppBar(title: Text(id == null ? 'Your payouts' : 'Payout details')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView(id == null ? '/supplier/payouts' : '/supplier/payouts/$id',
            builder: (data) {
          if (id != null) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusText(data['status']),
                  const SizedBox(height: 24),
                  MoneySummary({
                    'Asking price × ${amount(data['quantity'])}': tsh(
                        num.parse('${data['farmer_asking_price_per_unit']}') *
                            num.parse('${data['quantity']}')),
                    'Commission × ${amount(data['quantity'])}': tsh(
                        num.parse('${data['commission_amount_per_unit']}') *
                            num.parse('${data['quantity']}')),
                    'Your payout': tsh(data['total_payable'])
                  }),
                  if (data['payment_reference'] != null) ...[
                    const SizedBox(height: 24),
                    Text('Payment reference: ${data['payment_reference']}')
                  ]
                ]);
          }
          final rows = data as List;
          if (rows.isEmpty) {
            return const EmptyState('No payouts yet',
                'Settlements appear here after your supply is delivered.');
          }
          return Column(children: [
            MoneySummary({
              for (final status in ['pending', 'paid'])
                label(status): tsh(rows
                    .where((r) => r['status'] == status)
                    .fold<num>(
                        0, (s, r) => s + num.parse('${r['total_payable']}')))
            }),
            const SizedBox(height: 24),
            for (final row in rows)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tsh(row['total_payable'])),
                  subtitle: StatusText(row['status']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/payouts/${row['id']}'))
          ]);
        })
      ]));
}
