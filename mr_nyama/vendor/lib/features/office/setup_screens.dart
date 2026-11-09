import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import '../../core/routing/routes.dart';
import '../notifications/notification_bell.dart';
import 'owner_reference.dart';
import 'owner_widgets.dart';
import 'people_screens.dart' show officeErrorText;
import 'product_screens.dart' show officeProductsProvider, ownerProductImage;

/// Opening stock (#10) and kitchens and stores (#13). The server holds every
/// rule; these screens only show it and say plainly what it refuses.

Future<T> _setup<T>(OfficeSessionController session,
        Future<T> Function(OfficeSetupRepository) work) =>
    session.guard((repo) {
      if (repo is! OfficeSetupRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OfficeSetupRepository);
    });

Future<T> officeSetupCall<T>(
        WidgetRef ref, Future<T> Function(OfficeSetupRepository) work) =>
    _setup(ref.read(officeSessionProvider.notifier), work);

final openingEntriesProvider = FutureProvider.autoDispose((ref) => _setup(
    ref.read(officeSessionProvider.notifier), (r) => r.openingEntries()));
final openingSettingsProvider = FutureProvider.autoDispose((ref) => _setup(
    ref.read(officeSessionProvider.notifier), (r) => r.openingSettings()));
final setupLocationsProvider = FutureProvider.autoDispose((ref) => _setup(
    ref.read(officeSessionProvider.notifier), (r) => r.setupLocations()));

/// Who may draft (opening.draft: finance, owner) and decide (owner).
({bool draft, bool decide, bool owner, String id}) openingAccess(
    WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  if (auth is! OfficeSignedIn) {
    return (draft: false, decide: false, owner: false, id: '');
  }
  final p = auth.profile;
  return (
    draft: p.isOwner || p.roles.contains(StaffRole.finance),
    decide: p.isOwner,
    owner: p.isOwner,
    id: p.id
  );
}

/// stations.manage: the owner and the operations manager.
bool canManageKitchens(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn && auth.profile.canManagePeople;
}

String kitchenKindName(Strings s, String kind) => switch (kind) {
      'kitchen' => s.kitchenKindKitchen,
      'receiving' => s.kitchenKindReceiving,
      'station' => s.kitchenKindStation,
      'vendor_custody' => s.kitchenKindCustody,
      'in_transit' => s.kitchenKindTransit,
      _ => s.kitchenKindOther,
    };

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Widget _gap(BuildContext context, [double n = 14]) =>
    SizedBox(height: OwnerStyle.px(context, n));

Widget _divided(List<Widget> rows) => Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: OwnerStyle.line)),
        rows[i],
      ]
    ]);

Widget _heading(BuildContext context, String title) => Padding(
    padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 4),
        OwnerStyle.px(context, 20), 0, OwnerStyle.px(context, 8)),
    child: Semantics(
        header: true,
        child: Text(title, style: OwnerStyle.text(context, 17, weight: 600))));

// Opening stock -------------------------------------------------------------------

class OfficeOpeningStockScreen extends ConsumerWidget {
  const OfficeOpeningStockScreen({super.key});

