import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/number_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'people_screens.dart';
import 'product_screens.dart';
import 'supply_request_screens.dart' show supplyLinkableProvider;

Future<T> _receiving<T>(OfficeSessionController session,
        Future<T> Function(OfficeReceivingRepository) call) =>
    session.guard((repository) {
      if (repository is! OfficeReceivingRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return call(repository as OfficeReceivingRepository);
    });
final receivingLocationsProvider = FutureProvider.autoDispose((ref) =>
    _receiving(ref.read(officeSessionProvider.notifier),
        (r) => r.receivingLocations()));
final receivingLotsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) => _receiving(
        ref.read(officeSessionProvider.notifier), (r) => r.receivingLots(id)));

/// Short delivery note shown to staff: DN-1A2B3C4D from the client UUID.
String deliveryReference(String clientId) {
  final compact = clientId.replaceAll('-', '').toUpperCase();
  final short = compact.length <= 8 ? compact : compact.substring(0, 8);
  return 'DN-$short';
}

/// One product on the delivery. A transfer line names only the product:
/// the oldest owned lots at the source are dispatched first when saving.
class _DeliveryLine {
  final String product;
  int quantity = 1;
  final price = TextEditingController();
  _DeliveryLine(this.product);
  void dispose() => price.dispose();
}

/// Whole units on hand per product code at the source (lots oldest first).
Map<String, List<(Map<String, dynamic>, int)>> _lotsByProduct(
    List<Map<String, dynamic>> lots) {
  final rows = [...lots]
    ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
  final result = <String, List<(Map<String, dynamic>, int)>>{};
  for (final lot in rows) {
    final whole = (num.tryParse('${lot['quantity']}') ?? 0).floor();
    if (whole > 0) {
      result.putIfAbsent('${lot['product']}', () => []).add((lot, whole));
    }
  }
  return result;
}

/// A purchase creates an expected receipt. A transfer dispatches existing
/// owned lots to transit; the receiving vendor must still confirm arrival.
class OfficeDeliveryForm extends ConsumerStatefulWidget {
  final String stationId;

  /// The receiving station's own stock; never offered as a transfer source.
  final String? destinationLocationId;
  const OfficeDeliveryForm(
      {super.key, required this.stationId, this.destinationLocationId});
  @override
  ConsumerState<OfficeDeliveryForm> createState() => _OfficeDeliveryFormState();
}

class _OfficeDeliveryFormState extends ConsumerState<OfficeDeliveryForm> {
  static const _purchaseMax = 999999;
  final _clientId = const Uuid().v4();
  late final _reference =
      TextEditingController(text: deliveryReference(_clientId));
  final _sender = TextEditingController(), _agreement = TextEditingController();
  final _lines = <_DeliveryLine>[];
  String? _mode, _source, _title, _error, _requestId;
  String? _invalid; // the field the last save attempt found missing
  late DateTime _day = businessDate(ref.read(clockProvider)());
  Map<String, dynamic>? _attempt;
  bool _busy = false;
  bool _unrecorded = false;
  bool get _locked => _busy || _attempt != null;

  bool get _canAddLine =>
      !_locked &&
      _lines.length < 200 &&
      _mode != null &&
      (_mode != 'B' || _source != null);

