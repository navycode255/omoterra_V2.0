import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/domain.dart';
import '../../shared/widgets/components.dart';

class BuyerHome extends ConsumerWidget {
  const BuyerHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Hello, ${user?.name.split(' ').first ?? 'there'}',
          style: const TextStyle(color: OColors.secondary)),
      const SizedBox(height: 8),
      Text('What do you\nneed today?',
          style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 24),
      InkWell(
          onTap: () => context.go('/explore'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: OColors.forest,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.agriculture_outlined,
                        size: 36, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text('Buy Supply',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Fresh stock. Clear prices.\nCoordinated from farm to you.',
                        style:
                            TextStyle(color: Color(0xFFD6E5DA), height: 1.5)),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Text('Explore available supply',
                          style: TextStyle(color: Colors.white)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward, color: Colors.white)
                    ])
                  ]))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _entry(context, 'Request Supply', 'Tell us what you need',
                Icons.playlist_add, '/request')),
        const SizedBox(width: 12),
        Expanded(
            child: _entry(context, 'Start a Business', 'Take your next step',
                Icons.storefront_outlined, '/business'))
      ]),
      const SizedBox(height: 12),
      ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('My orders'),
          trailing: const Icon(Icons.arrow_forward, size: 20),
          onTap: () => context.go('/orders')),
      const SectionHeader('Available today'),
      const ListingFeed(),
      const SectionHeader('Browse by category'),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories
              .map((c) => ActionChip(
                  label: Text(label(c)),
                  onPressed: () => context.go('/explore?category=$c')))
              .toList())
    ]);
  }

  Widget _entry(BuildContext context, String title, String subtitle,
          IconData icon, String route) =>
      InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(16),
          child: Surface(
              color: OColors.pale,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: OColors.forest),
                    const SizedBox(height: 12),
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: OColors.secondary))
                  ])));
}

class ListingFeed extends ConsumerWidget {
  final String category, search, region, readyBy, condition;
  final double? maxPrice, minWeight, maxWeight;
  const ListingFeed(
      {super.key,
      this.category = '',
      this.search = '',
      this.region = '',
      this.readyBy = '',
      this.condition = '',
      this.minWeight,
      this.maxWeight,
      this.maxPrice});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(listingsProvider(category)).when(
          data: (list) {
            final matches = list
                .where((l) =>
                    label(l.category)
                        .toLowerCase()
                        .contains(search.toLowerCase()) &&
                    l.region.toLowerCase().contains(region.toLowerCase()) &&
                    (maxPrice == null || double.parse(l.price) <= maxPrice!) &&
                    (readyBy.isEmpty ||
                        ((l.specs['ready_date'] ??
                                    l.specs['slaughter_date'] ??
                                    '')
                                .toString()
                                .isNotEmpty &&
                            (l.specs['ready_date'] ?? l.specs['slaughter_date'])
                                    .toString()
                                    .compareTo(readyBy) <=
                                0)) &&
                    (condition.isEmpty ||
                        l.specs['live_or_dressed'] == condition ||
                        l.specs['chilled_or_frozen'] == condition) &&
                    weightMatches(l.specs, minWeight, maxWeight))
                .toList();
            if (matches.isEmpty) {
              return EmptyState('No supply available right now',
                  'Tell Omoterra what you need and we’ll help source it.',
                  action: OmoterraButton('Request Supply',
                      onPressed: () => context.push('/request')));
            }
            return Column(
                children: matches
                    .map((l) => ListingCard(l,
                        onTap: () => context.push('/listing/${l.id}')))
                    .toList());
          },
          loading: () => const LoadingSkeleton(),
          error: (e, _) => ErrorState(e,
              retry: () => ref.invalidate(listingsProvider(category))));
}

class ExploreScreen extends StatefulWidget {
  final String initialCategory;
  const ExploreScreen({super.key, this.initialCategory = ''});
  @override
  State<ExploreScreen> createState() => _ExploreState();
}