  Future<void> _setDate(BuildContext context, WidgetRef ref,
      OfficeOpeningSettings settings) async {
    final s = ref.read(stringsProvider);
    final today = businessDate(ref.read(clockProvider)());
    final picked = await showMNDateSheet(context,
        initial: DateTime.tryParse(settings.date ?? '') ?? today,
        first: today.subtract(const Duration(days: 365)),
        last: today.add(const Duration(days: 365)),
        title: s.openingSetDate);
    if (picked == null) return;
    try {
      await officeSetupCall(
          ref,
          (r) => r.setOpeningDate(picked.toIso8601String().substring(0, 10),
              reason: s.officeReason));
      ref.invalidate(openingSettingsProvider);
      if (context.mounted) _toast(context, s.openingDateSet);
    } catch (error) {
      if (context.mounted) _toast(context, officeErrorText(s, error));
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    // The sheet names how many drafts are open: without the list, it does not open.
    final int drafts;
    try {
      drafts = (await ref.read(openingEntriesProvider.future))
          .where((e) => e.isDraft)
          .length;
    } catch (error) {
      if (context.mounted) _toast(context, officeErrorText(s, error));
      return;
    }
    if (!context.mounted) return;
    final yes = await showMNConfirmDialog(context,
        title: s.openingClose,
        message: drafts == 0
            ? s.openingCloseBody
            : '${s.openingCloseBody}\n\n${s.openingCloseDrafts(drafts)}',
        confirmLabel: s.openingCloseYes,
        cancelLabel: s.cancel,
        sheet: true);
    if (!yes || !context.mounted) return;
    try {
      await officeSetupCall(ref, (r) => r.closeOpening(reason: s.officeReason));
      ref.invalidate(openingSettingsProvider);
      if (context.mounted) _toast(context, s.openingClosedToast);
    } catch (error) {
      if (context.mounted) _toast(context, officeErrorText(s, error));
    }
  }

  Future<void> _decide(BuildContext context, WidgetRef ref,
      OfficeOpeningEntry entry, bool approve) async {
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecisionSheet(entry: entry, approve: approve));
    if (done != true) return;
    ref.invalidate(openingEntriesProvider);
    if (context.mounted) {
      _toast(context, ref.read(stringsProvider).openingDecided);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = openingAccess(ref);
    final settings = ref.watch(openingSettingsProvider);
    final entries = ref.watch(openingEntriesProvider);
    return OwnerPage(
        title: s.openingTitle,
        strings: s,
        trailing: const NotificationBell(office: true),
        onRefresh: () async {
          ref.invalidate(openingSettingsProvider);
          ref.invalidate(openingEntriesProvider);
        },
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 13)),
            child: !access.draft
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: settings,
                    onRetry: () => ref.invalidate(openingSettingsProvider),
                    data: (st) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OwnerCard(
                                  child: _divided([
                                OwnerMenuRow(
                                    label: s.openingDate,
                                    subtitle: s.openingDateCaption,
                                    value: st.date ?? s.openingDateUnset,
                                    valueSize: 15,
                                    leading: const MNIcon(MNIconData.calendar),
                                    showChevron: access.owner && !st.closed,
                                    onTap: access.owner && !st.closed
                                        ? () => _setDate(context, ref, st)
                                        : null),
                              ])),
                              OwnerAsyncView(
                                  value: entries,
                                  onRetry: () =>
                                      ref.invalidate(openingEntriesProvider),
                                  data: (rows) => _entries(
                                      context, ref, s, access, rows, st)),
                            ]))));
  }

  Widget _entries(
      BuildContext context,
      WidgetRef ref,
      Strings s,
      ({bool draft, bool decide, bool owner, String id}) access,
      List<OfficeOpeningEntry> rows,
      OfficeOpeningSettings st) {
    final productCount = rows.length;
    final quantity =
        rows.fold<int>(0, (total, entry) => total + entry.quantity);
    final totalValue = rows.every((entry) => entry.unitCost != null)
        ? rows.fold<int>(
            0, (total, entry) => total + entry.quantity * entry.unitCost!)
        : null;
    final status = st.closed
        ? s.openingStatusClosed
        : rows.isEmpty
            ? s.openingStatusNotStarted
            : rows.any((entry) => entry.isDraft)
                ? s.openingStatusPending
                : rows.every((entry) => entry.status == 'approved')
                    ? s.openingApproved
                    : rows.every((entry) => entry.status == 'rejected')
                        ? s.openingRejected
                        : s.openingStatusMixed;

    Future<void> addEntry() async {
      final saved = await context.push<bool>(MNRoutes.officeOpeningNew);
      if (saved == true) ref.invalidate(openingEntriesProvider);
    }

    final groups = [
      ('draft', s.openingDraft),
      ('approved', s.openingApproved),
      ('rejected', s.openingRejected),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _gap(context, 10),
      OwnerCard(
          child: _divided([
        OwnerMenuRow(
            label: s.openingStatus,
            value: status,
            valueSize: 14,
            valueWeight: 400,
            valueColor: OwnerStyle.muted,
            leading: const OwnerGlyph('stock-box'),
            showChevron: false),
      ])),
      if (st.closed) ...[
        _gap(context, 10),
        MNNote(s.openingClosedNote, tone: MNNoteTone.info),
      ] else if (st.date == null) ...[
        _gap(context, 10),
        MNNote(access.owner ? s.openingSetDate : s.openingDateOwnerOnly,
            tone: MNNoteTone.warning),
      ],
      if (rows.isNotEmpty) ...[
        _gap(context, 10),
        OwnerCard(
            child: _divided([
          OwnerMenuRow(
              label: s.openingProducts,
              value: '$productCount',
              valueSize: 15,
              showChevron: false),
          OwnerMenuRow(
              label: s.openingQuantityTotal,
              value: '$quantity',
              valueSize: 15,
              showChevron: false),
          OwnerMenuRow(
              label: s.openingTotalValue,
              value: totalValue == null
                  ? s.openingCostUnknown
                  : formatTzs(totalValue),
              valueSize: 15,
              valueColor:
                  totalValue == null ? OwnerStyle.muted : OwnerStyle.ink,
              valueWeight: totalValue == null ? 400 : 600,
              showChevron: false),
        ])),
      ],
      if (st.open && rows.isNotEmpty) ...[
        _gap(context, 10),
        MNButton(s.openingAdd, onPressed: addEntry),
      ],
      if (rows.isEmpty) ...[
        SizedBox(height: OwnerStyle.px(context, 28)),
        const MNIcon(MNIconData.box, size: 40, color: OwnerStyle.ink),
        _gap(context, 10),
        Center(
            child: Text(s.openingNone,
                textAlign: TextAlign.center,
                style: OwnerStyle.text(context, 20, weight: 700))),
        _gap(context, 8),
        Center(
            child: Text(s.openingEmptyInstruction,
                textAlign: TextAlign.center,
                style: OwnerStyle.text(context, 14, color: OwnerStyle.muted))),
        _gap(context, 8),
        Center(
            child: Text(s.openingApprovalRequired,
                textAlign: TextAlign.center,
                style: OwnerStyle.text(context, 13, color: OwnerStyle.muted))),
        if (st.open) ...[
          _gap(context, 20),
          MNButton(s.openingAdd, onPressed: addEntry),
        ],
        _gap(context, 20),
      ] else ...[
        _gap(context, 12),
        for (final (entryStatus, title) in groups)
          if (rows.any((entry) => entry.status == entryStatus)) ...[
            _heading(context, title),
            OwnerCard(
                child: _divided([
              for (final entry
                  in rows.where((entry) => entry.status == entryStatus))
                _EntryTile(
                    entry: entry,
                    strings: s,
                    trailing: _decision(context, ref, s, access, entry, st)),
            ])),
          ],
      ],
      if (access.owner && st.date != null && !st.closed) ...[
        _gap(context, 12),
        OwnerMenuRow(
            label: s.openingClose,
            icon: 'clock',
            onTap: () => _close(context, ref)),
      ],
      _gap(context, 20),
    ]);
  }

  /// What can be done with a draft. The server refuses the rest; this only
  /// says so first. Rejecting moves nothing, so the one who drafted may do it.
  Widget? _decision(
      BuildContext context,
      WidgetRef ref,
      Strings s,
      ({bool draft, bool decide, bool owner, String id}) access,
      OfficeOpeningEntry e,
      OfficeOpeningSettings st) {
    if (!e.isDraft) return null;
    final mine = e.enteredBy == access.id;
    final current = !st.closed && e.asOf == st.date;
    final canApprove = access.decide && !mine && current;
    final canReject = access.decide || mine;
    final note = !canReject
        ? s.openingOwnerDecides
        : st.closed
            ? s.openingClosedRejectOnly
            : !current
                ? s.openingOldDate
                : mine
                    ? (access.owner
                        ? s.openingOwnDraftOwner
                        : s.openingOwnDraftFinance)
                    : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (note != null)
        Text(note,
            style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
      if (note != null && canReject) const SizedBox(height: 8),
      if (canReject)
        Row(children: [
          if (canApprove) ...[
            Expanded(
                child: MNButton(s.openingApprove,
                    onPressed: () => _decide(context, ref, e, true))),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: MNButton.secondary(s.openingReject,
                  onPressed: () => _decide(context, ref, e, false))),
        ]),
    ]);
  }
}

