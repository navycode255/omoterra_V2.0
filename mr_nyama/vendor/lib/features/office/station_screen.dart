import 'dart:typed_data';

import 'owner_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/format.dart';
import '../../core/media/photo_cache.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/image_spinner.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/select_field.dart';
import 'owner_reference.dart';
import 'people_screens.dart';
import 'removal_sheet.dart';
import 'product_screens.dart';
import '../../shared/widgets/icon.dart';
import '../../core/theme/icon_data.dart';
import 'credit_screens.dart' show officeCreditCustomersProvider;
import 'delivery_form.dart';
import 'stock_screens.dart' show stockAccess;
import '../../shared/widgets/pressable.dart';

Future<T> stationGuard<T>(
        WidgetRef ref, Future<T> Function(StationManagementRepository) work) =>
    ref.read(officeSessionProvider.notifier).guard((repo) {
      if (repo is! StationManagementRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as StationManagementRepository);
    });

final stationStockProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) => ref
        .read(officeSessionProvider.notifier)
        .guard(
            (repo) => (repo as StationManagementRepository).stationStock(id)));
final stationManifestsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) => ref
        .read(officeSessionProvider.notifier)
        .guard((repo) =>
            (repo as StationManagementRepository).stationManifests(id)));

/// How a station's photo link becomes an image; replaceable in widget tests.
final stationImageProvider =
    Provider<ImageProvider Function(String)>((ref) => CachedPhoto.new);

/// A station, to the owner-approved reference (30 October 2026): its photo
/// (or the place to add one), name and code, then information, people, menu,
/// stock and delete. Credit customers, performance and expected deliveries
/// live on the Stock page ([StationStockLinks]).
class OfficeStationScreen extends ConsumerWidget {
  final String stationId;
  const OfficeStationScreen({super.key, required this.stationId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final stations = ref.watch(officeStationsProvider);
    final station =
        stations.valueOrNull?.where((x) => x.id == stationId).firstOrNull;
    return OwnerPage(
        title: station?.name ?? s.stations,
        strings: s,
        headingSize: 32,
        contentGap: 20,
        backSize: 24,
        header: station == null ? null : _StationHeader(station: station),
        onRefresh: () async {
          ref.invalidate(officeVendorsProvider);
          ref.invalidate(officeStaffProvider);
          if (station?.stockLocationId != null) {
            ref.invalidate(stationStockProvider(station!.stockLocationId!));
          }
          ref.invalidate(officeStationsProvider);
          await ref.read(officeStationsProvider.future);
        },
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 20)),
            child: OwnerAsyncView(
                value: stations,
                onRetry: () => ref.invalidate(officeStationsProvider),
                data: (_) => station == null
                    ? MNNote(s.noStations)
                    : _StationDetails(station: station))));
  }
}

class _StationHeader extends ConsumerStatefulWidget {
  final OfficeStation station;
  const _StationHeader({required this.station});
  @override
  ConsumerState<_StationHeader> createState() => _StationHeaderState();
}

