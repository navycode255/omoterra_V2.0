import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/back_navigation.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/photo_picker.dart';
import '../../shared/widgets/stock_video.dart';

class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key});
  @override
  ConsumerState<AddStockScreen> createState() => _AddStockState();
}

class _AddStockState extends ConsumerState<AddStockScreen>
    with StepBackHistory {
  String category = 'broilers';
  int step = 0;
  Map<String, dynamic>? preview;
  List<String> photos = [];
  String? video;
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(stringsProvider).stockSubmitted)));
        // Replace the form with the new stock so back returns to the list
        // it was opened from, not to a submitted form.
        context.pushReplacement('/stock/${row['id']}');
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.addProductionStock)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView('/supplier/profile', builder: (profile) {
            if (profile == null) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.firstPickupDetails,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(s.pickupDetailsPrivate),
                    const SizedBox(height: 24),
                    DataForm(
                        path: '/supplier/profile',
                        method: 'PUT',
                        fields: [
                          FormFieldSpec('legal_name', s.legalName),
                          FormFieldSpec('internal_pickup_address',
                              s.internalPickupAddress,
                              multiline: true)
                        ],
                        button: s.saveAndAddStock,
                        onSuccess: (_) => ref
                            .invalidate(resourceProvider('/supplier/profile')))
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
                            s.selectCategory,
                            s.stockDetails,
                            s.priceAndLocation,
                            s.addPhotos,
                            s.previewSubmit
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
                        Text(s.registerLivestockIntro),
                        const SizedBox(height: 16),
                        OmoterraTextField(
                            s.quantityIn(s.unit(unitFor(category), 1)),
                            field('quantity_total'),
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true)),
                        for (final k in specKeys)
                          if (k.endsWith('date'))
                            OmoterraDateField(
                                k == 'ready_date'
                                    ? s.expectedReadyDate
                                    : s.label(k),
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
                                label: s.label(k),
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
                                            ? s.nEggs(v)
                                            : s.label(v))))
                                    .toList(),
                                onChanged: (value) => field(k).text = value!)
                          else
                            OmoterraTextField(s.label(k), field(k),
                                keyboard:
                                    ['avg_weight_kg', 'age_weeks'].contains(k)
                                        ? const TextInputType.numberWithOptions(
                                            decimal: true)
                                        : TextInputType.text),
                      ],
                      if (step == 2) ...[
                        OmoterraTextField(
                            s.askingPricePer(s.unit(unitFor(category), 1)),
                            field('farmer_asking_price_per_unit'),
                            keyboard: TextInputType.number),
                        OmoterraTextField(
                            s.generalRegion,
                            field(
                                'region',
                                ref.read(sessionProvider).valueOrNull?.region ??
                                    '')),
                        Text(s.priceReviewNote)
                      ],
                      if (step == 3) ...[
                        PhotoPicker(
                            photos: photos,
                            onChanged: (value) =>
                                setState(() => photos = value)),
                        const SizedBox(height: 28),
                        StockVideoPicker(
                            video: video,
                            onChanged: (value) =>
                                setState(() => video = value)),
                      ],
                      if (step == 4) ...[
                        ProductImage(photos, category: category, height: 150),
                        if (video != null) ...[
                          const SizedBox(height: 10),
                          StockVideoTile(video!),
                        ],
                        const SizedBox(height: 16),
                        MoneySummary({
                          s.category: s.label(category),
                          s.quantity:
                              '${preview!['quantity_total']} ${s.unit(unitFor(category), num.tryParse('${preview!['quantity_total']}'))}',
                          s.askingPriceShort:
                              tsh(preview!['farmer_asking_price_per_unit']),
                          s.regionLabel: preview!['region']
                        }),
                        const SizedBox(height: 12),
                        MoneySummary(
                            Map<String, dynamic>.from(preview!['specs'])
                                .map((k, v) => MapEntry(s.label(k), '$v')))
                      ],
                      if (error != null) ErrorState(error!),
                      const SizedBox(height: 24),
                      OmoterraButton(
                          step == 4 ? s.submitForReviewLower : s.continueLabel,
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
                                for (final k in specKeys)
                                  k: field(k).text.trim()
                              },
                              'photos': photos,
                              'video': video,
                            };
                          }
                          step++;
                        });
                        pushStep(() => step--);
                      }),
                      if (step > 0)
                        TextButton(
                            onPressed: busy ? null : popStep,
                            child: Text(s.back))
                    ]));
          })
        ]));
  }
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
