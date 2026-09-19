import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/photo_picker.dart';
import '../../shared/widgets/supply_art.dart';
import 'inventory_screens.dart';

class SupplierHome extends ConsumerWidget {
  const SupplierHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
              s.greeting(ref
                      .watch(sessionProvider)
                      .valueOrNull
                      ?.name
                      .split(' ')
                      .first ??
                  ''),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          ResourceView('/supplier/stock', builder: (rows) {
            return Column(children: [
              StockBalances(rows, labels: s),
              for (final row in rows)
                if (row['listing_status'] == 'needs_confirmation')
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFDF8F0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFF0DEC4))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.schedule,
                                      size: 17, color: OColors.warning),
                                  const SizedBox(width: 7),
                                  Text(s.confirmStock,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                    s.confirmStockBody(
                                        amount(row['quantity_available']),
                                        label(row['category']).toLowerCase()),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: OColors.secondary)),
                                const SizedBox(height: 8),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 34)),
                                    onPressed: () =>
                                        context.push('/stock/${row['id']}'),
                                    child: Text(
                                        s.confirmQty(amount(
                                            row['quantity_available']))))
                              ])))
            ]);
          }),
          const SizedBox(height: 12),
          ResourceView('/supplier/payouts',
              builder: (rows) => InkWell(
                  onTap: () => context.push('/payouts'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: OColors.soft,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(s.expectedPayment,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: OColors.secondary)),
                              const SizedBox(height: 5),
                              Text(
                                  tsh((rows as List)
                                      .where((r) => r['status'] == 'pending')
                                      .fold<num>(
                                          0,
                                          (sum, r) => sum +
                                              num.parse(
                                                  '${r['total_payable']}'))),
                                  style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                      color: OColors.forest)),
                            ])),
                        const Icon(Icons.chevron_right, color: OColors.forest),
                      ])))),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: () => context.push('/stock/new'),
              icon: const Icon(Icons.add, size: 19),
              label: Text(s.addStock)),
          const SizedBox(height: 10),
          OmoterraButton('Sales records',
              secondary: true, onPressed: () => context.push('/sales')),
          SectionHeader(s.yourStock,
              action: s.viewAll, onTap: () => context.go('/stock')),
          const StockList()
        ]);
  }
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
          Text(action == 'confirm' ? 'Confirm your stock' : 'Pause listing',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(action == 'confirm'
              ? 'Are ${stockUnits(row['quantity_available'], row['unit_type'])} still available?'
              : 'Buyers will no longer be able to reserve this stock. Existing confirmed orders remain reserved.'),
          const SizedBox(height: 24),
          DataForm(
              path: '/supplier/stock/$id',
              method: 'PATCH',
              fixed: {'action': action},
              fields: const [],
              button: action == 'confirm'
                  ? 'Confirm ${amount(row['quantity_available'])}'
                  : 'Pause listing',
              onSuccess: (_) {
                refreshStock(ref, id);
                Navigator.pop(context);
              }),
          if (action == 'confirm')
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/stock/$id/correct');
                },
                child: const Text('The count is different')),
        ]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: OmoterraAppBar(title: const Text('Stock details'), actions: [
        IconButton(
            tooltip: 'Refresh stock',
            onPressed: () => refreshStock(ref, id),
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/supplier/stock/$id',
            builder: (row) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ProductImage(List<String>.from(row['photos']),
                      category: row['category'], height: 190),
                  const SizedBox(height: 20),
                  Text(label(row['category']),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  StatusText(row['listing_status']),
                  const SizedBox(height: 20),
                  StockBalances([row]),
                  const SizedBox(height: 20),
                  OmoterraButton('Record a sale',
                      onPressed: num.parse('${row['quantity_available']}') > 0
                          ? () => context.push('/stock/$id/sell')
                          : null),
                  const SizedBox(height: 8),
                  const Text(
                      'Omoterra deliveries are recorded automatically. Use this button for goods sold elsewhere.',
                      style: TextStyle(fontSize: 12, color: OColors.secondary)),
                  const SectionHeader('Manage your stock'),
                  _action(
                      context,
                      'Correct stock count',
                      'Fix an entry mistake. Sold history stays unchanged.',
                      'history',
                      '/stock/$id/correct'),
                  _action(
                      context,
                      'Add stock received',
                      'Increase this batch with a receipt in history.',
                      'crate',
                      '/stock/$id/add'),
                  _action(
                      context,
                      'Stock history',
                      'See sales, corrections and reservations.',
                      'receipt',
                      '/stock/$id/history'),
                  const SectionHeader('Stock information'),
                  MoneySummary({
                    'Recorded total':
                        stockUnits(row['quantity_total'], row['unit_type']),
                    'Your asking price':
                        '${tsh(row['farmer_asking_price_per_unit'])} / ${row['unit_type']}',
                    'Region': row['region']
                  }),
                  const SizedBox(height: 12),
                  MoneySummary(Map<String, dynamic>.from(row['specs'])
                      .map((k, v) => MapEntry(label(k), '$v'))),
                  if (!['pending_review', 'rejected']
                      .contains(row['listing_status'])) ...[
                    const SizedBox(height: 24),
                    OmoterraButton('Confirm availability',
                        secondary: true,
                        onPressed: () => action(context, ref, row, 'confirm')),
                    TextButton(
                        onPressed: () => action(context, ref, row, 'pause'),
                        child: const Text('Pause listing')),
                  ],
                ]))
      ]));
  Widget _action(BuildContext context, String title, String subtitle,
          String kind, String route) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SupplyArt(kind, size: 46),
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => context.push(route)));
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
        'tray' => ['tray_size', 'egg_size', 'ready_date'],
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
      appBar: OmoterraAppBar(title: const Text('Add Stock')),
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
                    _StepDots(current: step, total: 5),
                    const SizedBox(height: 20),
                    Text(
                        [
                          ref.s.selectCategory,
                          ref.s.stockDetails,
                          ref.s.priceAndLocation,
                          ref.s.addPhotos,
                          ref.s.previewSubmit
                        ][step],
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 20),
                    if (step == 0)
                      LayoutBuilder(
                          builder: (context, box) => Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: categories
                                  .map((c) => SizedBox(
                                      width: (box.maxWidth - 12) / 2,
                                      child: CategoryCard(c,
                                          selected: category == c,
                                          onTap: () =>
                                              setState(() => category = c))))
                                  .toList())),
                    if (step == 1) ...[
                      OmoterraTextField('Quantity (${unitFor(category)})',
                          field('quantity_total'),
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true)),
                      for (final k in specKeys)
                        if (k.endsWith('date'))
                          OmoterraDateField(
                              label(k),
                              field(
                                  k,
                                  DateTime.now()
                                      .toIso8601String()
                                      .split('T')
                                      .first),
                              pastAllowed: k == 'slaughter_date')
                        else if ([
                          'live_or_dressed',
                          'chilled_or_frozen',
                          'sex',
                          'tray_size',
                          'egg_size'
                        ].contains(k))
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                  initialValue: field(
                                          k,
                                          switch (k) {
                                            'live_or_dressed' => 'live',
                                            'sex' => 'mixed',
                                            'tray_size' => '30',
                                            'egg_size' => 'medium',
                                            _ => 'chilled',
                                          })
                                      .text,
                                  decoration:
                                      InputDecoration(labelText: label(k)),
                                  items: switch (k) {
                                    'live_or_dressed' => ['live', 'dressed'],
                                    'sex' => ['male', 'female', 'mixed'],
                                    'tray_size' => ['12', '24', '30'],
                                    'egg_size' => ['small', 'medium', 'large'],
                                    _ => ['chilled', 'frozen'],
                                  }
                                      .map((v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(k == 'tray_size'
                                              ? '$v eggs'
                                              : label(v))))
                                      .toList(),
                                  onChanged: (value) => field(k).text = value!))
                        else
                          OmoterraTextField(label(k), field(k),
                              keyboard:
                                  ['avg_weight_kg', 'age_weeks'].contains(k)
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true)
                                      : TextInputType.text),
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
                      ProductImage(photos, category: category, height: 150),
                      const SizedBox(height: 16),
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
    return id == null ? body : Scaffold(appBar: OmoterraAppBar(), body: body);
  }
}

class PayoutScreen extends StatelessWidget {
  final String? id;
  const PayoutScreen({super.key, this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: OmoterraAppBar(
          title: Text(id == null ? 'Your payouts' : 'Payout details')),
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

/// Numbered progress dots across the Add Stock steps, as drawn.
class _StepDots extends StatelessWidget {
  final int current, total;
  const _StepDots({required this.current, required this.total});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < total; i++) ...[
          Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: i <= current ? OColors.forest : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: i <= current ? OColors.forest : OColors.border)),
              child: i < current
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              i <= current ? Colors.white : OColors.muted))),
          if (i != total - 1)
            Expanded(
                child: Container(
                    height: 2,
                    color: i < current ? OColors.forest : OColors.border)),
        ]
      ]);
}
