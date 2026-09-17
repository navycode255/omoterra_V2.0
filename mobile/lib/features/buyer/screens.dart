import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/domain.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';

class BuyerHome extends ConsumerWidget {
  const BuyerHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final s = ref.s;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      Text(s.greeting(user?.name.split(' ').first ?? ''),
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(s.whatToday, style: const TextStyle(color: OColors.secondary)),
      const SizedBox(height: 18),
      // Buy Supply is the visually dominant card; the rest support it.
      InkWell(
          onTap: () => context.go('/explore'),
          borderRadius: BorderRadius.circular(18),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(children: [
                const Positioned.fill(
                    child: BrandImage('category_broilers',
                        fallbackArt: 'broilers')),
                Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                              OColors.forest,
                              OColors.forest.withValues(alpha: .72),
                            ])))),
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(s.buySupplyCard,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(s.buySupplyCardBody,
                                style: const TextStyle(
                                    color: Color(0xFFD6E5DA),
                                    fontSize: 13,
                                    height: 1.45)),
                          ])),
                      Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 19)),
                    ])),
              ]))),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: _entry(
                context,
                s.requestSupply,
                s.requestSupplyBody,
                Icons.assignment_outlined,
                const Color(0xFFFBF1E6),
                OColors.warning,
                '/request')),
        const SizedBox(width: 12),
        Expanded(
            child: _entry(
                context,
                s.startBusiness,
                s.startBusinessBody,
                Icons.storefront_outlined,
                const Color(0xFFF1EDF8),
                const Color(0xFF6A4FA3),
                '/business')),
      ]),
      const SizedBox(height: 12),
      _entryWide(context, s.myOrders, s.myOrdersBody, Icons.receipt_long_outlined,
          '/orders'),
      SectionHeader(s.availableToday,
          action: s.viewAll, onTap: () => context.go('/explore')),
      const ListingFeed(),
    ]);
  }

  Widget _entry(BuildContext context, String title, String subtitle,
          IconData icon, Color tint, Color iconColor, String route) =>
      InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OColors.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 19, color: iconColor)),
                    const SizedBox(height: 12),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: OColors.secondary,
                            height: 1.35))
                  ])));

  Widget _entryWide(BuildContext context, String title, String subtitle,
          IconData icon, String route) =>
      InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OColors.border)),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: OColors.soft,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 19, color: OColors.forest)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: OColors.secondary))
                    ])),
                const Icon(Icons.chevron_right, color: OColors.muted),
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
  Widget build(BuildContext context) => Consumer(builder: (context, ref, _) {
        final s = ref.s;
        return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(children: [
                Expanded(
                    child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(color: OColors.border)),
                        child: TextField(
                            decoration: InputDecoration(
                                hintText: s.searchHint,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13, horizontal: 4),
                                prefixIcon: const Icon(Icons.search,
                                    size: 20, color: OColors.muted),
                                hintStyle: const TextStyle(
                                    color: OColors.muted, fontSize: 14)),
                            onChanged: (v) => setState(() => search = v)))),
                const SizedBox(width: 10),
                InkWell(
                    onTap: filters,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: OColors.border)),
                        child: const Icon(Icons.tune,
                            size: 20, color: OColors.forest))),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                  height: 36,
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      children: ['', ...categories]
                          .map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                  label: c.isEmpty ? s.all : label(c),
                                  selected: c == category,
                                  onTap: () => setState(() => category = c))))
                          .toList())),
              const SizedBox(height: 18),
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
      });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
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
                  color: selected ? OColors.forest : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected ? OColors.forest : OColors.border)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : OColors.secondary)))));
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
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        body: ResourceView('/listings/${widget.id}', builder: (data) {
          final listing =
              SupplyListing.fromJson(Map<String, dynamic>.from(data));
          final count = num.tryParse(quantity.text) ?? 0;
          final total = count * num.parse(listing.price);
          return Column(children: [
            Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
              // Full-bleed hero with floating controls, as drawn.
              Stack(children: [
                Hero(
                    tag: listing.id,
                    child: ProductImage(listing.photos,
                        category: listing.category, height: 300)),
                Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 16,
                    right: 16,
                    child: Row(children: [
                      _HeroButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).maybePop()),
                      const Spacer(),
                      const _HeroButton(icon: Icons.favorite_border),
                    ])),
              ]),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label(listing.category),
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text('${tsh(listing.price)} / ${listing.unitType}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: OColors.forest)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.check_circle,
                              size: 15, color: OColors.positive),
                          const SizedBox(width: 5),
                          Text(s.omoterraApproved,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: OColors.positive,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                            '${amount(listing.available)} ${listing.unitType} ${s.available} · ${listing.region}',
                            style: const TextStyle(
                                fontSize: 13, color: OColors.secondary)),
                        const SizedBox(height: 18),
                        _SupplierCard(
                            alias: '${listing.supplier?['public_alias'] ?? 'Omoterra supply partner'}',
                            region: listing.region,
                            approved: s.omoterraApproved),
                        const SizedBox(height: 20),
                        Text(s.specifications,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        _SpecTable(listing.specs),
                        if (error != null) ErrorState(error!),
                        if (hold != null) ...[
                          const SizedBox(height: 12),
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: OColors.soft,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                const Icon(Icons.lock_clock,
                                    size: 17, color: OColors.forest),
                                const SizedBox(width: 8),
                                const Expanded(
                                    child: Text('Stock reserved for 15 minutes.',
                                        style: TextStyle(fontSize: 13))),
                                TextButton(
                                    onPressed: busy ? null : changeQuantity,
                                    child: const Text('Change')),
                              ])),
                        ],
                        const SizedBox(height: 8),
                        Center(
                            child: TextButton(
                                onPressed: () => context.push('/request'),
                                child: Text(s.needMore))),
                        const SizedBox(height: 8),
                      ])),
            ])),
            // Sticky quantity + Buy Now bar.
            Container(
                padding: EdgeInsets.fromLTRB(
                    20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: OColors.border))),
                child: Row(children: [
                  _Stepper(
                      value: quantity.text,
                      enabled: hold == null && !busy,
                      onMinus: () => setState(() {
                            final v = num.tryParse(quantity.text) ?? 1;
                            quantity.text = (v > 1 ? v - 1 : 1).toString();
                          }),
                      onPlus: () => setState(() => quantity.text =
                          ((num.tryParse(quantity.text) ?? 0) + 1).toString())),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(tsh(total),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(s.orderTotal,
                            style: const TextStyle(
                                fontSize: 11, color: OColors.muted)),
                      ])),
                  const SizedBox(width: 10),
                  SizedBox(
                      width: 132,
                      child: FilledButton(
                          onPressed: busy ? null : () => reserve(checkout: true),
                          child: Text(busy ? '…' : s.buyNow))),
                ])),
          ]);
        }));
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HeroButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 19, color: OColors.ink))));
}