class _StationHeaderState extends ConsumerState<_StationHeader> {
  bool _busy = false;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save(
      Future<void> Function(StationManagementRepository) work) async {
    setState(() => _busy = true);
    try {
      await stationGuard(ref, work);
      ref.invalidate(officeStationsProvider);
      await ref.read(officeStationsProvider.future);
    } catch (e) {
      if (mounted) {
        _toast(e is OfficeError
            ? officeErrorText(ref.read(stringsProvider), e)
            : ref.read(stringsProvider).stationPhotoFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    final Uint8List? bytes;
    try {
      bytes = await ref.read(pickProductPhotoProvider)();
    } catch (_) {
      _toast(ref.read(stringsProvider).stationPhotoFailed);
      return;
    }
    if (bytes == null || !mounted) return;
    final chosen = bytes;
    await _save((r) => r.uploadStationPhoto(widget.station.id, chosen));
  }

  Future<void> _options() async {
    final s = ref.read(stringsProvider);
    await showMNSheet<void>(context,
        builder: (sheet) => MNSheet(title: s.stationPhotoOptions, children: [
              OwnerCard(
                  child: _stationDivided([
                OwnerMenuRow(
                    label: s.stationPhotoChange,
                    onTap: () {
                      Navigator.pop(sheet);
                      _pick();
                    }),
                OwnerMenuRow(
                    label: s.stationPhotoRemove,
                    labelColor: OwnerStyle.red,
                    onTap: () {
                      Navigator.pop(sheet);
                      _save((r) => r.removeStationPhoto(widget.station.id));
                    }),
              ])),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final station = widget.station;
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final manage = auth is OfficeSignedIn && auth.profile.canManagePeople;
    double u(double n) => OwnerStyle.px(context, n);
    final url = station.imageUrl;
    final empty = _StationPhotoEmpty(
        label: manage ? s.stationPhotoAdd : null, onTap: manage ? _pick : null);
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: u(20)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              height: u(176),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(u(17)),
                  child: Stack(fit: StackFit.expand, children: [
                    if (url == null)
                      empty
                    else
                      ColoredBox(
                          color: OwnerStyle.stationPhotoEmpty,
                          child: MNLoadingImage(
                              image: ref.watch(stationImageProvider)(url),
                              onDark: false,
                              error: empty)),
                    if (url != null && manage)
                      Positioned(
                          top: u(5),
                          right: u(5),
                          child: _StationPhotoMenuButton(
                              label: s.stationPhotoOptions,
                              onTap: _busy ? null : _options)),
                    if (_busy)
                      const ColoredBox(
                          color: OwnerStyle.stationPhotoBusy,
                          child: Center(
                              child: MNImageSpinner(size: 36, onDark: false))),
                  ]))),
          SizedBox(height: u(5)),
          Semantics(
              header: true,
              child: Text(station.name,
                  style: OwnerStyle.text(context, 31.5,
                      weight: 700, height: 1.23, spacing: -.5))),
          SizedBox(height: u(3)),
          Text('${s.station} ${station.code}',
              style: OwnerStyle.text(context, 20, color: OwnerStyle.muted)),
        ]));
  }
}

/// The reference's grey "Add photo" panel; without [label] it only marks
/// the place of a photo for someone who may not add one.
class _StationPhotoEmpty extends StatelessWidget {
  final String? label;
  final VoidCallback? onTap;
  const _StationPhotoEmpty({this.label, this.onTap});
  @override
  Widget build(BuildContext context) => MNPressable(
      onTap: onTap,
      pressedScale: 1,
      semanticLabel: label,
      color: OwnerStyle.stationPhotoEmpty,
      pressedColor: OwnerStyle.line,
      child: Padding(
          padding: EdgeInsets.only(top: OwnerStyle.px(context, 16)),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const OwnerGlyph('shop', size: 64),
            if (label != null) ...[
              SizedBox(height: OwnerStyle.px(context, 8)),
              Text(label!,
                  style: OwnerStyle.text(context, 19.5,
                      color: OwnerStyle.stationPhotoHint)),
            ],
          ]))));
}

class _StationPhotoMenuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _StationPhotoMenuButton({required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
                padding: EdgeInsets.all(u(6)),
                child: Container(
                    width: u(42),
                    height: u(42),
                    decoration: const BoxDecoration(
                        color: OwnerStyle.white, shape: BoxShape.circle),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) SizedBox(width: u(3.5)),
                            Container(
                                width: u(4),
                                height: u(4),
                                decoration: const BoxDecoration(
                                    color: OwnerStyle.ink,
                                    shape: BoxShape.circle)),
                          ]
                        ])))));
  }
}