  @override
  void dispose() {
    _reference.dispose();
    _sender.dispose();
    _agreement.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// The short error shown on [field] after a refused save attempt.
  String? _fieldError(String field) => _invalid == field ? _error : null;

  void _edited(String _) {
    if (_invalid != null) {
      setState(() {
        _invalid = null;
        _error = null;
      });
    }
  }

  void _clearLines() {
    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();
  }

  Future<void> _save(List<Map<String, dynamic>> lots,
      List<Map<String, dynamic>> locations) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    if (_attempt == null) {
      final source = locations.where((r) => r['id'] == _source).firstOrNull;
      // Name the first missing field, and mark it, instead of one generic
      // message: on a long delivery the field can be far off screen.
      final (String, String)? missing = _mode == null
          ? ('kind', s.officeFieldNeeded(s.officeDeliveryKind, 0))
          : _reference.text.trim().length < 2
              ? ('reference', s.officeFieldNeeded(s.reference, 2))
              : _mode == 'P' && _sender.text.trim().length < 3
                  ? ('sender', s.officeFieldNeeded(s.officePreparedBy, 3))
                  : _mode == 'P' && !_unrecorded
                      ? ('declaration', s.officePreparedDeclarationNeeded)
                      : _mode == 'A' && _sender.text.trim().length < 2
                          ? ('sender', s.officeFieldNeeded(s.sentFrom, 2))
                          : _mode == 'A' && _agreement.text.trim().length < 2
                              ? (
                                  'agreement',
                                  s.officeFieldNeeded(
                                      s.officeAgreementReference, 2)
                                )
                              : _mode == 'A' && _title == null
                                  ? (
                                      'title',
                                      s.officeFieldNeeded(
                                          s.officeTitleTransfer, 0)
                                    )
                                  : _mode == 'B' && source == null
                                      ? ('source', s.officeChooseSourceFirst)
                                      : null;
      if (missing != null) {
        setState(() {
          _invalid = missing.$1;
          _error = missing.$2;
        });
        return;
      }
      final lines = <Map<String, dynamic>>[];
      final stock = _lotsByProduct(lots);
      for (final line in _lines) {
        final price = line.price.text.trim().isEmpty
            ? null
            : int.tryParse(line.price.text);
        if (line.quantity <= 0 ||
            (_mode != 'B' &&
                (line.quantity > _purchaseMax ||
                    (line.price.text.isNotEmpty &&
                        (price == null || price > 100000000))))) {
          setState(() => _error = s.officeDeliveryLineInvalid);
          return;
        }
        if (_mode != 'B') {
          lines.add({
            'product': line.product,
            'quantity': line.quantity,
            'agreed_unit_price': _mode == 'P' ? null : price
          });
          continue;
        }
        var left = line.quantity;
        for (final (lot, whole)
            in stock[line.product] ?? const <(Map<String, dynamic>, int)>[]) {
          if (left == 0) break;
          final take = left < whole ? left : whole;
          lines.add({
            'product': line.product,
            'quantity': take,
            'source_lot_id': '${lot['lot_id']}',
            'source_location_id': _source
          });
          left -= take;
        }
        if (left > 0) {
          setState(() => _error = s.officeDeliveryLineInvalid);
          return;
        }
      }
      if (lines.isEmpty || lines.length > 200) {
        setState(() => _error = s.officeDeliveryLineInvalid);
        return;
      }
      _attempt = {
        'client_id': _clientId,
        'station_id': widget.stationId,
        'arrangement': _mode == 'P' ? 'prepared_locally' : _mode,
        if (_mode == 'P') 'intake_kind': 'prepared_locally',
        if (_mode == 'P') 'prepared_note': _sender.text.trim(),
        if (_mode == 'P') 'unrecorded_stock': _unrecorded,
        'reference': _reference.text.trim(),
        'sender': _mode != 'B' ? _sender.text.trim() : source!['name'],
        'expected_date': _day.toIso8601String().substring(0, 10),
        'lines': lines,
        if (_mode == 'A') 'agreement_reference': _agreement.text.trim(),
        if (_mode == 'A') 'title_transfer': _title,
        if (_mode == 'A' && _requestId != null)
          'supply_request_id': _requestId,
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final yes = await showMNConfirmDialog(context,
          title: s.officeNewDelivery,
          message: _mode == 'P'
              ? s.officePreparedConfirm
              : _mode == 'B'
                  ? s.officeTransferConfirm
                  : s.officePurchaseConfirm,
          confirmLabel: s.saveWorkflow,
          cancelLabel: s.cancel);
      if (!yes) {
        _attempt = null;
        return;
      }
      final result = await _receiving(ref.read(officeSessionProvider.notifier),
          (r) => r.createExpectedDelivery(_attempt!));
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final message = e is OfficeError && e.kind == OfficeErrorKind.invalid
              ? s.detailsInvalid
              : officeErrorText(s, e);
          if (e is OfficeError || e is SupplyError) {
            _attempt = null; // A definite server refusal committed no delivery.
            _error = message;
          } else {
            _error = '$message\n${s.officeDeliveryRetry}';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Registered products to choose from. A transfer shows what the source
  /// holds and greys out products it has none of.
  List<MNSelectOption<String>> _productOptions(
      Strings s, List<OfficeProduct> products, Map<String, int>? available) {
    final options = <MNSelectOption<String>>[];
    final listed = <String>{};
    for (final p in products.where((p) => p.status == 'active')) {
      listed.add(p.code);
      final added = _lines.any((l) => l.product == p.code);
      final here = available?[p.code] ?? 0;
      options.add(MNSelectOption(
          value: p.code,
          label: p.name,
          image: ownerProductImage(p),
          enabled: !added && (available == null || here > 0),
          caption: added
              ? s.officeAlreadyAdded
              : available == null
                  ? s.unitName(p.unit)
                  : here > 0
                      ? s.officeAvailableHere('$here ${s.unitName(p.unit)}')
                      : s.officeNoneHere));
    }
    final auth = ref.read(officeSessionProvider).valueOrNull;
    if (_mode != 'B' &&
        auth is OfficeSignedIn &&
        auth.profile.canManagePeople) {
      options.add(
          MNSelectOption(value: '+', label: s.ownerAddProduct, action: true));
    }
    return options;
  }

  Future<void> _addProduct(
      Strings s, List<MNSelectOption<String>> options, bool loading) async {
    final picked = await showMNSelectSheet<String>(context,
        title: s.officeChooseProduct,
        options: options,
        emptyText: loading ? s.loading : s.noOfficeProducts);
    if (picked?.value == '+' && mounted) {
      final product = await Navigator.of(context).push<OfficeProduct>(
          MaterialPageRoute(
              builder: (_) =>
                  const OfficeNewProductScreen(returnCreated: true)));
      if (product != null && mounted) {
        setState(() => _lines.add(_DeliveryLine(product.code)));
      }
      return;
    }
    if (picked != null && mounted) {
      setState(() {
        _lines.add(_DeliveryLine(picked.value));
        _error = null;
      });
    }
  }

  Widget _lineRow({
    required Strings s,
    required int index,
    required _DeliveryLine line,
    required OfficeProduct? product,
    required int max,
  }) {
    final name = product?.name ?? line.product;
    void set(int v) => setState(() {
          if (v == 0) {
            _lines.remove(line);
            line.dispose();
          } else {
            line.quantity = v;
          }
        });
    return Container(
      key: ValueKey(line),
      padding: const EdgeInsets.symmetric(
          horizontal: MNSpace.x3, vertical: MNSpace.x3 - 2),
      decoration: BoxDecoration(
          border: index == 0
              ? null
              : const Border(top: BorderSide(color: MNColors.cardBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            MNProductImage.thumb(
                image: product == null ? null : ownerProductImage(product)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  MNPressable(
                      semanticLabel: s.quantityFor(name),
                      onTap: _locked
                          ? null
                          : () async {
                              final v = await showNumberSheet(context,
                                  title: s.quantityFor(name),
                                  initial: line.quantity,
                                  max: max);
                              if (v != null && mounted) set(v);
                            },
                      child: Text(name,
                          style: MNText.resolve(context, MNText.body))),
                  if (product != null)
                    Text(
                        _mode == 'B'
                            ? s.officeAvailableHere(
                                '$max ${s.unitName(product.unit)}')
                            : s.unitName(product.unit),
                        style: MNText.resolve(context, MNText.meta)),
                  if (product?.unit == 'kg')
                    Text(s.officeKgReceiptHelp,
                        style: MNText.resolve(context, MNText.meta)),
                  const SizedBox(height: 4),
                  MNQuantitySelector(
                      value: line.quantity,
                      min: 0,
                      max: max,
                      itemLabel: name,
                      onChanged: _locked ? (_) {} : set),
                ])),
          ]),
          if (_mode == 'A') ...[
            const SizedBox(height: MNSpace.x3),
            MNTextField(
                label: s.officePurchaseUnitPrice,
                controller: line.price,
                enabled: !_locked,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(officeProductsProvider);
    final locations =
        _mode == 'B' ? ref.watch(receivingLocationsProvider) : null;
    final lots =
        _source == null ? null : ref.watch(receivingLotsProvider(_source!));
    final sourceRows = locations?.valueOrNull ?? <Map<String, dynamic>>[];
    final lotRows = lots?.valueOrNull ?? <Map<String, dynamic>>[];
    final productRows = products.valueOrNull ?? <OfficeProduct>[];
    final byCode = {for (final p in productRows) p.code: p};
    final available = _mode == 'B'
        ? {
            for (final e in _lotsByProduct(lotRows).entries)
              e.key: e.value.fold<int>(0, (sum, r) => sum + r.$2)
          }
        : null;
    final sourceOptions = [
      for (final row in sourceRows.where((r) =>
          r['active'] == true &&
          '${r['id']}' != widget.destinationLocationId &&
          !const {'in_transit', 'transit'}.contains(r['kind'])))
        MNSelectOption(value: '${row['id']}', label: '${row['name']}')
    ];
    final noSources =
        _mode == 'B' && locations?.hasValue == true && sourceOptions.isEmpty;
    final loadingProducts =
        products.isLoading || (_mode == 'B' && lots?.isLoading == true);
    return MNSheet(title: s.officeNewDelivery, children: [
      MNSelectField<String>(
          label: s.officeDeliveryKind,
          value: _mode,
          options: [
            MNSelectOption(value: 'P', label: s.officePrepared),
            MNSelectOption(value: 'A', label: s.officePurchase),
            MNSelectOption(value: 'B', label: s.officeTransfer),
          ],
          onChanged: _locked
              ? null
              : (value) => setState(() {
                    if (value != _mode) _clearLines();
                    _mode = value;
                    _unrecorded = false;
                    final today = businessDate(ref.read(clockProvider)());
                    if (value == 'P' && _day.isAfter(today)) _day = today;
                    _source = null;
                    _requestId = null;
                  })),
      if (_mode == 'P')
        Text('${s.reference}: ${_reference.text}',
            style: MNText.resolve(context, MNText.meta))
      else
        MNTextField(label: s.reference, controller: _reference, enabled: false),
      if (_mode == 'A') ...[
        MNTextField(
            label: s.sentFrom,
            controller: _sender,
            enabled: !_locked,
            error: _fieldError('sender'),
            onChanged: _edited),
        MNTextField(
            label: s.officeAgreementReference,
            controller: _agreement,
            enabled: !_locked,
            error: _fieldError('agreement'),
            onChanged: _edited),
        MNSelectField<String>(
            label: s.officeTitleTransfer,
            value: _title,
            options: [
              MNSelectOption(
                  value: 'on_accepted_receipt', label: s.officeTitleAtReceipt),
              MNSelectOption(value: 'later', label: s.officeTitleLater),
            ],
            onChanged:
                _locked ? null : (value) => setState(() => _title = value)),
        MNSelectField<String>(
            label: s.supplyPickRequest,
            value: _requestId ?? '',
            emptyText: s.supplyPickEmpty,
            options: [
              MNSelectOption(value: '', label: s.supplyNoRequest),
              for (final r in ref
                      .watch(supplyLinkableProvider(widget.stationId))
                      .valueOrNull ??
                  const <SupplyRequest>[])
                MNSelectOption(
                    value: r.id,
                    label:
                        '${r.requesterName.isEmpty ? '' : '${r.requesterName} · '}${formatTsh(r.advance?.amount ?? r.estimatedTotal)}',
                    caption: s.supplyStatus(r.status)),
            ],
            onChanged: _locked
                ? null
                : (value) =>
                    setState(() => _requestId = value.isEmpty ? null : value)),
      ],
      if (_mode == 'B') ...[
        if (locations?.hasError == true)
          MNNote(officeErrorText(s, locations!.error!), error: true),
        MNSelectField<String>(
            label: s.officeSourceLocation,
            value: _source,
            emptyText: locations?.isLoading == true ? s.loading : null,
            options: sourceOptions,
            onChanged: _locked || noSources
                ? null
                : (value) => setState(() {
                      if (value != _source) _clearLines();
                      _source = value;
                    })),
        if (lots?.hasError == true)
          MNNote(officeErrorText(s, lots!.error!), error: true),
        if (_source != null && lots?.hasValue == true && lotRows.isEmpty)
          MNNote(s.officeNoTransferStock),
      ],
      MNFieldButton(
          label: s.officeHandoverDate,
          text: s.date(_day),
          placeholder: s.date(_day),
          icon: MNIconData.calendar,
          onTap: _locked
              ? null
              : () async {
                  final date = await showMNDateSheet(context,
                      title: s.officeHandoverDate,
                      initial: _day,
                      first: DateTime.utc(2020),
                      last: _mode == 'P'
                          ? businessDate(ref.read(clockProvider)())
                          : businessDate(ref.read(clockProvider)())
                              .add(const Duration(days: 365)));
                  if (date != null && mounted) {
                    setState(() =>
                        _day = DateTime.utc(date.year, date.month, date.day));
                  }
                }),
      if (_mode == null)
        MNNote(s.officePickSourceFirst, tone: MNNoteTone.info)
      else ...[
        Semantics(
            header: true,
            child: Text(s.officeDeliveryProducts,
                style: MNText.resolve(context, MNText.title))),
        if (products.hasError)
          MNNote(officeErrorText(s, products.error!), error: true),
        if (noSources)
          MNNote(s.officeNoTransferSources)
        else if (_mode == 'B' && _source == null)
          MNNote(s.officeChooseSourceFirst, tone: MNNoteTone.info)
        else if (_lines.isEmpty)
          Text(s.officeNoDeliveryProducts,
              style: MNText.resolve(context, MNText.meta))
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: MNColors.white,
                borderRadius: BorderRadius.circular(MNRadius.medium),
                border: Border.all(color: MNColors.cardBorder)),
            child: Column(children: [
              for (final (i, line) in _lines.indexed)
                _lineRow(
                    s: s,
                    index: i,
                    line: line,
                    product: byCode[line.product],
                    max: _mode == 'B'
                        ? (available?[line.product] ?? line.quantity)
                        : _purchaseMax),
            ]),
          ),
        MNButton.secondary(s.addMore,
            onPressed: _canAddLine
                ? () => _addProduct(s,
                    _productOptions(s, productRows, available), loadingProducts)
                : null),
      ],
      if (_mode == 'P') ...[
        // Next to the declaration and Hifadhi, so it is on screen when the
        // person saves (it used to sit at the top, off screen on long lists).
        MNTextField(
            label: s.officePreparedBy,
            controller: _sender,
            enabled: !_locked,
            error: _fieldError('sender'),
            onChanged: _edited,
            inputFormatters: [LengthLimitingTextInputFormatter(150)]),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(s.officePreparedDeclaration,
                style: MNText.resolve(context, MNText.secondary)),
            value: _unrecorded,
            onChanged: _locked
                ? null
                : (v) => setState(() => _unrecorded = v ?? false)),
        Text(s.officePreparedHelp, style: MNText.resolve(context, MNText.meta)),
      ],
      if (_error != null) MNNote(_error!, error: true),
      MNButton(_attempt == null ? s.saveWorkflow : s.retry,
          busy: _busy,
          onPressed: _busy ||
                  _mode == null ||
                  _lines.isEmpty ||
                  (_mode == 'P' && !_unrecorded)
              ? null
              : () => _save(lotRows, sourceRows)),
    ]);
  }
}
