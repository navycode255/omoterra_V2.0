import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_assets.dart';
import '../../core/auth/office_session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/states.dart';
import 'asset_forms.dart';
import 'asset_providers.dart';
import 'owner_reference.dart';

/// Only the conditions that need attention get a status colour.
Color _conditionColor(String condition) => switch (condition) {
      'needs_maintenance' || 'under_repair' => MNColors.warning,
      'damaged' || 'unusable' => MNColors.error,
      _ => OwnerStyle.muted,
    };

OfficeSignedIn? _signedIn(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn ? auth : null;
}

String _tzs(Strings s, num value) =>
    '${s.ownerCurrency} ${groupDigits(value.round())}';

/// A pure date (`YYYY-MM-DD`) is shown as it is.
String _day(String? iso) =>
    iso == null ? '' : (iso.length >= 10 ? iso.substring(0, 10) : iso);

/// A timestamp (UTC; a missing zone means UTC) as its East Africa Time date.
String _stamp(String? iso) {
  if (iso == null) return '';
  final zoned = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(iso) ? iso : '${iso}Z';
  final moment = DateTime.tryParse(zoned);
  return moment == null ? _day(iso) : businessDateKey(moment);
}

/// Mali za biashara: the register, grouped by category, with a location
/// switch, search and (owner only) the register button.
class OfficeAssetsScreen extends ConsumerStatefulWidget {
  /// `?station=`: the kituo whose location is preselected.
  final String? stationId;
  const OfficeAssetsScreen({super.key, this.stationId});
  @override
  ConsumerState<OfficeAssetsScreen> createState() => _AssetsState();
}

class _AssetsState extends ConsumerState<OfficeAssetsScreen> {
  /// null: not chosen yet; '' : "Biashara yote".
  String? _picked;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The location asked for: a single location is fixed, otherwise the
  /// person's choice, otherwise the `?station=` preselection.
  String? _location(List<AssetLocation> locations) {
    if (locations.length == 1) return locations.first.id;
    final picked = _picked;
    if (picked != null) return picked.isEmpty ? null : picked;
    final station = widget.stationId;
    if (station == null) return null;
    for (final l in locations) {
      if (l.stationId == station) return l.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final profile = _signedIn(ref)?.profile;
    final values = profile?.canSeeAssetValues ?? false;
    final owner = profile?.isOwner ?? false;
    final locations =
        ref.watch(officeAssetLocationsProvider).valueOrNull ?? const [];
    final locationId = _location(locations);
    final filter = AssetFilter(locationId: locationId);
    final assets = ref.watch(officeAssetsProvider(filter));
    final needle = _search.text.trim().toLowerCase();
    List<Asset> shown(List<Asset> all) => needle.isEmpty
        ? all
        : [
            for (final a in all)
              if ('${a.name} ${a.number ?? ''} ${a.category.name}'
                  .toLowerCase()
                  .contains(needle))
                a
          ];
    final gap = SizedBox(height: OwnerStyle.px(context, 12));
    return OwnerPage(
        title: s.assetsTitle,
        strings: s,
        onRefresh: () async {
          ref.invalidate(officeAssetLocationsProvider);
          await ref
              .refresh(officeAssetsProvider(filter).future)
              .then((_) {}, onError: (_) {});
        },
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (locations.length > 1) ...[
                    MNSelectField<String>(
                        label: s.assetLocation,
                        value: locationId ?? '',
                        options: [
                          MNSelectOption(value: '', label: s.assetAllLocations),
                          for (final l in locations)
                            MNSelectOption(value: l.id, label: l.name),
                        ],
                        onChanged: (v) => setState(() => _picked = v)),
                    gap,
                  ],
                  MNTextField(
                      label: s.assetSearch,
                      controller: _search,
                      onChanged: (_) => setState(() {})),
                  gap,
                  OwnerAsyncView<List<Asset>>(
                      value: assets,
                      onRetry: () =>
                          ref.invalidate(officeAssetsProvider(filter)),
                      isEmpty: (rows) => rows.isEmpty,
                      empty: (_) => MNEmptyState(
                          icon: MNIconData.box, title: s.assetEmpty),
                      data: (all) => _Register(
                          assets: shown(all),
                          values: values,
                          showLocation: locationId == null)),
                  if (owner) ...[
                    gap,
                    MNButton(s.assetRegister,
                        onPressed: () => context.push(MNRoutes.officeAssetNew)),
                  ],
                ])));
  }
}