class _EntryTile extends StatelessWidget {
  final OfficeOpeningEntry entry;
  final Strings strings;
  final Widget? trailing;
  const _EntryTile({required this.entry, required this.strings, this.trailing});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    final muted = OwnerStyle.text(context, 13, color: OwnerStyle.muted);
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.openingLine(entry.productName, entry.quantity),
              style: OwnerStyle.text(context, 16, weight: 600)),
          Text(entry.locationName, style: muted),
          Text(
              entry.unitCost == null
                  ? s.openingCostUnknown
                  : s.openingCostEach(formatTsh(entry.unitCost!)),
              style: muted),
          Text('${s.openingReference}: ${entry.reference}', style: muted),
          if (entry.enteredByName.isNotEmpty)
            Text(s.openingEnteredBy(entry.enteredByName), style: muted),
          if (trailing != null) ...[const SizedBox(height: 10), trailing!],
        ]));
  }
}

class _DecisionSheet extends ConsumerStatefulWidget {
  final OfficeOpeningEntry entry;
  final bool approve;
  const _DecisionSheet({required this.entry, required this.approve});
  @override
  ConsumerState<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends ConsumerState<_DecisionSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = s.reasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeSetupCall(
          ref,
          (r) => r.decideOpening(widget.entry.id,
              approve: widget.approve, reason: reason));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(
        title: widget.approve ? s.openingApproveTitle : s.openingRejectTitle,
        children: [
          Text(s.openingLine(widget.entry.productName, widget.entry.quantity),
              style: OwnerStyle.text(context, 16, weight: 600)),
          MNTextField(
              label: s.openingDecisionReason,
              controller: _reason,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(500)]),
          if (_error != null) MNNote(_error!, error: true),
          widget.approve
              ? MNButton(s.openingApprove,
                  busy: _busy, onPressed: _busy ? null : _save)
              : MNButton.destructive(s.openingReject,
                  busy: _busy, onPressed: _busy ? null : _save),
        ]);
  }
}

