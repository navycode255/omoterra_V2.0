import 'dart:math' as math;

import 'owner_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText, officeStationsProvider;
import 'product_screens.dart'
    show officeProductsProvider, officeCategoriesProvider, officePricesProvider;

Future<T> menuCall<T>(
        WidgetRef ref, Future<T> Function(MenuSetupRepository) work) =>
    ref.read(officeSessionProvider.notifier).guard((r) {
      if (r is! MenuSetupRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(r as MenuSetupRepository);
    });
final stationMenuProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
        (ref, id) => ref.read(officeSessionProvider.notifier).guard((r) {
              if (r is! MenuSetupRepository) {
                throw const OfficeError(OfficeErrorKind.invalid);
              }
              return (r as MenuSetupRepository).stationMenu(id);
            }));

// Platform file dialogs are replaceable in widget tests.
final pickMenuFileProvider =
    Provider<Future<Uint8List?> Function()>((ref) => () async {
          final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['xlsx'],
              withData: kIsWeb);
          if (result == null) return null;
          final file = result.files.single;
          if (file.size > 5 * 1024 * 1024) {
            throw const FormatException('Excel lisizidi MB 5.');
          }
          final bytes = file.bytes ?? await file.xFile.readAsBytes();
          if (bytes.length > 5 * 1024 * 1024) {
            throw const FormatException('Excel lisizidi MB 5.');
          }
          return bytes;
        });
final saveMenuTemplateProvider =
    Provider<Future<void> Function(Uint8List)>((ref) => (bytes) async {
          await FilePicker.platform.saveFile(
              fileName: 'Mr_Nyama_Menu.xlsx',
              type: FileType.custom,
              allowedExtensions: ['xlsx'],
              bytes: bytes);
        });

class MenuImportEntry extends ConsumerWidget {
  const MenuImportEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerCard(
        child: OwnerMenuRow(
            label: s.menuImportTitle,
            subtitle: s.menuImportCaption,
            onTap: () => context.push(MNRoutes.officeMenuImport)));
  }
}

class MenuImportScreen extends ConsumerStatefulWidget {
  const MenuImportScreen({super.key});
  @override
  ConsumerState<MenuImportScreen> createState() => _MenuImportState();
}

class _MenuImportState extends ConsumerState<MenuImportScreen> {
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _preview, _pending, _result;
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FormatException
              ? ref.read(stringsProvider).menuFileInvalid
              : officeErrorText(ref.read(stringsProvider), e);
          if (e is OfficeError && _pending != null) {
            // A definite server refusal rolled back; require a fresh review.
            _pending = null;
            _preview = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _run(() async {
        final bytes = await ref.read(pickMenuFileProvider)();
        if (bytes == null) return;
        if (mounted) {
          setState(() {
            _preview = null;
            _result = null;
          });
        }
        final preview = await menuCall(ref, (r) => r.previewMenu(bytes));
        if (mounted) {
          setState(() {
            _preview = preview;
            _result = null;
          });
        }
      });
  Future<void> _save() => _run(() async {
        if (_pending == null) {
          if (_reason.text.trim().length < 3) {
            setState(() => _error = ref.read(stringsProvider).reasonInvalid);
            return;
          }
          _pending = {
            'client_id': const Uuid().v4(),
            'reason': _reason.text.trim(),
            'items': [
              for (final item in _preview!['items'] as List)
                Map<String, dynamic>.from(item as Map)
                  ..remove('action')
                  ..remove('row')
            ]
          };
        }
        final result = await menuCall(ref, (r) => r.importMenu(_pending!));
        ref.invalidate(officeProductsProvider);
        ref.invalidate(officeCategoriesProvider);
        ref.invalidate(officePricesProvider);
        ref.invalidate(stationMenuProvider);
        if (mounted) {
          setState(() {
            _result = result;
            _pending = null;
            _preview = null;
          });
        }
      });
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final preview = _preview;
    return OwnerPage(
        title: s.menuImportTitle,
        strings: s,
        bottom: preview?['can_import'] == true
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: MNButton(
                    _pending == null ? s.menuImportConfirm : s.retry,
                    busy: _busy,
                    onPressed: _busy ? null : _save))
            : null,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OwnerHelp(message: s.menuExcelInstructions),
                  const SizedBox(height: 16),
                  MNTextButton(s.menuDownloadTemplate,
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final bytes = await menuCall(
                                    ref, (r) => r.menuTemplate());
                                await ref.read(saveMenuTemplateProvider)(bytes);
                              })),
                  const SizedBox(height: 12),
                  MNButton(s.menuChooseExcel,
                      onPressed: _busy || _pending != null ? null : _pick),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    MNNote(_error!, error: true)
                  ],
                  if (_pending != null) ...[
                    const SizedBox(height: 12),
                    MNNote(s.sendRetryNote)
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 20),
                    MNNote(s.menuImportSaved(_result!['created'] as int,
                        _result!['updated'] as int)),
                    const SizedBox(height: 12),
                    MNButton.secondary(s.menuChooseStations,
                        onPressed: () => context.push(MNRoutes.officeStations)),
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: 20),
                    Text(s.menuPreviewTitle,
                        style: OwnerStyle.text(context, 20, weight: 600)),
                    for (final error in preview['errors'] as List) ...[
                      const SizedBox(height: 8),
                      MNNote(
                          s.menuRowError(
                              error['row'] as int, '${error['message']}'),
                          error: true),
                    ],
                    const SizedBox(height: 12),
                    OwnerCard(
                        child: Column(children: [
                      for (final item in preview['items'] as List)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('${item['name']}',
                                      style: OwnerStyle.text(context, 16,
                                          weight: 600)),
                                  Text(
                                      '${s.unitName('${item['unit']}')} · ${formatTsh(item['price'] as int)}',
                                      style: OwnerStyle.text(context, 14)),
                                  Text(
                                      item['action'] == 'create'
                                          ? s.menuNewItem
                                          : s.menuUpdateItem,
                                      style: OwnerStyle.text(context, 13,
                                          color: OwnerStyle.muted)),
                                ])),
                    ])),
                    const SizedBox(height: 16),
                    MNTextField(
                        label: s.changeReason,
                        controller: _reason,
                        enabled: !_busy && _pending == null),
                  ],
                ])));
  }
}

