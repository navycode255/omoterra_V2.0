import 'owner_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/format.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/states.dart';
import '../sales/product_images.dart';
import 'money_screens.dart' show moneySettingsProvider;
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;
import 'removal_sheet.dart';
import 'menu_screens.dart' show MenuImportEntry;

final officeProductsProvider = FutureProvider.autoDispose((ref) =>
    ref.read(officeSessionProvider.notifier).guard((r) => r.products()));
final officeCategoriesProvider = FutureProvider.autoDispose((ref) =>
    ref.read(officeSessionProvider.notifier).guard((r) => r.categories()));

/// Units the business added; loading them also updates [addedUnitsProvider],
/// which names them on every screen.
final officeUnitsProvider = FutureProvider.autoDispose((ref) async {
  final units =
      await ref.read(officeSessionProvider.notifier).guard((r) => r.units());
  ref.read(addedUnitsProvider.notifier).state = {
    for (final u in units) u.code: u
  };
  return units;
});
final officePricesProvider = FutureProvider.autoDispose
    .family<List<OfficeStationPrice>, String>((ref, code) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.productPrices(code)));

// A provider also makes the platform photo picker replaceable in widget tests.
final pickProductPhotoProvider =
    Provider<Future<Uint8List?> Function()>((ref) => () async {
          final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 88,
              requestFullMetadata: false);
          if (file == null) return null;
          if (await file.length() > 5 * 1024 * 1024) {
            throw const FormatException();
          }
          return file.readAsBytes();
        });

class OfficeProductsScreen extends ConsumerWidget {
  const OfficeProductsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Names the units the business added.
    ref.watch(officeUnitsProvider);
    final s = ref.watch(stringsProvider);
    final products = ref.watch(officeProductsProvider);
    final count = products.valueOrNull?.where((p) => p.price == null).length;
    return OwnerPage(
        title: s.manageProducts,
        strings: s,
        onRefresh: () => ref.refresh(officeProductsProvider.future),
        onAdd: () => context.push(MNRoutes.officeNewProduct),
        addLabel: s.ownerAddProduct,
        subtitle: Text(
            count == null
                ? s.ownerUnpriced(0).replaceFirst('0', '—')
                : s.ownerUnpriced(count),
            style: OwnerStyle.text(context, 13, color: OwnerStyle.priceHint)),
        trailingSubtitle: Text(s.ownerPriceColumn,
            style: OwnerStyle.text(context, 13, color: OwnerStyle.priceHint)),
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 11.5)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MenuImportEntry(),
                  const SizedBox(height: 12),
                  OwnerCard(
                      child: OwnerMenuRow(
                          label: s.productCategories,
                          subtitle: s.productCategoriesCaption,
                          onTap: () => showMNSheet<void>(context,
                              builder: (_) => const _CategoriesSheet()))),
                  const SizedBox(height: 16),
                  OwnerAsyncView(
                    value: products,
                    onRetry: () => ref.invalidate(officeProductsProvider),
                    isEmpty: (items) => items.isEmpty,
                    empty: (_) => MNEmptyState(
                        icon: MNIconData.box, title: s.noOfficeProducts),
                    data: (items) => OwnerCard(
                        child: Column(children: [
                      for (final (i, p)
                          in _approvedProductOrder(items).indexed) ...[
                        if (i > 0)
                          Padding(
                              padding: EdgeInsets.only(
                                  left: OwnerStyle.px(context, 73)),
                              child: const Divider(
                                  height: 1,
                                  thickness: .6,
                                  color: OwnerStyle.line)),
                        _ApprovedProductRow(
                            product: p,
                            strings: s,
                            onTap: () async {
                              await context
                                  .push(MNRoutes.officeProduct(p.code));
                              ref.invalidate(officeProductsProvider);
                            }),
                      ],
                    ])),
                  )
                ])));
  }
}

