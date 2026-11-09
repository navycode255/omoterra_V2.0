import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client_id.dart';
import '../../core/api/office_assets.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'asset_providers.dart';
import 'owner_reference.dart';
import 'people_screens.dart'
    show officeErrorText, officeStaffProvider, officeVendorsProvider;

const _conditions = [
  'new',
  'good',
  'needs_maintenance',
  'damaged',
  'under_repair',
  'unusable',
  'disposed',
];

const _newCategory = '\u0000new';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? _blankToNull(String text) {
  final t = text.trim();
  return t.isEmpty ? null : t;
}

int? _wholeNumber(String text) => int.tryParse(text.trim());

/// A write error as a sentence: a refusal of the register, else the office text.
String _errorText(Strings s, Object error) =>
    error is AssetError ? s.assetError(error) : officeErrorText(s, error);

void _toast(ScaffoldMessengerState messenger, String text) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Active sellers and staff at a kituo (all of them when the location has
/// no kituo, such as a kitchen). Staff with no kituo are business-wide.
/// Value `vendor:<id>` or `staff:<id>`.
List<MNSelectOption<String>> _peopleOptions(WidgetRef ref, String? stationId) {
  final vendors = ref.watch(officeVendorsProvider).valueOrNull ?? const [];
  final staff = ref.watch(officeStaffProvider).valueOrNull ?? const [];
  return [
    for (final v in vendors)
      if (!v.left &&
          !v.suspended &&
          (stationId == null || v.stationId == stationId))
        MNSelectOption(value: 'vendor:${v.id}', label: v.name),
    for (final p in staff)
      if (!p.left &&
          !p.suspended &&
          (stationId == null ||
              p.stationIds.isEmpty ||
              p.stationIds.contains(stationId)))
        MNSelectOption(value: 'staff:${p.id}', label: p.name),
  ];
}

AssetPerson? _person(String? key) {
  if (key == null) return null;
  final cut = key.indexOf(':');
  return cut < 0
      ? null
      : AssetPerson(kind: key.substring(0, cut), id: key.substring(cut + 1));
}

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

/// A date field opening the themed date sheet.
class _DateField extends ConsumerWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final bool future;
  final bool enabled;
  const _DateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onPicked,
      this.future = false,
      this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return MNFieldButton(
        label: label,
        text: value == null ? null : s.date(value!),
        placeholder: s.selectPlaceholder,
        icon: MNIconData.calendar,
        onTap: !enabled
            ? null
            : () async {
                final today = businessDate(ref.read(clockProvider)());
                final picked = await showMNDateSheet(context,
                    title: label,
                    initial: value ?? today,
                    first: DateTime.utc(2000),
                    last:
                        future ? today.add(const Duration(days: 365)) : today);
                if (picked != null) {
                  onPicked(DateTime.utc(picked.year, picked.month, picked.day));
                }
              });
  }
}

MNTextField _moneyField(
        {Key? key,
        required String label,
        required TextEditingController controller,
        required VoidCallback changed,
        bool enabled = true}) =>
    MNTextField(
        key: key,
        label: label,
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        onChanged: (_) => changed(),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10)
        ]);

// Registration ---------------------------------------------------------------------------

/// One item card's values.
class _ItemForm {
  final name = TextEditingController();
  final unit = TextEditingController();
  final area = TextEditingController();
  final notes = TextEditingController();
  final price = TextEditingController();
  final originalPrice = TextEditingController();
  final numbers = <TextEditingController>[];
  String? categoryId, locationId, custodian;
  String tracking = 'counted';
  String condition = 'good';
  int quantity = 1;
  DateTime? originalDate;

  /// Number fields only grow; the draft uses the first [quantity].
  void ensureNumbers() {
    while (numbers.length < quantity) {
      numbers.add(TextEditingController());
    }
  }

  void dispose() {
    for (final c in [
      name,
      unit,
      area,
      notes,
      price,
      originalPrice,
      ...numbers
    ]) {
      c.dispose();
    }
  }
}