const _menuPageSize = 10;

class StationMenuScreen extends ConsumerStatefulWidget {
  final String stationId;
  const StationMenuScreen({super.key, required this.stationId});
  @override
  ConsumerState<StationMenuScreen> createState() => _StationMenuState();
}

class _StationMenuState extends ConsumerState<StationMenuScreen> {
  List<Map<String, dynamic>>? _items;
  int _revision = 0;
  bool _configured = true;
  final _selected = <String>{};
  final _prices = <String, int?>{};
  // As loaded, so Hifadhi stays off until something changes.
  final _savedSelected = <String>{};
  final _savedPrices = <String, int?>{};
  String _search = '';
  int _limit = _menuPageSize;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _pending;

  bool get _locked => _busy || _pending != null;
  bool get _changed =>
      _selected.length != _savedSelected.length ||
      !_selected.containsAll(_savedSelected) ||
      _prices.entries.any((e) => _savedPrices[e.key] != e.value);
  bool get _canSave => _pending != null || _changed || !_configured;

  int? _priceOf(Map<String, dynamic> item) =>
      _prices[item['code']] ?? item['default_price'] as int?;

  void _toggle(String code) => setState(() {
        _selected.contains(code) ? _selected.remove(code) : _selected.add(code);
        _error = null;
      });