class _SupplierCard extends StatelessWidget {
  final String alias, region, approved;
  const _SupplierCard(
      {required this.alias, required this.region, required this.approved});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: OColors.pale,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OColors.border)),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: OColors.soft, shape: BoxShape.circle),
            child: const Icon(Icons.agriculture_outlined,
                size: 21, color: OColors.forest)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(alias,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(region,
                  style: const TextStyle(
                      fontSize: 12, color: OColors.secondary)),
            ])),
        // Deliberately no contact control: buyers never reach suppliers direct.
        Row(children: [
          const Icon(Icons.verified, size: 15, color: OColors.positive),
          const SizedBox(width: 4),
          Text(approved,
              style: const TextStyle(
                  fontSize: 11,
                  color: OColors.positive,
                  fontWeight: FontWeight.w600)),
        ]),
      ]));
}

class _SpecTable extends StatelessWidget {
  final Map<String, dynamic> specs;
  const _SpecTable(this.specs);
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OColors.border)),
      child: Column(
          children: specs.entries.toList().asMap().entries.map((row) {
        final last = row.key == specs.length - 1;
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                border: last
                    ? null
                    : const Border(
                        bottom: BorderSide(color: OColors.border))),
            child: Row(children: [
              Expanded(
                  child: Text(label(row.value.key),
                      style: const TextStyle(
                          fontSize: 13, color: OColors.secondary))),
              Text('${row.value.value}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]));
      }).toList()));
}

class _Stepper extends StatelessWidget {
  final String value;
  final bool enabled;
  final VoidCallback onMinus, onPlus;
  const _Stepper(
      {required this.value,
      required this.enabled,
      required this.onMinus,
      required this.onPlus});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _StepButton(
            icon: Icons.remove, onTap: enabled ? onMinus : null),
        SizedBox(
            width: 34,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700))),
        _StepButton(icon: Icons.add, onTap: enabled ? onPlus : null),
      ]));
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: SizedBox(
          width: 36,
          height: 44,
          child: Icon(icon,
              size: 17,
              color: onTap == null ? OColors.muted : OColors.forest)));
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
          // The server decides which methods this order may use.
          final allowed = List<String>.from(
              data['payment_methods'] as List? ?? const ['pay_on_delivery']);
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
                SectionHeader(ref.s.paymentMethod),
                // Both methods render as designed. Pay Now stays disabled until
                // the backend actually lists it, so no buyer can select a method
                // that cannot complete.
                _PaymentOption(
                    title: ref.s.payNow,
                    subtitle: ref.s.payNowSoon,
                    icon: Icons.smartphone_outlined,
                    selected: false,
                    enabled: allowed.contains('pay_now'),
                    onTap: null),
                const SizedBox(height: 10),
                _PaymentOption(
                    title: ref.s.payOnDelivery,
                    subtitle: ref.s.payOnDeliveryBody,
                    icon: Icons.payments_outlined,
                    selected: true,
                    enabled: true,
                    onTap: () {}),
                if (error != null) ErrorState(error!),
                const SizedBox(height: 24),
                OmoterraButton(ref.s.confirmOrder,
                    busy: busy, onPressed: expired ? null : submit)
              ]);
        })
      ]));
}