/// "Sajili mali": the owner registers one or many assets in one save.
class OfficeAssetRegisterScreen extends ConsumerStatefulWidget {
  const OfficeAssetRegisterScreen({super.key});
  @override
  ConsumerState<OfficeAssetRegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<OfficeAssetRegisterScreen> {
  /// One id for this opening of the screen, kept across retries.
  final _clientId = newClientId();
  final _items = <_ItemForm>[_ItemForm()];
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _opening = false, _busy = false;
  DateTime? _purchaseDate, _inService;
  String? _error;

  /// Categories made on this screen, in case the list has not reloaded yet.
  final _made = <AssetCategory>[];

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _supplier.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _error = null);

  num? _price(_ItemForm i) =>
      i.price.text.trim().isEmpty ? null : _wholeNumber(i.price.text);

  bool get _ready {
    if (!_opening && _purchaseDate == null) return false;
    for (final i in _items) {
      if (i.name.text.trim().isEmpty ||
          i.unit.text.trim().isEmpty ||
          i.categoryId == null ||
          i.locationId == null) {
        return false;
      }
      if (!_opening && _price(i) == null) return false;
    }
    return true;
  }

  num get _total {
    num sum = 0;
    for (final i in _items) {
      sum += i.quantity * (_price(i) ?? 0);
    }
    return sum;
  }