class _ExploreState extends State<ExploreScreen> {
  late String category = widget.initialCategory;
  String search = '', region = '', readyBy = '', condition = '';
  double? maxPrice, minWeight, maxWeight;
  Future<void> filters() async {
    final regionText = TextEditingController(text: region),
        price = TextEditingController(text: maxPrice?.toStringAsFixed(0) ?? ''),
        date = TextEditingController(text: readyBy),
        minimum = TextEditingController(text: minWeight?.toString() ?? ''),
        maximum = TextEditingController(text: maxWeight?.toString() ?? '');
    String selectedCondition = condition;
    final values = await omoterraSheet<List<String>>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filter supply', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          OmoterraTextField('Region', regionText, requiredField: false),
          OmoterraTextField('Maximum price per unit', price,
              keyboard: TextInputType.number, requiredField: false),
          OmoterraTextField('Ready by (YYYY-MM-DD)', date,
              requiredField: false),
          OmoterraTextField('Minimum weight (kg)', minimum,
              requiredField: false, keyboard: TextInputType.number),
          OmoterraTextField('Maximum weight (kg)', maximum,
              requiredField: false, keyboard: TextInputType.number),
          DropdownButtonFormField<String>(
              initialValue: condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: ['', 'live', 'dressed', 'chilled', 'frozen']
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.isEmpty ? 'Any condition' : label(v))))
                  .toList(),
              onChanged: (v) => selectedCondition = v!),
          const SizedBox(height: 24),
          OmoterraButton('Apply filters',
              onPressed: () => Navigator.pop(context, [
                    regionText.text,
                    price.text,
                    date.text,
                    minimum.text,
                    maximum.text,
                    selectedCondition
                  ]))
        ]));
    if (values != null && mounted) {
      setState(() {
        region = values[0];
        maxPrice = double.tryParse(values[1]);
        readyBy = values[2];
        minWeight = double.tryParse(values[3]);
        maxWeight = double.tryParse(values[4]);
        condition = values[5];
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('Explore supply',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'Search livestock or meat',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => search = v))),
          const SizedBox(width: 8),
          IconButton(
              tooltip: 'Filter supply',
              onPressed: filters,
              icon: const Icon(Icons.tune))
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: ['', ...categories]
                    .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(c.isEmpty ? 'All supply' : label(c)),
                            selected: c == category,
                            onSelected: (_) => setState(() => category = c))))
                    .toList())),
        const SizedBox(height: 20),
        ListingFeed(
            category: category,
            search: search,
            region: region,
            readyBy: readyBy,
            condition: condition,
            minWeight: minWeight,
            maxWeight: maxWeight,
            maxPrice: maxPrice)
      ]);
}

class ListingDetail extends ConsumerStatefulWidget {
  final String id;
  const ListingDetail(this.id, {super.key});
  @override
  ConsumerState<ListingDetail> createState() => _ListingDetailState();
}

class _ListingDetailState extends ConsumerState<ListingDetail> {
  final quantity = TextEditingController(text: '1');
  String key = newKey();
  Reservation? hold;
  bool busy = false;
  Object? error;
  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  Future<void> reserve({bool checkout = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(repositoryProvider);
      if (hold == null) {
        final response = await api.write('/reservations',
            {'listing_id': widget.id, 'quantity': quantity.text},
            key: key);
        hold = Reservation.fromJson(Map<String, dynamic>.from(response));
      }
      if (hold!.status != 'active' ||
          hold!.expiresAt.isBefore(DateTime.now())) {
        hold = null;
        key = newKey();
        throw const ApiFailure(
            'Your reservation expired. Select your quantity again.');
      }
      if (checkout && mounted) {
        final id = hold!.id;
        await context.push('/checkout/$id');
        if (mounted) {
          hold = null;
          key = newKey();
          ref.invalidate(resourceProvider('/listings/${widget.id}'));
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeQuantity() async {
    if (hold != null) {
      setState(() => busy = true);
      try {
        await ref
            .read(repositoryProvider)
            .write('/reservations/${hold!.id}', {}, method: 'DELETE');
        if (mounted) {
          setState(() {
            hold = null;
            key = newKey();
          });
        }
      } catch (e) {
        if (mounted) setState(() => error = e);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Supply details')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/listings/${widget.id}', builder: (data) {
          final listing =
              SupplyListing.fromJson(Map<String, dynamic>.from(data));
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                    tag: listing.id,
                    child: ProductImage(listing.photos, height: 240)),
                const SizedBox(height: 24),
                Text(label(listing.category),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('${tsh(listing.price)} / ${listing.unitType}',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: OColors.forest)),
                Text(
                    '${amount(listing.available)} ${listing.unitType}s available · ${listing.region}'),
                const SectionHeader('Supply details'),
                MoneySummary(
                    listing.specs.map((k, v) => MapEntry(label(k), '$v'))),
                const SizedBox(height: 16),
                Surface(
                    color: OColors.pale,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${listing.supplier?['public_alias'] ?? 'Omoterra supply partner'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(listing.region),
                          const SizedBox(height: 8),
                          const Text('Omoterra Approved',
                              style: TextStyle(color: OColors.positive)),
                          const SizedBox(height: 8),
                          const Text(
                              'Omoterra coordinates quality, collection and delivery.')
                        ])),
                const SectionHeader('Choose your quantity'),
                TextField(
                    controller: quantity,
                    enabled: hold == null && !busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Quantity (${listing.unitType})'),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => reserve()),
                const SizedBox(height: 12),
                Text(
                    'Estimated total ${tsh((num.tryParse(quantity.text) ?? 0) * num.parse(listing.price))}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'Final pricing is confirmed by the server at checkout.',
                    style: TextStyle(fontSize: 12, color: OColors.secondary)),
                if (hold != null) ...[
                  const SizedBox(height: 12),
                  const Text('Stock reserved for 15 minutes.'),
                  TextButton(
                      onPressed: busy ? null : changeQuantity,
                      child: const Text('Release & change quantity'))
                ],
                if (error != null) ErrorState(error!),
                const SizedBox(height: 20),
                if (hold == null)
                  OmoterraButton('Confirm quantity & reserve',
                      secondary: true, busy: busy, onPressed: () => reserve()),
                const SizedBox(height: 12),
                OmoterraButton('Buy Now',
                    busy: busy, onPressed: () => reserve(checkout: true)),
                TextButton(
                    onPressed: () => context.push('/request'),
                    child: const Text('Need more? Request Supply'))
              ]);
        })
      ]));
}