List<OfficeProduct> _approvedProductOrder(List<OfficeProduct> items) =>
    [...items]..sort((a, b) {
        if ((a.price == null) != (b.price == null)) {
          return a.price == null ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

ImageProvider? ownerProductImage(OfficeProduct p) {
  if (p.imageKey?.startsWith('uploads/') ?? false) {
    return productImageFor(p.imageKey);
  }
  final n = p.name.toLowerCase();
  for (final key in [
    'mishkaki',
    'maini',
    'ndizi',
    'firigisi',
    'kidali',
    'mzima',
    'nusu',
    'paja',
    'shingo'
  ]) {
    if (n.contains(key)) return AssetImage('assets/owner/$key.png');
  }
  return productImageFor(p.imageKey);
}

class _ApprovedProductRow extends StatelessWidget {
  final OfficeProduct product;
  final Strings strings;
  final VoidCallback onTap;
  const _ApprovedProductRow(
      {required this.product, required this.strings, required this.onTap});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    final n = product.name.toLowerCase();
    final key = [
      'mishkaki',
      'maini',
      'ndizi',
      'firigisi',
      'kidali',
      'mzima',
      'nusu',
      'paja',
      'shingo'
    ].where(n.contains).firstOrNull;
    const rowHeights = {
      'mishkaki': 66.8,
      'maini': 66.3,
      'ndizi': 67.2,
      'firigisi': 67.2,
      'kidali': 67.7,
      'mzima': 67.2,
      'nusu': 68.6,
      'paja': 67.7,
      'shingo': 70.0
    };
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    return InkWell(
        onTap: onTap,
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: u(rowHeights[key] ?? 67.8)),
            child: Padding(
                padding: EdgeInsets.fromLTRB(u(13), u(6), u(10), u(6)),
                child: Row(children: [
                  Transform.translate(
                      offset: Offset(0, u(key == 'mishkaki' ? 3 : -2.3)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(u(9)),
                          child: SizedBox(
                              width: u(46),
                              height: u(product.name
                                      .toLowerCase()
                                      .contains('mishkaki')
                                  ? 46
                                  : 51),
                              child: MNProductImage(
                                  image: ownerProductImage(product))))),
                  SizedBox(width: u(14)),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(product.name,
                            style:
                                OwnerStyle.text(context, 14.5, spacing: -.5)),
                        Text(
                            strings.ownerProductPortion(
                                product.name, product.unit),
                            style: OwnerStyle.text(context, 11.5,
                                color: OwnerStyle.secondary, spacing: -.3)),
                        if (largeText)
                          Text(
                              product.price == null
                                  ? strings.ownerSetPrice
                                  : groupDigits(product.price!),
                              style: OwnerStyle.text(context, 14,
                                  weight: 500,
                                  color: product.price == null
                                      ? OwnerStyle.missingPrice
                                      : OwnerStyle.ink)),
                      ])),
                  if (!largeText) ...[
                    SizedBox(width: u(8)),
                    Text(
                        product.price == null
                            ? strings.ownerSetPrice
                            : groupDigits(product.price!),
                        style: OwnerStyle.text(
                            context, product.price == null ? 13 : 15.5,
                            weight: 500,
                            color: product.price == null
                                ? OwnerStyle.missingPrice
                                : OwnerStyle.ink)),
                  ],
                  SizedBox(width: u(14)),
                  const OwnerGlyph('chevron', size: 9),
                ]))));
  }
}

class OfficeProductScreen extends ConsumerWidget {
  final String code;
  const OfficeProductScreen({super.key, required this.code});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ref.watch(officeProductsProvider).when(
          data: (items) {
            final product = items.where((p) => p.code == code).firstOrNull;
            if (product != null) {
              return _ProductEditor(key: ValueKey(code), product: product);
            }
            return OwnerPage(
                title: s.productEditTitle,
                strings: s,
                child: MNEmptyState(
                    icon: MNIconData.box, title: s.noOfficeProducts));
          },
          loading: () => OwnerPage(
              title: s.productEditTitle,
              strings: s,
              child: const Center(child: CircularProgressIndicator())),
          error: (error, _) => OwnerPage(
              title: s.productEditTitle,
              strings: s,
              child: MNErrorState(
                  error: error,
                  message: officeErrorText(s, error),
                  onRetry: () => ref.invalidate(officeProductsProvider))),
        );
  }
}