  AssetDraft _draft() => AssetDraft(
          clientId: _clientId,
          opening: _opening,
          purchaseDate:
              _opening || _purchaseDate == null ? null : _iso(_purchaseDate!),
          supplier: _blankToNull(_supplier.text),
          reference: _blankToNull(_reference.text),
          inServiceDate: _inService == null ? null : _iso(_inService!),
          notes: _blankToNull(_notes.text),
          items: [
            for (final i in _items)
              AssetDraftItem(
                  name: i.name.text.trim(),
                  categoryId: i.categoryId!,
                  unit: i.unit.text.trim(),
                  tracking: i.tracking,
                  quantity: i.quantity,
                  locationId: i.locationId!,
                  unitPrice: _price(i),
                  originalUnitPrice: _opening && i.originalPrice.text.isNotEmpty
                      ? _wholeNumber(i.originalPrice.text)
                      : null,
                  originalPurchaseDate: _opening && i.originalDate != null
                      ? _iso(i.originalDate!)
                      : null,
                  area: _blankToNull(i.area.text),
                  condition: i.condition,
                  notes: _blankToNull(i.notes.text),
                  numbers: i.tracking == 'numbered'
                      ? [
                          for (final c in i.numbers.take(i.quantity))
                            if (c.text.trim().isNotEmpty) c.text.trim()
                        ]
                      : const [],
                  custodianVendorId: _person(i.custodian)?.kind == 'vendor'
                      ? _person(i.custodian)!.id
                      : null,
                  custodianStaffId: _person(i.custodian)?.kind == 'staff'
                      ? _person(i.custodian)!.id
                      : null)
          ]);

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = _draft();
      await officeAssetCall(ref.read(officeSessionProvider.notifier),
          (repo) => repo.registerAssets(draft));
      ref.invalidate(officeAssetsProvider);
      ref.invalidate(officeAssetCategoriesProvider);
      _toast(messenger, s.assetRegistered);
      if (mounted) context.go(MNRoutes.officeAssets);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _newCategorySheet() async {
    final made = await showMNSheet<AssetCategory>(context,
        builder: (_) => const _CategorySheet());
    if (made == null) return null;
    ref.invalidate(officeAssetCategoriesProvider);
    setState(() => _made.add(made));
    return made.id;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final locations = <AssetLocation>[
      for (final l in ref.watch(officeAssetLocationsProvider).valueOrNull ??
          const <AssetLocation>[])
        if (!l.deleted) l
    ];
    final loaded =
        ref.watch(officeAssetCategoriesProvider).valueOrNull ?? const [];
    final categories = [
      ...loaded,
      for (final m in _made)
        if (!loaded.any((c) => c.id == m.id)) m
    ];
    if (locations.length == 1) {
      for (final i in _items) {
        i.locationId ??= locations.first.id;
      }
    }
    final busy = _busy;
    return OwnerPage(
        title: s.assetRegister,
        strings: s,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OwnerCard(
                      child: Padding(
                          padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _mode(s, false, s.assetNewPurchase),
                                _gap(context, 8),
                                _mode(s, true, s.assetOldItems),
                                _gap(context),
                                if (!_opening) ...[
                                  _DateField(
                                      key: const Key('pdate'),
                                      label: s.assetPurchaseDate,
                                      value: _purchaseDate,
                                      enabled: !busy,
                                      onPicked: (d) => setState(() {
                                            _purchaseDate = d;
                                            _error = null;
                                          })),
                                  _gap(context),
                                ],
                                MNTextField(
                                    key: const Key('supplier'),
                                    label: s.assetSupplier,
                                    controller: _supplier,
                                    enabled: !busy),
                                _gap(context),
                                MNTextField(
                                    key: const Key('reference'),
                                    label: s.assetReference,
                                    controller: _reference,
                                    enabled: !busy),
                                _gap(context),
                                _DateField(
                                    key: const Key('inservice'),
                                    label: s.assetInService,
                                    value: _inService,
                                    future: true,
                                    enabled: !busy,
                                    onPicked: (d) =>
                                        setState(() => _inService = d)),
                                _gap(context),
                                MNTextField(
                                    key: const Key('pnotes'),
                                    label: s.assetNotes,
                                    controller: _notes,
                                    maxLines: 2,
                                    enabled: !busy),
                              ]))),
                  for (final (n, item) in _items.indexed) ...[
                    _gap(context),
                    KeyedSubtree(
                        key: ObjectKey(item),
                        child: _itemCard(s, n, item, categories, locations)),
                  ],
                  _gap(context),
                  MNButton.secondary(s.assetAddItem,
                      onPressed: busy
                          ? null
                          : () => setState(() => _items.add(_ItemForm()))),
                  if (!_opening) ...[
                    _gap(context),
                    Padding(
                        padding:
                            EdgeInsets.only(left: OwnerStyle.px(context, 8)),
                        child: Text(
                            '${s.assetTotalCost}: ${s.ownerCurrency} ${groupDigits(_total.round())}',
                            key: const Key('total'),
                            style: OwnerStyle.text(context, 17, weight: 700))),
                  ],
                  if (_error != null) ...[
                    _gap(context),
                    MNNote(_error!, error: true),
                  ],
                  _gap(context),
                  MNButton(s.assetSaveRegister,
                      key: const Key('save'),
                      busy: busy,
                      onPressed: _ready && !busy ? _save : null),
                ])));
  }

  Widget _mode(Strings s, bool opening, String label) {
    void pick() => setState(() {
          _opening = opening;
          _error = null;
        });
    final onPressed = _busy ? null : pick;
    return _opening == opening
        ? MNButton(label, onPressed: onPressed)
        : MNButton.secondary(label, onPressed: onPressed);
  }

  Widget _itemCard(Strings s, int n, _ItemForm item,
      List<AssetCategory> categories, List<AssetLocation> locations) {
    final busy = _busy;
    final numbered = item.tracking == 'numbered';
    if (numbered) item.ensureNumbers();
    AssetLocation? place;
    for (final l in locations) {
      if (l.id == item.locationId) place = l;
    }
    final people = _peopleOptions(ref, place?.stationId);
    if (item.custodian != null &&
        !people.any((o) => o.value == item.custodian)) {
      item.custodian = null;
    }
    final k = 'i$n';
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                      header: true,
                      child: Text(s.assetItemTitle(n + 1),
                          style: OwnerStyle.text(context, 17, weight: 700))),
                  _gap(context),
                  MNTextField(
                      key: Key('$k-name'),
                      label: s.assetItemName,
                      controller: item.name,
                      enabled: !busy,
                      onChanged: (_) => _changed()),
                  _gap(context),
                  MNSelectField<String>(
                      key: Key('$k-cat'),
                      label: s.assetCategory,
                      value: item.categoryId,
                      options: [
                        for (final c in categories)
                          MNSelectOption(value: c.id, label: c.name),
                        MNSelectOption(
                            value: _newCategory,
                            label: s.assetAddCategory,
                            action: true),
                      ],
                      onChanged: busy
                          ? null
                          : (v) async {
                              if (v != _newCategory) {
                                setState(() {
                                  item.categoryId = v;
                                  _error = null;
                                });
                                return;
                              }
                              final id = await _newCategorySheet();
                              if (id != null && mounted) {
                                setState(() => item.categoryId = id);
                              }
                            }),
                  _gap(context),
                  MNTextField(
                      key: Key('$k-unit'),
                      label: s.assetUnit,
                      controller: item.unit,
                      enabled: !busy,
                      onChanged: (_) => _changed()),
                  _gap(context),
                  MNSelectField<String>(
                      key: Key('$k-track'),
                      label: s.assetTracking,
                      value: item.tracking,
                      options: [
                        MNSelectOption(value: 'counted', label: s.assetCounted),
                        MNSelectOption(
                            value: 'numbered', label: s.assetNumbered),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => item.tracking = v)),
                  _gap(context),
                  Row(children: [
                    Expanded(
                        child: Text(s.assetQuantity,
                            style: OwnerStyle.text(context, 15))),
                    MNQuantitySelector(
                        key: Key('$k-qty'),
                        value: item.quantity,
                        min: 1,
                        itemLabel: '${s.assetQuantity} ${n + 1}',
                        onChanged: (v) => setState(() {
                              item.quantity = v;
                              _error = null;
                            })),
                  ]),
                  _gap(context),
                  _moneyField(
                      key: Key('$k-price'),
                      label:
                          _opening ? s.assetOpeningUnitValue : s.assetUnitPrice,
                      controller: item.price,
                      enabled: !busy,
                      changed: _changed),
                  if (_opening) ...[
                    _gap(context),
                    _moneyField(
                        key: Key('$k-oprice'),
                        label: s.assetOriginalPrice,
                        controller: item.originalPrice,
                        enabled: !busy,
                        changed: _changed),
                    _gap(context),
                    _DateField(
                        key: Key('$k-odate'),
                        label: s.assetOriginalDate,
                        value: item.originalDate,
                        enabled: !busy,
                        onPicked: (d) => setState(() => item.originalDate = d)),
                  ],
                  _gap(context),
                  MNSelectField<String>(
                      key: Key('$k-loc'),
                      label: s.assetLocation,
                      value: item.locationId,
                      options: [
                        for (final l in locations)
                          MNSelectOption(value: l.id, label: l.name),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                                item.locationId = v;
                                _error = null;
                              })),
                  _gap(context),
                  MNTextField(
                      key: Key('$k-area'),
                      label: s.assetArea,
                      controller: item.area,
                      enabled: !busy),
                  _gap(context),
                  MNSelectField<String>(
                      key: Key('$k-cond'),
                      label: s.assetCondition,
                      value: item.condition,
                      options: [
                        for (final c in _conditions)
                          MNSelectOption(value: c, label: s.conditionLabel(c)),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => item.condition = v)),
                  _gap(context),
                  MNSelectField<String>(
                      key: Key('$k-cust'),
                      label: s.assetCustodian,
                      value: item.custodian ?? '',
                      options: [
                        MNSelectOption(value: '', label: s.assetNoCustodian),
                        ...people,
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(
                              () => item.custodian = v.isEmpty ? null : v)),
                  _gap(context),
                  MNTextField(
                      key: Key('$k-notes'),
                      label: s.assetNotes,
                      controller: item.notes,
                      maxLines: 2,
                      enabled: !busy),
                  if (numbered) ...[
                    _gap(context),
                    Semantics(
                        header: true,
                        child: Text(s.assetNumbersLabel,
                            style: OwnerStyle.text(context, 15, weight: 600))),
                    Text(s.assetNumbersHint,
                        style: OwnerStyle.text(context, 12.5,
                            color: OwnerStyle.muted)),
                    for (var q = 0; q < item.quantity; q++) ...[
                      _gap(context, 8),
                      MNTextField(
                          key: Key('$k-num$q'),
                          label: s.assetNumberN(q + 1),
                          controller: item.numbers[q],
                          enabled: !busy),
                    ],
                  ],
                  if (_items.length > 1) ...[
                    _gap(context),
                    MNButton.secondary(s.assetRemoveItem,
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  _items.remove(item);
                                  // The controllers go once the card is gone.
                                  WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => item.dispose());
                                })),
                  ],
                ])));
  }
}