// The form ----------------------------------------------------------------------------

class OfficeOpeningFormScreen extends ConsumerStatefulWidget {
  const OfficeOpeningFormScreen({super.key});
  @override
  ConsumerState<OfficeOpeningFormScreen> createState() => _OpeningFormState();
}

class _OpeningFormState extends ConsumerState<OfficeOpeningFormScreen> {
  final _cost = TextEditingController(), _reference = TextEditingController();
  String? _location, _product, _error;
  // One id per draft; kept while the details are unchanged, so a retry after a
  // lost answer finds the first draft instead of adding a second.
  String? _clientId, _sentAs;
  int _quantity = 1;
  bool _busy = false;
  @override
  void dispose() {
    _cost.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save(String date) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final costText = _cost.text.trim();
    final cost = costText.isEmpty ? null : int.tryParse(costText);
    final problem = _location == null
        ? s.openingChooseLocation
        : _product == null
            ? s.openingChooseProduct
            : costText.isNotEmpty && cost == null
                ? s.openingCostInvalid
                : _reference.text.trim().length < 3
                    ? s.openingRefInvalid
                    : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final details = [
      _location,
      _product,
      _quantity,
      cost,
      date,
      _reference.text.trim()
    ].join('|');
    if (_clientId == null || _sentAs != details) _clientId = const Uuid().v4();
    _sentAs = details;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeSetupCall(
          ref,
          (r) => r.draftOpening(
              clientId: _clientId!,
              locationId: _location!,
              product: _product!,
              quantity: _quantity,
              unitCost: cost,
              asOf: date,
              reference: _reference.text.trim()));
      if (!mounted) return;
      _toast(context, s.openingSaved);
      context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = openingAccess(ref);
    final settings = ref.watch(openingSettingsProvider);
    final locations = ref.watch(setupLocationsProvider);
    final products = ref.watch(officeProductsProvider);
    final st = settings.valueOrNull;
    final usable = access.draft && st != null && st.open;
    final rows = (locations.valueOrNull ?? const <OfficeStockLocation>[])
        .where((l) => l.active && l.kind != 'in_transit')
        .toList();
    return OwnerPage(
        title: s.openingAdd,
        strings: s,
        bottom: usable
            ? SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
                    child: MNButton(s.openingSave,
                        busy: _busy,
                        onPressed: _busy ? null : () => _save(st.date!))))
            : null,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: st == null
                ? OwnerAsyncView(
                    value: settings,
                    onRetry: () => ref.invalidate(openingSettingsProvider),
                    data: (_) => const SizedBox.shrink())
                : !usable
                    ? MNNote(
                        st.closed
                            ? s.openingClosedNote
                            : access.owner
                                ? s.openingSetDate
                                : s.openingDateOwnerOnly,
                        tone: MNNoteTone.warning)
                    : OwnerFormSection(children: [
                        if (access.owner) ...[
                          MNNote(
                              '${s.openingWarnOwner}\n${s.openingWarnOwnerBody}',
                              tone: MNNoteTone.warning),
                          const SizedBox(height: MNSpace.x4),
                        ],
                        MNSelectField<String>(
                            label: s.openingLocation,
                            value: _location,
                            emptyText: s.openingNoLocations,
                            options: [
                              for (final l in rows)
                                MNSelectOption(
                                    value: l.id,
                                    label: l.name,
                                    caption: kitchenKindName(s, l.kind))
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _location = v)),
                        const SizedBox(height: MNSpace.x4),
                        MNSelectField<String>(
                            label: s.openingProduct,
                            value: _product,
                            emptyText: s.noOfficeProducts,
                            options: [
                              for (final p in (products.valueOrNull ??
                                      const <OfficeProduct>[])
                                  .where((p) => p.status == 'active'))
                                MNSelectOption(
                                    value: p.code,
                                    label: p.name,
                                    image: ownerProductImage(p),
                                    caption: s.unitName(p.unit))
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _product = v)),
                        const SizedBox(height: MNSpace.x4),
                        Row(children: [
                          Expanded(
                              child: Text(s.openingQuantity,
                                  style:
                                      MNText.resolve(context, MNText.label))),
                          MNQuantitySelector(
                              compact: true,
                              value: _quantity,
                              min: 1,
                              max: 1000000,
                              itemLabel: s.openingQuantity,
                              onChanged: (v) =>
                                  _busy ? null : setState(() => _quantity = v)),
                        ]),
                        const SizedBox(height: MNSpace.x4),
                        MNTextField(
                            label: s.openingUnitCost,
                            hint: s.openingUnitCostHint,
                            controller: _cost,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9)
                            ]),
                        const SizedBox(height: MNSpace.x4),
                        MNTextField(
                            label: s.openingRefRequired,
                            controller: _reference,
                            enabled: !_busy,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(300)
                            ]),
                        if (_error != null) ...[
                          const SizedBox(height: MNSpace.x3),
                          MNNote(_error!, error: true),
                        ],
                      ])));
  }
}

