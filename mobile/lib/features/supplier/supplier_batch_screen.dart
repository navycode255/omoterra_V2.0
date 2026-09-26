import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import '../../core/routing/back_navigation.dart';
import '../buyer/request_supply_screen.dart' show tanzaniaRegions;
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/photo_picker.dart';

/// Register a production batch in three steps, like Request Supply: what is
/// being raised, when it will be ready and at what price, and where Omoterra
/// collects it.
class SupplierBatchScreen extends ConsumerWidget {
  /// Product to start with, e.g. the category of the demand being supplied.
  final String? category;

  /// Opened from a market demand: go back to it once the batch is saved, so
  /// the supplier can make their offer straight away.
  final bool returnToDemand;
  const SupplierBatchScreen(
      {super.key, this.category, this.returnToDemand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      body: SafeArea(
          child: ResourceView('/supplier/profile',
              builder: (profile) => profile == null
                  ? _PickupFirst(
                      onSaved: () =>
                          ref.invalidate(resourceProvider('/supplier/profile')))
                  : _BatchSteps(
                      profile: Map<String, dynamic>.from(profile),
                      category: category,
                      returnToDemand: returnToDemand))));
}

const _liveOnly = ['broilers', 'local_chicken', 'goats', 'cattle'];
const _meatProducts = ['chicken_meat', 'beef', 'goat_meat'];

/// Counted units for a product: birds, animals, trays or kg.
String batchUnits(String category, Strings s) => s.unit(unitFor(category));

/// Header shared by every step: back, title, step count and progress bars.
class _StepHeader extends StatelessWidget {
  final int step, steps;
  final String subtitle;
  const _StepHeader(
      {required this.step, required this.steps, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Stack(clipBehavior: Clip.none, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: BackChevron()),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.registerBatchTitle,
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: OColors.ink,
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 14, color: OColors.secondary)),
        ])),
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(s.stepOf(step + 1, steps),
                  style:
                      const TextStyle(fontSize: 13, color: OColors.secondary)),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 0; i < steps; i++)
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 22,
                      height: 5,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                          color: i <= step
                              ? OColors.forest
                              : const Color(0xFFDDE8E1),
                          borderRadius: BorderRadius.circular(3))),
              ]),
            ])),
      ]),
    ]);
  }
}

class _BatchSteps extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final String? category;
  final bool returnToDemand;
  const _BatchSteps(
      {required this.profile, this.category, required this.returnToDemand});
  @override
  ConsumerState<_BatchSteps> createState() => _BatchStepsState();
}

class _BatchStepsState extends ConsumerState<_BatchSteps> with StepBackHistory {
  List<String> get _titles =>
      [ref.s.batchStepRaising, ref.s.batchStepReady, ref.s.batchStepPickup];
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  final _fields = <String, TextEditingController>{};
  final _key = newKey();
  int step = 0;
  late String category = categories.contains(widget.category)
      ? widget.category!
      : (List<String>.from(widget.profile['categories'] ?? const [])
              .where(categories.contains)
              .firstOrNull ??
          'broilers');
  String form = 'live', ageUnit = 'weeks';
  late String region = tanzaniaRegions.contains(widget.profile['region'])
      ? '${widget.profile['region']}'
      : 'Dar es Salaam';
  final photos = <String>[];
  bool busy = false;
  Object? error;

  bool get _meat => _meatProducts.contains(category);
  bool get _hasWeight => category != 'eggs' && !_meat;

  TextEditingController _c(String key, [String initial = '']) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void initState() {
    super.initState();
    _fitForm();
    _c(
        'ready',
        DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first);
    _c('pickup', '${widget.profile['internal_pickup_address'] ?? ''}');
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Live animals are always live; meat is never live.
  void _fitForm() {
    if (_liveOnly.contains(category)) form = 'live';
    if (_meat && form == 'live') form = 'dressed';
  }

  List<String> get _formOptions => _meat
      ? const ['dressed', 'chilled', 'frozen']
      : const ['live', 'dressed', 'chilled', 'frozen'];

  String? _positive(String text) {
    final n = double.tryParse(text);
    return n == null || !n.isFinite || n <= 0
        ? ref.read(stringsProvider).enterNumberAboveZero
        : null;
  }

  Widget _tag(String text) => Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Text(text,
          style: const TextStyle(fontSize: 13.5, color: OColors.secondary)));