/// Name sheet for a new category; pops the category the server made.
class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet();
  @override
  ConsumerState<_CategorySheet> createState() => _CategoryState();
}

class _CategoryState extends ConsumerState<_CategorySheet> {
  final _clientId = newClientId();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      final made = await officeAssetCall(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.createAssetCategory(name, clientId: _clientId));
      if (mounted) Navigator.of(context).pop(made);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.assetAddCategory, children: [
      MNTextField(
          key: const Key('category-name'),
          label: s.assetCategoryName,
          controller: _name,
          enabled: !_busy,
          onChanged: (_) => setState(() => _error = null)),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.assetChangeSave,
          key: const Key('category-save'),
          busy: _busy,
          onPressed: _name.text.trim().isEmpty || _busy ? null : _save),
    ]);
  }
}

// Sheets -----------------------------------------------------------------------------------

/// Shared frame of the three asset sheets: runs [work], closes on success.
mixin _SheetSave<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? error;

  Future<void> run(Future<Object?> Function() work, Asset asset) async {
    final s = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
      ref.invalidate(officeAssetProvider(asset.id));
      ref.invalidate(officeAssetsProvider);
      ref.invalidate(officeAssetCategoriesProvider);
      _toast(messenger, s.settingSaved);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = _errorText(s, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// "Badilisha": quantity, condition, area, custodian or location correction.
Future<void> showAssetChangeSheet(
        BuildContext context, WidgetRef ref, Asset asset) =>
    showMNSheet<void>(context, builder: (_) => _ChangeSheet(asset: asset));

class _ChangeSheet extends ConsumerStatefulWidget {
  final Asset asset;
  const _ChangeSheet({required this.asset});
  @override
  ConsumerState<_ChangeSheet> createState() => _ChangeState();
}

class _ChangeState extends ConsumerState<_ChangeSheet> with _SheetSave {
  /// One id for this opening of the sheet, kept across retries.
  final _clientId = newClientId();
  final _reason = TextEditingController();
  late final _area = TextEditingController(text: widget.asset.area ?? '');
  late String _kind =
      widget.asset.tracking == 'numbered' ? 'condition' : 'quantity';
  late int _quantity = widget.asset.quantity < 1 ? 1 : widget.asset.quantity;
  late String _condition = widget.asset.condition;
  late String _location = widget.asset.location.id;
  String? _custodian;

  @override
  void dispose() {
    _reason.dispose();
    _area.dispose();
    super.dispose();
  }

  bool get _valid => switch (_kind) {
        'quantity' => _quantity != widget.asset.quantity,
        'condition' => _condition != widget.asset.condition,
        'area' => _area.text.trim().isNotEmpty &&
            _area.text.trim() != (widget.asset.area ?? ''),
        'custodian' => _custodian != null,
        'location' => _location != widget.asset.location.id,
        _ => false,
      };

  Future<void> _save() => run(
      () => officeAssetCall(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.changeAsset(widget.asset.id,
              clientId: _clientId,
              change: _kind,
              reason: _reason.text.trim(),
              quantity: _kind == 'quantity' ? _quantity : null,
              condition: _kind == 'condition' ? _condition : null,
              area: _kind == 'area' ? _area.text.trim() : null,
              custodian: _kind == 'custodian' ? _person(_custodian) : null,
              locationId: _kind == 'location' ? _location : null)),
      widget.asset);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final a = widget.asset;
    final locations = <AssetLocation>[
      for (final l in ref.watch(officeAssetLocationsProvider).valueOrNull ??
          const <AssetLocation>[])
        if (!l.deleted) l
    ];
    final people = _peopleOptions(ref, a.location.stationId);
    final ready = _valid && _reason.text.trim().isNotEmpty && !busy;
    return MNSheet(title: s.assetChange, children: [
      MNSelectField<String>(
          key: const Key('change-kind'),
          label: s.assetChangeWhat,
          value: _kind,
          options: [
            if (a.tracking != 'numbered')
              MNSelectOption(value: 'quantity', label: s.assetQuantity),
            MNSelectOption(value: 'condition', label: s.assetCondition),
            MNSelectOption(value: 'area', label: s.assetArea),
            MNSelectOption(value: 'custodian', label: s.assetCustodian),
            MNSelectOption(value: 'location', label: s.assetFixLocation),
          ],
          onChanged: busy ? null : (v) => setState(() => _kind = v)),
      if (_kind == 'quantity')
        Row(children: [
          Expanded(
              child:
                  Text(s.assetQuantity, style: OwnerStyle.text(context, 15))),
          MNQuantitySelector(
              key: const Key('change-qty'),
              value: _quantity,
              min: 1,
              itemLabel: s.assetQuantity,
              onChanged: (v) => setState(() => _quantity = v)),
        ]),
      if (_kind == 'condition')
        MNSelectField<String>(
            key: const Key('change-condition'),
            label: s.assetCondition,
            value: _condition,
            options: [
              for (final c in _conditions)
                MNSelectOption(value: c, label: s.conditionLabel(c)),
            ],
            onChanged: busy ? null : (v) => setState(() => _condition = v)),
      if (_kind == 'area')
        MNTextField(
            key: const Key('change-area'),
            label: s.assetArea,
            controller: _area,
            enabled: !busy,
            onChanged: (_) => setState(() {})),
      if (_kind == 'custodian')
        MNSelectField<String>(
            key: const Key('change-custodian'),
            label: s.assetCustodian,
            value: _custodian,
            options: people,
            onChanged: busy ? null : (v) => setState(() => _custodian = v)),
      if (_kind == 'location')
        MNSelectField<String>(
            key: const Key('change-location'),
            label: s.assetLocation,
            value: _location,
            options: [
              for (final l in locations)
                MNSelectOption(value: l.id, label: l.name),
            ],
            onChanged: busy ? null : (v) => setState(() => _location = v)),
      MNTextField(
          key: const Key('change-reason'),
          label: s.assetReason,
          controller: _reason,
          enabled: !busy,
          maxLines: 2,
          onChanged: (_) => setState(() => error = null)),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.assetChangeSave, busy: busy, onPressed: ready ? _save : null),
    ]);
  }
}