class _ProductEditor extends ConsumerStatefulWidget {
  final OfficeProduct product;
  const _ProductEditor({super.key, required this.product});
  @override
  ConsumerState<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends ConsumerState<_ProductEditor> {
  late final _name = TextEditingController(text: widget.product.name);
  final _reason = TextEditingController();
  late String _category = widget.product.category, _unit = widget.product.unit;
  late bool _available = widget.product.available,
      _active = widget.product.status == 'active';
  late String? _image = widget.product.imageKey;
  late int? _defaultPrice = widget.product.price,
      _savedPrice = widget.product.price;
  late Map<String, Object?> _savedMetadata;
  bool _busy = false;
  String? _error;

  Map<String, Object?> get _metadata => {
        'name': _name.text.trim(),
        'category': _category,
        'unit': _unit,
        'available': _available && _active,
        'active': _active,
        'image': _image,
      };
  bool get _dirty =>
      !mapEquals(_metadata, _savedMetadata) || _defaultPrice != _savedPrice;
  @override
  void initState() {
    super.initState();
    _savedMetadata = _metadata;
    _name.addListener(_refresh);
    _reason.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _reason.removeListener(_refresh);
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(pickProductPhotoProvider)();
      if (bytes == null || !mounted) return;
      final key = await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => r.uploadProductImage(bytes));
      if (mounted) setState(() => _image = key);
    } catch (_) {
      if (mounted) {
        setState(() => _error = ref.read(stringsProvider).photoFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_dirty) return;
    final s = ref.read(stringsProvider);
    if (_name.text.trim().length < 2 || _reason.text.trim().length < 3) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    var savedPart = false;
    try {
      // Existing endpoints are separate transactions. Remember confirmed work
      // so a failed price update can be retried without resaving metadata.
      if (!mapEquals(_metadata, _savedMetadata)) {
        await ref.read(officeSessionProvider.notifier).guard((r) =>
            r.updateProduct(widget.product.code,
                name: _name.text.trim(),
                category: _category,
                unit: _unit,
                available: _available && _active,
                status: _active ? 'active' : 'discontinued',
                imageKey: _image,
                reason: _reason.text.trim()));
        _savedMetadata = _metadata;
        savedPart = true;
      }
      if (_defaultPrice != _savedPrice && _defaultPrice != null) {
        await ref.read(officeSessionProvider.notifier).guard((r) =>
            r.setProductPrice(widget.product.code,
                amount: _defaultPrice!,
                stationId: null,
                reason: _reason.text.trim()));
        _savedPrice = _defaultPrice;
        savedPart = true;
      }
      ref.invalidate(officeProductsProvider);
      ref.invalidate(officePricesProvider(widget.product.code));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.changesSaved)));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = savedPart ? s.productPartialSave : s.productSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _field(String title, Widget child) => showMNSheet<void>(context,
      builder: (ctx) => MNSheet(title: title, children: [
            child,
            MNButton(ref.read(stringsProvider).productApplyDraft,
                onPressed: () => Navigator.of(ctx).pop()),
          ]));
  Future<void> _categorySheet() => showMNSheet<void>(context,
      builder: (sheetContext) => Consumer(builder: (_, sheetRef, __) {
            final s = sheetRef.watch(stringsProvider);
            return MNSheet(title: s.productCategory, children: [
              OwnerAsyncView(
                  value: sheetRef.watch(officeCategoriesProvider),
                  onRetry: () => sheetRef.invalidate(officeCategoriesProvider),
                  data: (items) => MNSelectField<String>(
                      label: s.productCategory,
                      value: _category,
                      options: [
                        for (final c in items)
                          MNSelectOption(value: c.code, label: c.name),
                        if (!items.any((c) => c.code == _category))
                          MNSelectOption(value: _category, label: _category),
                      ],
                      onChanged: (value) {
                        setState(() => _category = value);
                        Navigator.of(sheetContext).pop();
                      })),
            ]);
          }));