/// A row of the station's cards, at the reference's sizes.
class _StationRow extends StatelessWidget {
  final String label;
  final String? icon, value, subtitle;
  final double height, subtitleSize, leftPadding;
  final Color labelColor, valueColor;
  final bool showChevron;
  final VoidCallback? onTap;
  const _StationRow(
      {required this.label,
      this.icon,
      this.value,
      this.subtitle,
      this.height = 70,
      this.subtitleSize = 14,
      this.leftPadding = 18,
      this.labelColor = OwnerStyle.ink,
      this.valueColor = OwnerStyle.muted,
      this.showChevron = true,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    return MNPressable(
        onTap: onTap,
        pressedScale: 1,
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: u(height)),
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    u(icon == null ? leftPadding : 24),
                    u(subtitleSize < 14 ? 20 : 12),
                    u(subtitleSize < 14 ? 8 : 16),
                    u(12)),
                child: Row(
                    crossAxisAlignment: subtitleSize < 14
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        SizedBox(
                            width: u(30), child: OwnerGlyph(icon!, size: 30)),
                        SizedBox(width: u(26)),
                      ],
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(label,
                                style: OwnerStyle.text(context, 17,
                                    color: labelColor, spacing: -.7)),
                            if (subtitle != null) ...[
                              SizedBox(height: u(4)),
                              Text(subtitle!,
                                  style: OwnerStyle.text(context, subtitleSize,
                                      color: OwnerStyle.muted,
                                      spacing: subtitleSize < 14 ? -.35 : -.2,
                                      height: subtitleSize < 14 ? 1.55 : 1.35)),
                            ],
                          ])),
                      if (value != null) ...[
                        SizedBox(width: u(8)),
                        ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: u(230)),
                            child: Text(value!,
                                textAlign: TextAlign.end,
                                style: OwnerStyle.text(context, 15,
                                    color: valueColor, spacing: -.7))),
                      ],
                      if (showChevron) ...[
                        SizedBox(width: u(subtitleSize < 14 ? 6 : 12)),
                        const OwnerGlyph('vendor-chevron',
                            size: 20, color: OwnerStyle.stationChevron),
                      ],
                    ]))));
  }
}

class _StationDetails extends ConsumerWidget {
  final OfficeStation station;
  const _StationDetails({required this.station});
  void refresh(WidgetRef ref) {
    ref.invalidate(officeStationsProvider);
    ref.invalidate(officeVendorsProvider);
    ref.invalidate(officeStaffProvider);
    if (station.stockLocationId != null) {
      ref.invalidate(stationStockProvider(station.stockLocationId!));
    }
  }

  Future<void> form(
      BuildContext context,
      WidgetRef ref,
      String title,
      List<(String, String)> fields,
      Future<void> Function(List<String>) save) async {
    final done = await showMNSheet<bool>(context,
        builder: (_) => _StationForm(title: title, fields: fields, save: save));
    if (done == true) refresh(ref);
  }

