import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/back_navigation.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import '../../shared/widgets/photo_picker.dart';

const tanzaniaRegions = [
  'Arusha',
  'Dar es Salaam',
  'Dodoma',
  'Geita',
  'Iringa',
  'Kagera',
  'Katavi',
  'Kigoma',
  'Kilimanjaro',
  'Lindi',
  'Manyara',
  'Mara',
  'Mbeya',
  'Morogoro',
  'Mtwara',
  'Mwanza',
  'Njombe',
  'Pemba North',
  'Pemba South',
  'Pwani',
  'Rukwa',
  'Ruvuma',
  'Shinyanga',
  'Simiyu',
  'Singida',
  'Songwe',
  'Tabora',
  'Tanga',
  'Zanzibar North',
  'Zanzibar South & Central',
  'Zanzibar West',
];
const darDistricts = ['Ilala', 'Kinondoni', 'Temeke', 'Kigamboni', 'Ubungo'];

String unitPlural(String category) => switch (unitFor(category)) {
      'bird' => 'birds',
      'animal' => 'animals',
      'tray' => 'trays',
      _ => 'kg',
    };

/// Request Supply in two steps: what the buyer needs, then delivery.
class RequestSupplyScreen extends ConsumerStatefulWidget {
  /// Editing an existing request: its id and current values.
  final String? editId;
  final Map<String, dynamic>? initial;

  /// A new request started from a search that found nothing: what the buyer
  /// searched for, and the category they had chosen, if any.
  final String? search, category;
  const RequestSupplyScreen(
      {super.key, this.editId, this.initial, this.search, this.category});
  @override
  ConsumerState<RequestSupplyScreen> createState() => _RequestSupplyState();
}

