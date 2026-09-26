import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';

String demandDate(Object? value, Strings s) {
  final date = DateTime.tryParse('$value');
  return date == null ? s.dateTbc : s.date(date);
}

String demandSchedule(Map row, Strings s) {
  final frequency = row['recurrence_frequency'];
  final days = row['preferred_weekdays'];
  if (frequency != null && '$frequency'.isNotEmpty) {
    final dayText = days is List && days.isNotEmpty
        ? ' · ${days.map((d) => s.label('$d')).join(', ')}'
        : '';
    return '${s.repeats(s.label('$frequency'))}$dayText';
  }
  return row['schedule'] ??
      s.neededByDate(demandDate(row['needed_by'] ?? row['needed_by_date'], s));
}

String demandTitle(Map row, Strings s) =>
    '${amount(row['quantity'])} ${s.label(row['category'])}${row['requirement_type'] == 'recurring' || row['repeating'] == true ? s.recurringSuffix : ''}';
String demandRegion(Map row, Strings s) =>
    '${row['delivery_region'] ?? row['region'] ?? s.locationTbc}';
String demandWeight(Map row, Strings s) {
  final min = row['minimum_weight_kg'] ?? row['weight'];
  final max = row['maximum_weight_kg'];
  if (min == null && max == null) return s.weightTbc;
  if (min != null && max != null) return '$min–$max kg';
  return '${min ?? '$max+'} kg';
}

num demandSecured(Map row) =>
    num.tryParse('${row['secured_quantity'] ?? row['matched'] ?? 0}') ?? 0;
num demandRemaining(Map row) =>
    num.tryParse(
        '${row['remaining_quantity'] ?? ((num.tryParse('${row['quantity']}') ?? 0) - demandSecured(row))}') ??
    0;
String demandUnit(Map row, Strings s) =>
    s.label('${row['unit_type'] ?? row['unit'] ?? 'birds'}');

bool demandRecurring(Map row) =>
    row['requirement_type'] == 'recurring' || row['repeating'] == true;

/// '20 birds', '1 bird', '12 kg' — the demand's unit, counted.
String demandUnits(Map row, num quantity, Strings s) {
  final unit = '${row['unit_type'] ?? row['unit'] ?? 'bird'}';
  return '${amount(quantity)} ${s.unit(unit, quantity)}';
}

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
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(children: [
            BackChevron(onPressed: () => context.go('/supplier')),
            Expanded(
                child: Text(s.marketDemand,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800))),
            IconButton(
                tooltip: s.searchDemand,
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
                    decoration: InputDecoration(
                        hintText: s.searchProductOrLocation,
                        prefixIcon: const Icon(Icons.search)),
                    onChanged: (value) =>
                        setState(() => search = value.trim().toLowerCase()))),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final entry in [
                  ('all', s.all),
                  ('broilers', s.label('broilers')),
                  ('layers', s.label('layers')),
                  ('goats', s.label('goats')),
                  ('cattle', s.cows)
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
                    '${row['category']} ${s.label('${row['category']}')} ${demandRegion(row, s)}'
                        .toLowerCase()
                        .contains(search))
                .toList();
            if (rows.isEmpty) {
              return EmptyState(s.noDemandTitle, s.noDemandBody);
            }
            return Column(children: [
              for (final row in rows) DemandCard(Map<String, dynamic>.from(row))
            ]);
          }),
        ]);
  }
}

class DemandCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const DemandCard(this.row, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  _FormBadge(
                                      '${row['live_dressed_or_cut'] ?? row['form'] ?? 'live'}'),
                                  const SizedBox(height: 5),
                                  Text(demandTitle(row, s),
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  Text(demandWeight(row, s),
                                      style: const TextStyle(
                                          color: OColors.secondary,
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  _DetailLine(Icons.location_on_outlined,
                                      demandRegion(row, s)),
                                ])),
                            const Icon(Icons.chevron_right, size: 21),
                          ]),
                          const SizedBox(height: 12),
                          _DetailLine(Icons.calendar_today_outlined,
                              demandSchedule(row, s)),
                          const SizedBox(height: 12),
                          DemandProgress(row),
                        ])))));
  }
}

class DemandProgress extends StatelessWidget {
  final Map row;
  const DemandProgress(this.row, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final total = num.tryParse('${row['quantity']}') ?? 0;
    final matched = demandSecured(row);
    final share = total > 0 ? (matched / total).clamp(0, 1).toDouble() : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: amount(matched),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: s.matchedOf(amount(total)))
                ]),
                style: const TextStyle(fontSize: 13, color: OColors.ink))),
        Text('${(share * 100).round()}%',
            style: const TextStyle(fontSize: 12.5, color: OColors.secondary)),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(
          value: share,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF007653),
          // Dark enough to read as an empty bar on the pale card.
          backgroundColor: const Color(0xFFC9D8CF),
          semanticsLabel: s.matchedSemantics(amount(matched), amount(total))),
    ]);
  }
}