  Future<void> _price(Map<String, dynamic> item) async {
    final s = ref.read(stringsProvider), code = item['code'] as String;
    final result = await showMNSheet<String>(context,
        builder: (_) => _MenuPriceSheet(
            name: '${item['name']}', amount: _prices[code], strings: s));
    if (result == null || !mounted) return;
    final n = int.tryParse(result);
    if (result.isNotEmpty && (n == null || n <= 0 || n > 100000000)) {
      setState(() => _error = s.priceInvalid);
      return;
    }
    setState(() {
      final wasPriced = _priceOf(item) != null;
      _prices[code] = n;
      // A newly priced item is ready to sell; an unpriced one cannot be.
      if (!wasPriced && n != null) _selected.add(code);
      if (_priceOf(item) == null) _selected.remove(code);
      _error = null;
    });
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    if (_busy) return;
    if (_pending == null) {
      final reason = await showMNSheet<String>(context,
          builder: (_) => _MenuReasonSheet(strings: s));
      if (reason == null || !mounted) return;
      _pending = {
        'client_id': const Uuid().v4(),
        'reason': reason,
        'expected_revision': _revision,
        'items': [
          for (final code in _selected.toList()..sort())
            {'code': code, 'station_price': _prices[code]}
        ]
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await menuCall(
          ref, (r) => r.saveStationMenu(widget.stationId, _pending!));
      ref.invalidate(stationMenuProvider(widget.stationId));
      ref.invalidate(officePricesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = officeErrorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reload() {
    ref.invalidate(stationMenuProvider(widget.stationId));
    setState(() {
      _items = null;
      _pending = null;
      _selected.clear();
      _prices.clear();
      _savedSelected.clear();
      _savedPrices.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final data = ref.watch(stationMenuProvider(widget.stationId));
    final station = ref
        .watch(officeStationsProvider)
        .valueOrNull
        ?.where((x) => x.id == widget.stationId)
        .firstOrNull;
    final value = data.valueOrNull;
    if (_items == null && value != null) {
      _items = [
        for (final item in value['items'] as List)
          Map<String, dynamic>.from(item as Map)
      ];
      _revision = value['revision'] as int;
      _configured = value['configured'] != false;
      for (final item in _items!) {
        final code = item['code'] as String;
        if (item['selected'] == true) _selected.add(code);
        _prices[code] = item['station_price'] as int?;
      }
      _savedSelected.addAll(_selected);
      _savedPrices.addAll(_prices);
    }
    final query = _search.trim().toLowerCase();
    final visible = _items
            ?.where((i) =>
                '${i['name']} ${i['code']}'.toLowerCase().contains(query))
            .toList() ??
        const <Map<String, dynamic>>[];
    // "Chagua zote" covers the shown items that can be sold (have a price).
    final selectable = [
      for (final i in visible)
        if (_priceOf(i) != null) i['code'] as String
    ];
    final allSelected =
        selectable.isNotEmpty && _selected.containsAll(selectable);
    final shown = math.min(_limit, visible.length);
    return OwnerPage(
        title: s.stationMenuHeading,
        strings: s,
        header: Padding(
            padding: EdgeInsets.only(left: u(19), right: u(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Semantics(
                        header: true,
                        child: Text(s.stationMenuHeading,
                            style: OwnerStyle.text(context, 31,
                                weight: 700, height: 1.23, spacing: -.9))),
                    if (station != null) ...[
                      SizedBox(height: u(5)),
                      Text(station.name,
                          style: OwnerStyle.text(context, 17,
                              color: OwnerStyle.muted)),
                    ],
                  ])),
              OwnerHelp(message: s.menuStationInstructions),
            ])),
        contentGap: 16,
        bottom: _items == null
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(u(20), u(8), u(20), u(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  MNButton(_pending == null ? s.saveWorkflow : s.retry,
                      busy: _busy,
                      onPressed: _busy || !_canSave ? null : _save),
                  if (!_canSave) ...[
                    SizedBox(height: u(10)),
                    Text(s.menuNoChanges,
                        textAlign: TextAlign.center,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                  ],
                ])),
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: u(20)),
            child: OwnerAsyncView(
                value: data,
                onRetry: () =>
                    ref.invalidate(stationMenuProvider(widget.stationId)),
                data: (_) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_configured) ...[
                            MNNote(s.menuNotConfigured),
                            SizedBox(height: u(12)),
                          ],
                          _MenuSearchField(
                              hint: s.menuSearch,
                              enabled: !_locked,
                              onChanged: (v) => setState(() {
                                    _search = v;
                                    _limit = _menuPageSize;
                                  })),
                          SizedBox(height: u(14)),
                          // Stacks when large text leaves no room for both.
                          Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: u(12),
                              children: [
                                Text(s.menuSelectedCount(_selected.length),
                                    style: OwnerStyle.text(context, 16,
                                        color: OwnerStyle.muted)),
                                if (selectable.isNotEmpty)
                                  MNPressable(
                                      pressedScale: MNMotion.pressChip,
                                      onTap: _locked
                                          ? null
                                          : () => setState(() {
                                                allSelected
                                                    ? _selected
                                                        .removeAll(selectable)
                                                    : _selected
                                                        .addAll(selectable);
                                              }),
                                      semanticLabel: allSelected
                                          ? s.menuSelectNone
                                          : s.menuSelectAll,
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight: MNSize.minTouch),
                                          child: Center(
                                              widthFactor: 1,
                                              child: ExcludeSemantics(
                                                  child: Text(
                                                      allSelected
                                                          ? s.menuSelectNone
                                                          : s.menuSelectAll,
                                                      style: OwnerStyle.text(
                                                          context, 16,
                                                          color: OwnerStyle
                                                              .muted)))))),
                              ]),
                          SizedBox(height: u(6)),
                          if (_items!.isEmpty || visible.isEmpty)
                            Padding(
                                padding: EdgeInsets.symmetric(vertical: u(12)),
                                child: Text(
                                    _items!.isEmpty
                                        ? s.noOfficeProducts
                                        : s.menuNoMatches,
                                    style: OwnerStyle.text(context, 15,
                                        color: OwnerStyle.muted)))
                          else
                            OwnerCard(
                                child: Column(children: [
                              for (var i = 0; i < shown; i++) ...[
                                if (i > 0)
                                  const Divider(
                                      height: 1, color: OwnerStyle.line),
                                _MenuRow(
                                    item: visible[i],
                                    strings: s,
                                    selected:
                                        _selected.contains(visible[i]['code']),
                                    price: _priceOf(visible[i]),
                                    stationPrice: _prices[visible[i]['code']],
                                    locked: _locked,
                                    onToggle: () =>
                                        _toggle(visible[i]['code'] as String),
                                    onPrice: () => _price(visible[i])),
                              ]
                            ])),
                          if (visible.length > _limit) ...[
                            SizedBox(height: u(12)),
                            MNButton.secondary(s.moreRows,
                                onPressed: () =>
                                    setState(() => _limit += _menuPageSize)),
                          ],
                          if (_error != null) ...[
                            SizedBox(height: u(12)),
                            MNNote(_error!, error: true)
                          ],
                          if (_pending != null && !_busy) ...[
                            SizedBox(height: u(12)),
                            MNNote(s.sendRetryNote),
                            TextButton(
                                onPressed: _reload, child: Text(s.menuReload)),
                          ],
                        ]))));
  }
}

