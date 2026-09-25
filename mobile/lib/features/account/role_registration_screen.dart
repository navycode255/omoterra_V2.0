import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/routing/back_navigation.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/farm_location.dart';
import '../../shared/widgets/photo_picker.dart';

class RoleRegistrationScreen extends ConsumerWidget {
  final String role;
  const RoleRegistrationScreen(this.role, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (role == 'supplier') return const SupplierOnboardingWizard();
    if (role != 'buyer') {
      return const Scaffold(body: Center(child: Text('Unknown role')));
    }
    return Scaffold(
        appBar: const OmoterraAppBar(title: Text('Register as a buyer')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Complete buyer registration',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Choose the buyer profile that fits how you purchase.'),
          const SizedBox(height: 24),
          DataForm(
              path: '/account/register-role',
              fixed: const {'role': 'buyer'},
              fields: const [
                FormFieldSpec('buyer_type', 'Buyer type', options: [
                  'personal',
                  'restaurant',
                  'butchery',
                  'hotel',
                  'retailer',
                  'caterer',
                  'other'
                ])
              ],
              button: 'Complete registration',
              onSuccess: (response) async {
                try {
                  await ref
                      .read(sessionProvider.notifier)
                      .acceptRegisteredRole(response, 'buyer');
                  if (context.mounted) context.go('/buyer');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyErrorMessage(e))));
                  }
                }
              }),
        ]));
  }
}