class _FormBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _FormBadge(this.text, {this.color = const Color(0xFFFFA33C)});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Text(context.s.label(text),
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
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
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
                // Clear at the top, where the logo and role pill float over
                // the sky as on Supplier Home; deep green behind the text.
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [
                      0,
                      .28,
                      1
                    ],
                        colors: [
                      Colors.transparent,
                      Color(0x22000000),
                      Color(0xDD084B35)
                    ])),
                padding: EdgeInsets.fromLTRB(
                    24, MediaQuery.paddingOf(context).top + 8, 24, 44),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A soft disc keeps the arrow visible on light sky.
                      Material(
                          color: Colors.white.withValues(alpha: .82),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                              tooltip: s.backToDemand,
                              constraints: const BoxConstraints.tightFor(
                                  width: 40, height: 40),
                              padding: EdgeInsets.zero,
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/supplier-demand'),
                              icon: const BackChevron())),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, children: [
                        _FormBadge(
                            '${row['live_dressed_or_cut'] ?? row['form'] ?? 'live'}'),
                        if (demandRecurring(row))
                          const _FormBadge('recurring',
                              color: Color(0xFF2F7D5B)),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          '${amount(row['quantity'])} ${s.label(row['category'])}',
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text(demandWeight(row, s),
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white)),
                      const SizedBox(height: 18),
                      _DetailLine(
                          Icons.location_on_outlined, demandRegion(row, s),
                          color: Colors.white),
                      const SizedBox(height: 10),
                      _DetailLine(
                          Icons.calendar_today_outlined, demandSchedule(row, s),
                          color: Colors.white),
                      const SizedBox(height: 10),
                      _DetailLine(
                          Icons.sync,
                          demandRecurring(row)
                              ? s.recurringDemand
                              : s.oneTimeDemand,
                          color: Colors.white),
                      if (demandRecurring(row)) ...[
                        const SizedBox(height: 10),
                        // Offers are made one cycle at a time.
                        _DetailLine(
                            Icons.event_available_outlined,
                            s.currentCycle(demandDate(
                                row['needed_by_date'] ?? row['needed_by'], s)),
                            color: Colors.white),
                      ],
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
}

class SupplyOfferForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> demand;
  const SupplyOfferForm(this.demand, {super.key});
  @override
  ConsumerState<SupplyOfferForm> createState() => _SupplyOfferState();
}

/// A batch that can back an offer on [demand]: same product, stock left to
/// commit, still active, and ready by the date the buyer needs it.
bool offerableBatch(Map batch, Map demand) {
  final needed =
      DateTime.tryParse('${demand['needed_by_date'] ?? demand['needed_by']}');
  final ready = DateTime.tryParse('${batch['expected_ready_date']}');
  return batch['category'] == demand['category'] &&
      (num.tryParse('${batch['available_to_commit']}') ?? 0) > 0 &&
      !['paused', 'cancelled', 'completed', 'fully_reserved']
          .contains(batch['status']) &&
      (needed == null || ready == null || !ready.isAfter(needed));
}