class _PaymentOption extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool selected, enabled;
  final VoidCallback? onTap;
  const _PaymentOption(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.selected,
      required this.enabled,
      this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: enabled ? 1 : .55,
      child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: selected ? OColors.soft : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: selected ? OColors.forest : OColors.border,
                      width: selected ? 1.5 : 1)),
              child: Row(children: [
                Icon(icon,
                    size: 21,
                    color: enabled ? OColors.forest : OColors.muted),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: OColors.secondary)),
                    ])),
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? OColors.forest : OColors.border),
              ]))));
}

class OrderConfirmation extends ConsumerWidget {
  final String id;
  const OrderConfirmation(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(children: [
                  const Spacer(),
                  Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                          color: OColors.soft, shape: BoxShape.circle),
                      child: Center(
                          child: Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                  color: OColors.forest,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 33)))),
                  const SizedBox(height: 26),
                  Text(s.orderConfirmed,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(s.orderConfirmedBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: OColors.secondary, height: 1.5)),
                  const SizedBox(height: 26),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: OColors.pale,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: OColors.border)),
                      child: Column(children: [
                        Text(s.orderNumber,
                            style: const TextStyle(
                                fontSize: 12, color: OColors.muted)),
                        const SizedBox(height: 4),
                        Text('OMT-${id.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                      ])),
                  const Spacer(),
                  OmoterraButton(s.trackOrder,
                      onPressed: () => context.go('/order/$id')),
                  const SizedBox(height: 10),
                  OmoterraButton(s.backHome,
                      secondary: true, onPressed: () => context.go('/buyer')),
                ]))));
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<OrdersScreen> {
  bool past = false;
  @override
  Widget build(BuildContext context) => Consumer(builder: (context, ref, _) {
        final s = ref.s;
        return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Segmented pills, as drawn.
              Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: OColors.soft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                        child: _Segment(
                            label: s.active,
                            selected: !past,
                            onTap: () => setState(() => past = false))),
                    Expanded(
                        child: _Segment(
                            label: s.past,
                            selected: past,
                            onTap: () => setState(() => past = true))),
                  ])),
              const SizedBox(height: 18),
              ResourceView('/orders', builder: (rows) {
                final orders = (rows as List)
                    .map((r) =>
                        BuyerOrder.fromJson(Map<String, dynamic>.from(r)))
                    .where((o) =>
                        ['delivered', 'cancelled'].contains(o.status) == past)
                    .toList();
                if (orders.isEmpty) {
                  return EmptyState(s.noOrdersTitle, s.noOrdersBody,
                      action: Column(children: [
                        OmoterraButton(s.buySupplyCard,
                            onPressed: () => context.go('/explore')),
                        TextButton(
                            onPressed: () => context.push('/request'),
                            child: Text(s.requestSupply))
                      ]));
                }
                return Column(
                    children: orders
                        .map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OrderCard(order: o, statusLabel: s)))
                        .toList());
              }),
              SectionHeader(s.requestSupply),
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
      });
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: selected ? OColors.forest : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : OColors.secondary))));
}

class _OrderCard extends StatelessWidget {
  final BuyerOrder order;
  final Strings statusLabel;
  const _OrderCard({required this.order, required this.statusLabel});
  @override
  Widget build(BuildContext context) {
    final item = order.items.isEmpty ? null : order.items.first;
    return InkWell(
        onTap: () => context.push('/order/${order.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OColors.border)),
            child: Row(children: [
              SizedBox(
                  width: 64,
                  child: ProductImage(const [],
                      category: '${item?['category'] ?? 'crate'}', height: 64)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('OMT-${order.id.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    if (item != null)
                      Text(
                          '${label(item['category'])} × ${amount(item['quantity'])}',
                          style: const TextStyle(
                              fontSize: 12.5, color: OColors.secondary)),
                    const SizedBox(height: 5),
                    Text(tsh(order.total),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    StatusText(order.status),
                  ])),
              const Icon(Icons.chevron_right, color: OColors.muted),
            ])));
  }
}

class OrderDetail extends ConsumerWidget {
  final String id;
  const OrderDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(
          title: Text('Order #${id.substring(0, 8).toUpperCase()}'),
          actions: [
            IconButton(
                tooltip: 'Refresh order',
                onPressed: () =>
                    ref.invalidate(resourceProvider('/orders/$id')),
                icon: const Icon(Icons.refresh))
          ]),
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
                if (order.status == 'confirmed') ...[
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => omoterraSheet(
                          context,
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cancel this order?',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                const Text(
                                    'Your reserved stock will be released. This is available before collection starts.'),
                                const SizedBox(height: 20),
                                DataForm(
                                    path: '/orders/$id/cancel',
                                    fields: const [],
                                    button: 'Cancel order',
                                    onSuccess: (_) {
                                      ref.invalidate(
                                          resourceProvider('/orders/$id'));
                                      ref.invalidate(
                                          resourceProvider('/orders'));
                                      Navigator.pop(context);
                                    })
                              ])),
                      child: const Text('Cancel order'))
                ],
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