// Kitchens and stores -----------------------------------------------------------------

class OfficeKitchensScreen extends ConsumerWidget {
  const OfficeKitchensScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final manage = canManageKitchens(ref);
    final locations = ref.watch(setupLocationsProvider);
    Future<void> add() async {
      final done = await showMNSheet<bool>(context,
          builder: (_) => const _NewLocationSheet());
      if (done == true) {
        ref.invalidate(setupLocationsProvider);
        if (context.mounted) _toast(context, s.kitchenSaved);
      }
    }

    return OwnerPage(
        title: s.kitchensTitle,
        strings: s,
        onAdd: manage ? add : null,
        addLabel: manage ? s.kitchensAdd : null,
        onRefresh: () => ref.refresh(setupLocationsProvider.future),
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 13)),
            child: OwnerAsyncView(
                value: locations,
                onRetry: () => ref.invalidate(setupLocationsProvider),
                data: (all) {
                  final rows = all
                      .where((l) => setupLocationKinds.contains(l.kind))
                      .toList();
                  if (rows.isEmpty) {
                    return MNNote(s.kitchensNone, tone: MNNoteTone.info);
                  }
                  return OwnerCard(
                      child: _divided([
                    for (final l in rows)
                      OwnerMenuRow(
                          label: l.name,
                          subtitle: '${kitchenKindName(s, l.kind)} · ${l.code}',
                          showChevron: false),
                  ]));
                })));
  }
}