/// "Ongeza manunuzi": another purchase of a counted asset.
Future<void> showAssetPurchaseSheet(
        BuildContext context, WidgetRef ref, Asset asset) =>
    showMNSheet<void>(context, builder: (_) => _PurchaseSheet(asset: asset));

class _PurchaseSheet extends ConsumerStatefulWidget {
  final Asset asset;
  const _PurchaseSheet({required this.asset});
  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseState();
}

class _PurchaseState extends ConsumerState<_PurchaseSheet> with _SheetSave {
  final _clientId = newClientId();
  final _price = TextEditingController();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  int _quantity = 1;
  DateTime? _date, _inService;

  @override
  void dispose() {
    _price.dispose();
    _supplier.dispose();
    _reference.dispose();
    super.dispose();
  }

  int? get _priceValue => _wholeNumber(_price.text);

  Future<void> _save() => run(
      () => officeAssetCall(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.addAssetPurchase(widget.asset.id,
              clientId: _clientId,
              quantity: _quantity,
              unitPrice: _priceValue!,
              purchaseDate: _iso(_date!),
              supplier: _blankToNull(_supplier.text),
              reference: _blankToNull(_reference.text),
              inServiceDate: _inService == null ? null : _iso(_inService!))),
      widget.asset);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final ready = _priceValue != null && _date != null && !busy;
    return MNSheet(title: s.assetAddPurchase, children: [
      Row(children: [
        Expanded(
            child: Text(s.assetQuantity, style: OwnerStyle.text(context, 15))),
        MNQuantitySelector(
            key: const Key('purchase-qty'),
            value: _quantity,
            min: 1,
            itemLabel: s.assetQuantity,
            onChanged: (v) => setState(() => _quantity = v)),
      ]),
      _moneyField(
          key: const Key('purchase-price'),
          label: s.assetUnitPrice,
          controller: _price,
          enabled: !busy,
          changed: () => setState(() => error = null)),
      _DateField(
          key: const Key('purchase-date'),
          label: s.assetPurchaseDate,
          value: _date,
          enabled: !busy,
          onPicked: (d) => setState(() => _date = d)),
      MNTextField(
          key: const Key('purchase-supplier'),
          label: s.assetSupplier,
          controller: _supplier,
          enabled: !busy),
      MNTextField(
          key: const Key('purchase-reference'),
          label: s.assetReference,
          controller: _reference,
          enabled: !busy),
      _DateField(
          key: const Key('purchase-service'),
          label: s.assetInService,
          value: _inService,
          future: true,
          enabled: !busy,
          onPicked: (d) => setState(() => _inService = d)),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.assetChangeSave, busy: busy, onPressed: ready ? _save : null),
    ]);
  }
}