  Future<void> _deactivate() async {
    if (_busy || !_active) return;
    final s = ref.read(stringsProvider);
    final confirmed = await showMNSheet<bool>(context,
        builder: (ctx) =>
            MNSheet(title: s.productDisableTitle(_name.text.trim()), children: [
              Text(s.productDisableBody,
                  textAlign: TextAlign.center,
                  style: OwnerStyle.text(ctx, 14, color: OwnerStyle.muted)),
              MNButton.secondary(s.cancel,
                  onPressed: () => Navigator.of(ctx).pop(false)),
              MNTextButton(s.productDisable,
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ]));
    if (confirmed == true && mounted) setState(() => _active = false);
  }

  Future<void> _delete() async {
    final s = ref.read(stringsProvider);
    final done = await showRemovalSheet(context,
        title: s.deleteProduct,
        body: s.deleteProductBody,
        name: widget.product.name,
        run: (r, reason) =>
            r.deleteProduct(widget.product.code, reason: reason));
    if (!done || !mounted) return;
    ref.invalidate(officeProductsProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.deletedToast)));
    context.pop();
  }

  Future<void> _actions() => showMNSheet<void>(context, builder: (ctx) {
        final s = ref.read(stringsProvider);
        return MNSheet(title: s.productActions, children: [
          MNButton.secondary(s.uploadPhoto, onPressed: () {
            Navigator.of(ctx).pop();
            _photo();
          }),
          if (_image != null)
            MNTextButton(s.removePhoto, onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _image = null);
            }),
          MNTextButton(s.deleteProduct, onPressed: () {
            Navigator.of(ctx).pop();
            _delete();
          }),
        ]);
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final categories = ref.watch(officeCategoriesProvider);
    final priceState = ref.watch(officePricesProvider(widget.product.code));
    String price(int n) => formatTsh(n).replaceFirst('TSh', 'TZS');
    Widget section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
        child: Text(title, style: OwnerStyle.text(context, 14, weight: 600)));
    Widget group(List<Widget> children) => OwnerCard(
        child: Material(
            color: OwnerStyle.white,
            child: Column(children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                          height: 1, thickness: .7, color: OwnerStyle.line)),
                child,
              ],
            ])));
    Widget row(String label, String? value, VoidCallback onTap,
            {String? subtitle}) =>
        OwnerMenuRow(
            label: label,
            value: value,
            subtitle: subtitle,
            valueSize: 14,
            valueWeight: 400,
            valueColor: OwnerStyle.ink,
            height: 52,
            onTap: _busy ? null : onTap);
    final category = categories.valueOrNull
            ?.where((c) => c.code == _category)
            .firstOrNull
            ?.name ??
        _category;
    return OwnerPage(
      title: s.productEditTitle,
      strings: s,
      subtitle: Text(widget.product.name,
          style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
      trailing: OwnerHelp(
          compact: true,
          message: [s.photoHelp, s.cutHelp, s.priceHelp].join('\n\n')),
      bottom: SafeArea(
          top: false,
          child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: OwnerStyle.line))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null) ...[
                  MNNote(_error!, error: true),
                  const SizedBox(height: 8)
                ],
                MNButton(s.saveChanges,
                    busy: _busy,
                    onPressed:
                        !_busy && _dirty && _reason.text.trim().length >= 3
                            ? _save
                            : null),
                if (!_dirty)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(s.productNoChanges,
                          style: OwnerStyle.text(context, 12,
                              color: OwnerStyle.muted))),
              ]))),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OwnerCard(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      GestureDetector(
                          onTap: _busy ? null : _photo,
                          child: SizedBox(
                              width: 64,
                              height: 64,
                              child: MNProductImage.thumb(
                                  size: 64,
                                  image: productImageFor(_image,
                                      productName: widget.product.name)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: InkWell(
                              onTap: _busy ? null : _photo,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.productPhoto,
                                        style: OwnerStyle.text(context, 14)),
                                    const SizedBox(height: 4),
                                    Text(s.productPhotoHint,
                                        style: OwnerStyle.text(context, 12,
                                            color: OwnerStyle.muted)),
                                  ]))),
                      MNIconButton(MNIconData.more,
                          label: s.productActions,
                          onPressed: _busy ? null : _actions),
                    ]))),
            section(s.productInformation),
            group([
              row(
                  s.productName,
                  _name.text.trim(),
                  () => _field(
                      s.productName,
                      MNTextField(
                          label: s.productName,
                          controller: _name,
                          enabled: !_busy))),
              row(s.productCategory, category, _categorySheet),
              row(
                  s.productUnit,
                  s.unitName(_unit),
                  () => _field(
                      s.productUnit,
                      _UnitField(
                          value: _unit,
                          enabled: !_busy,
                          onChanged: (value) {
                            setState(() => _unit = value);
                            Navigator.of(context).pop();
                          }))),
            ]),
            section(s.productAvailabilitySection),
            group([
              SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeTrackColor: OwnerStyle.ink,
                  title: Text(s.productActive,
                      style: OwnerStyle.text(context, 14)),
                  subtitle: Text(s.productActiveHint,
                      style: OwnerStyle.text(context, 12,
                          color: OwnerStyle.muted)),
                  value: _active,
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value) {
                            setState(() => _active = true);
                          } else {
                            _deactivate();
                          }
                        }),
              SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeTrackColor: OwnerStyle.ink,
                  title: Text(s.productAvailable,
                      style: OwnerStyle.text(context, 14)),
                  subtitle: Text(s.productAvailableHint,
                      style: OwnerStyle.text(context, 12,
                          color: OwnerStyle.muted)),
                  value: _available && _active,
                  onChanged: _busy || !_active
                      ? null
                      : (value) => setState(() => _available = value)),
            ]),
            section(s.productPricesSection),
            group([
              row(s.defaultPrice,
                  _defaultPrice == null ? s.noPriceSet : price(_defaultPrice!),
                  () async {
                final amount = await showMNSheet<int>(context,
                    builder: (_) => _DraftPriceSheet(amount: _defaultPrice));
                if (mounted && amount != null) {
                  setState(() => _defaultPrice = amount);
                }
              },
                  subtitle: _defaultPrice != _savedPrice && _savedPrice != null
                      ? s.productPreviousPrice(price(_savedPrice!))
                      : null),
              row(
                  s.stationPrices,
                  null,
                  () => showMNSheet<void>(context,
                      builder: (_) =>
                          _ProductStationPrices(code: widget.product.code)),
                  subtitle: priceState.valueOrNull == null
                      ? null
                      : s.productDefaultStations(priceState.valueOrNull!
                          .where((p) => !p.overridden)
                          .length)),
            ]),
            section(s.productProductionSection),
            ref.watch(moneySettingsProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => MNButton.secondary(s.retry,
                    onPressed: () => ref.invalidate(moneySettingsProvider)),
                data: (settings) {
                  final cut = settings.cuts[widget.product.code];
                  final source = ref
                          .watch(officeProductsProvider)
                          .valueOrNull
                          ?.where((p) => p.code == cut?.from)
                          .firstOrNull
                          ?.name ??
                      cut?.from;
                  return group([
                    row(
                        s.productMadeFrom,
                        null,
                        () => showMNSheet<void>(context,
                            builder: (_) => _CutSheet(
                                product: widget.product, settings: settings)),
                        subtitle: cut == null
                            ? s.cutNone
                            : s.cutRule(source!, cut.count))
                  ]);
                }),
            if (_dirty) ...[
              section(s.productReasonRequired),
              OwnerFormSection(children: [
                MNTextField(
                    label: s.changeReason,
                    controller: _reason,
                    enabled: !_busy,
                    maxLines: 3)
              ]),
            ],
            section(s.productManagementSection),
            group([
              OwnerMenuRow(
                  label: s.productDisable,
                  labelColor: _active ? MNColors.error : OwnerStyle.muted,
                  subtitle:
                      _active ? s.productDisableHint : s.productInactiveHint,
                  onTap: _busy || !_active ? null : _deactivate)
            ]),
            const SizedBox(height: 24),
          ])),
    );
  }
}

