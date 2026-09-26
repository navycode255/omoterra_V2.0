import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import 'listing_feed.dart';

class ExploreScreen extends StatefulWidget {
  final String initialCategory;
  const ExploreScreen({super.key, this.initialCategory = ''});
  @override
  State<ExploreScreen> createState() => _ExploreState();
}

/// How long typing must pause before the search goes to the server.
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
                            onChanged: _searchChanged))),
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