class _Register extends ConsumerWidget {
  final List<Asset> assets;
  final bool values, showLocation;
  const _Register(
      {required this.assets, required this.values, required this.showLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final groups = <String, List<Asset>>{};
    for (final a in assets) {
      groups.putIfAbsent(a.category.name, () => []).add(a);
    }
    final names = groups.keys.toList()..sort();
    num total = 0;
    for (final a in assets) {
      total += a.cost ?? 0;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (values)
        Padding(
            padding: EdgeInsets.only(
                left: OwnerStyle.px(context, 8),
                bottom: OwnerStyle.px(context, 4)),
            child: Text('${s.assetTotalCost}: ${_tzs(s, total)}',
                style: OwnerStyle.text(context, 17, weight: 700))),
      for (final name in names) ...[
        Padding(
            padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 10),
                OwnerStyle.px(context, 16), 0, OwnerStyle.px(context, 8)),
            child: Semantics(
                header: true,
                child: Text(name.toUpperCase(),
                    style: OwnerStyle.text(context, 12,
                        weight: 600, color: OwnerStyle.muted)))),
        OwnerCard(
            child: Column(children: [
          for (final (i, a) in (groups[name]!
                ..sort((x, y) => x.name.compareTo(y.name)))
              .indexed) ...[
            if (i > 0)
              Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: OwnerStyle.px(context, 16)),
                  child: const Divider(
                      height: 1, thickness: .7, color: OwnerStyle.line)),
            _AssetRow(asset: a, values: values, showLocation: showLocation),
          ],
        ])),
      ],
    ]);
  }
}

class _AssetRow extends ConsumerWidget {
  final Asset asset;
  final bool values, showLocation;
  const _AssetRow(
      {required this.asset, required this.values, required this.showLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final a = asset;
    final ident = (a.number ?? '').isNotEmpty
        ? a.number!
        : s.assetQuantityUnit(a.quantity, a.unit);
    final cost = values && a.cost != null ? _tzs(s, a.cost!) : null;
    return MNPressable(
        onTap: () => context.push(MNRoutes.officeAsset(a.id)),
        pressedScale: 1,
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: u(64)),
            child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: u(16), vertical: u(12)),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(a.name,
                            style: OwnerStyle.text(context, 17,
                                weight: 500, spacing: -.55)),
                        Text(
                            showLocation
                                ? '$ident · ${a.location.name}'
                                : ident,
                            style: OwnerStyle.text(context, 12.5,
                                color: OwnerStyle.muted)),
                        Text(s.conditionLabel(a.condition),
                            style: OwnerStyle.text(context, 12.5,
                                color: _conditionColor(a.condition))),
                      ])),
                  if (cost != null) ...[
                    SizedBox(width: u(8)),
                    Text(cost,
                        textAlign: TextAlign.end,
                        style: OwnerStyle.text(context, 14, weight: 400)),
                  ],
                  SizedBox(width: u(12)),
                  const OwnerGlyph('chevron', size: 12),
                ]))));
  }
}

/// One asset: details, purchases and history, and the owner's buttons.
class OfficeAssetScreen extends ConsumerWidget {
  final String id;
  const OfficeAssetScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(officeAssetProvider(id));
    final err = value.error;
    final gone = err is AssetError &&
        (err.code == 'not_found' || err.code == 'forbidden');
    return OwnerPage(
        title: s.assetsTitle,
        strings: s,
        onRefresh: () async {
          await ref
              .refresh(officeAssetProvider(id).future)
              .then((_) {}, onError: (_) {});
        },
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: gone
                ? MNNote(s.assetNotFound, tone: MNNoteTone.info)
                : OwnerAsyncView<Asset>(
                    value: value,
                    onRetry: () => ref.invalidate(officeAssetProvider(id)),
                    data: (asset) => _Detail(asset: asset))));
  }
}