class CheckoutScreen extends ConsumerStatefulWidget {
  final String id;
  const CheckoutScreen(this.id, {super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<CheckoutScreen> {
  String? address;
  DateTime date = DateTime.now();
  final key = newKey();
  bool busy = false;
  Object? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (address == null) {
      setState(() => error = 'Choose a delivery address.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await ref.read(repositoryProvider).write(
          '/orders',
          {
            'reservation_id': widget.id,
            'delivery_address_id': address,
            'preferred_delivery_date': date.toIso8601String().split('T').first,
            'payment_method': 'pay_on_delivery'
          },
          key: key);
      ref.invalidate(resourceProvider('/orders'));
      ref.invalidate(listingsProvider);
      if (mounted) context.go('/confirmation/${response['id']}');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/reservations/${widget.id}', builder: (data) {
          final hold = Reservation.fromJson(Map<String, dynamic>.from(data));
          final remaining = hold.expiresAt.difference(DateTime.now());
          final expired = remaining.isNegative || hold.status != 'active';
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label(data['listing']['category']),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                MoneySummary({
                  'Quantity':
                      '${amount(hold.quantity)} ${data['listing']['unit_type']}',
                  'Price per unit':
                      tsh(data['listing']['buyer_price_per_unit']),
                  'Estimated total': tsh(num.parse(hold.quantity) *
                      num.parse('${data['listing']['buyer_price_per_unit']}'))
                }),
                const SizedBox(height: 12),
                Text(
                    expired
                        ? 'Reservation expired. Return to the listing to reserve again.'
                        : 'Your stock is held for ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                        color: expired ? OColors.error : OColors.secondary)),
                const SectionHeader('Delivery address'),
                ResourceView('/addresses',
                    builder: (rows) => Column(children: [
                          for (final a in rows)
                            ListTile(
                                selected: address == a['id'],
                                leading: Icon(address == a['id']
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                                onTap: busy
                                    ? null
                                    : () => setState(() => address = a['id']),
                                title: Text(a['label']),
                                subtitle: Text(
                                    '${a['district_area']}, ${a['region']}')),
                          TextButton.icon(
                              onPressed: () async {
                                await context.push('/addresses/new');
                                ref.invalidate(resourceProvider('/addresses'));
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add delivery address'))
                        ])),
                const SectionHeader('Preferred delivery'),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(date.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: busy
                        ? null
                        : () async {
                            final chosen = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)));
                            if (chosen != null) setState(() => date = chosen);
                          }),
                const SectionHeader('Payment method'),
                const Surface(
                    child: Row(children: [
                  Icon(Icons.payments_outlined, color: OColors.forest),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'Pay on Delivery\nPayment is recorded by Omoterra.'))
                ])),
                if (error != null) ErrorState(error!),
                const SizedBox(height: 24),
                OmoterraButton('Confirm order',
                    busy: busy, onPressed: expired ? null : submit)
              ]);
        })
      ]));
}

