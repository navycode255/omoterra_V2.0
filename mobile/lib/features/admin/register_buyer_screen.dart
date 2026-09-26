import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/routing/back_navigation.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../buyer/request_supply_screen.dart' show tanzaniaRegions, darDistricts;

const buyerTypes = [
  'restaurant',
  'hotel',
  'butchery',
  'retailer',
  'caterer',
  'personal',
  'other'
];
const _products = [
  'broilers',
  'local_chicken',
  'layers',
  'eggs',
  'goats',
  'cattle',
  'chicken_meat',
  'beef',
  'goat_meat'
];
const _days = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday'
];

/// Staff registering a buyer, in three steps: who they are, where they are,
/// and how they buy. Everything the dashboard's buyer record holds, so staff
/// never have to come back to fill it in.
class RegisterBuyerScreen extends ConsumerStatefulWidget {
  final VoidCallback onRegistered;
  const RegisterBuyerScreen({super.key, required this.onRegistered});
  @override
  ConsumerState<RegisterBuyerScreen> createState() => _RegisterBuyerState();
}

class _RegisterBuyerState extends ConsumerState<RegisterBuyerScreen>
    with StepBackHistory {
  List<String> get _titles =>
      [ref.s.whoTheyAre, ref.s.whereTheyAre, ref.s.howTheyBuy];
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  final _fields = <String, TextEditingController>{};
  final _key = newKey();
  int step = 0;
  String buyerType = 'restaurant',
      region = 'Dar es Salaam',
      district = 'Kinondoni',
      condition = '',
      frequency = '',
      handover = '';
  final products = <String>{}, days = <String>{};
  bool busy = false;
  Object? error;

  TextEditingController _c(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _number(String text) {
    final value = double.tryParse(text);
    return value == null || value <= 0
        ? ref.read(stringsProvider).enterNumberAboveZero
        : null;
  }

  Widget _text(String key, String label,
          {bool required = false,
          bool numeric = false,
          bool multiline = false,
          String? hint,
          String? suffix,
          String? Function(String)? check}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              key: Key('buyer_$key'),
              controller: _c(key),
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : key == 'phone'
                      ? TextInputType.phone
                      : TextInputType.text,
              maxLines: multiline ? 3 : 1,
              decoration: InputDecoration(
                  labelText: label, hintText: hint, suffixText: suffix),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return required
                      ? ref.read(stringsProvider).fieldRequired
                      : null;
                }
                return check?.call(text);
              }));

  Widget _dropdown(String label, String value, Map<String, String> options,
          ValueChanged<String> onChanged) =>
      OmoterraDropdown<String>(
          label: label,
          value: value,
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value))
          ],
          onChanged: (v) => setState(() => onChanged(v!)));

  Widget _chips(String title, List<String> values, Set<String> selected) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 13.5, color: OColors.secondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final value in values)
                FilterChip(
                    label: Text(ref.s.label(value)),
                    selected: selected.contains(value),
                    onSelected: (on) => setState(() =>
                        on ? selected.add(value) : selected.remove(value))),
            ]),
          ]));

  List<Widget> _fieldsFor(int step, Strings s) => switch (step) {
        0 => [
            _text('business_name', s.businessName,
                required: true,
                hint: s.businessNameHint,
                check: (t) => t.length < 2 ? s.enterBusinessName : null),
            _dropdown(
                s.buyerType,
                buyerType,
                {for (final t in buyerTypes) t: s.label(t)},
                (v) => buyerType = v),
            _text('name', s.contactPerson,
                required: true,
                check: (t) => t.length < 2 ? s.enterTheirName : null),
            _text('phone', s.theirMobile,
                required: true,
                hint: '0712 345 678',
                check: (t) =>
                    tanzanianMobile(t) == null ? s.enterTzMobileShort : null),
          ],
        1 => [
            _dropdown(
                s.regionLabel,
                region,
                {for (final r in tanzaniaRegions) r: s.regionName(r)},
                (v) => region = v),
            if (region == 'Dar es Salaam')
              _dropdown(s.area, district, {for (final d in darDistricts) d: d},
                  (v) => district = v)
            else
              _text('area', s.areaOptional, hint: s.townOrDistrict),
            _dropdown(
                s.pickupOrDelivery,
                handover,
                {
                  '': s.noPreference,
                  'delivery': s.delivery,
                  'pickup': s.theyCollect,
                  'either': s.either
                },
                (v) => handover = v),
          ],
        _ => [
            _chips(s.productsTheyBuy, _products, products),
            _dropdown(
                s.liveOrDressed,
                condition,
                {
                  '': s.noPreference,
                  for (final form in ['live', 'dressed', 'chilled', 'frozen'])
                    form: s.label(form),
                },
                (v) => condition = v),
            _text('typical_quantity', s.typicalQuantityOptional,
                numeric: true, check: _number),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _text('min_weight', s.minWeight,
                      suffix: 'kg', numeric: true, check: _number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _text('max_weight', s.maxWeight,
                      suffix: 'kg', numeric: true, check: (t) {
                final low = double.tryParse(_c('min_weight').text.trim());
                final high = double.tryParse(t);
                return _number(t) ??
                    (low != null && high! < low ? s.maxAtLeastMin : null);
              })),
            ]),
            _dropdown(
                s.howOftenTheyBuy,
                frequency,
                {
                  '': s.notKnown,
                  'daily': s.label('daily'),
                  'weekly': s.label('weekly'),
                  'every_two_weeks': s.everyTwoWeeks,
                  'monthly': s.label('monthly'),
                  'occasionally': s.occasionally
                },
                (v) => frequency = v),
            _chips(s.preferredDays, _days, days),
            _text('last_price', s.lastBuyingPrice,
                numeric: true, suffix: s.tzsPerUnit, check: _number),
            _text('minimum_order', s.minimumOrderOptional,
                numeric: true, check: _number),
            _text('payment_terms', s.paymentTermsOptional,
                hint: s.paymentTermsHint),
            _text('internal_notes', s.privateStaffNotes, multiline: true),
          ],
      };

  String? _optional(String key) {
    final text = _c(key).text.trim();
    return text.isEmpty ? null : text;
  }

  void _next() {
    if (!_forms[step].currentState!.validate()) return;
    setState(() {
      step++;
      error = null;
    });
    pushStep(() => step--);
  }

  Future<void> _submit() async {
    if (!_forms[step].currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write(
          '/referrals/buyer',
          {
            'phone': tanzanianMobile(_c('phone').text),
            'name': _c('name').text.trim(),
            'business_name': _c('business_name').text.trim(),
            'buyer_type': buyerType,
            'region': region,
            'area':
                region == 'Dar es Salaam' ? district : _c('area').text.trim(),
            'preferences': {
              'preferred_products': products.toList(),
              'live_dressed_preference': condition,
              'minimum_weight_kg': _optional('min_weight'),
              'maximum_weight_kg': _optional('max_weight'),
              'typical_quantity': _optional('typical_quantity'),
              'purchase_frequency': frequency,
              'preferred_days': days.toList(),
              'pickup_delivery_preference': handover,
            },
            'last_known_buying_price': _optional('last_price'),
            'minimum_order': _optional('minimum_order'),
            'payment_terms': _c('payment_terms').text.trim(),
            'internal_notes': _c('internal_notes').text.trim(),
          },
          key: _key);
      widget.onRegistered();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    final last = step == _titles.length - 1;
    return Scaffold(
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 28),
                children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.only(top: 2), child: BackChevron()),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(s.registerBuyerTitle,
                      style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: OColors.ink,
                          letterSpacing: -.4)),
                  const SizedBox(height: 4),
                  Text(_titles[step],
                      style: const TextStyle(
                          fontSize: 14, color: OColors.secondary)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(s.stepOf(step + 1, _titles.length),
                  style:
                      const TextStyle(fontSize: 13, color: OColors.secondary)),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 0; i < _titles.length; i++)
                  Container(
                      width: 22,
                      height: 5,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                          color: i <= step
                              ? OColors.forest
                              : const Color(0xFFDDE8E1),
                          borderRadius: BorderRadius.circular(3))),
              ]),
            ]),
          ]),
          const SizedBox(height: 22),
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Form(
                  key: _forms[step],
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _fieldsFor(step, s)))),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ErrorState(error!)),
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: last
                  ? FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Text(busy ? s.registering : s.finishRegistration))
                  : FilledButton(
                      onPressed: _next,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                            child: Text(s.nextStep(_titles[step + 1]),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward, size: 20),
                      ]))),
        ])));
  }
}