class _NewLocationSheet extends ConsumerStatefulWidget {
  const _NewLocationSheet();
  @override
  ConsumerState<_NewLocationSheet> createState() => _NewLocationSheetState();
}

class _NewLocationSheetState extends ConsumerState<_NewLocationSheet> {
  final _name = TextEditingController(), _code = TextEditingController();
  String _kind = 'kitchen';
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final name = _name.text.trim(), code = _code.text.trim();
    if (name.length < 2) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{1,29}$').hasMatch(code)) {
      setState(() => _error = s.kitchenCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeSetupCall(
          ref, (r) => r.createLocation(code: code, name: name, kind: _kind));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.kitchensAddTitle, children: [
      MNSelectField<String>(
          label: s.kitchenKind,
          value: _kind,
          options: [
            for (final k in setupLocationKinds)
              MNSelectOption(value: k, label: kitchenKindName(s, k))
          ],
          onChanged: _busy ? null : (v) => setState(() => _kind = v)),
      MNTextField(
          label: s.kitchenName,
          controller: _name,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(150)]),
      MNTextField(
          label: s.kitchenCode,
          controller: _code,
          enabled: !_busy,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            LengthLimitingTextInputFormatter(30),
            TextInputFormatter.withFunction(
                (o, n) => n.copyWith(text: n.text.toUpperCase()))
          ]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.kitchensAdd, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// The kitchen choice in a grant or registration: required for kitchen staff.
class KitchenChoice extends ConsumerWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  /// Kitchens the person already holds: nothing to grant there.
  final Set<String> exclude;
  const KitchenChoice(
      {super.key,
      required this.value,
      required this.onChanged,
      this.enabled = true,
      this.exclude = const {}});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final locations = ref.watch(setupLocationsProvider);
    final kitchens = (locations.valueOrNull ?? const <OfficeStockLocation>[])
        .where((l) => l.kind == 'kitchen' && l.active)
        .toList();
    if (locations.hasValue && kitchens.isEmpty) {
      return MNNote(s.kitchenNoneToPick, tone: MNNoteTone.warning);
    }
    final open = kitchens.where((k) => !exclude.contains(k.id)).toList();
    if (locations.hasValue && open.isEmpty) {
      return MNNote(s.kitchenAllHeld, tone: MNNoteTone.info);
    }
    return MNSelectField<String>(
        label: s.kitchenPick,
        value: value,
        emptyText: locations.isLoading ? s.loading : null,
        options: [
          for (final k in open) MNSelectOption(value: k.id, label: k.name)
        ],
        onChanged: enabled ? onChanged : null);
  }
}
