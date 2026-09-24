import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';

String demandDate(Object? value) {
  final date = DateTime.tryParse('$value');
  return date == null
      ? 'Date to be confirmed'
      : DateFormat('dd MMM yyyy').format(date);
}

String demandSchedule(Map row) {
  final frequency = row['recurrence_frequency'];
  final days = row['preferred_weekdays'];
  if (frequency != null && '$frequency'.isNotEmpty) {
    final dayText = days is List && days.isNotEmpty
        ? ' · ${days.map((d) => label('$d')).join(', ')}'
        : '';
    return 'Repeats ${label('$frequency')}$dayText';
  }
  return row['schedule'] ??
      'Needed by ${demandDate(row['needed_by'] ?? row['needed_by_date'])}';
}

String demandTitle(Map row) =>
    '${amount(row['quantity'])} ${label(row['category'])}${row['requirement_type'] == 'recurring' || row['repeating'] == true ? ' · recurring' : ''}';
String demandRegion(Map row) =>
    '${row['delivery_region'] ?? row['region'] ?? 'Location to be confirmed'}';
String demandWeight(Map row) {
  final min = row['minimum_weight_kg'] ?? row['weight'];
  final max = row['maximum_weight_kg'];
  if (min == null && max == null) return 'Weight to be confirmed';
  if (min != null && max != null) return '$min–$max kg';
  return '${min ?? '$max+'} kg';
}

num demandSecured(Map row) =>
    num.tryParse('${row['secured_quantity'] ?? row['matched'] ?? 0}') ?? 0;
num demandRemaining(Map row) =>
    num.tryParse(
        '${row['remaining_quantity'] ?? ((num.tryParse('${row['quantity']}') ?? 0) - demandSecured(row))}') ??
    0;
String demandUnit(Map row) =>
    label('${row['unit_type'] ?? row['unit'] ?? 'birds'}');

String demandHeroAsset(Map row) {
  switch ('${row['category']}') {
    case 'goats':
      return 'assets/images/category_goats.jpg';
    case 'cattle':
      return 'assets/images/category_cow.jpg';
    default:
      return 'assets/images/demand-detail-hero-v1.png';
  }
}

class MarketDemandScreen extends StatefulWidget {
  const MarketDemandScreen({super.key});
  @override
  State<MarketDemandScreen> createState() => _MarketDemandState();
}

class _MarketDemandState extends State<MarketDemandScreen> {
  String category = 'all', search = '';
  bool searching = false;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Row(children: [
          BackChevron(onPressed: () => context.go('/supplier')),
          const Expanded(
              child: Text('Market Demand',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Search demand',
              onPressed: () => setState(() {
                    searching = !searching;
                    search = '';
                  }),
              icon: Icon(searching ? Icons.close : Icons.search)),
        ]),
        if (searching)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                      hintText: 'Search product or location',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) =>
                      setState(() => search = value.trim().toLowerCase()))),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final entry in [
                ('all', 'All'),
                ('broilers', 'Broilers'),
                ('layers', 'Layers'),
                ('goats', 'Goats'),
                ('cattle', 'Cows')
              ])
                Padding(
                    padding:
                        const EdgeInsets.only(right: 8, top: 12, bottom: 14),
                    child: ChoiceChip(
                        label: Text(entry.$2),
                        selected: category == entry.$1,
                        showCheckmark: false,
                        selectedColor: const Color(0xFF006747),
                        backgroundColor: OColors.soft,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: category == entry.$1
                                ? Colors.white
                                : OColors.secondary),
                        onSelected: (_) =>
                            setState(() => category = entry.$1))),
            ])),
        ResourceView('/supplier/demand', builder: (data) {
          final rows = (data as List)
              .where((row) =>
                  (category == 'all' || row['category'] == category) &&
                  '${row['category']} ${demandRegion(row)}'
                      .toLowerCase()
                      .contains(search))
              .toList();
          if (rows.isEmpty) {
            return const EmptyState('No demand here yet',
                'Try another category or location. You can still register your stock while we find suitable demand.');
          }
          return Column(children: [
            for (final row in rows) DemandCard(Map<String, dynamic>.from(row))
          ]);
        }),
      ]);
}

class DemandCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const DemandCard(this.row, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
          color: Colors.white,
          elevation: 2,
          shadowColor: OColors.forest.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/supplier-demand/${row['id']}'),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  width: 94,
                                  height: 102,
                                  child: BrandImage(
                                      row['category'] == 'broilers' ||
                                              row['category'] == 'layers'
                                          ? 'poultry-card-v1'
                                          : 'category_${row['category'] == 'cattle' ? 'cow' : row['category']}',
                                      extension:
                                          row['category'] == 'broilers' ||
                                                  row['category'] == 'layers'
                                              ? 'png'
                                              : 'jpg',
                                      fallbackArt: row['category']))),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                _FormBadge(
                                    '${row['live_dressed_or_cut'] ?? row['form'] ?? 'Live'}'),
                                const SizedBox(height: 5),
                                Text(demandTitle(row),
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                                Text(demandWeight(row),
                                    style: const TextStyle(
                                        color: OColors.secondary,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                _DetailLine(Icons.location_on_outlined,
                                    demandRegion(row)),
                              ])),
                          const Icon(Icons.chevron_right, size: 21),
                        ]),
                        const SizedBox(height: 12),
                        _DetailLine(
                            Icons.calendar_today_outlined, demandSchedule(row)),
                        const SizedBox(height: 12),
                        DemandProgress(row),
                      ])))));
}

class DemandProgress extends StatelessWidget {
  final Map row;
  const DemandProgress(this.row, {super.key});
  @override
  Widget build(BuildContext context) {
    final total = num.tryParse('${row['quantity']}') ?? 0;
    final matched = demandSecured(row);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(
          TextSpan(children: [
            TextSpan(
                text: amount(matched),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' / ${amount(total)} matched')
          ]),
          style: const TextStyle(fontSize: 13, color: OColors.ink)),
      const SizedBox(height: 7),
      LinearProgressIndicator(
          value: total > 0 ? (matched / total).clamp(0, 1).toDouble() : 0,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF007653),
          backgroundColor: const Color(0xFFDFE8E3),
          semanticsLabel: '${amount(matched)} of ${amount(total)} matched'),
    ]);
  }
}

class _FormBadge extends StatelessWidget {
  final String text;
  const _FormBadge(this.text);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFFFFA33C),
          borderRadius: BorderRadius.circular(7)),
      child: Text(label(text),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)));
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DetailLine(this.icon, this.text, {this.color = OColors.secondary});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)))
      ]);
}

class DemandDetailScreen extends StatelessWidget {
  final String id;
  const DemandDetailScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: ResourceView('/supplier/demand/$id', builder: (data) {
        final row = Map<String, dynamic>.from(data);
        return SingleChildScrollView(
            child: Column(children: [
          Container(
              decoration: BoxDecoration(
                  color: OColors.forest,
                  image: DecorationImage(
                      image: AssetImage(demandHeroAsset(row)),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter)),
              child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x55000000), Color(0xDD084B35)])),
                  padding: EdgeInsets.fromLTRB(
                      24, MediaQuery.paddingOf(context).top + 8, 24, 44),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                            tooltip: 'Back to demand',
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/supplier-demand'),
                            icon: const BackChevron(color: Colors.white)),
                        const SizedBox(height: 16),
                        _FormBadge(
                            '${row['live_dressed_or_cut'] ?? row['form'] ?? 'Live'}'),
                        const SizedBox(height: 10),
                        Text(demandTitle(row),
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text(demandWeight(row),
                            style: const TextStyle(
                                fontSize: 20, color: Colors.white)),
                        const SizedBox(height: 18),
                        _DetailLine(
                            Icons.location_on_outlined, demandRegion(row),
                            color: Colors.white),
                        const SizedBox(height: 10),
                        _DetailLine(
                            Icons.calendar_today_outlined, demandSchedule(row),
                            color: Colors.white),
                        const SizedBox(height: 10),
                        _DetailLine(
                            Icons.sync,
                            row['requirement_type'] == 'recurring' ||
                                    row['repeating'] == true
                                ? 'Repeating requirement'
                                : 'One-time requirement',
                            color: Colors.white),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .88),
                                borderRadius: BorderRadius.circular(12)),
                            child: DemandProgress(row)),
                      ]))),
          Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                  decoration: const BoxDecoration(
                      color: OColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28))),
                  padding: const EdgeInsets.all(24),
                  child: SupplyOfferForm(row))),
        ]));
      }));
}

class SupplyOfferForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> demand;
  const SupplyOfferForm(this.demand, {super.key});
  @override
  ConsumerState<SupplyOfferForm> createState() => _SupplyOfferState();
}