class OrderConfirmation extends StatelessWidget {
  final String id;
  const OrderConfirmation(this.id, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 64),
        const Icon(Icons.check_circle_outline,
            color: OColors.positive, size: 72),
        const SizedBox(height: 24),
        Text('Your order is confirmed',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Order #${id.substring(0, 8).toUpperCase()}',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Text(
            'Omoterra will coordinate your supply and delivery. Follow its progress here.',
            textAlign: TextAlign.center),
        const SizedBox(height: 40),
        OmoterraButton('Track order',
            onPressed: () => context.go('/order/$id')),
        const SizedBox(height: 12),
        OmoterraButton('Back to Home',
            secondary: true, onPressed: () => context.go('/buyer'))
      ])));
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<OrdersScreen> {
  bool past = false;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('Your orders', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        SegmentedButton<bool>(segments: const [
          ButtonSegment(value: false, label: Text('Active')),
          ButtonSegment(value: true, label: Text('Past'))
        ], selected: {
          past
        }, onSelectionChanged: (s) => setState(() => past = s.first)),
        const SizedBox(height: 24),
        ResourceView('/orders', builder: (rows) {
          final orders = (rows as List)
              .map((r) => BuyerOrder.fromJson(Map<String, dynamic>.from(r)))
              .where(
                  (o) => ['delivered', 'cancelled'].contains(o.status) == past)
              .toList();
          if (orders.isEmpty) {
            return EmptyState('No orders yet',
                'Browse today’s available supply or request what you need.',
                action: Column(children: [
                  OmoterraButton('Browse Supply',
                      onPressed: () => context.go('/explore')),
                  TextButton(
                      onPressed: () => context.push('/request'),
                      child: const Text('Request Supply'))
                ]));
          }
          return Column(
              children: orders
                  .map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                          onTap: () => context.push('/order/${o.id}'),
                          child: Surface(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    'Order #${o.id.substring(0, 8).toUpperCase()}'),
                                const SizedBox(height: 8),
                                for (final item in o.items)
                                  Text(
                                      '${label(item['category'])} · ${amount(item['quantity'])} ${item['unit_type']}'),
                                const SizedBox(height: 12),
                                Text(tsh(o.total),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                StatusText(o.status)
                              ])))))
                  .toList());
        }),
        const SectionHeader('Supply requests'),
        ResourceView('/requests',
            builder: (rows) => Column(children: [
                  for (final r in rows)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${label(r['category'])} · ${amount(r['quantity'])} ${r['unit_type']}'),
                        subtitle: StatusText(r['status']),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/requests/${r['id']}'))
                ]))
      ]);
}

class OrderDetail extends StatelessWidget {
  final String id;
  const OrderDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Order #${id.substring(0, 8).toUpperCase()}')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/orders/$id', builder: (data) {
          final order = BuyerOrder.fromJson(Map<String, dynamic>.from(data));
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your supply, on its way',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Surface(child: OrderProgress(order.status)),
                if (order.message != null) ErrorState(order.message!),
                const SectionHeader('Order summary'),
                MoneySummary({
                  for (final i in order.items)
                    '${label(i['category'])} · ${amount(i['quantity'])} ${i['unit_type']}':
                        tsh(i['subtotal']),
                  'Total': tsh(order.total)
                }),
                const SectionHeader('Delivery'),
                Surface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.address['recipient_name']),
                      Text(
                          '${order.address['address_text']}, ${order.address['district_area']}'),
                      Text(order.address['region']),
                      const SizedBox(height: 8),
                      Text('Preferred date: ${order.deliveryDate}')
                    ])),
                const SectionHeader('Payment'),
                MoneySummary({
                  'Method': label(order.paymentMethod),
                  'Status': label(order.paymentStatus)
                }),
                const SectionHeader('Activity'),
                for (final event in order.activity)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, size: 20),
                      title: Text(event['label']),
                      subtitle: Text(event['at'].toString().split('T').first))
              ]);
        })
      ]));
}

bool weightMatches(
    Map<String, dynamic> specs, double? minimum, double? maximum) {
  if (minimum == null && maximum == null) return true;
  final raw = '${specs['avg_weight_kg'] ?? specs['weight_range'] ?? ''}';
  final weights = RegExp(r'\d+(?:\.\d+)?')
      .allMatches(raw)
      .map((m) => double.parse(m.group(0)!))
      .toList();
  if (weights.isEmpty) return false;
  final low = weights.first,
      high = weights.length > 1 ? weights.last : weights.first;
  return (minimum == null || high >= minimum) &&
      (maximum == null || low <= maximum);
}