  Widget _text(String key, String? label,
          {bool numeric = false,
          bool required = false,
          bool multiline = false,
          String? hint,
          Widget? suffix,
          String? Function(String)? check}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              key: Key('batch_$key'),
              controller: _c(key),
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : multiline
                      ? TextInputType.multiline
                      : TextInputType.text,
              maxLines: multiline ? 3 : 1,
              decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  suffixIcon: suffix,
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0)),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return required
                      ? ref.read(stringsProvider).fieldRequired
                      : null;
                }
                return check?.call(text);
              }));

  Widget _productCard() => DecorCard(
      padding: EdgeInsets.zero,
      child: Row(children: [
        SizedBox(
            width: 112,
            height: 92,
            child: ProductImage(const [], category: category, height: 92)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ref.s.label(category),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: OColors.ink)),
          const SizedBox(height: 3),
          Text(ref.s.countedIn(batchUnits(category, ref.s)),
              style: const TextStyle(fontSize: 13, color: OColors.secondary)),
        ])),
      ]));

  List<Widget> _step0() => [
        _productCard(),
        const SizedBox(height: 18),
        OmoterraDropdown<String>(
            label: ref.s.product,
            value: category,
            items: categories
                .map((c) =>
                    DropdownMenuItem(value: c, child: Text(ref.s.label(c))))
                .toList(),
            onChanged: (v) => setState(() {
                  category = v!;
                  _fitForm();
                })),
        _text('subtype', ref.s.breedTypeOptional, hint: ref.s.breedHint),
        _text('quantity', ref.s.batchQuantity,
            numeric: true,
            required: true,
            suffix: _tag(batchUnits(category, ref.s)),
            check: (text) =>
                _positive(text) ??
                (!_meat && double.parse(text) % 1 != 0
                    ? ref.s.useWholeNumber
                    : null)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _text('age', ref.s.ageOptional,
                  numeric: true,
                  check: (t) => (double.tryParse(t) ?? -1) < 0
                      ? ref.s.enterZeroOrMore
                      : null)),
          const SizedBox(width: 12),
          Expanded(
              child: OmoterraDropdown<String>(
                  label: ref.s.ageIn,
                  value: ageUnit,
                  items: [
                    for (final unit in ['days', 'weeks', 'months'])
                      DropdownMenuItem(
                          value: unit, child: Text(ref.s.label(unit))),
                  ],
                  onChanged: (v) => setState(() => ageUnit = v!))),
        ]),
        if (!_liveOnly.contains(category))
          OmoterraDropdown<String>(
              label: ref.s.suppliedAs,
              value: form,
              items: _formOptions
                  .map((f) =>
                      DropdownMenuItem(value: f, child: Text(ref.s.label(f))))
                  .toList(),
              onChanged: (v) => setState(() => form = v!)),
      ];

  List<Widget> _step1() => [
        OmoterraDateField(ref.s.expectedReadyDate, _c('ready')),
        if (_hasWeight)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _text('min', ref.s.weightRangeKg,
                    numeric: true, suffix: _tag(ref.s.min), check: _positive)),
            const SizedBox(width: 12),
            Expanded(
                child: _text('max', null,
                    numeric: true, suffix: _tag(ref.s.max), check: (text) {
              final low = double.tryParse(_c('min').text.trim());
              final high = double.tryParse(text);
              return _positive(text) ??
                  (low != null && high != null && high < low
                      ? ref.s.maxAtLeastMin
                      : null);
            })),
          ]),
        _text('price', ref.s.askingPriceOptional,
            numeric: true,
            suffix: _tag('TZS / ${ref.s.unit(unitFor(category), 1)}'),
            check: _positive),
      ];

  List<Widget> _step2() => [
        OmoterraDropdown<String>(
            label: ref.s.regionLabel,
            value: region,
            items: tanzaniaRegions
                .map((r) => DropdownMenuItem(
                    value: r, child: Text(ref.s.regionName(r))))
                .toList(),
            onChanged: (v) => setState(() => region = v!)),
        _text('pickup', ref.s.pickupLocation,
            multiline: true, hint: ref.s.pickupHint),
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              const Icon(Icons.lock_outline,
                  size: 16, color: OColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(ref.s.onlyOmoterraSeesPickup,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: OColors.secondary.withValues(alpha: .9)))),
            ])),
        Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            decoration: BoxDecoration(
                color: const Color(0xFFF6FAF7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCEAE1))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE3EFE7), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera_outlined,
                        size: 20, color: OColors.forest)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(ref.s.batchPhotos,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: OColors.ink)),
                      Text(ref.s.batchPhotosHint,
                          style: const TextStyle(
                              fontSize: 12.5, color: OColors.secondary)),
                    ])),
              ]),
              const SizedBox(height: 10),
              PhotoPicker(
                  photos: photos,
                  onChanged: (v) => setState(() => photos
                    ..clear()
                    ..addAll(v))),
            ])),
        const SizedBox(height: 16),
      ];

  void _next() {
    if (!_forms[step].currentState!.validate()) return;
    setState(() {
      step++;
      error = null;
    });
    pushStep(() => step--);
  }

  String? _optional(String key) {
    final text = _c(key).text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (!_forms[step].currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write(
          '/supplier/batches',
          {
            'category': category,
            'subtype': _c('subtype').text.trim(),
            'initial_quantity': _c('quantity').text.trim(),
            'current_age': _optional('age'),
            'age_unit': ageUnit,
            'expected_ready_date': _c('ready').text,
            'expected_min_weight_kg': _hasWeight ? _optional('min') : null,
            'expected_max_weight_kg': _hasWeight ? _optional('max') : null,
            'form': form,
            'asking_price_per_unit': _optional('price'),
            'region': region,
            'private_pickup_location': _c('pickup').text.trim(),
            'photos': photos,
          },
          key: _key);
      if (!mounted) return;
      ref.invalidate(resourceProvider('/supplier/batches'));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).batchRegistered)));
      clearSteps();
      widget.returnToDemand && context.canPop()
          ? context.pop(true)
          : context.go('/stock');
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
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 28),
        children: [
          _StepHeader(
              step: step, steps: _titles.length, subtitle: _titles[step]),
          const SizedBox(height: 22),
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Form(
                  key: _forms[step],
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: switch (step) {
                        0 => _step0(),
                        1 => _step1(),
                        _ => _step2(),
                      }))),
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
                      child: Text(busy ? s.saving : s.registerBatch))
                  : FilledButton(
                      onPressed: _next,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        // Shrinks with big system text rather than overflow.
                        Flexible(
                            child: Text(s.nextStep(_titles[step + 1]),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward, size: 20),
                      ]))),
          if (step == 0)
            Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                child: Text(s.batchesOfferedNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, color: OColors.secondary))),
        ]);
  }
}