class _SupplyOfferState extends ConsumerState<SupplyOfferForm> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController(),
      date = TextEditingController(),
      weight = TextEditingController(),
      price = TextEditingController();
  final key = newKey();
  bool busy = false, submitted = false, loadingBatches = true;
  Object? error;
  List<Map<String, dynamic>> batches = [];
  String? selectedBatchId;
  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final data = await ref.read(repositoryProvider).read('/supplier/batches');
      if (mounted) {
        setState(() {
          batches = (data as List)
              .map((r) => Map<String, dynamic>.from(r))
              .where((r) =>
                  r['category'] == widget.demand['category'] &&
                  (num.tryParse('${r['available_to_commit']}') ?? 0) > 0 &&
                  !['paused', 'cancelled', 'completed', 'fully_reserved']
                      .contains(r['status']))
              .toList();
          selectedBatchId = batches.isEmpty ? null : '${batches.first['id']}';
          loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loadingBatches = false;
        });
      }
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    date.dispose();
    weight.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final ready = DateTime.parse(date.text);
    final now = DateTime.now();
    final needed = DateTime.tryParse(
        '${widget.demand['needed_by_date'] ?? widget.demand['needed_by']}');
    if (ready.isBefore(DateTime(now.year, now.month, now.day)) ||
        (needed != null && ready.isAfter(needed))) {
      setState(() => error = const ApiFailure(
          'Choose a ready date between today and the demand deadline.'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write(
          '/supplier/demand/${widget.demand['id']}/offers',
          {
            'batch_id': selectedBatchId,
            'offered_quantity': quantity.text,
            'expected_ready_date': date.text,
            'expected_min_weight_kg': double.parse(weight.text),
            'expected_max_weight_kg': double.parse(weight.text),
            if (price.text.trim().isNotEmpty)
              'asking_price_per_unit': double.parse(price.text),
          },
          key: key);
      if (mounted) setState(() => submitted = true);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return const EmptyState('Supply offer received',
          'Omoterra will review your offer and contact you before any stock is reserved.');
    }
    final remaining = demandRemaining(widget.demand);
    if (remaining <= 0) {
      return const EmptyState('Demand fully matched',
          'Explore other demand to find your next opportunity.');
    }
    return Form(
        key: form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Supply This Demand',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          if (loadingBatches) const LinearProgressIndicator(),
          if (!loadingBatches && batches.isEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const EmptyState('Register a production batch first',
                  'Omoterra can only review an offer tied to your own recorded stock.'),
              TextButton(
                  onPressed: () => context.push('/batches/new'),
                  child: const Text('Register production batch'))
            ]),
          if (batches.isNotEmpty) ...[
            OmoterraDropdown<String>(
              label: 'Supplier batch',
              value: selectedBatchId!,
              items: batches
                  .map((batch) => DropdownMenuItem(
                      value: '${batch['id']}',
                      child: Text(
                          '${label('${batch['category']}')} · ${amount(batch['available_to_commit'])} available · ${demandDate(batch['expected_ready_date'])}')))
                  .toList(),
              onChanged:
                  busy ? null : (id) => setState(() => selectedBatchId = id),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
          TextFormField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Quantity you can supply',
                  suffixText: demandUnit(widget.demand)),
              validator: (value) {
                final n = int.tryParse(value ?? '');
                final batch = batches
                    .where((r) => '${r['id']}' == selectedBatchId)
                    .firstOrNull;
                final available =
                    num.tryParse('${batch?['available_to_commit']}') ?? 0;
                return n == null || n <= 0 || n > remaining || n > available
                    ? 'Enter a quantity within remaining demand and your available batch amount'
                    : null;
              }),
          const SizedBox(height: 16),
          OmoterraDateField('Expected ready date', date),
          TextFormField(
              controller: weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Expected average weight', suffixText: 'kg'),
              validator: (value) {
                final n = double.tryParse(value ?? '');
                return n == null || !n.isFinite || n <= 0
                    ? 'Enter a valid weight'
                    : null;
              }),
          const SizedBox(height: 16),
          TextFormField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Your asking price (optional)',
                  prefixText: 'TZS ',
                  suffixText: 'per unit'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final n = double.tryParse(value);
                return n == null || !n.isFinite || n <= 0
                    ? 'Enter a valid price'
                    : null;
              }),
          if (error != null) ErrorState(error!),
          const SizedBox(height: 20),
          OmoterraButton('Submit Supply',
              busy: busy || loadingBatches || batches.isEmpty,
              onPressed: submit),
          const SizedBox(height: 10),
          const Text(
              'Your offer will be reviewed by Omoterra. Stock is reserved only after confirmation.',
              style: TextStyle(fontSize: 12, color: OColors.secondary)),
        ]));
  }
}