/// The white search box: a search glyph and a hint, no label.
class _MenuSearchField extends StatelessWidget {
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _MenuSearchField(
      {required this.hint, required this.enabled, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(u(14)),
        borderSide: BorderSide.none);
    return TextField(
        enabled: enabled,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: OwnerStyle.text(context, 17),
        cursorColor: OwnerStyle.red,
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: OwnerStyle.text(context, 17, color: OwnerStyle.muted),
            filled: true,
            fillColor: OwnerStyle.white,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: u(15)),
            prefixIcon: Padding(
                padding: EdgeInsets.only(left: u(14), right: u(10)),
                child: MNIcon(MNIconData.search,
                    size: u(24), color: OwnerStyle.muted)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border));
  }
}

/// One menu line: tap the left side to choose it, the price side to set the
/// station price. An item with no price shows a lock until it is priced.
class _MenuRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final Strings strings;
  final bool selected, locked;
  final int? price, stationPrice;
  final VoidCallback onToggle, onPrice;
  const _MenuRow(
      {required this.item,
      required this.strings,
      required this.selected,
      required this.price,
      required this.stationPrice,
      required this.locked,
      required this.onToggle,
      required this.onPrice});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    double u(double n) => OwnerStyle.px(context, n);
    final name = '${item['name']}';
    final unit = s.menuUnitPer('${item['unit']}');
    final unpriced = price == null && !selected;
    final offInCatalogue = item['available'] != true;
    final priceText = price == null ? s.menuNoPrice : formatTzs(price!);
    final vertical = u(14);
    // Prices sit in one column with every chevron at the right edge.
    return LayoutBuilder(
        builder: (context, box) => IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: Semantics(
                            container: true,
                            checked: selected,
                            label: '$name, $unit, $priceText',
                            child: MNPressable(
                                button: false,
                                pressedScale: 1,
                                color: OwnerStyle.white,
                                pressedColor: MNColors.surface,
                                onTap: locked
                                    ? null
                                    : (unpriced ? onPrice : onToggle),
                                child: ExcludeSemantics(
                                    child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                            u(16), vertical, u(8), vertical),
                                        child: Row(children: [
                                          _MenuCheck(
                                              selected: selected,
                                              locked: unpriced),
                                          SizedBox(width: u(16)),
                                          Expanded(
                                              child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: OwnerStyle.text(
                                                        context, 17,
                                                        weight: 450)),
                                                SizedBox(height: u(3)),
                                                Text(unit,
                                                    style: OwnerStyle.text(
                                                        context, 14,
                                                        color:
                                                            OwnerStyle.muted)),
                                                if (offInCatalogue)
                                                  Text(s.menuOffInCatalogue,
                                                      style: OwnerStyle.text(
                                                          context, 13,
                                                          color: OwnerStyle
                                                              .muted)),
                                              ])),
                                        ])))))),
                    SizedBox(
                        width: box.maxWidth * .36,
                        child: MNPressable(
                            pressedScale: 1,
                            color: OwnerStyle.white,
                            pressedColor: MNColors.surface,
                            semanticLabel: s.menuPriceAction(name),
                            onTap: locked ? null : onPrice,
                            child: ExcludeSemantics(
                                child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        u(4), vertical, u(14), vertical),
                                    child: Row(children: [
                                      Expanded(
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            if (price == null) ...[
                                              Text(s.menuNoPrice,
                                                  style: OwnerStyle.text(
                                                      context, 16,
                                                      color: OwnerStyle
                                                          .missingPrice)),
                                              SizedBox(height: u(3)),
                                              Text(s.menuSetPriceToSell,
                                                  style: OwnerStyle.text(
                                                      context, 13,
                                                      color: OwnerStyle.muted)),
                                            ] else ...[
                                              if (stationPrice != null)
                                                Text(s.menuStationPrice,
                                                    style: OwnerStyle.text(
                                                        context, 13,
                                                        color:
                                                            OwnerStyle.muted)),
                                              FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(formatTzs(price!),
                                                      style: OwnerStyle.text(
                                                          context, 16))),
                                            ],
                                          ])),
                                      SizedBox(width: u(8)),
                                      const OwnerGlyph('chevron',
                                          size: 14, color: OwnerStyle.muted),
                                    ]))))),
                  ]),
            ));
  }
}