  Future<void> assign(BuildContext context, WidgetRef ref, bool vendor) async {
    final done = await showMNSheet<bool>(context,
        builder: (_) => _AssignStationPerson(station: station, vendor: vendor));
    if (done == true) refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final vendors = ref.watch(officeVendorsProvider);
    final staff = ref.watch(officeStaffProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final manage = auth is OfficeSignedIn && auth.profile.canManagePeople;
    final canViewStock = stockAccess(ref).view;
    final stock = !canViewStock || station.stockLocationId == null
        ? null
        : ref.watch(stationStockProvider(station.stockLocationId!));
    Widget gap() => SizedBox(height: OwnerStyle.px(context, 24));
    Future<void> edit() => form(
        context,
        ref,
        s.stationEdit,
        [
          (s.stationName, station.name),
          (s.stationArea, station.area),
          (s.stationAddress, station.address),
          (s.changeReason, '')
        ],
        (v) => stationGuard(
            ref,
            (r) => r.updateStation(station.id,
                name: v[0], area: v[1], address: v[2], reason: v[3])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _stationHeading(context, s.stationInformation),
      OwnerCard(
          child: _stationDivided([
        _StationRow(
            label: s.stationArea,
            value: station.area.isEmpty ? s.stationUnset : station.area,
            onTap: manage ? edit : null,
            showChevron: manage),
        _StationRow(
            label: s.stationAddress,
            value: station.address.isEmpty ? s.stationUnset : station.address,
            onTap: manage ? edit : null,
            showChevron: manage),
      ])),
      SizedBox(height: OwnerStyle.px(context, 9)),
      _stationHeading(context, s.stationPeople,
          actionLabel: s.stationAdd,
          action: manage
              ? () => showMNSheet<void>(context,
                  builder: (sheetContext) => MNSheet(children: [
                        Row(children: [
                          Expanded(
                              child: Text(s.stationAssignPerson,
                                  style: OwnerStyle.text(context, 21,
                                      weight: 700))),
                          IconButton(
                              tooltip: s.close,
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const MNIcon(MNIconData.x,
                                  color: OwnerStyle.muted)),
                        ]),
                        OwnerCard(
                            child: _stationDivided([
                          OwnerMenuRow(
                              label: s.ownerAssignVendor,
                              subtitle: s.stationVendorHint,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                assign(context, ref, true);
                              }),
                          OwnerMenuRow(
                              label: s.stationAssignStaff,
                              subtitle: s.stationStaffHint,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                assign(context, ref, false);
                              }),
                        ]))
                      ]))
              : null),
      OwnerCard(
          child: Column(children: [
        OwnerAsyncView(
            value: vendors,
            onRetry: () => ref.invalidate(officeVendorsProvider),
            data: (items) => _stationDivided([
                  for (final p in items.where((p) => p.stationId == station.id))
                    StationPersonRow(
                        name: p.name,
                        role: s.stationVendorRole,
                        imageUrl: p.imageUrl,
                        onTap: () async {
                          await context.push(
                              MNRoutes.officeStationVendor(station.id, p.id));
                          refresh(ref);
                        }),
                  if (!items.any((p) => p.stationId == station.id))
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(s.stationNoVendor,
                            style: OwnerStyle.text(context, 14,
                                color: OwnerStyle.muted))),
                ])),
        OwnerAsyncView(
            value: staff,
            onRetry: () => ref.invalidate(officeStaffProvider),
            data: (items) => _stationDivided([
                  for (final p
                      in items.where((p) => p.stationIds.contains(station.id)))
                    StationPersonRow(
                        name: p.name,
                        role: p.roles.map(s.roleName).join(', '),
                        imageUrl: p.imageUrl,
                        onTap: () =>
                            context.push(MNRoutes.officeStaffMember(p.id))),
                ])),
      ])),
      gap(),
      if (manage) ...[
        _stationHeading(context, s.stationMenuTitle),
        OwnerCard(
            child: _StationRow(
                label: s.stationMenuRow,
                icon: 'menu-list',
                height: 79,
                onTap: () =>
                    context.push(MNRoutes.officeStationMenu(station.id)))),
        gap(),
      ],
      _stationHeading(context, s.stationStock),
      OwnerCard(
          child: _StationRow(
              label: s.stockTitle,
              subtitle: s.stationStockSummary,
              icon: 'stock-box',
              height: 81,
              valueColor: OwnerStyle.ink,
              value: stock?.valueOrNull == null
                  ? '—'
                  : '${stock!.valueOrNull!.where((r) => num.tryParse('${r['quantity']}') != 0).length}',
              onTap: () => context.push(MNRoutes.officeStock(station.id)))),
      if (manage) ...[
        SizedBox(height: OwnerStyle.px(context, 30)),
        OwnerCard(
            child: _StationRow(
                label: s.deleteStation,
                labelColor: OwnerStyle.red,
                subtitle: s.deleteStationBody,
                subtitleSize: 13,
                leftPadding: 22,
                height: 109,
                onTap: () async {
                  final done = await showRemovalSheet(context,
                      title: s.deleteStation,
                      body: s.deleteStationBody,
                      name: station.name,
                      run: (r, reason) =>
                          r.deleteStation(station.id, reason: reason));
                  if (!done) return;
                  ref.invalidate(officeStationsProvider);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(s.deletedToast)));
                  context.pop();
                })),
      ],
    ]);
  }
}

Widget _stationHeading(BuildContext context, String text,
        {String? actionLabel, VoidCallback? action}) =>
    Padding(
        padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 1.5), 0, 0,
            action == null ? OwnerStyle.px(context, 12) : 0),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: OwnerStyle.text(context, 20.8, weight: 700))),
          if (action != null && actionLabel != null)
            TextButton(
                onPressed: action,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Row(children: [
                  const OwnerGlyph('plus', size: 25, color: OwnerStyle.muted),
                  SizedBox(width: OwnerStyle.px(context, 15)),
                  Text(actionLabel,
                      style: OwnerStyle.text(context, 17.5,
                          color: OwnerStyle.muted)),
                ])),
        ]));

/// Moved here from the station's page (30 October 2026): the station's credit
/// customers, performance (owner) and expected deliveries, on its Stock page.
class StationStockLinks extends ConsumerWidget {
  final OfficeStation station;
  const StationStockLinks({super.key, required this.station});