/// Before a first batch: the private pickup details Omoterra needs.
class _PickupFirst extends StatelessWidget {
  final VoidCallback onSaved;
  const _PickupFirst({required this.onSaved});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 28),
        children: [
          _StepHeader(step: 0, steps: 3, subtitle: s.pickupDetailsFirst),
          const SizedBox(height: 22),
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: DataForm(
                  path: '/supplier/profile',
                  method: 'PUT',
                  fields: [
                    FormFieldSpec('legal_name', s.legalName),
                    FormFieldSpec(
                        'internal_pickup_address', s.privatePickupAddress,
                        multiline: true),
                  ],
                  button: s.saveAndContinue,
                  onSuccess: (_) => onSaved())),
        ]);
  }
}

String _batchDate(Object? value, Strings s) {
  final date = DateTime.tryParse('$value');
  return date == null ? s.dateTbc : s.date(date);
}

/// Which filter chip a batch falls under: awaiting review is `pending`,
/// finished or cancelled is `completed`, anything approved and open is `live`.
String batchPhase(Map row) => row['approved_at'] == null
    ? 'pending'
    : ['completed', 'cancelled'].contains(row['status'])
        ? 'completed'
        : 'live';

class SupplierBatchList extends ConsumerWidget {
  /// '' shows every batch; otherwise one [batchPhase].
  final String phase;
  const SupplierBatchList({super.key, this.phase = ''});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return ResourceView('/supplier/batches', builder: (data) {
      final batches =
          (data as List).map((row) => Map<String, dynamic>.from(row)).toList();
      if (batches.isEmpty && phase.isEmpty) {
        return Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F6F3),
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE3EEE7), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const CubeOutlineIcon(
                      size: 17, color: OColors.secondary, stroke: 1.5)),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(s.noBatches,
                      style: const TextStyle(
                          fontSize: 13.5, color: OColors.secondary))),
            ]));
      }
      return Column(children: [
        for (final row in batches)
          if (phase.isEmpty || batchPhase(row) == phase)
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BatchCard(row)),
      ]);
    });
  }
}