class _Detail extends ConsumerWidget {
  final Asset asset;
  const _Detail({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profile = _signedIn(ref)?.profile;
    final values = profile?.canSeeAssetValues ?? false;
    final owner = profile?.isOwner ?? false;
    final a = asset;
    final gap = SizedBox(height: OwnerStyle.px(context, 12));
    final history = [...a.history]
      ..sort((x, y) => (y.recordedAt ?? '').compareTo(x.recordedAt ?? ''));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.only(left: OwnerStyle.px(context, 8)),
          child:
              Text(a.name, style: OwnerStyle.text(context, 22, weight: 700))),
      gap,
      _Card(lines: [
        (s.assetCategory, a.category.name),
        if ((a.number ?? '').isNotEmpty) (s.assetNumber, a.number!),
        (s.assetQuantity, '${a.quantity}'),
        if (a.unit.isNotEmpty) (s.assetUnit, a.unit),
        (s.assetLocation, a.location.name),
        if ((a.area ?? '').isNotEmpty) (s.assetArea, a.area!),
        if (a.custodian != null && a.custodian!.name.isNotEmpty)
          (s.assetCustodian, a.custodian!.name),
        (s.assetCondition, s.conditionLabel(a.condition)),
        (s.assetStatus, s.assetStatusLabel(a.status)),
        if (values && a.cost != null) (s.assetTotalCost, _tzs(s, a.cost!)),
        if ((a.notes ?? '').isNotEmpty) (s.assetNotes, a.notes!),
      ]),
      if (a.lots.isNotEmpty) ...[
        _Heading(s.assetLots),
        for (final lot in a.lots)
          Padding(
              padding: EdgeInsets.only(bottom: OwnerStyle.px(context, 10)),
              child: _Card(lines: [
                if (lot.opening) (s.assetOpeningItem, ''),
                if (lot.purchaseDate != null)
                  (s.assetPurchaseDate, _day(lot.purchaseDate)),
                if ((lot.supplier ?? '').isNotEmpty)
                  (s.assetSupplier, lot.supplier!),
                if ((lot.reference ?? '').isNotEmpty)
                  (s.assetReference, lot.reference!),
                (s.assetQuantity, '${lot.quantity}'),
                if (values && lot.unitPrice != null)
                  (
                    lot.opening ? s.assetOpeningValue : s.assetUnitPrice,
                    _tzs(s, lot.unitPrice!)
                  ),
                if (values && !lot.opening && lot.totalCost != null)
                  (s.assetTotalCost, _tzs(s, lot.totalCost!)),
              ])),
      ],
      if (history.isNotEmpty) ...[
        _Heading(s.assetHistory),
        for (final h in history)
          Padding(
              padding: EdgeInsets.only(bottom: OwnerStyle.px(context, 10)),
              child: _Card(lines: [
                (s.assetChangeLabel(h.change), _historyValue(s, h)),
                if ((h.reason ?? '').isNotEmpty) (s.assetReason, h.reason!),
                if (h.recordedBy.isNotEmpty)
                  (h.recordedBy, _stamp(h.recordedAt)),
                if (h.recordedBy.isEmpty && h.recordedAt != null)
                  ('', _stamp(h.recordedAt)),
              ])),
      ],
      if (owner) ...[
        gap,
        MNButton(s.assetChange,
            onPressed: () => showAssetChangeSheet(context, ref, a)),
        if (a.tracking != 'numbered') ...[
          SizedBox(height: OwnerStyle.px(context, 8)),
          MNButton.secondary(s.assetAddPurchase,
              onPressed: () => showAssetPurchaseSheet(context, ref, a)),
        ],
        SizedBox(height: OwnerStyle.px(context, 8)),
        MNButton.secondary(s.assetEditDetails,
            onPressed: () => showAssetDetailsSheet(context, ref, a)),
      ],
    ]);
  }

  /// The value a history row records for its kind of change.
  String _historyValue(Strings s, AssetHistoryEntry h) => switch (h.change) {
        'quantity' || 'purchase' => '${h.quantity}',
        'condition' => s.conditionLabel(h.condition),
        'area' => h.area ?? '',
        'custodian' => h.custodian?.name ?? '',
        'location' => h.location.name,
        _ => '${s.conditionLabel(h.condition)} · ${h.location.name}',
      };
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 8),
          OwnerStyle.px(context, 16), 0, OwnerStyle.px(context, 8)),
      child: Semantics(
          header: true,
          child: Text(text, style: OwnerStyle.text(context, 17, weight: 700))));
}

/// Label and value lines in an office card. An empty value shows the label
/// alone; an empty label shows the value alone.
class _Card extends StatelessWidget {
  final List<(String, String)> lines;
  const _Card({required this.lines});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (label, value) in lines)
              Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: OwnerStyle.px(context, 2)),
                  child: Text(
                      value.isEmpty
                          ? label
                          : label.isEmpty
                              ? value
                              : '$label: $value',
                      style: OwnerStyle.text(context, 15))),
          ])));
}