  void refresh(WidgetRef ref) {
    ref.invalidate(officeStationsProvider);
    ref.invalidate(stationManifestsProvider(station.id));
    if (station.stockLocationId != null) {
      ref.invalidate(stationStockProvider(station.stockLocationId!));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    // The server's `receiving.manage`: lists and changes deliveries alike.
    final canDeliver = auth is OfficeSignedIn &&
        (auth.profile.isOwner ||
            auth.profile.roles.contains(StaffRole.supervisor));
    final manifests =
        canDeliver ? ref.watch(stationManifestsProvider(station.id)) : null;
    void open(String title, Widget child, {List<String> help = const []}) =>
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (ctx) => OwnerPage(
                title: title,
                strings: s,
                onBack: () => Navigator.of(ctx).pop(),
                trailing: help.isEmpty
                    ? null
                    : OwnerHelp(compact: true, message: help.join("\n\n")),
                child:
                    Padding(padding: const EdgeInsets.all(16), child: child))));
    Future<void> addDelivery() async {
      final result = await showMNSheet<Map<String, dynamic>>(context,
          builder: (_) => OfficeDeliveryForm(
              stationId: station.id,
              destinationLocationId: station.stockLocationId));
      if (result != null) refresh(ref);
    }

    Widget gap() => SizedBox(height: OwnerStyle.px(context, 10));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Credit customers of this station (MN018).
      OwnerCard(
          child: OwnerMenuRow(
              label: s.creditCustomers,
              subtitle: s.creditOwed,
              value: switch (ref
                  .watch(officeCreditCustomersProvider(station.id))
                  .valueOrNull) {
                final rows? =>
                  formatTsh(rows.fold<int>(0, (sum, c) => sum + c.owed)),
                null => '—',
              },
              onTap: () => context.push(MNRoutes.officeCredit(station.id)))),
      if (auth is OfficeSignedIn && auth.profile.isOwner) ...[
        gap(),
        OwnerCard(
            child: OwnerMenuRow(
                label: s.opStationPerformance,
                subtitle: s.opEntryCaption,
                onTap: () => context
                    .push(MNRoutes.officePerformanceStation(station.id)))),
      ],
      if (manifests != null) ...[
        SizedBox(height: OwnerStyle.px(context, 24)),
        _stationHeading(context, s.stationPendingTitle,
            actionLabel: s.stationAdd, action: addDelivery),
        OwnerAsyncView(
            value: manifests,
            onRetry: () => ref.invalidate(stationManifestsProvider(station.id)),
            data: (items) => OwnerCard(
                    child: OwnerMenuRow(
                  label: s.stationExpectedLoads,
                  subtitle: s.stationExpectedCaption,
                  value:
                      '${items.where((m) => m['status'] == 'open' && m['receipt'] == null).length}',
                  onTap: () => open(s.stationExpectedLoads,
                      Consumer(builder: (ctx, liveRef, _) {
                    final live =
                        liveRef.watch(stationManifestsProvider(station.id));
                    return OwnerAsyncView(
                        value: live,
                        onRetry: () => liveRef
                            .invalidate(stationManifestsProvider(station.id)),
                        data: (rows) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: MNButton(s.officeNewDelivery,
                                          onPressed: addDelivery)),
                                  if (rows.isEmpty)
                                    Text(s.stationNoDeliveries,
                                        style: OwnerStyle.text(ctx, 15,
                                            color: OwnerStyle.muted)),
                                  for (final m in rows)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: OwnerCard(
                                            child: _StationManifest(
                                                manifest: m,
                                                onChanged: () =>
                                                    refresh(liveRef)))),
                                ]));
                  }), help: [
                    s.stationExpectedCaption,
                    s.stationDeliveryLocked,
                    s.stationOwnedDelivery
                  ]),
                ))),
      ],
    ]);
  }
}

Widget _stationDivided(List<Widget> children) => Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: OwnerStyle.line)),
        children[i],
      ]
    ]);