/// "Rekebisha maelezo": name, category and notes, with a reason.
Future<void> showAssetDetailsSheet(
        BuildContext context, WidgetRef ref, Asset asset) =>
    showMNSheet<void>(context, builder: (_) => _DetailsSheet(asset: asset));

class _DetailsSheet extends ConsumerStatefulWidget {
  final Asset asset;
  const _DetailsSheet({required this.asset});
  @override
  ConsumerState<_DetailsSheet> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_DetailsSheet> with _SheetSave {
  late final _name = TextEditingController(text: widget.asset.name);
  late final _notes = TextEditingController(text: widget.asset.notes ?? '');
  final _reason = TextEditingController();
  late String _categoryId = widget.asset.category.id;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _nameChanged => _name.text.trim() != widget.asset.name;
  bool get _categoryChanged => _categoryId != widget.asset.category.id;
  bool get _notesChanged => _notes.text.trim() != (widget.asset.notes ?? '');

  Future<void> _save() => run(
      () => officeAssetCall(
          ref.read(officeSessionProvider.notifier),
          (repo) => repo.editAssetDetails(widget.asset.id,
              name: _nameChanged ? _name.text.trim() : null,
              categoryId: _categoryChanged ? _categoryId : null,
              notes: _notesChanged ? _notes.text.trim() : null,
              reason: _reason.text.trim())),
      widget.asset);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final loaded =
        ref.watch(officeAssetCategoriesProvider).valueOrNull ?? const [];
    final categories = [
      ...loaded,
      if (!loaded.any((c) => c.id == widget.asset.category.id))
        widget.asset.category
    ];
    final ready = _name.text.trim().isNotEmpty &&
        (_nameChanged || _categoryChanged || _notesChanged) &&
        _reason.text.trim().isNotEmpty &&
        !busy;
    return MNSheet(title: s.assetEditDetails, children: [
      MNTextField(
          key: const Key('details-name'),
          label: s.assetItemName,
          controller: _name,
          enabled: !busy,
          onChanged: (_) => setState(() => error = null)),
      MNSelectField<String>(
          key: const Key('details-category'),
          label: s.assetCategory,
          value: _categoryId,
          options: [
            for (final c in categories)
              MNSelectOption(value: c.id, label: c.name),
          ],
          onChanged: busy ? null : (v) => setState(() => _categoryId = v)),
      MNTextField(
          key: const Key('details-notes'),
          label: s.assetNotes,
          controller: _notes,
          maxLines: 2,
          enabled: !busy,
          onChanged: (_) => setState(() => error = null)),
      MNTextField(
          key: const Key('details-reason'),
          label: s.assetReason,
          controller: _reason,
          maxLines: 2,
          enabled: !busy,
          onChanged: (_) => setState(() => error = null)),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.assetChangeSave, busy: busy, onPressed: ready ? _save : null),
    ]);
  }
}