const _categories = [
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
const _units = {
  'broilers': 'bird',
  'local_chicken': 'bird',
  'layers': 'bird',
  'eggs': 'tray',
  'goats': 'animal',
  'cattle': 'animal',
  'chicken_meat': 'kg',
  'beef': 'kg',
  'goat_meat': 'kg'
};

class SupplierOnboardingWizard extends ConsumerStatefulWidget {
  const SupplierOnboardingWizard({super.key});
  @override
  ConsumerState<SupplierOnboardingWizard> createState() =>
      _SupplierOnboardingWizardState();
}

class _SupplierOnboardingWizardState
    extends ConsumerState<SupplierOnboardingWizard> with StepBackHistory {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _selected = <String>{}, _forms = <String>{'live'};
  final _evidencePhotos = <String>[],
      _currentPhotos = <String>[],
      _futurePhotos = <String>[];
  int _step = 0;
  FarmLocation? _farm;
  String? _error;
  bool _busy = false,
      _hasCurrent = false,
      _hasFuture = false,
      _canCollect = false,
      _canTransport = false;
  String _primary = 'broilers',
      _contact = 'phone',
      _currentCategory = 'broilers',
      _futureCategory = 'broilers';
  String _currentForm = 'live',
      _futureForm = 'live',
      _currentAgeUnit = 'weeks',
      _futureAgeUnit = 'weeks';

  TextEditingController _c(String key, {String initial = ''}) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: initial));
  String _unit(String category) => _units[category] ?? 'unit';
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _text(String key, String title,
          {bool required = false,
          bool numeric = false,
          bool multiline = false,
          String initial = '',
          String? suffix}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              key: Key(key),
              controller: _c(key, initial: initial),
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              maxLines: multiline ? 3 : 1,
              decoration: InputDecoration(labelText: title, suffixText: suffix),
              validator: required
                  ? (value) => value == null || value.trim().isEmpty
                      ? 'This field is required'
                      : null
                  : null));

  Widget _select(String title, String value, List<String> values,
          ValueChanged<String?> onChanged) =>
      OmoterraDropdown<String>(
          label: title,
          value: value,
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(label(v))))
              .toList(),
          onChanged: onChanged);
  String get _title => const [
        'Supplier identity',
        'What you supply',
        'Pickup & operations',
        'Current production',
        'Photos',
        'Review'
      ][_step];

  Widget _batchForm(
          String prefix,
          String category,
          ValueChanged<String?> setCategory,
          String form,
          ValueChanged<String?> setForm,
          String ageUnit,
          ValueChanged<String?> setAgeUnit,
          List<String> photos,
          ValueChanged<List<String>> setPhotos) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _select('Product category', category, _selected.toList(), setCategory),
        _text('${prefix}_subtype', 'Breed / type (optional)'),
        _text('${prefix}_quantity', 'Current quantity (${_unit(category)})',
            required: true, numeric: true),
        Row(children: [
          Expanded(
              child: _text('${prefix}_age', 'Current age (optional)',
                  numeric: true)),
          const SizedBox(width: 12),
          Expanded(
              child: _select('Age unit', ageUnit,
                  const ['days', 'weeks', 'months'], setAgeUnit))
        ]),
        if (!['eggs', 'chicken_meat', 'beef', 'goat_meat']
            .contains(category)) ...[
          _text('${prefix}_min_weight', 'Expected minimum weight (kg)',
              numeric: true),
          _text('${prefix}_max_weight', 'Expected maximum weight (kg)',
              numeric: true)
        ],
        OmoterraDateField(
            'Expected ready / collection date',
            _c('${prefix}_ready_date',
                initial: DateTime.now()
                    .add(const Duration(days: 1))
                    .toIso8601String()
                    .split('T')
                    .first)),
        _select('Supply form', form,
            const ['live', 'dressed', 'chilled', 'frozen'], setForm),
        _text('${prefix}_asking_price',
            'Asking price per ${_unit(category)} (TZS)',
            required: true, numeric: true),
        PhotoPicker(photos: photos, onChanged: setPhotos),
      ]);

  Widget _body() {
    final user = ref.read(sessionProvider).value;
    switch (_step) {
      case 0:
        return Column(children: [
          _text('public_alias', 'Farm / supplier name', required: true),
          _text('legal_name', 'Legal / full name',
              required: true, initial: user?.name ?? ''),
          TextFormField(
              initialValue: user?.phone ?? '',
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Primary phone')),
          _text('alternate_phone', 'Alternate phone (optional)'),
          _text('region', 'Region',
              required: true, initial: user?.region ?? ''),
          _text('district', 'District', required: true),
          _text('general_area', 'General area (optional)'),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Choose the products you normally supply.'),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _categories
                  .map((c) => FilterChip(
                      label: Text(label(c)),
                      selected: _selected.contains(c),
                      onSelected: (selected) => setState(() {
                            selected ? _selected.add(c) : _selected.remove(c);
                            if (_selected.isNotEmpty &&
                                !_selected.contains(_primary)) {
                              _primary = _selected.first;
                            }
                            if (_selected.isNotEmpty &&
                                !_selected.contains(_currentCategory)) {
                              _currentCategory = _selected.first;
                            }
                            if (_selected.isNotEmpty &&
                                !_selected.contains(_futureCategory)) {
                              _futureCategory = _selected.first;
                            }
                          })))
                  .toList()),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 18),
            _select('Main category', _primary, _selected.toList(),
                (value) => setState(() => _primary = value!)),
            for (final category in _selected)
              _text('capacity_$category',
                  '${label(category)} typical capacity (optional)',
                  numeric: true, suffix: '${_unit(category)} / cycle')
          ],
          _text('production_frequency', 'Usual production cycle (optional)',
              suffix: 'e.g. every 6 weeks'),
        ]);
      case 2:
        return Column(children: [
          FarmLocationField(
              value: _farm, onChanged: (v) => setState(() => _farm = v)),
          _text('internal_pickup_address',
              'Pickup directions / landmarks (private)',
              required: true, multiline: true),
          _text('pickup_instructions', 'Pickup instructions (optional)',
              multiline: true),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Omoterra can collect from this location'),
              value: _canCollect,
              onChanged: (v) => setState(() => _canCollect = v)),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Supplier can arrange transport'),
              value: _canTransport,
              onChanged: (v) => setState(() => _canTransport = v)),
          _select(
              'Preferred contact',
              _contact,
              const ['phone', 'whatsapp', 'sms'],
              (v) => setState(() => _contact = v!)),
          Wrap(
              spacing: 8,
              children: ['live', 'dressed', 'chilled', 'frozen']
                  .map((form) => FilterChip(
                      label: Text(label(form)),
                      selected: _forms.contains(form),
                      onSelected: (yes) => setState(
                          () => yes ? _forms.add(form) : _forms.remove(form))))
                  .toList()),
          _text('operating_notes', 'Operating schedule or notes (optional)',
              multiline: true),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Do you have livestock or stock currently in production?',
              style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_hasCurrent
                  ? 'Yes, add the current batch'
                  : 'No current batch'),
              value: _hasCurrent,
              onChanged: (v) => setState(() => _hasCurrent = v)),
          if (_hasCurrent)
            _batchForm(
                'current',
                _currentCategory,
                (v) => setState(() => _currentCategory = v!),
                _currentForm,
                (v) => setState(() => _currentForm = v!),
                _currentAgeUnit,
                (v) => setState(() => _currentAgeUnit = v!),
                _currentPhotos,
                (v) => setState(() => _currentPhotos
                  ..clear()
                  ..addAll(v))),
          const Divider(height: 30),
          Text('Next planned production',
              style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add a planned batch too'),
              value: _hasFuture,
              onChanged: (v) => setState(() => _hasFuture = v)),
          if (_hasFuture)
            _batchForm(
                'future',
                _futureCategory,
                (v) => setState(() => _futureCategory = v!),
                _futureForm,
                (v) => setState(() => _futureForm = v!),
                _futureAgeUnit,
                (v) => setState(() => _futureAgeUnit = v!),
                _futurePhotos,
                (v) => setState(() => _futurePhotos
                  ..clear()
                  ..addAll(v))),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Add farm and location photos for Omoterra staff to review.'),
          const SizedBox(height: 16),
          const Text('Farm / location photos'),
          PhotoPicker(
              photos: _evidencePhotos,
              onChanged: (v) => setState(() => _evidencePhotos
                ..clear()
                ..addAll(v)))
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _summary('Farm / supplier', _c('public_alias').text),
          _summary('Legal name', _c('legal_name').text),
          _summary('Contact', user?.phone ?? ''),
          _summary('Location', '${_c('district').text}, ${_c('region').text}'),
          _summary('Supply categories', _selected.map(label).join(', ')),
          _summary(
              'Typical cycle',
              _c('production_frequency').text.isEmpty
                  ? 'Not provided'
                  : _c('production_frequency').text),
          _summary('Farm location', _farm?.label ?? ''),
          _summary('Pickup', _c('internal_pickup_address').text),
          _summary('Omoterra collection',
              _canCollect ? 'Available' : 'Not available'),
          _summary(
              'Current production',
              _hasCurrent
                  ? '${_c('current_quantity').text} ${_unit(_currentCategory)} · ready ${_c('current_ready_date').text}'
                  : 'No current batch'),
          _summary(
              'Next planned production',
              _hasFuture
                  ? '${_c('future_quantity').text} ${_unit(_futureCategory)} · ready ${_c('future_ready_date').text}'
                  : 'Not provided'),
          const SizedBox(height: 12),
          const Text(
              'Registration will be reviewed by Omoterra before supply is shown to buyers.'),
        ]);
    }
  }

  Widget _summary(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(
            width: 145,
            child:
                Text(title, style: const TextStyle(color: OColors.secondary))),
        Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(fontWeight: FontWeight.w600)))
      ]));

  bool _validStep() {
    if ((_step == 0 || _step == 2) &&
        !(_form.currentState?.validate() ?? false)) {
      return false;
    }
    if (_step == 1 && _selected.isEmpty) {
      setState(() => _error = 'Choose at least one supply category.');
      return false;
    }
    if (_step == 1) {
      for (final c in _selected) {
        final value = double.tryParse(_c('capacity_$c').text);
        if (value != null && value < 0) {
          setState(() => _error = 'Production capacity cannot be negative.');
          return false;
        }
      }
    }
    if (_step == 2 && _farm == null) {
      setState(() => _error =
          'Add the farm location: paste a Google Maps link or pick it on the map.');
      return false;
    }
    if (_step == 2 && _forms.isEmpty) {
      setState(() => _error = 'Choose at least one supply form.');
      return false;
    }
    if (_step == 3) {
      for (final prefix in [
        _hasCurrent ? 'current' : null,
        _hasFuture ? 'future' : null
      ].whereType<String>()) {
        final qty = double.tryParse(_c('${prefix}_quantity').text);
        if (qty == null || qty <= 0) {
          setState(() =>
              _error = 'Enter a quantity greater than zero for each batch.');
          return false;
        }
        final low = double.tryParse(_c('${prefix}_min_weight').text),
            high = double.tryParse(_c('${prefix}_max_weight').text);
        if (low != null && high != null && high < low) {
          setState(() =>
              _error = 'Expected maximum weight must be at least the minimum.');
          return false;
        }
        if (_c('${prefix}_ready_date').text.isEmpty) {
          setState(() => _error = 'Choose an expected ready date.');
          return false;
        }
        final price = double.tryParse(_c('${prefix}_asking_price').text);
        if (price == null || price <= 0) {
          setState(() => _error = 'Enter an asking price greater than zero.');
          return false;
        }
      }
    }
    setState(() => _error = null);
    return true;
  }

  Map<String, dynamic> _batch(
          String prefix, String category, String form, String ageUnit) =>
      {
        'category': category,
        'subtype': _c('${prefix}_subtype').text.trim(),
        'initial_quantity': _c('${prefix}_quantity').text.trim(),
        'current_age': _c('${prefix}_age').text.trim().isEmpty
            ? null
            : _c('${prefix}_age').text.trim(),
        'age_unit': ageUnit,
        'expected_ready_date': _c('${prefix}_ready_date').text,
        'expected_min_weight_kg': _c('${prefix}_min_weight').text.trim().isEmpty
            ? null
            : _c('${prefix}_min_weight').text.trim(),
        'expected_max_weight_kg': _c('${prefix}_max_weight').text.trim().isEmpty
            ? null
            : _c('${prefix}_max_weight').text.trim(),
        'form': form,
        'asking_price_per_unit': _c('${prefix}_asking_price').text.trim(),
        'region': _c('region').text.trim(),
        'private_pickup_location': _c('internal_pickup_address').text.trim(),
        'photos': prefix == 'current' ? _currentPhotos : _futurePhotos,
      };
  Future<void> _submit() async {
    if (!_validStep()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final production = <String, dynamic>{};
      for (final category in _selected) {
        final capacity = _c('capacity_$category').text.trim();
        if (capacity.isNotEmpty) {
          production[category] = {
            'capacity': capacity,
            'unit': _unit(category),
            'frequency': _c('production_frequency').text.trim()
          };
        }
      }
      final payload = <String, dynamic>{
        'name': _c('legal_name').text.trim(),
        'public_alias': _c('public_alias').text.trim(),
        'legal_name': _c('legal_name').text.trim(),
        'alternate_phone': _c('alternate_phone').text.trim(),
        'region': _c('region').text.trim(),
        'district': _c('district').text.trim(),
        'general_area': _c('general_area').text.trim(),
        'categories': _selected.toList(),
        'primary_category': _primary,
        'production_profile': production,
        'evidence_photos': _evidencePhotos,
        'production_frequency': _c('production_frequency').text.trim(),
        'internal_pickup_address': _c('internal_pickup_address').text.trim(),
        'pickup_instructions': _c('pickup_instructions').text.trim(),
        'omoterra_pickup': _canCollect,
        'supplier_transport': _canTransport,
        'supply_forms': _forms.toList(),
        'preferred_contact_method': _contact,
        'operating_notes': _c('operating_notes').text.trim(),
        ...?_farm?.toJson(),
        'current_batch': _hasCurrent
            ? _batch('current', _currentCategory, _currentForm, _currentAgeUnit)
            : null,
        'future_batches': _hasFuture
            ? [_batch('future', _futureCategory, _futureForm, _futureAgeUnit)]
            : <dynamic>[],
      };
      final response = await ref
          .read(repositoryProvider)
          .write('/supplier/onboarding', payload, key: newKey());
      await ref
          .read(sessionProvider.notifier)
          .acceptRegisteredRole(response['user'], 'supplier');
      if (mounted) context.go('/supplier');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: OmoterraAppBar(title: Text(_title)),
      body: SafeArea(
          child: Form(
              key: _form,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    LinearProgressIndicator(
                        value: (_step + 1) / 6,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(4),
                        color: OColors.forest,
                        backgroundColor: OColors.soft),
                    const SizedBox(height: 18),
                    Text('Step ${_step + 1} of 6',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: OColors.secondary)),
                    const SizedBox(height: 8),
                    Text(_title,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 20),
                    _body(),
                    if (_error != null) ErrorState(ApiFailure(_error!)),
                    const SizedBox(height: 20),
                    Row(children: [
                      if (_step > 0)
                        Expanded(
                            child: OutlinedButton(
                                onPressed: _busy ? null : popStep,
                                child: const Text('Back'))),
                      if (_step > 0) const SizedBox(width: 12),
                      Expanded(
                          child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : _step == 5
                                      ? _submit
                                      : () {
                                          if (_validStep()) {
                                            setState(() => _step++);
                                            pushStep(() {
                                              _step--;
                                              _error = null;
                                            });
                                          }
                                        },
                              child: Text(_busy
                                  ? 'Submitting…'
                                  : _step == 5
                                      ? 'Submit registration'
                                      : 'Continue')))
                    ]),
                  ]))));
}