/// Two states, never mixed: without an offerable batch the supplier only sees
/// why and how to add one; with one, the offer form, filled from the batch.
class _SupplyOfferState extends ConsumerState<SupplyOfferForm> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController(),
      date = TextEditingController(),
      weight = TextEditingController(),
      price = TextEditingController();
  final key = newKey();
  bool busy = false, submitted = false, loading = true;
  Object? loadError, error;
  List<Map<String, dynamic>> sameProduct = [], batches = [];
  String? selectedBatchId;

  Map<String, dynamic> get demand => widget.demand;
  Map<String, dynamic>? get selected =>
      batches.where((b) => '${b['id']}' == selectedBatchId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final data = await ref.read(repositoryProvider).read('/supplier/batches');
      if (!mounted) return;
      final rows = (data as List).map((r) => Map<String, dynamic>.from(r));
      setState(() {
        sameProduct =
            rows.where((r) => r['category'] == demand['category']).toList();
        batches = sameProduct.where((r) => offerableBatch(r, demand)).toList();
        if (selected == null) {
          selectedBatchId = batches.isEmpty ? null : '${batches.first['id']}';
          _fillFrom(selected);
        }
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = e;
          loading = false;
        });
      }
    }
  }

  String _plain(num value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  /// What Omoterra already knows from the batch, so the supplier only edits
  /// what differs.
  void _fillFrom(Map<String, dynamic>? batch) {
    if (batch == null) return;
    final available = num.tryParse('${batch['available_to_commit']}') ?? 0;
    final remaining = demandRemaining(demand);
    quantity.text = _plain(available < remaining ? available : remaining);
    date.text = DateTime.tryParse('${batch['expected_ready_date']}') == null
        ? ''
        : '${batch['expected_ready_date']}'.split('T').first;
    final actual = num.tryParse('${batch['actual_average_weight_kg']}');
    final low = num.tryParse('${batch['expected_min_weight_kg']}');
    final high = num.tryParse('${batch['expected_max_weight_kg']}');
    final average = actual ??
        (low != null && high != null ? (low + high) / 2 : low ?? high);
    weight.text =
        average == null ? '' : _plain(num.parse(average.toStringAsFixed(2)));
    final asking = num.tryParse('${batch['asking_price_per_unit']}');
    price.text = asking == null ? '' : _plain(asking);
  }

  Future<void> _registerBatch() async {
    await context
        .push('/batches/new?category=${demand['category']}&from=demand');
    // Back from registering: the new batch may make the offer possible.
    if (mounted) await _loadBatches();
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
    final needed =
        DateTime.tryParse('${demand['needed_by_date'] ?? demand['needed_by']}');
    if (ready.isBefore(DateTime(now.year, now.month, now.day)) ||
        (needed != null && ready.isAfter(needed))) {
      setState(
          () => error = ApiFailure(ref.read(stringsProvider).readyDateRange));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write(
          '/supplier/demand/${demand['id']}/offers',
          {
            'batch_id': selectedBatchId,
            'offered_quantity': quantity.text.trim(),
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

  Widget _title(Strings s) => Row(children: [
        Expanded(
            child: Text(s.supplyThisDemand,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800))),
        InfoButton(
            color: OColors.forest,
            title: s.aboutOffers,
            message: '${s.aboutOffersBody}'
                '${demandRecurring(demand) ? '\n\n${s.offerCycleNote(demandDate(demand['needed_by_date'] ?? demand['needed_by'], s))}' : ''}'),
      ]);

  Widget _blocked(Strings s) {
    final needed =
        demandDate(demand['needed_by_date'] ?? demand['needed_by'], s);
    // They have this product, just nothing ready in time or left to offer.
    final notInTime = sameProduct.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EmptyState(
          notInTime ? s.noBatchInTime : s.registerBatchFirst,
          notInTime
              ? s.noneReadyBy(s.label(demand['category']), needed)
              : s.offersFromStock),
      const SizedBox(height: 16),
      OmoterraButton(s.registerProductionBatch, onPressed: _registerBatch),
    ]);
  }

  Widget _available(Map<String, dynamic> batch, Strings s) {
    final available = num.tryParse('${batch['available_to_commit']}') ?? 0;
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF6F1),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(
              child: Text(s.availableStat,
                  style: const TextStyle(
                      fontSize: 13.5, color: OColors.secondary))),
          Text(demandUnits(demand, available, s),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: OColors.ink)),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    if (submitted) {
      return EmptyState(s.offerReceived, s.offerReceivedBody);
    }
    final remaining = demandRemaining(demand);
    if (remaining <= 0) {
      return EmptyState(s.demandFullyMatched, s.demandFullyMatchedBody);
    }
    final batch = selected;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(s),
      const SizedBox(height: 12),
      if (loading)
        const LoadingSkeleton()
      else if (loadError != null)
        ErrorState(loadError!, retry: _loadBatches)
      else if (batch == null)
        _blocked(s)
      else
        Form(
            key: form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OmoterraDropdown<String>(
                    label: s.productionBatch,
                    value: selectedBatchId!,
                    items: batches
                        .map((b) => DropdownMenuItem(
                            value: '${b['id']}',
                            child: Text(
                                '${s.label('${b['category']}')} · ${s.batchNo('${b['id']}'.substring(0, 6).toUpperCase())}')))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (id) => setState(() {
                              selectedBatchId = id;
                              _fillFrom(selected);
                            }),
                  ),
                  _available(batch, s),
                  TextFormField(
                      key: const Key('offer_quantity'),
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: s.quantityToSupply,
                          suffixText: demandUnits(demand, 2, s)
                              .replaceFirst(RegExp(r'^\S+ '), '')),
                      validator: (value) {
                        final n = int.tryParse(value?.trim() ?? '');
                        final available =
                            num.tryParse('${batch['available_to_commit']}') ??
                                0;
                        if (n == null || n <= 0) return s.enterQuantity;
                        if (n > remaining) {
                          return s.onlyStillNeeded(
                              demandUnits(demand, remaining, s));
                        }
                        if (n > available) {
                          return s.batchHasAvailable(
                              demandUnits(demand, available, s));
                        }
                        return null;
                      }),
                  const SizedBox(height: 16),
                  OmoterraDateField(s.expectedReady, date),
                  TextFormField(
                      key: const Key('offer_weight'),
                      controller: weight,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: s.averageWeightLabel, suffixText: 'kg'),
                      validator: (value) {
                        final n = double.tryParse(value ?? '');
                        return n == null || !n.isFinite || n <= 0
                            ? s.enterValidWeight
                            : null;
                      }),
                  const SizedBox(height: 16),
                  TextFormField(
                      key: const Key('offer_price'),
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: s.askingPriceOptional,
                          suffixText: s.tzsPer(demand['unit_type'] == null
                              ? s.unitWord
                              : s.unit('${demand['unit_type']}', 1))),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final n = double.tryParse(value);
                        return n == null || !n.isFinite || n <= 0
                            ? s.enterValidPrice
                            : null;
                      }),
                  if (error != null) ErrorState(error!),
                  const SizedBox(height: 20),
                  // Busy only while the offer is actually being sent.
                  OmoterraButton(s.submitOffer, busy: busy, onPressed: submit),
                ])),
    ]);
  }
}
