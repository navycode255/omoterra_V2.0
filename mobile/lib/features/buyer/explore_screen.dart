import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/brand_image.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import 'listing_feed.dart';

class ExploreScreen extends StatefulWidget {
  final String initialCategory;
  const ExploreScreen({super.key, this.initialCategory = ''});
  @override
  State<ExploreScreen> createState() => _ExploreState();
}

const searchDebounce = Duration(milliseconds: 400);

class _ExploreState extends State<ExploreScreen> {
  late String category = widget.initialCategory;
  String search = '', region = '', readyBy = '', condition = '';
  double? maxPrice, minWeight, maxWeight;
  Timer? _typing;

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  void _searchChanged(String value) {
    _typing?.cancel();
    _typing = Timer(searchDebounce, () {
      if (mounted && value.trim() != search) {
        setState(() => search = value.trim());
      }
    });
  }

  Future<void> filters() async {
    final regionText = TextEditingController(text: region),
        price = TextEditingController(text: maxPrice?.toStringAsFixed(0) ?? ''),
        date = TextEditingController(text: readyBy),
        minimum = TextEditingController(text: minWeight?.toString() ?? ''),
        maximum = TextEditingController(text: maxWeight?.toString() ?? '');
    String selectedCondition = condition;
    final s = context.s;
    final values = await omoterraSheet<List<String>>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.filterSupply, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          OmoterraTextField(s.regionLabel, regionText, requiredField: false),
          OmoterraTextField(s.maxPricePerUnit, price,
              keyboard: TextInputType.number, requiredField: false),
          OmoterraDateField(s.readyBy, date, optional: true),
          OmoterraTextField(s.minWeightKg, minimum,
              requiredField: false, keyboard: TextInputType.number),
          OmoterraTextField(s.maxWeightKg, maximum,
              requiredField: false, keyboard: TextInputType.number),
          OmoterraDropdown<String>(
              label: s.condition,
              value: condition,
              items: ['', 'live', 'dressed', 'chilled', 'frozen']
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.isEmpty ? s.anyCondition : s.label(v))))
                  .toList(),
              onChanged: (v) => selectedCondition = v!),
          const SizedBox(height: 24),
          OmoterraButton(s.applyFilters,
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
        final base = ref.watch(listingsProvider(''));
        final basePage = base.valueOrNull;
        final noOpenSupply = basePage != null && basePage.items.isEmpty;
        final searching = search.isNotEmpty ||
            category.isNotEmpty ||
            region.isNotEmpty ||
            readyBy.isNotEmpty ||
            condition.isNotEmpty ||
            maxPrice != null ||
            minWeight != null ||
            maxWeight != null;
        return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _MarketplaceHero(open: !noOpenSupply),
              const SizedBox(height: 18),
              if (noOpenSupply && !searching) ...[
                const _MarketplaceEmptyCard(),
                const SizedBox(height: 22),
                Text(s.myOrders,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: OColors.ink,
                        letterSpacing: -.5)),
                const SizedBox(height: 10),
                _OrdersShortcut(onTap: () => context.go('/orders')),
              ] else ...[
                Row(children: [
                  Expanded(
                      child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: OColors.border),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        OColors.forest.withValues(alpha: .05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ]),
                          child: TextField(
                              decoration: InputDecoration(
                                  hintText: s.searchHint,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 4),
                                  prefixIcon: const Icon(Icons.search,
                                      size: 21, color: OColors.muted),
                                  hintStyle: const TextStyle(
                                      color: OColors.muted, fontSize: 14)),
                              onChanged: _searchChanged))),
                  const SizedBox(width: 10),
                  InkWell(
                      onTap: filters,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: OColors.border)),
                          child: const Icon(Icons.tune,
                              size: 22, color: OColors.forest))),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                    height: 40,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        children: ['', ...categories]
                            .map((c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterChip(
                                    label: c.isEmpty ? s.all : s.label(c),
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
              ]
            ]);
      });
}

class _MarketplaceHero extends StatelessWidget {
  final bool open;
  const _MarketplaceHero({required this.open});

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
          aspectRatio: 2.68,
          child: Stack(fit: StackFit.expand, children: [
            const BrandImage('buyer-marketplace-hero-v1',
                extension: 'jpg',
                fallbackArt: 'broilers',
                alignment: Alignment.centerRight),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: [
                  0,
                  .48,
                  .8
                ],
                        colors: [
                  Color(0xE8003F2A),
                  Color(0xA4004D31),
                  Color(0x00002719)
                ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 18, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.storefront_outlined,
                              size: 23, color: Colors.white)),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.s.marketplace,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    height: 1.05,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.7)),
                            const SizedBox(height: 5),
                            Text(
                                open
                                    ? context.s.marketplaceOpen
                                    : context.s.marketplaceClosed,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: .94),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ])
                    ]))
          ])));
}

class _MarketplaceEmptyCard extends StatelessWidget {
  const _MarketplaceEmptyCard();

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE1E9E4)),
          boxShadow: [
            BoxShadow(
                color: OColors.forest.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 9))
          ]),
      child: Column(children: [
        SizedBox(
            height: 112,
            child: Stack(alignment: Alignment.center, children: [
              const Positioned.fill(child: HillsBackdrop()),
              Positioned(
                  left: 55,
                  bottom: 18,
                  child: LeafSprig(
                      size: 38,
                      angle: -.25,
                      color: const Color(0xFFB8D8C2).withValues(alpha: .72))),
              Positioned(
                  right: 54,
                  bottom: 22,
                  child: LeafSprig(
                      size: 32,
                      angle: .24,
                      color: const Color(0xFFB8D8C2).withValues(alpha: .72))),
              Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE6F2E9), shape: BoxShape.circle),
                  child: const Icon(Icons.event_busy_outlined,
                      size: 46, color: Color(0xFF5A9A71)))
            ])),
        const SizedBox(height: 8),
        Text(context.s.marketplaceEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: OColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4)),
        const SizedBox(height: 7),
        Text(context.s.marketplaceEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: OColors.muted, fontSize: 14, height: 1.45)),
        const SizedBox(height: 22),
        Material(
            color: const Color(0xFFEDF6F0),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                onTap: () => context.push('/request'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(children: [
                      const Icon(Icons.add_alert_outlined,
                          color: Color(0xFF08743F), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(context.s.requestWhatYouNeed,
                              style: const TextStyle(
                                  color: Color(0xFF08743F),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700))),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF08743F), size: 25)
                    ]))))
      ]));
}

class _OrdersShortcut extends StatelessWidget {
  final VoidCallback onTap;
  const _OrdersShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE1E9E4))),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                        color: Color(0xFFF0F3F5), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: Color(0xFF64748B), size: 25)),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(context.s.myOrdersBody,
                        style: const TextStyle(
                            color: OColors.secondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right, color: OColors.muted, size: 25)
              ]))));
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: selected ? const Color(0xFF08743F) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          selected ? const Color(0xFF08743F) : OColors.border)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : OColors.secondary)))));
}