class _RequestSupplyState extends ConsumerState<RequestSupplyScreen>
    with StepBackHistory {
  final _what = GlobalKey<FormState>(), _where = GlobalKey<FormState>();
  final _key = newKey();
  final _fields = <String, TextEditingController>{};
  int step = 0;
  String category = 'broilers', condition = 'live', requirement = 'one_time';
  String frequency = 'weekly';
  final weekdays = <String>{};
  late String region =
      tanzaniaRegions.contains(ref.read(sessionProvider).valueOrNull?.region)
          ? ref.read(sessionProvider).valueOrNull!.region
          : 'Dar es Salaam';
  String district = 'Kinondoni';
  String? photo;
  DateTime? neededBy = DateTime.now().add(const Duration(days: 1));
  bool uploading = false, busy = false;
  Object? error;

  TextEditingController _c(String key, [String initial = '']) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: initial));

  bool get _editing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (categories.contains(widget.category)) category = widget.category!;
    if ((widget.search ?? '').trim().isNotEmpty) {
      _c('subtype', widget.search!.trim());
    }
    final r = widget.initial;
    if (r == null) return;
    String text(String key) {
      final value = r[key];
      if (value == null) return '';
      final number = num.tryParse('$value');
      if (number == null) return '$value';
      return number == number.roundToDouble() ? '${number.round()}' : '$number';
    }

    category = '${r['category'] ?? category}';
    if ('${r['live_dressed_or_cut'] ?? ''}'.isNotEmpty) {
      condition = '${r['live_dressed_or_cut']}';
    }
    requirement = '${r['requirement_type'] ?? requirement}';
    if ('${r['recurrence_frequency'] ?? ''}'.isNotEmpty) {
      frequency = '${r['recurrence_frequency']}';
    }
    weekdays.addAll(List<String>.from(r['preferred_weekdays'] ?? const []));
    _c('quantity', text('quantity'));
    _c('min', text('minimum_weight_kg'));
    _c('max', text('maximum_weight_kg'));
    _c('subtype', '${r['product_subtype'] ?? ''}');
    _c('size', '${r['weight_or_size_requirement'] ?? ''}');
    _c('instructions', '${r['delivery_notes'] ?? ''}');
    _c('notes', '${r['notes'] ?? ''}');
    neededBy = DateTime.tryParse('${r['needed_by_date']}') ?? neededBy;
    final savedRegion = '${r['delivery_region'] ?? ''}';
    if (tanzaniaRegions.contains(savedRegion)) region = savedRegion;
    final area = '${r['delivery_area'] ?? ''}';
    if (region == 'Dar es Salaam' && darDistricts.contains(area)) {
      district = area;
    } else {
      _c('area', area);
    }
    photo = r['reference_photo'] as String?;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _decimal(String key) {
    final text = _c(key).text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _addPhoto() async {
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final url = await pickAndUploadPhoto(ref);
      if (url != null && mounted) setState(() => photo = url);
    } catch (e) {
      if (mounted) {
        setState(() => error =
            e is ApiFailure ? e : ref.read(stringsProvider).photoUploadFailed);
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _next() {
    if (!_what.currentState!.validate()) return;
    setState(() {
      step = 1;
      error = null;
    });
    pushStep(() => step = 0);
  }

  Future<void> _submit() async {
    if (!_where.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final recurring = requirement == 'recurring';
    try {
      final response = await ref.read(repositoryProvider).write(
          _editing ? '/requests/${widget.editId}' : '/requests',
          {
            'category': category,
            'unit_type': unitFor(category),
            'quantity': _c('quantity').text.trim(),
            'minimum_weight_kg': _decimal('min'),
            'maximum_weight_kg': _decimal('max'),
            'product_subtype': _c('subtype').text.trim(),
            'weight_or_size_requirement': _c('size').text.trim(),
            'live_dressed_or_cut': condition,
            'needed_by_date': neededBy!.toIso8601String().split('T').first,
            'delivery_region': region,
            'delivery_area':
                region == 'Dar es Salaam' ? district : _c('area').text.trim(),
            'delivery_notes': _c('instructions').text.trim(),
            'requirement_type': requirement,
            'recurrence_frequency': recurring ? frequency : '',
            'preferred_weekdays': recurring ? weekdays.toList() : <String>[],
            'notes': _c('notes').text.trim(),
            'reference_photo': photo,
          },
          method: _editing ? 'PUT' : 'POST',
          key: _key);
      if (!mounted) return;
      if (_editing) {
        ref.invalidate(resourceProvider('/requests/${widget.editId}'));
        ref.invalidate(resourceProvider('/requests'));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(stringsProvider).requestUpdated)));
        clearSteps();
        context.canPop()
            ? context.pop()
            : context.go('/requests/${widget.editId}');
      } else {
        context.go('/request-submitted/${response['id']}');
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // --- building blocks --------------------------------------------------

  InputDecoration _decoration(String? label,
          {String? hint, Widget? suffix, Widget? prefix}) =>
      InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: suffix,
          prefixIcon: prefix,
          hintStyle: const TextStyle(color: OColors.muted, fontSize: 14.5));

  Widget _text(String key, String? label,
          {String? hint,
          bool numeric = false,
          bool required = false,
          bool multiline = false,
          Widget? suffix,
          String? Function(String)? check}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              key: Key('request_$key'),
              controller: _c(key),
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : multiline
                      ? TextInputType.multiline
                      : TextInputType.text,
              minLines: multiline ? 3 : 1,
              maxLines: multiline ? 4 : 1,
              style: const TextStyle(fontSize: 15),
              decoration: _decoration(label, hint: hint, suffix: suffix),
              validator: (value) {
                final text = (value ?? '').trim();
                if (required && text.isEmpty) return ref.s.fieldRequired;
                return text.isEmpty ? null : check?.call(text);
              }));

  Widget _tag(String text) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F4),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5, color: OColors.secondary)))));

  String? _positive(String text) {
    final value = double.tryParse(text);
    return value == null || value <= 0 ? ref.s.enterNumberAboveZeroWord : null;
  }

  Widget _header() => Stack(clipBehavior: Clip.none, children: [
        if (step == 0)
          const Positioned(
              right: -6,
              top: -16,
              child: LeafSprig(size: 70, angle: .2, color: Color(0xFFE3EFE6))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: BackChevron()),
          const SizedBox(width: 8),
          Expanded(
              child: step == 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(ref.s.requestSupplyTitle,
                              style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: OColors.ink,
                                  letterSpacing: -.4)),
                          const SizedBox(height: 4),
                          Text(
                              _editing
                                  ? ref.s.updateYourRequest
                                  : ref.s.requestSupplyBody,
                              style: const TextStyle(
                                  fontSize: 14, color: OColors.secondary)),
                        ])
                  : Row(children: [
                      Expanded(
                          child: Text(ref.s.requestSupplyTitle,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: OColors.ink))),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(ref.s.stepOf(2, 2),
                                style: const TextStyle(
                                    fontSize: 13, color: OColors.secondary)),
                            const SizedBox(height: 6),
                            Row(children: [
                              for (final done in [false, true])
                                Container(
                                    width: 30,
                                    height: 5,
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                        color: done
                                            ? OColors.forest
                                            : const Color(0xFFDDE8E1),
                                        borderRadius:
                                            BorderRadius.circular(3))),
                            ]),
                          ]),
                    ])),
        ]),
      ]);

  Widget _photoCard() => InkWell(
      onTap: uploading ? null : _addPhoto,
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
          painter: _DashedBorder(),
          child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF6FAF7),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                if (photo != null)
                  ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                          height: 96,
                          child: ProductImage([photo!], height: 96)))
                else
                  Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE3EFE7), shape: BoxShape.circle),
                      child: uploading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera_outlined,
                              color: OColors.forest)),
                const SizedBox(height: 12),
                Text(
                    photo == null
                        ? ref.s.addReferencePhoto
                        : ref.s.changeReferencePhoto,
                    style: const TextStyle(fontSize: 13.5, color: OColors.ink)),
                const SizedBox(height: 3),
                Text(ref.s.referencePhotoHint,
                    style: const TextStyle(
                        fontSize: 12.5, color: OColors.secondary)),
              ]))));

  List<Widget> _whatFields(Strings s) => [
        _photoCard(),
        const SizedBox(height: 18),
        OmoterraDropdown<String>(
            label: s.product,
            value: category,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(s.label(c))))
                .toList(),
            onChanged: (v) => setState(() => category = v!)),
        _text('quantity', s.quantity,
            numeric: true,
            required: true,
            suffix: _tag(s.unit(unitFor(category))),
            check: (text) =>
                _positive(text) ??
                (unitFor(category) != 'kg' && double.parse(text) % 1 != 0
                    ? s.useWholeNumber
                    : null)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _text('min', s.weightRangeKg,
                  numeric: true, suffix: _tag(s.min), check: _positive)),
          const SizedBox(width: 12),
          Expanded(
              child: _text('max', null, numeric: true, suffix: _tag(s.max),
                  check: (text) {
            final low = double.tryParse(_c('min').text.trim());
            final high = double.tryParse(text);
            return _positive(text) ??
                (low != null && high != null && high < low
                    ? s.maxAtLeastMin
                    : null);
          })),
        ]),
        _text('subtype', s.subtypeOptional, hint: s.subtypeHint),
        _text('size', s.sizeNotesOptional, hint: s.sizeNotesHint),
        OmoterraDropdown<String>(
            label: s.condition,
            value: condition,
            items: ['live', 'dressed', 'chilled', 'frozen']
                .map((c) => DropdownMenuItem(value: c, child: Text(s.label(c))))
                .toList(),
            onChanged: (v) => setState(() => condition = v!)),
      ];

  List<Widget> _whereFields(Strings s) => [
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FormField<DateTime>(
                validator: (_) => neededBy == null ? s.chooseDate : null,
                builder: (field) => InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final today = DateTime.now();
                      final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              neededBy ?? today.add(const Duration(days: 1)),
                          firstDate:
                              DateTime(today.year, today.month, today.day),
                          lastDate: today.add(const Duration(days: 730)));
                      if (picked != null) {
                        setState(() => neededBy = picked);
                        field.didChange(picked);
                      }
                    },
                    child: InputDecorator(
                        isEmpty: neededBy == null,
                        decoration: _decoration(s.neededByLabel,
                                hint: s.chooseDate,
                                prefix: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 21,
                                    color: OColors.ink),
                                suffix: neededBy == null
                                    ? null
                                    : IconButton(
                                        tooltip: s.clearDate,
                                        icon: const Icon(Icons.close,
                                            size: 20, color: OColors.secondary),
                                        onPressed: () {
                                          setState(() => neededBy = null);
                                          field.didChange(null);
                                        }))
                            .copyWith(errorText: field.errorText),
                        child: Text(neededBy == null ? '' : s.date(neededBy!),
                            style: const TextStyle(fontSize: 15)))))),
        OmoterraDropdown<String>(
            label: s.deliveryRegion,
            value: region,
            items: tanzaniaRegions
                .map((r) =>
                    DropdownMenuItem(value: r, child: Text(s.regionName(r))))
                .toList(),
            onChanged: (v) => setState(() => region = v!)),
        if (region == 'Dar es Salaam')
          OmoterraDropdown<String>(
              label: s.deliveryAreaLabel,
              value: district,
              items: darDistricts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => district = v!))
        else
          _text('area', s.deliveryAreaLabel,
              required: true,
              hint: s.townOrDistrict,
              check: (text) => text.length < 2 ? s.enterArea : null),
        _text('instructions', s.deliveryInstructionsOptional,
            multiline: true, hint: s.deliveryInstructionsHint),
        OmoterraDropdown<String>(
            label: s.requirementType,
            value: requirement,
            items: [
              for (final value in ['one_time', 'recurring'])
                DropdownMenuItem(value: value, child: Text(s.label(value))),
            ],
            onChanged: (v) => setState(() => requirement = v!)),
        if (requirement == 'recurring') ...[
          OmoterraDropdown<String>(
              label: s.repeat,
              value: frequency,
              items: [
                for (final value in ['weekly', 'monthly'])
                  DropdownMenuItem(value: value, child: Text(s.label(value))),
              ],
              onChanged: (v) => setState(() => frequency = v!)),
          Text(s.preferredDeliveryDays,
              style: const TextStyle(fontSize: 13.5, color: OColors.secondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final day in const [
              'monday',
              'tuesday',
              'wednesday',
              'thursday',
              'friday',
              'saturday',
              'sunday'
            ])
              FilterChip(
                  label: Text(s.label(day)),
                  selected: weekdays.contains(day),
                  onSelected: (on) => setState(
                      () => on ? weekdays.add(day) : weekdays.remove(day))),
          ]),
          const SizedBox(height: 16),
        ],
        _text('notes', s.additionalNotesOptional,
            multiline: true, hint: s.additionalNotesHint),
      ];

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    final recurringIncomplete =
        step == 1 && requirement == 'recurring' && weekdays.isEmpty;
    return Scaffold(
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 28),
                children: [
          _header(),
          const SizedBox(height: 22),
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: step == 0
                  ? Form(
                      key: _what,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _whatFields(s)))
                  : Form(
                      key: _where,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _whereFields(s)))),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ErrorState(error!)),
          if (recurringIncomplete)
            Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(s.chooseOneDeliveryDay,
                    style: const TextStyle(color: OColors.error))),
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: step == 0
                  ? FilledButton(
                      onPressed: _next,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        // Shrinks with big system text rather than overflow.
                        Flexible(
                            child: Text(s.nextDeliveryDetails,
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward, size: 20),
                      ]))
                  : FilledButton(
                      onPressed: busy || recurringIncomplete ? null : _submit,
                      child: Text(busy
                          ? s.saving
                          : _editing
                              ? s.saveChanges
                              : s.submitRequestLower))),
        ])));
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFD8C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