class StationPersonRow extends StatelessWidget {
  final String name, role;
  final String? imageUrl;
  final VoidCallback? onTap;
  const StationPersonRow(
      {super.key,
      required this.name,
      required this.role,
      this.imageUrl,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.length > 1
        ? '${words.first.characters.first}${words.last.characters.first}'
        : words.first.characters.take(2).toString();
    return MNPressable(
        onTap: onTap,
        child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: OwnerStyle.px(context, 16),
                vertical: OwnerStyle.px(context, 14.5)),
            child: Row(children: [
              MNPersonPhoto(
                  imageUrl: imageUrl,
                  size: OwnerStyle.px(context, 51),
                  color: OwnerStyle.avatar,
                  initials: Text(initials.toUpperCase(),
                      style: OwnerStyle.text(context, 20, weight: 600))),
              SizedBox(width: OwnerStyle.px(context, 20)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: OwnerStyle.text(context, 17.5, weight: 400)),
                    Text(role,
                        style: OwnerStyle.text(context, 14,
                            color: OwnerStyle.muted)),
                  ])),
              if (onTap != null)
                const OwnerGlyph('vendor-chevron',
                    size: 20, color: OwnerStyle.stationChevron),
            ])));
  }
}

class _StationManifest extends ConsumerWidget {
  final Map<String, dynamic> manifest;
  final VoidCallback onChanged;
  const _StationManifest({required this.manifest, required this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(officeProductsProvider).valueOrNull;
    String productName(Map<String, dynamic> line) =>
        products?.where((p) => p.code == line['product']).firstOrNull?.name ??
        '${line['product']}';
    final lines = (manifest['lines'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final open = manifest['status'] == 'open' && manifest['receipt'] == null;
    final prepared = manifest['intake_kind'] == 'prepared_locally';
    final stride = prepared ? 1 : 2;
    final canAmend = open && manifest['arrangement'] == 'A';
    Future<void> change(bool cancel) async {
      final fields = cancel
          ? <(String, String)>[]
          : [
              for (final line in lines) ...[
                (
                  '${line['product']} · ${s.stationQuantity}',
                  '${line['quantity']}'
                ),
                if (!prepared)
                  (
                    '${line['product']} · ${s.stationUnitCost}',
                    '${line['agreed_unit_price'] ?? ''}'
                  ),
              ]
            ];
      fields.add((s.changeReason, ''));
      final done = await showMNSheet<bool>(context,
          builder: (_) => _StationForm(
              title: cancel ? s.stationCancelDelivery : s.stationEditDelivery,
              fields: fields,
              numericEntries: !cancel,
              save: (values) async {
                if (cancel) {
                  await stationGuard(
                      ref,
                      (r) => r.cancelManifest('${manifest['id']}', values.last,
                          manifest['version'] as int));
                } else {
                  final amended = <Map<String, dynamic>>[];
                  for (var i = 0; i < lines.length; i++) {
                    final quantity = int.tryParse(values[i * stride]);
                    final cost = prepared || values[i * stride + 1].isEmpty
                        ? null
                        : int.tryParse(values[i * stride + 1]);
                    if (quantity == null ||
                        quantity <= 0 ||
                        quantity > 1000000 ||
                        (!prepared &&
                            values[i * stride + 1].isNotEmpty &&
                            (cost == null || cost < 0))) {
                      throw const OfficeError(OfficeErrorKind.invalid);
                    }
                    amended.add({
                      'product': lines[i]['product'],
                      'quantity': quantity,
                      'agreed_unit_price': cost
                    });
                  }
                  await stationGuard(
                      ref,
                      (r) => r.amendManifest('${manifest['id']}', amended,
                          values.last, manifest['version'] as int));
                }
              }));
      if (done == true) onChanged();
    }

    return Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${manifest['reference']}',
              style: OwnerStyle.text(context, 17, weight: 700)),
          if (manifest['intake_kind'] == 'prepared_locally')
            Text(s.officePrepared,
                style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
          Text('${manifest['sender']} · ${manifest['expected_date']}',
              style: OwnerStyle.text(context, 12.5, color: OwnerStyle.muted)),
          Text(s.stationDeliveryStatus('${manifest['status']}'),
              style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
          const SizedBox(height: 8),
          OwnerDetails(title: s.recordDetails, children: [
            for (final line in lines)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      '${productName(line)} · ${s.stationQuantity}: ${line['quantity']}'
                      '${line['accepted'] == null ? '' : ' · ${s.stationAccepted}: ${line['accepted']}'}',
                      style: OwnerStyle.text(context, 14))),
            if (!open)
              OwnerHelp(compact: true, message: s.stationDeliveryLocked),
            if (open && !canAmend)
              OwnerHelp(compact: true, message: s.stationOwnedDelivery),
            if (canAmend)
              OwnerMenuRow(
                  label: s.stationEditDelivery, onTap: () => change(false)),
            if (open)
              OwnerMenuRow(
                  label: s.stationCancelDelivery, onTap: () => change(true)),
          ]),
        ]));
  }
}