/// One batch at a glance: photo with its review state, ready date, weight
/// range and head count. Everything else is one tap away in the details.
class _BatchCard extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _BatchCard(this.row);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    final pending = row['approved_at'] == null;
    final quantity = num.tryParse('${row['current_quantity']}');
    final min = row['expected_min_weight_kg'],
        max = row['expected_max_weight_kg'];
    final canSell = (num.tryParse('${row['available_to_commit']}') ?? 0) > 0;
    const meta = TextStyle(fontSize: 13.5, color: OColors.secondary);
    Widget gap() => Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: OColors.border);
    return DecorCard(
        onTap: () => showBatchDetails(context, row),
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                  width: 98,
                  height: 116,
                  child: Stack(fit: StackFit.expand, children: [
                    ProductImage(List<String>.from(row['photos'] ?? const []),
                        category: '${row['category']}', height: 116),
                    Positioned(
                        left: 7,
                        right: 7,
                        bottom: 8,
                        child: _StatusBadge(
                            pending
                                ? s.pendingReview
                                : s.status('${row['status']}'),
                            pending: pending)),
                  ]))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(s.label('${row['category']}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: OColors.ink))),
                  SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                          tooltip: s.stockActions,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, color: OColors.ink),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          onSelected: (action) => showBatchDetails(context, row,
                              recordSale: action == 'sale'),
                          itemBuilder: (context) => [
                                PopupMenuItem(
                                    value: 'details',
                                    child: Text(s.viewDetails)),
                                if (canSell)
                                  PopupMenuItem(
                                      value: 'sale',
                                      child: Text(s.recordExternalSale)),
                              ])),
                ]),
                const SizedBox(height: 6),
                // Scales down rather than cutting the date or weight short.
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event_note_outlined,
                          size: 17, color: OColors.secondary),
                      const SizedBox(width: 4),
                      Text(_batchDate(row['expected_ready_date'], s),
                          style: meta),
                      if (min != null || max != null) ...[
                        gap(),
                        const Icon(Icons.scale_outlined,
                            size: 17, color: OColors.secondary),
                        const SizedBox(width: 4),
                        Text(s.weightRange('${min ?? '—'}', '${max ?? '—'}'),
                            style: meta),
                      ],
                      gap(),
                      InkResponse(
                          onTap: () => showBatchDetails(context, row),
                          radius: 18,
                          child: Icon(Icons.info_outline,
                              size: 20,
                              color: OColors.forest,
                              semanticLabel: s.batchDetails)),
                    ])),
                const Divider(height: 22, color: Color(0xFFEAEFEC)),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(amount(quantity ?? 0),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: OColors.ink,
                              letterSpacing: -.5)),
                      const SizedBox(width: 7),
                      Text(s.unit(unitFor('${row['category']}'), quantity),
                          style: const TextStyle(
                              fontSize: 15, color: OColors.secondary)),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: OColors.ink),
                    ]),
              ])),
        ]));
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool pending;
  const _StatusBadge(this.label, {required this.pending});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: pending ? const Color(0xFFFFF1D9) : const Color(0xFFE3F0E7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  pending ? const Color(0xFFF0D7A6) : const Color(0xFFCFE4D6))),
      child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: pending ? const Color(0xFF7A4B00) : OColors.forest))));
}

/// Everything the card leaves out: age, reserved and sold figures, and
/// recording a sale made outside Omoterra.
Future<void> showBatchDetails(BuildContext context, Map<String, dynamic> row,
    {bool recordSale = false}) {
  final canSell = (num.tryParse('${row['available_to_commit']}') ?? 0) > 0;
  return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => Consumer(builder: (sheet, ref, _) {
            final s = ref.s;
            const line =
                TextStyle(fontSize: 14.5, height: 1.5, color: OColors.ink);
            return Padding(
                padding: EdgeInsets.fromLTRB(
                    22, 0, 22, 24 + MediaQuery.viewInsetsOf(sheet).bottom),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(s.label('${row['category']}'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(
                          s.batchAgeReady(
                              '${row['current_age'] ?? '—'}',
                              s.label('${row['age_unit']}').toLowerCase(),
                              _batchDate(row['expected_ready_date'], s)),
                          style: line),
                      Text(
                          s.expectedWeight(
                              '${row['expected_min_weight_kg'] ?? '—'}',
                              '${row['expected_max_weight_kg'] ?? '—'}'),
                          style: line),
                      Text(
                          s.reservedAvailableToCommit(
                              amount(row['reserved_quantity']),
                              amount(row['available_to_commit'])),
                          style: line),
                      Text(
                          s.externallySold(
                              amount(row['externally_sold_quantity'])),
                          style: line),
                      if (row['approved_at'] == null)
                        Text(s.awaitingReview,
                            style: const TextStyle(
                                fontSize: 13.5, color: OColors.secondary)),
                      if (canSell)
                        Material(
                            color: Colors.transparent,
                            child: ExpansionTile(
                                initiallyExpanded: recordSale,
                                tilePadding: EdgeInsets.zero,
                                title: Text(s.recordExternalSale),
                                children: [
                                  DataForm(
                                    path:
                                        '/supplier/batches/${row['id']}/external-sales',
                                    fields: [
                                      FormFieldSpec(
                                          'quantity', s.quantitySoldOutside,
                                          numeric: true),
                                      FormFieldSpec('notes', s.noteOptional,
                                          optional: true),
                                    ],
                                    button: s.confirmExternalSale,
                                    onSuccess: (_) {
                                      ref.invalidate(resourceProvider(
                                          '/supplier/batches'));
                                      Navigator.of(sheet).pop();
                                    },
                                  ),
                                ])),
                    ])));
          }));
}