class _ProductStationPrices extends ConsumerWidget {
  final String code;
  const _ProductStationPrices({required this.code});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.stationPrices, children: [
      OwnerAsyncView(
          value: ref.watch(officePricesProvider(code)),
          onRetry: () => ref.invalidate(officePricesProvider(code)),
          data: (prices) => Column(children: [
                for (final p in prices)
                  OwnerMenuRow(
                      label: p.stationName,
                      subtitle: p.overridden ? null : s.defaultPrice,
                      value: p.amount == null
                          ? s.noPriceSet
                          : formatTsh(p.amount!).replaceFirst('TSh', 'TZS'),
                      onTap: () => _priceSheet(
                          context, code, p.stationName, p.amount, p.stationId)),
              ])),
    ]);
  }
}

class _DraftPriceSheet extends ConsumerStatefulWidget {
  final int? amount;
  const _DraftPriceSheet({required this.amount});
  @override
  ConsumerState<_DraftPriceSheet> createState() => _DraftPriceSheetState();
}

class _DraftPriceSheetState extends ConsumerState<_DraftPriceSheet> {
  late final _amount =
      TextEditingController(text: widget.amount?.toString() ?? '');
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.defaultPrice, children: [
      MNTextField(
          label: s.priceAmount,
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.productApplyDraft, onPressed: () {
        final amount = int.tryParse(_amount.text);
        if (amount == null || amount < 1 || amount > 100000000) {
          setState(() => _error = s.priceInvalid);
          return;
        }
        Navigator.of(context).pop(amount);
      }),
    ]);
  }
}

Future<int?> _priceSheet(BuildContext context, String code, String title,
        int? amount, String? stationId) =>
    showMNSheet<int>(context,
        builder: (_) => _PriceSheet(
            code: code, title: title, amount: amount, stationId: stationId));