class _StationForm extends ConsumerStatefulWidget {
  final String title;
  final List<(String, String)> fields;
  final Future<void> Function(List<String>) save;
  final bool numericEntries;
  const _StationForm(
      {required this.title,
      required this.fields,
      required this.save,
      this.numericEntries = false});
  @override
  ConsumerState<_StationForm> createState() => _StationFormState();
}

class _StationFormState extends ConsumerState<_StationForm> {
  late final controllers = [
    for (final field in widget.fields) TextEditingController(text: field.$2)
  ];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final s = ref.read(stringsProvider);
    final values = controllers.map((c) => c.text.trim()).toList();
    if (values.last.length < 3) {
      setState(() => error = s.detailsInvalid);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(values);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = officeErrorText(s, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: widget.title, children: [
      for (var i = 0; i < controllers.length; i++)
        MNTextField(
            label: widget.fields[i].$1,
            controller: controllers[i],
            keyboardType: widget.numericEntries && i < controllers.length - 1
                ? TextInputType.number
                : null,
            textInputAction: i == controllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next),
      if (error != null) MNNote(error!, error: true),
      MNButton(s.saveChanges, busy: busy, onPressed: busy ? null : save),
    ]);
  }
}

class _AssignStationPerson extends ConsumerStatefulWidget {
  final OfficeStation station;
  final bool vendor;
  const _AssignStationPerson({required this.station, required this.vendor});
  @override
  ConsumerState<_AssignStationPerson> createState() =>
      _AssignStationPersonState();
}

class _AssignStationPersonState extends ConsumerState<_AssignStationPerson> {
  final reason = TextEditingController();
  String? selected, error;
  bool busy = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final vendors = ref.watch(officeVendorsProvider);
    final staff = ref.watch(officeStaffProvider);
    final options = widget.vendor
        ? vendors.valueOrNull
            ?.where((p) =>
                !p.left && !p.suspended && p.stationId != widget.station.id)
            .map((p) => (
                  p.id,
                  '${p.name}${p.stationName == null ? '' : ' · ${p.stationName}'}'
                ))
            .toList()
        : staff.valueOrNull
            ?.where((p) =>
                !p.left &&
                !p.suspended &&
                !p.stationIds.contains(widget.station.id))
            .map((p) => (p.id, p.name))
            .toList();
    return MNSheet(
        title: widget.vendor ? s.ownerAssignVendor : s.stationAssignStaff,
        children: [
          if (options == null)
            MNNote(s.ownerDataUnavailable)
          else if (options.isEmpty)
            MNNote(s.stationNoAvailablePeople)
          else
            MNSelectField<String>(
                label: s.stationChoosePerson,
                value: selected,
                options: [
                  for (final item in options)
                    MNSelectOption(value: item.$1, label: item.$2)
                ],
                onChanged: busy ? null : (v) => setState(() => selected = v)),
          MNTextField(label: s.stationAssignmentReason, controller: reason),
          if (error != null) MNNote(error!, error: true),
          MNButton(s.saveChanges,
              busy: busy,
              onPressed: busy || options == null || options.isEmpty
                  ? null
                  : () async {
                      if (selected == null || reason.text.trim().length < 3) {
                        setState(() => error = s.detailsInvalid);
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref.read(officeSessionProvider.notifier).guard(
                            (repo) => widget.vendor
                                ? repo.assignVendor(
                                    vendorId: selected!,
                                    stationId: widget.station.id,
                                    reason: reason.text.trim())
                                : repo.placeStaff(selected!,
                                    stationIds: {
                                      ...staff.valueOrNull!
                                          .firstWhere((p) => p.id == selected)
                                          .stationIds,
                                      widget.station.id
                                    }.toList(),
                                    reason: reason.text.trim()));
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (e) {
                        if (mounted) {
                          setState(() => error = officeErrorText(s, e));
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    }),
        ]);
  }
}
