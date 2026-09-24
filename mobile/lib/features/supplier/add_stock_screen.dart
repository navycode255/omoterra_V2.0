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
      appBar: OmoterraAppBar(title: const Text('Add Production / Stock')),
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
                      const Text(
                          'Register livestock that is still growing or ready now. Tell us when this batch will be ready.'),
                      const SizedBox(height: 16),
                      OmoterraTextField('Quantity (${unitFor(category)})',
                          field('quantity_total'),
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true)),
                      for (final k in specKeys)
                        if (k.endsWith('date'))
                          OmoterraDateField(
                              k == 'ready_date'
                                  ? 'Expected ready date'
                                  : label(k),
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
                          OmoterraDropdown<String>(
                              value: field(
                                      k,
                                      switch (k) {
                                        'live_or_dressed' => 'live',
                                        'sex' => 'mixed',
                                        'tray_size' => '30',
                                        'egg_size' => 'medium',
                                        _ => 'chilled',
                                      })
                                  .text,
                              label: label(k),
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
                              onChanged: (value) => field(k).text = value!)
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
                          color: i <= current ? Colors.white : OColors.muted))),
          if (i != total - 1)
            Expanded(
                child: Container(
                    height: 2,
                    color: i < current ? OColors.forest : OColors.border)),
        ]
      ]);
}