class _PriceSheet extends ConsumerStatefulWidget {
  final String code, title;
  final String? stationId;
  final int? amount;
  const _PriceSheet(
      {required this.code, required this.title, this.stationId, this.amount});
  @override
  ConsumerState<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends ConsumerState<_PriceSheet> {
  late final _amount =
      TextEditingController(text: widget.amount?.toString() ?? '');
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final value = int.tryParse(_amount.text);
    if (value == null ||
        value < 1 ||
        value > 100000000 ||
        _reason.text.trim().length < 3) {
      setState(() => _error = s.priceInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          r.setProductPrice(widget.code,
              amount: value,
              stationId: widget.stationId,
              reason: _reason.text.trim()));
      ref.invalidate(officePricesProvider(widget.code));
      if (mounted) Navigator.of(context).pop(value);
    } catch (_) {
      if (mounted) setState(() => _error = s.productSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      MNTextField(
          label: s.priceAmount,
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      MNTextField(label: s.changeReason, controller: _reason, enabled: !_busy),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// Sets or removes the product's cut rule. The whole `stock.cuts` setting
/// is sent again with this product changed (owner only).
class _CutSheet extends ConsumerStatefulWidget {
  final OfficeProduct product;
  final OfficeMoneySettings settings;
  const _CutSheet({required this.product, required this.settings});
  @override
  ConsumerState<_CutSheet> createState() => _CutSheetState();
}

class _CutSheetState extends ConsumerState<_CutSheet> {
  late String? _from = widget.settings.cuts[widget.product.code]?.from;
  late int _count = widget.settings.cuts[widget.product.code]?.count ?? 1;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    if (_reason.text.trim().length < 3) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final cuts = {
      ...widget.settings.cuts,
      if (_from != null) widget.product.code: OfficeCut(_from!, _count),
    };
    if (_from == null) cuts.remove(widget.product.code);
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) => r.saveSetting(
          OfficeMoneySettings.cutsKey,
          value: cutsSetting(cuts),
          reason: _reason.text.trim()));
      ref.invalidate(moneySettingsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = s.cutSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whether [code] is this product or is cut (directly or not) from it:
  /// choosing it would cut the product from itself.
  bool _below(String code) {
    final cuts = widget.settings.cuts;
    for (var c = code, n = 0; n <= cuts.length; n++) {
      if (c == widget.product.code) return true;
      final up = cuts[c]?.from;
      if (up == null) return false;
      c = up;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(officeProductsProvider).valueOrNull ?? [];
    return MNSheet(title: widget.product.name, children: [
      MNSelectField<String>(
          label: s.cutSource,
          value: _from ?? '',
          options: [
            MNSelectOption(value: '', label: s.cutNone),
            for (final p in products)
              if (!_below(p.code)) MNSelectOption(value: p.code, label: p.name),
          ],
          onChanged: _busy
              ? null
              : (v) => setState(() => _from = v.isEmpty ? null : v)),
      if (_from != null)
        MNSelectField<int>(
            label: s.cutCount,
            value: _count,
            options: [
              for (var n = 1; n <= 8; n++)
                MNSelectOption(value: n, label: '$n'),
            ],
            onChanged: _busy ? null : (v) => setState(() => _count = v)),
      MNTextField(label: s.changeReason, controller: _reason, enabled: !_busy),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// The approved top-right + opens real product creation through the existing
/// admin endpoint; prices/photos remain in the existing product editor.
class OfficeNewProductScreen extends ConsumerStatefulWidget {
  final bool returnCreated;
  const OfficeNewProductScreen({super.key, this.returnCreated = false});
  @override
  ConsumerState<OfficeNewProductScreen> createState() =>
      _OfficeNewProductState();
}

class _OfficeNewProductState extends ConsumerState<OfficeNewProductScreen> {
  /// The dropdown entry that opens the new-category form.
  static const _newCategoryValue = '+';

  /// The product number is generated, never typed by the owner.
  final _code =
      'PR-${const Uuid().v4().replaceAll('-', '').substring(0, 10).toUpperCase()}';
  final _name = TextEditingController();
  String? _category;
  String _unit = 'piece';
  String? _error;
  bool _busy = false;

  /// A category created here, shown until the list reloads with it.
  OfficeCategory? _created;

  /// Rebuilds the category field after the form, so it shows [_category].
  int _categoryField = 0;

  Future<void> _newCategory() async {
    final created = await showNewCategorySheet(context);
    if (!mounted) return;
    setState(() {
      if (created != null) {
        _created = created;
        _category = created.code;
      }
      _categoryField++;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    if (_name.text.trim().length < 2 || _category == null) {
      setState(() => _error = s.newProductInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final product = await ref.read(officeSessionProvider.notifier).guard(
          (r) => r.createProduct(
              code: _code,
              name: _name.text.trim(),
              category: _category!,
              unit: _unit));
      ref.invalidate(officeProductsProvider);
      if (mounted) {
        if (widget.returnCreated) {
          Navigator.of(context).pop(product);
        } else {
          context.pushReplacement(MNRoutes.officeProduct(product.code));
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = s.productSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return OwnerPage(
        title: s.ownerAddProduct,
        strings: s,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: OwnerFormSection(children: [
              MNTextField(
                  label: s.productName, controller: _name, enabled: !_busy),
              const SizedBox(height: 16),
              ref.watch(officeCategoriesProvider).when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => MNButton.secondary(s.retry,
                      onPressed: () =>
                          ref.invalidate(officeCategoriesProvider)),
                  data: (items) => MNSelectField<String>(
                      key: ValueKey(_categoryField),
                      label: s.productCategory,
                      value: _category,
                      options: [
                        for (final c in items)
                          MNSelectOption(value: c.code, label: c.name),
                        if (_created case final c?
                            when !items.any((i) => i.code == c.code))
                          MNSelectOption(value: c.code, label: c.name),
                        MNSelectOption(
                            value: _newCategoryValue,
                            label: s.newCategoryEntry,
                            action: true),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => v == _newCategoryValue
                              ? _newCategory()
                              : setState(() => _category = v))),
              const SizedBox(height: 16),
              _UnitField(
                  value: _unit,
                  enabled: !_busy,
                  onChanged: (v) => setState(() => _unit = v)),
              if (_error != null) MNNote(_error!, error: true),
              const SizedBox(height: 24),
              MNButton(s.saveChanges,
                  busy: _busy, onPressed: _busy ? null : _save),
            ])));
  }
}

/// The unit field of the product forms: the built-in units, the units the
/// business added, and "+ Kipimo kipya" to add one.
class _UnitField extends ConsumerStatefulWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _UnitField(
      {required this.value, required this.enabled, required this.onChanged});
  @override
  ConsumerState<_UnitField> createState() => _UnitFieldState();
}

class _UnitFieldState extends ConsumerState<_UnitField> {
  /// The dropdown entry that opens the new-unit form.
  static const _newUnitValue = '+';

  /// Rebuilds the field after the form, so it shows the chosen unit.
  int _field = 0;

  Future<void> _newUnit() async {
    final created = await showNewUnitSheet(context);
    if (!mounted) return;
    if (created != null) widget.onChanged(created.code);
    setState(() => _field++);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    ref.watch(officeUnitsProvider);
    final codes = [
      ...builtInUnits,
      ...ref.watch(addedUnitsProvider).keys,
    ];
    if (!codes.contains(widget.value)) codes.add(widget.value);
    return MNSelectField<String>(
        key: ValueKey(_field),
        label: s.productUnit,
        value: widget.value,
        options: [
          for (final code in codes)
            MNSelectOption(value: code, label: s.unitName(code)),
          MNSelectOption(
              value: _newUnitValue, label: s.newUnitEntry, action: true),
        ],
        onChanged: widget.enabled
            ? (v) => v == _newUnitValue ? _newUnit() : widget.onChanged(v)
            : null);
  }
}

/// A new unit: its name, and whether it is counted in whole numbers or
/// allows decimals. The code is made from the name. Returns the created
/// unit, or null when dismissed.
Future<OfficeUnit?> showNewUnitSheet(BuildContext context) =>
    showMNSheet<OfficeUnit>(context, builder: (_) => const _NewUnitSheet());

class _NewUnitSheet extends ConsumerStatefulWidget {
  const _NewUnitSheet();
  @override
  ConsumerState<_NewUnitSheet> createState() => _NewUnitSheetState();
}

class _NewUnitSheetState extends ConsumerState<_NewUnitSheet> {
  final _name = TextEditingController();
  bool _decimal = false;
  String? _nameError, _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The server code: the name in its format, or a generated one when the
  /// name has no letters it can use.
  static String _codeFrom(String name) {
    final code = _NewCategorySheetState._codeFrom(name);
    return RegExp(r'^[a-z][a-z0-9_]{1,31}$').hasMatch(code)
        ? code
        : 'kipimo_${const Uuid().v4().replaceAll('-', '').substring(0, 8)}';
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final name = _name.text.trim();
    final code = _codeFrom(name);
    final taken = builtInUnits.contains(code) ||
        builtInUnits
            .any((u) => s.unitName(u).toLowerCase() == name.toLowerCase());
    setState(() {
      _nameError = name.length < 2 || name.length > 50
          ? s.nameRequired
          : (taken ? s.duplicateUnit : null);
      _error = null;
    });
    if (_nameError != null) return;
    setState(() => _busy = true);
    try {
      final unit = await ref.read(officeSessionProvider.notifier).guard(
          (r) => r.createUnit(code: code, name: name, allowsDecimal: _decimal));
      ref.read(addedUnitsProvider.notifier).update((units) => {
            ...units,
            unit.code: unit,
          });
      ref.invalidate(officeUnitsProvider);
      if (mounted) Navigator.of(context).pop(unit);
    } catch (error) {
      if (mounted) {
        setState(() => _error = switch (error) {
              OfficeError(kind: OfficeErrorKind.duplicate) => s.duplicateUnit,
              _ => officeErrorText(s, error),
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.newUnit, children: [
      MNTextField(
          label: s.unitNameLabel,
          controller: _name,
          enabled: !_busy,
          hint: s.unitNameHint,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          error: _nameError),
      MNSelectField<bool>(
          label: s.unitCounting,
          value: _decimal,
          options: [
            MNSelectOption(value: false, label: s.unitWhole),
            MNSelectOption(value: true, label: s.unitDecimal),
          ],
          onChanged: _busy ? null : (v) => setState(() => _decimal = v)),
      Text(s.unitCountingFixed, style: MNText.resolve(context, MNText.meta)),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.addUnit, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// A new product category (code and name, as the server validates them).
/// Returns the created category, or null when dismissed.
Future<OfficeCategory?> showNewCategorySheet(BuildContext context) =>
    showMNSheet<OfficeCategory>(context,
        builder: (_) => const _NewCategorySheet());

class _NewCategorySheet extends ConsumerStatefulWidget {
  const _NewCategorySheet();
  @override
  ConsumerState<_NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends ConsumerState<_NewCategorySheet> {
  static final _codePattern = RegExp(r'^[a-z][a-z0-9_]{1,31}$');
  final _name = TextEditingController(), _code = TextEditingController();
  String? _nameError, _codeError, _error;
  bool _busy = false;

  /// The code follows the name until the person types one of their own.
  bool _codeEdited = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  static String _codeFrom(String name) {
    var code = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('^[^a-z]+'), '')
        .replaceAll(RegExp(r'_+$'), '');
    if (code.length > 32) code = code.substring(0, 32);
    return code;
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final name = _name.text.trim();
    final code = _code.text.trim();
    setState(() {
      _nameError = name.length < 2 || name.length > 100 ? s.nameRequired : null;
      _codeError = _codePattern.hasMatch(code) ? null : s.categoryCodeInvalid;
      _error = null;
    });
    if (_nameError != null || _codeError != null) return;
    setState(() => _busy = true);
    try {
      final category = await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => r.createCategory(code: code, name: name));
      ref.invalidate(officeCategoriesProvider);
      if (mounted) Navigator.of(context).pop(category);
    } catch (error) {
      if (mounted) {
        setState(() => _error = switch (error) {
              OfficeError(kind: OfficeErrorKind.duplicate) =>
                s.duplicateCategory,
              OfficeError(kind: OfficeErrorKind.invalid) =>
                s.categoryCodeInvalid,
              _ => officeErrorText(s, error),
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.newCategory, children: [
      MNTextField(
          label: s.categoryName,
          controller: _name,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          error: _nameError,
          onChanged: (value) {
            if (!_codeEdited) _code.text = _codeFrom(value);
          }),
      MNTextField(
          label: s.categoryCode,
          controller: _code,
          enabled: !_busy,
          hint: s.categoryCodeHint,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
            LengthLimitingTextInputFormatter(32),
          ],
          error: _codeError,
          onChanged: (value) {
            _codeEdited = true;
            final lower = value.toLowerCase();
            if (lower != value) {
              _code.value = _code.value.copyWith(text: lower);
            }
          }),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.addCategory, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// The business's product categories; one with no products can be deleted
/// (added by mistake). The server refuses one that still has products.
class _CategoriesSheet extends ConsumerWidget {
  const _CategoriesSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final categories = ref.watch(officeCategoriesProvider);
    final products = ref.watch(officeProductsProvider).valueOrNull ?? const [];
    return MNSheet(title: s.productCategories, children: [
      categories.when(
          data: (items) => items.isEmpty
              ? MNNote(s.deleteCategoryBody, tone: MNNoteTone.info)
              : OwnerCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      for (final c in items)
                        OwnerMenuRow(
                            label: c.name,
                            subtitle: s.productCount(products
                                .where((p) => p.category == c.code)
                                .length),
                            onTap: () async {
                              final done = await showRemovalSheet(context,
                                  title: s.deleteCategory,
                                  body: s.deleteCategoryBody,
                                  name: c.name,
                                  run: (r, reason) =>
                                      r.deleteCategory(c.code, reason: reason));
                              if (!done) return;
                              ref.invalidate(officeCategoriesProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(s.deletedToast)));
                              }
                            }),
                    ])),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => MNButton.secondary(s.retry,
              onPressed: () => ref.invalidate(officeCategoriesProvider))),
    ]);
  }
}