/// The square check: red with a white tick when chosen, outlined when not,
/// grey with a lock when the item cannot be chosen yet.
class _MenuCheck extends StatelessWidget {
  final bool selected, locked;
  const _MenuCheck({required this.selected, required this.locked});
  @override
  Widget build(BuildContext context) {
    final side = OwnerStyle.px(context, 22);
    return AnimatedContainer(
        duration: MNMotion.of(context, MNMotion.small),
        curve: MNMotion.standard,
        width: side,
        height: side,
        decoration: BoxDecoration(
            color: selected
                ? OwnerStyle.red
                : locked
                    ? MNColors.disabled
                    : OwnerStyle.white,
            borderRadius: BorderRadius.circular(side * .2),
            border: Border.all(
                width: 1.6,
                color: selected
                    ? OwnerStyle.red
                    : locked
                        ? OwnerStyle.secondary
                        : OwnerStyle.navMuted)),
        child: selected
            ? MNIcon(MNIconData.check, size: side * .8, color: OwnerStyle.white)
            : locked
                ? MNIcon(MNIconData.lock,
                    size: side * .62, color: OwnerStyle.muted)
                : null);
  }
}

/// Asks why the menu changed before it is sent; returns the reason.
class _MenuReasonSheet extends StatefulWidget {
  final Strings strings;
  const _MenuReasonSheet({required this.strings});
  @override
  State<_MenuReasonSheet> createState() => _MenuReasonSheetState();
}

class _MenuReasonSheetState extends State<_MenuReasonSheet> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MNSheet(
          title: widget.strings.menuSaveTitle,
          titleStyle: OwnerStyle.text(context, 21, weight: 600),
          children: [
            MNTextField(
                label: widget.strings.changeReason,
                controller: _controller,
                autofocus: true,
                error: _error),
            const SizedBox(height: 16),
            MNButton(widget.strings.saveWorkflow, onPressed: () {
              final reason = _controller.text.trim();
              if (reason.length < 3) {
                setState(() => _error = widget.strings.reasonInvalid);
                return;
              }
              Navigator.pop(context, reason);
            }),
          ]);
}

class _MenuPriceSheet extends StatefulWidget {
  final String name;
  final int? amount;
  final Strings strings;
  const _MenuPriceSheet(
      {required this.name, required this.amount, required this.strings});
  @override
  State<_MenuPriceSheet> createState() => _MenuPriceSheetState();
}

class _MenuPriceSheetState extends State<_MenuPriceSheet> {
  late final _controller =
      TextEditingController(text: widget.amount?.toString() ?? '');
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MNSheet(children: [
        Text(widget.name, style: OwnerStyle.text(context, 21, weight: 600)),
        const SizedBox(height: 12),
        Text(widget.strings.menuPriceFallback,
            style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
        const SizedBox(height: 16),
        MNTextField(
            label: widget.strings.menuStationPrice,
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 16),
        MNButton(widget.strings.saveWorkflow,
            onPressed: () => Navigator.pop(context, _controller.text.trim())),
      ]);
}
