import 'owner_widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_repository.dart';
import '../../core/api/office_approvals.dart' show OfficeApprovalsRepository;
import '../../core/auth/office_session.dart';
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../owner/bonus_screens.dart' show CorrectSaleSheet;
import 'approval_screens.dart' show ResolveProblemSheet;
import 'closing_case_screens.dart' show ClosingCasesRow;
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;
import 'lost_sale_screens.dart'
    show LostSaleRequestsSection, stationLostSalesProvider;
import 'sale_cancel_widgets.dart';
import 'stock_screens.dart' show ReceiptMismatchSheet, stockAccess;
import 'sync_review_screens.dart';

/// Office verification for supervisors, finance and the owner: verify vendor
/// sales, decide damage reports, confirm Funga Siku closing counts and read
/// the open problems. Nothing is shown as verified, decided or confirmed
/// until the server says so; every refusal shows the server's reason.

// Data ---------------------------------------------------------------------------------

final verificationQueueProvider =
    FutureProvider.autoDispose<List<OfficeVerificationStation>>((ref) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.verificationQueue()));

/// Unverified (`reported`) sales at a station, every business day.
final stationSalesProvider = FutureProvider.autoDispose
    .family<List<OfficeSale>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.stationSales(stationId, status: 'reported')));

/// Sales the system verified at a station, listed apart from the work waiting.
final stationAutoSalesProvider = FutureProvider.autoDispose
    .family<List<OfficeSale>, String>((ref, stationId) =>
        ref.read(officeSessionProvider.notifier).guard((r) {
          if (r is! OfficeAutoVerifyRepository) {
            throw const OfficeError(OfficeErrorKind.invalid);
          }
          return (r as OfficeAutoVerifyRepository).autoVerifiedSales(stationId);
        }));

final stationDamageProvider = FutureProvider.autoDispose
    .family<List<OfficeDamageReport>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.damageReports(stationId: stationId)));

final stationClosingsProvider = FutureProvider.autoDispose
    .family<List<OfficeClosingCount>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.closingCounts(stationId: stationId)));

final stationProblemsProvider = FutureProvider.autoDispose
    .family<List<OfficeException>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.exceptions(stationId: stationId)));

final resolvedStationProblemsProvider = FutureProvider.autoDispose
    .family<List<OfficeException>, String>((ref, stationId) => ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.exceptions(stationId: stationId, status: 'resolved')));

/// Rows shown before "Zaidi" (project convention).
const verificationPageSize = 10;

/// The server verifies at most this many sales per request.
const verifyBatchSize = 500;

/// A batch was refused: nothing in it was verified, but [verifiedBefore]
/// sales in earlier batches were.
class VerifyBatchRefused implements Exception {
  final int verifiedBefore;
  final Object error;
  const VerifyBatchRefused(this.verifiedBefore, this.error);
}

/// Sends [saleIds] in batches of at most [verifyBatchSize], stopping at the
/// first refusal. Returns how many sales the server verified.
Future<int> verifyInBatches(
    Future<List<String>> Function(List<String> batch) verify,
    List<String> saleIds) async {
  var done = 0;
  for (var i = 0; i < saleIds.length; i += verifyBatchSize) {
    final batch =
        saleIds.sublist(i, math.min(i + verifyBatchSize, saleIds.length));
    try {
      done += (await verify(batch)).length;
    } catch (error) {
      throw VerifyBatchRefused(done, error);
    }
  }
  return done;
}

({bool verify, bool reviewStock, bool owner}) _access(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final profile = auth is OfficeSignedIn ? auth.profile : null;
  return (
    verify: profile?.canVerify ?? false,
    reviewStock: profile?.canReviewStock ?? false,
    owner: profile?.isOwner ?? false,
  );
}

// Formatting ---------------------------------------------------------------------------

String _qty(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

String _signed(num n) => n > 0
    ? '+${_qty(n)}'
    : n < 0
        ? '−${_qty(-n)}'
        : '0';

String _quantity(Strings s, num n, String unit) =>
    unit.isEmpty ? _qty(n) : '${_qty(n)} ${s.unitName(unit)}';

String _day(Strings s, DateTime? d) => d == null ? '—' : s.date(d);

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

String _payment(Strings s, String p, {String? customer}) => switch (p) {
      'cash' => s.cash,
      'mpesa' => s.mpesa,
      'credit' => s.paymentMethodName(p, customer: customer),
      _ => p,
    };

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c, {Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, 14, color: color);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

/// Shows [count] items ten at a time, with "Zaidi" for the next ten.
class _Paged extends ConsumerStatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  const _Paged({required this.count, required this.itemBuilder});
  @override
  ConsumerState<_Paged> createState() => _PagedState();
}

class _PagedState extends ConsumerState<_Paged> {
  int _limit = verificationPageSize;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < math.min(_limit, widget.count); i++) ...[
        if (i > 0) _gap(context),
        widget.itemBuilder(context, i),
      ],
      if (widget.count > _limit) ...[
        _gap(context),
        MNButton.secondary(s.moreRows,
            onPressed: () => setState(() => _limit += verificationPageSize)),
      ],
    ]);
  }
}

/// A white card with the office padding.
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

// Queue --------------------------------------------------------------------------------

class OfficeVerificationScreen extends ConsumerWidget {
  const OfficeVerificationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allowed = _access(ref).verify;
    final queue = ref.watch(verificationQueueProvider);
    return OwnerPage(
        title: s.verification,
        strings: s,
        onRefresh: allowed
            ? () => ref.refresh(verificationQueueProvider.future)
            : null,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: !allowed
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: queue,
                    onRetry: () => ref.invalidate(verificationQueueProvider),
                    isEmpty: (rows) => rows.isEmpty,
                    empty: (_) =>
                        MNNote(s.verifyQueueEmpty, tone: MNNoteTone.info),
                    data: (rows) {
                      // Stations with work first; the server's order otherwise.
                      final ordered = [
                        ...rows.where((r) => r.hasWork),
                        ...rows.where((r) => !r.hasWork),
                      ];
                      final paged = _Paged(
                          count: ordered.length,
                          itemBuilder: (_, i) =>
                              _StationRow(station: ordered[i], strings: s));
                      // Phone records waiting for review (supervisor, owner).
                      final waiting = syncReviewAccess(ref).review
                          ? ref.watch(syncConflictsProvider).valueOrNull
                          : null;
                      if (waiting == null || waiting.isEmpty) return paged;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OwnerCard(
                                child: OwnerMenuRow(
                                    label: s.syncConflicts,
                                    subtitle: s.syncConflictsCaption,
                                    value: s.syncConflictsCount(waiting.length),
                                    valueSize: 12.5,
                                    valueWeight: 400,
                                    valueColor: OwnerStyle.assignAction,
                                    height: 61,
                                    onTap: () => context
                                        .push(MNRoutes.officeSyncConflicts))),
                            _gap(context),
                            paged,
                          ]);
                    })));
  }
}

class _StationRow extends StatelessWidget {
  final OfficeVerificationStation station;
  final Strings strings;
  const _StationRow({required this.station, required this.strings});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    double u(double n) => OwnerStyle.px(context, n);
    final waiting = [
      if (station.pendingSales > 0)
        s.verifySalesCount(
            station.pendingSales, formatTsh(station.pendingSalesAmount)),
      if (station.reportedDamage > 0)
        s.verifyDamageCount(station.reportedDamage),
      if (station.recordedClosings > 0)
        s.verifyClosingCount(station.recordedClosings),
      if (station.openExceptions > 0)
        s.verifyProblemCount(station.openExceptions),
    ];
    return OwnerCard(
        child: InkWell(
            onTap: () =>
                context.push(MNRoutes.officeVerificationStation(station.id)),
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: u(64)),
                child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: u(16), vertical: u(14)),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(station.name, style: _title(context)),
                            if (station.code.isNotEmpty)
                              Text(station.code, style: _meta(context)),
                            SizedBox(height: u(4)),
                            if (waiting.isEmpty)
                              Text(s.verifyNothingWaiting,
                                  style:
                                      _body(context, color: OwnerStyle.muted)),
                            for (final line in waiting)
                              Text(line, style: _body(context)),
                            if (station.autoVerifiedToday > 0 ||
                                station.heldToday > 0)
                              Text(
                                  s.autoQueueLine(station.autoVerifiedToday,
                                      station.heldToday),
                                  style: _meta(context)),
                            if (station.oldestPendingDate != null)
                              Text(
                                  s.verifyOldest(
                                      s.date(station.oldestPendingDate!)),
                                  style: _meta(context)),
                          ])),
                      SizedBox(width: u(12)),
                      const OwnerGlyph('vendor-chevron', size: 14),
                    ])))));
  }
}

// One station --------------------------------------------------------------------------

class OfficeVerificationStationScreen extends ConsumerStatefulWidget {
  final String stationId;
  /// Opens on the Damage chip (`?section=damage`).
  final bool openDamage;
  const OfficeVerificationStationScreen(
      {super.key, required this.stationId, this.openDamage = false});
  @override
  ConsumerState<OfficeVerificationStationScreen> createState() =>
      _StationScreenState();
}

class _StationScreenState
    extends ConsumerState<OfficeVerificationStationScreen> {
  late int _section = widget.openDamage ? 1 : 0;

  Future<void> _refresh() async {
    final id = widget.stationId;
    ref.invalidate(verificationQueueProvider);
    await switch (_section) {
      1 => ref.refresh(stationDamageProvider(id).future),
      2 => ref.refresh(stationClosingsProvider(id).future),
      _ => () {
          ref.invalidate(stationAutoSalesProvider(id));
          return ref.refresh(stationSalesProvider(id).future);
        }(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = _access(ref);
    final id = widget.stationId;
    final station = ref
        .watch(verificationQueueProvider)
        .valueOrNull
        ?.where((r) => r.id == id)
        .firstOrNull;
    final pad = EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));
    if (!access.verify) {
      return OwnerPage(
          title: s.verification,
          strings: s,
          child: Padding(padding: pad, child: MNNote(s.notAllowed)));
    }
    // Finance verifies sales only; damage and closing decisions belong to a
    // supervisor or the owner, and the server would refuse them.
    final stockNote = MNNote(s.notYourRole, tone: MNNoteTone.info);
    return OwnerPage(
        title: station?.name ?? s.verification,
        strings: s,
        onRefresh: _refresh,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: pad,
              child: OwnerCard(
                  child: Column(children: [
                OwnerMenuRow(
                    label: s.problems,
                    onTap: () =>
                        context.push(MNRoutes.officeVerificationProblems(id))),
                if (stockAccess(ref).view)
                  OwnerMenuRow(
                      label: s.stockTitle,
                      subtitle: s.stockCaption,
                      onTap: () => context.push(MNRoutes.officeStock(id))),
                // Days nobody counted (MN031); only while there are some.
                ClosingCasesRow(stationId: id),
                // The owner corrects verified sales (VR9, design §11).
                if (ref.watch(officeSessionProvider).valueOrNull
                    case OfficeSignedIn(:final profile) when profile.isOwner)
                  OwnerMenuRow(
                      label: s.bonusVerifiedSales,
                      subtitle: s.correctSalesCaption,
                      onTap: () =>
                          context.push(MNRoutes.officeVerifiedSales(id))),
              ]))),
          // Requests to cancel a sale (MN034); only while there are some.
          SaleCancelRequestsSection(
              stationId: id, onChanged: () => _afterChange(ref, id)),
          // Sales remembered after a lost phone (MN036), for those who decide them.
          LostSaleRequestsSection(
              stationId: id, onChanged: () => _afterChange(ref, id)),
          _gap(context, 8),
          MNChipBar(
              labels: [s.sales, s.damaged, s.closeDay],
              selected: _section,
              onSelect: (i) => setState(() => _section = i)),
          _gap(context, 8),
          Padding(
              padding: pad,
              child: switch (_section) {
                1 => access.reviewStock
                    ? _DamageSection(stationId: id)
                    : stockNote,
                2 => access.reviewStock
                    ? _ClosingSection(stationId: id)
                    : stockNote,
                _ => _SalesSection(stationId: id),
              }),
        ]));
  }
}

void _afterChange(WidgetRef ref, String stationId) {
  ref.invalidate(verificationQueueProvider);
  ref.invalidate(stationSalesProvider(stationId));
  ref.invalidate(stationAutoSalesProvider(stationId));
  ref.invalidate(stationDamageProvider(stationId));
  ref.invalidate(stationClosingsProvider(stationId));
  ref.invalidate(stationProblemsProvider(stationId));
  ref.invalidate(resolvedStationProblemsProvider(stationId));
  ref.invalidate(saleCancellationsProvider(stationId));
  ref.invalidate(stationLostSalesProvider(stationId));
}

// Sales --------------------------------------------------------------------------------

class _SalesSection extends ConsumerStatefulWidget {
  final String stationId;
  const _SalesSection({required this.stationId});
  @override
  ConsumerState<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends ConsumerState<_SalesSection> {
  final _selected = <String>{};
  final _open = <String>{};
  int _limit = verificationPageSize;
  bool _busy = false;
  bool _showAutomatic = false;
  String? _error;

  static String _group(OfficeSale sale) =>
      '${sale.vendorId}|${sale.businessDate?.toIso8601String() ?? ''}';

  Future<void> _verify(List<OfficeSale> chosen) async {
    if (_busy || chosen.isEmpty) return;
    final s = ref.read(stringsProvider);
    final total = chosen.fold<int>(0, (sum, sale) => sum + sale.amount);
    final yes = await showMNConfirmDialog(context,
        title: s.verifyConfirmTitle(chosen.length, formatTsh(total)),
        message: s.verifyConfirmBody,
        confirmLabel: s.yesConfirm,
        cancelLabel: s.cancel);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final office = ref.read(officeSessionProvider.notifier);
    try {
      final done = await verifyInBatches(
          (batch) => office.guard((r) => r.verifySales(batch)),
          [for (final sale in chosen) sale.saleId]);
      _selected.clear();
      if (mounted) _toast(context, s.salesVerified(done));
    } on VerifyBatchRefused catch (refusal) {
      _selected.clear();
      if (mounted) {
        setState(() => _error = [
              officeErrorText(s, refusal.error),
              s.verifyBatchNotDone,
              if (refusal.verifiedBefore > 0)
                s.verifyEarlierDone(refusal.verifiedBefore),
            ].join(' '));
      }
    } finally {
      // The server's list is the truth after either outcome.
      _afterChange(ref, widget.stationId);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(stationSalesProvider(widget.stationId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _waiting(s, value),
      _gap(context),
      MNTextButton(s.autoVerifiedFilter,
          onPressed: () => setState(() => _showAutomatic = !_showAutomatic)),
      if (_showAutomatic) _AutoVerifiedSales(stationId: widget.stationId),
    ]);
  }

  Widget _waiting(Strings s, AsyncValue<List<OfficeSale>> value) {
    return OwnerAsyncView(
        value: value,
        onRetry: () => ref.invalidate(stationSalesProvider(widget.stationId)),
        isEmpty: (rows) => rows.isEmpty && _error == null,
        empty: (_) => MNEmptyState(
            icon: MNIconData.list,
            image: 'assets/errors/sales_verification_state.png',
            imageWidth: 215,
            title: s.noUnverifiedSales),
        data: (rows) {
          final sorted = [...rows]..sort((a, b) {
              // Held sales first: they are what a person is here for.
              if (a.heldForReview != b.heldForReview) {
                return a.heldForReview ? -1 : 1;
              }
              final byVendor = a.vendorName.compareTo(b.vendorName);
              if (byVendor != 0) return byVendor;
              final byVendorId = a.vendorId.compareTo(b.vendorId);
              if (byVendorId != 0) return byVendorId;
              final ad = a.businessDate, bd = b.businessDate;
              if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
              final at = a.recordedAt, bt = b.recordedAt;
              return at != null && bt != null ? at.compareTo(bt) : 0;
            });
          final chosen = [
            for (final sale in sorted)
              if (sale.selectable && _selected.contains(sale.saleId)) sale
          ];
          final total = chosen.fold<int>(0, (sum, sale) => sum + sale.amount);
          final groups = <String, List<OfficeSale>>{};
          for (final sale in sorted) {
            groups.putIfAbsent(_group(sale), () => []).add(sale);
          }
          final visible = <String, List<OfficeSale>>{};
          for (final sale in sorted.take(_limit)) {
            visible.putIfAbsent(_group(sale), () => []).add(sale);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, entry) in visible.entries.indexed) ...[
                  if (i > 0) _gap(context),
                  _SaleGroup(
                      stationId: widget.stationId,
                      all: groups[entry.key]!,
                      shown: entry.value,
                      selected: _selected,
                      open: _open,
                      enabled: !_busy,
                      onChanged: () => setState(() {})),
                ],
                if (sorted.length > _limit) ...[
                  _gap(context),
                  MNButton.secondary(s.moreRows,
                      onPressed: () =>
                          setState(() => _limit += verificationPageSize)),
                ],
                _gap(context, 16),
                Text(
                    chosen.isEmpty
                        ? s.verifyNoneSelected
                        : s.verifySelection(chosen.length, formatTsh(total)),
                    style: _body(context)),
                if (_error != null) ...[
                  _gap(context),
                  MNNote(_error!, error: true),
                ],
                _gap(context),
                MNButton(s.verifyAction,
                    busy: _busy,
                    onPressed:
                        chosen.isEmpty || _busy ? null : () => _verify(chosen)),
              ]);
        });
  }
}

/// Sales the system verified: labelled, and correctable by the owner only.
class _AutoVerifiedSales extends ConsumerWidget {
  final String stationId;
  const _AutoVerifiedSales({required this.stationId});

  Future<void> _correct(
      BuildContext context, WidgetRef ref, OfficeSale sale) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => CorrectSaleSheet(saleId: sale.saleId));
    if (done != true) return;
    _afterChange(ref, stationId);
    if (context.mounted) _toast(context, s.correctSaleDone);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final owner = _access(ref).owner;
    return OwnerAsyncView(
        value: ref.watch(stationAutoSalesProvider(stationId)),
        onRetry: () => ref.invalidate(stationAutoSalesProvider(stationId)),
        isEmpty: (rows) => rows.isEmpty,
        empty: (_) => MNNote(s.autoVerifiedNone, tone: MNNoteTone.info),
        data: (rows) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final sale in rows) ...[
                OwnerCard(
                    child: Padding(
                        padding: EdgeInsets.all(u(14)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  '${sale.recordedAt == null ? '—' : s.hhmm(eatClock(sale.recordedAt!))}'
                                  ' · ${_payment(s, sale.payment, customer: sale.customer)}',
                                  style: _body(context)),
                              Text(
                                  sale.lines.isEmpty
                                      ? sale.product
                                      : sale.lines
                                          .map((l) => l.name)
                                          .join(', '),
                                  style: _meta(context)),
                              Text(formatTsh(sale.amount),
                                  style: OwnerStyle.text(context, 15,
                                      weight: 600)),
                              Text(
                                  sale.voided
                                      ? s.correctedSale
                                      : s.autoVerifiedLabel,
                                  style: _status(context, OwnerStyle.muted)),
                              if (owner && !sale.voided) ...[
                                _gap(context, 8),
                                MNButton.secondary(s.correctSale,
                                    onPressed: () =>
                                        _correct(context, ref, sale)),
                              ],
                            ]))),
                _gap(context),
              ],
            ]));
  }
}

/// One vendor's sales on one business day.
class _SaleGroup extends ConsumerWidget {
  /// Every sale in the group; [shown] is the part on this page.
  final List<OfficeSale> all, shown;
  final String stationId;
  final Set<String> selected, open;
  final bool enabled;
  final VoidCallback onChanged;
  const _SaleGroup(
      {required this.stationId,
      required this.all,
      required this.shown,
      required this.selected,
      required this.open,
      required this.enabled,
      required this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    double u(double n) => OwnerStyle.px(context, n);
    final first = all.first;
    final selectable = [
      for (final sale in all)
        if (sale.selectable) sale.saleId
    ];
    final allChosen =
        selectable.isNotEmpty && selectable.every(selected.contains);
    final amount = all
        .where((sale) => !sale.voided)
        .fold<int>(0, (sum, sale) => sum + sale.amount);
    final vendor = first.vendorCode == null
        ? first.vendorName
        : '${first.vendorName} · ${first.vendorCode}';
    return OwnerCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(u(16), u(14), u(8), u(4)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vendor, style: _title(context)),
            Text(
                '${_day(s, first.businessDate)} · '
                '${s.verifySalesCount(all.where((x) => !x.voided).length, formatTsh(amount))}',
                style: _meta(context)),
            MNTextButton(allChosen ? s.clearAll : s.selectAll,
                onPressed: selectable.isEmpty || !enabled
                    ? null
                    : () {
                        if (allChosen) {
                          selected.removeAll(selectable);
                        } else {
                          selected.addAll(selectable);
                        }
                        onChanged();
                      }),
          ])),
      for (final sale in shown) ...[
        const Divider(height: 1, thickness: .6, color: OwnerStyle.line),
        _SaleRow(
            sale: sale,
            strings: s,
            selected: selected.contains(sale.saleId),
            open: open.contains(sale.saleId),
            enabled: enabled,
            onAskCancel: () async {
              if (await askToCancelSale(context, sale.saleId)) {
                _afterChange(ref, stationId);
                if (context.mounted) _toast(context, s.cancelSent);
              }
            },
            onSelect: (yes) {
              yes ? selected.add(sale.saleId) : selected.remove(sale.saleId);
              onChanged();
            },
            onToggle: () {
              open.contains(sale.saleId)
                  ? open.remove(sale.saleId)
                  : open.add(sale.saleId);
              onChanged();
            }),
      ],
    ]));
  }
}

class _SaleRow extends StatelessWidget {
  final OfficeSale sale;
  final Strings strings;
  final bool selected, open, enabled;
  final ValueChanged<bool> onSelect;
  final VoidCallback onToggle, onAskCancel;
  const _SaleRow(
      {required this.onAskCancel,
      required this.sale,
      required this.strings,
      required this.selected,
      required this.open,
      required this.enabled,
      required this.onSelect,
      required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    double u(double n) => OwnerStyle.px(context, n);
    final time =
        sale.recordedAt == null ? '—' : s.hhmm(eatClock(sale.recordedAt!));
    final amount = formatTsh(sale.amount);
    final products = sale.lines.isEmpty
        ? sale.product
        : sale.lines.map((l) => l.name).join(', ');
    return Padding(
        padding: EdgeInsets.only(left: u(4), right: u(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 48,
              height: 48,
              child: sale.selectable
                  ? Checkbox(
                      value: selected,
                      semanticLabel: s.selectSale(time, amount),
                      onChanged: enabled ? (v) => onSelect(v ?? false) : null)
                  : null),
          Expanded(
              child: InkWell(
                  onTap: onToggle,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                          padding: EdgeInsets.symmetric(vertical: u(10)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '$time · ${_payment(s, sale.payment, customer: sale.customer)}',
                                    style: _body(context)),
                                if (products.isNotEmpty)
                                  Text(products, style: _meta(context)),
                                Text(amount,
                                    style: OwnerStyle.text(context, 15,
                                        weight: 600,
                                        color: sale.voided
                                            ? OwnerStyle.muted
                                            : OwnerStyle.ink)),
                                if (sale.voided)
                                  Text(s.voidedNotVerified,
                                      style: _status(context, MNColors.muted)),
                                if (sale.officeEntered) ...[
                                  Text(s.lostEnteredByOffice,
                                      style:
                                          _status(context, MNColors.warning)),
                                  Text(
                                      s.lostEnteredNames(sale.enteredBy!,
                                          sale.enteredAllowedBy ?? ''),
                                      style: _meta(context)),
                                  if (sale.enteredByMe && !sale.verified)
                                    Text(s.lostSaleAskerCannotVerify,
                                        style: _body(context)),
                                ],
                                if (sale.cancelRequestId != null)
                                  Text(s.cancelWaiting,
                                      style:
                                          _status(context, MNColors.warning)),
                                if (sale.heldForReview) ...[
                                  Text(s.autoHeldLabel,
                                      style:
                                          _status(context, MNColors.warning)),
                                  for (final code in sale.autoCheck!.reasons)
                                    Text(s.autoHoldReason(code),
                                        style: _body(context)),
                                ],
                                if (open)
                                  for (final l in sale.lines)
                                    Text(
                                        '${_qty(l.quantity)} × ${l.name} · ${formatTsh(l.amount)}',
                                        style: _body(context)),
                                if (!open && sale.lines.isNotEmpty)
                                  Text(s.showSaleLines,
                                      style:
                                          _status(context, OwnerStyle.muted)),
                                if (sale.cancellable)
                                  MNTextButton(s.cancelAsk,
                                      onPressed: enabled ? onAskCancel : null),
                              ]))))),
        ]));
  }
}

// Damage reports -----------------------------------------------------------------------

class _DamageSection extends ConsumerWidget {
  final String stationId;
  const _DamageSection({required this.stationId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerAsyncView(
        value: ref.watch(stationDamageProvider(stationId)),
        onRetry: () => ref.invalidate(stationDamageProvider(stationId)),
        isEmpty: (rows) => rows.isEmpty,
        empty: (_) => MNNote(s.noDamageWaiting, tone: MNNoteTone.info),
        data: (rows) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OwnerHelp(message: s.damageDecisionHelp),
              _gap(context),
              _Paged(
                  count: rows.length,
                  itemBuilder: (_, i) =>
                      _DamageCard(report: rows[i], stationId: stationId)),
            ]));
  }
}

class _DamageCard extends ConsumerWidget {
  final OfficeDamageReport report;
  final String stationId;
  const _DamageCard({required this.report, required this.stationId});

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecisionSheet(report: report, approve: approve));
    if (done != true) return;
    _afterChange(ref, stationId);
    if (context.mounted) _toast(context, s.decisionSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(report.productName, style: _title(context)),
      Text(_quantity(s, report.quantity, report.unit), style: _body(context)),
      Text(report.vendorName, style: _body(context)),
      Text(s.reasonText(s.damageReason(report.reason)), style: _body(context)),
      if (report.note != null)
        Text(s.noteText(report.note!), style: _body(context)),
      if (report.imageUrl != null) ...[
        _gap(context),
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(report.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Text(s.damagePhotoUnavailable, style: _body(context)))),
      ],
      Text(_when(s, report.reportedAt), style: _meta(context)),
      _gap(context, 4),
      Text(
          report.pending
              ? s.damageWaitingDecision
              : s.damageStatus(true, report.status),
          style: _status(
              context, report.pending ? MNColors.warning : MNColors.success)),
      if (report.pending) ...[
        _gap(context),
        MNButton(s.damageApprove, onPressed: () => _decide(context, ref, true)),
        _gap(context, 8),
        MNButton.secondary(s.damageReject,
            onPressed: () => _decide(context, ref, false)),
      ],
    ]));
  }
}

class _DecisionSheet extends ConsumerStatefulWidget {
  final OfficeDamageReport report;
  final bool approve;
  const _DecisionSheet({required this.report, required this.approve});
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
    if (reason.length < 3 || reason.length > 500) {
      setState(() => _error = s.decisionReasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          r.decideDamage(widget.report.id,
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
    final r = widget.report;
    return MNSheet(
        title: widget.approve ? s.damageApproveTitle : s.damageRejectTitle,
        children: [
          MNNote(
              widget.approve
                  ? s.damageApproveBody(
                      _quantity(s, r.quantity, r.unit), r.productName)
                  : s.damageRejectBody,
              tone: widget.approve ? MNNoteTone.warning : MNNoteTone.info),
          MNTextField(
              label: s.decisionReason,
              controller: _reason,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(500)]),
          if (_error != null) MNNote(_error!, error: true),
          MNButton(widget.approve ? s.damageApprove : s.damageReject,
              busy: _busy, onPressed: _busy ? null : _save),
        ]);
  }
}

// Funga Siku closing counts ------------------------------------------------------------

class _ClosingSection extends ConsumerStatefulWidget {
  final String stationId;
  const _ClosingSection({required this.stationId});
  @override
  ConsumerState<_ClosingSection> createState() => _ClosingSectionState();
}

class _ClosingSectionState extends ConsumerState<_ClosingSection> {
  /// Counts the server confirmed while this screen was open.
  final _confirmed = <String, OfficeClosingCount>{};
  final _errors = <String, String>{};
  final _busy = <String>{};

  Future<void> _confirm(OfficeClosingCount count) async {
    if (_busy.contains(count.id)) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy.add(count.id);
      _errors.remove(count.id);
    });
    try {
      final row = await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => r.confirmClosing(count.id));
      if (mounted) setState(() => _confirmed[count.id] = row);
      ref.invalidate(verificationQueueProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _errors[count.id] = officeErrorText(s, error));
      }
      // Blockers may have changed on the server.
      ref.invalidate(stationClosingsProvider(widget.stationId));
    } finally {
      if (mounted) setState(() => _busy.remove(count.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final id = widget.stationId;
    return OwnerAsyncView(
        value: ref.watch(stationClosingsProvider(id)),
        onRetry: () => ref.invalidate(stationClosingsProvider(id)),
        isEmpty: (rows) => rows.isEmpty && _confirmed.isEmpty,
        empty: (_) => MNNote(s.noClosingsWaiting, tone: MNNoteTone.info),
        data: (rows) {
          final shown = [
            for (final r in rows) _confirmed[r.id] ?? r,
            for (final c in _confirmed.values)
              if (!rows.any((r) => r.id == c.id)) c,
          ];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OwnerHelp(message: s.closingConfirmHelp),
                _gap(context),
                _Paged(
                    count: shown.length,
                    itemBuilder: (_, i) => _ClosingCard(
                        count: shown[i],
                        strings: s,
                        busy: _busy.contains(shown[i].id),
                        error: _errors[shown[i].id],
                        onConfirm: () => _confirm(shown[i]))),
              ]);
        });
  }
}

class _ClosingCard extends StatelessWidget {
  final OfficeClosingCount count;
  final Strings strings;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;
  const _ClosingCard(
      {required this.count,
      required this.strings,
      required this.busy,
      required this.error,
      required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final blockers = [
      if (count.unverifiedSales > 0)
        s.closingBlockedSales(count.unverifiedSales),
      if (count.pendingDamage > 0) s.closingBlockedDamage(count.pendingDamage),
      if (count.previousDayUnreconciled > 0) s.closingBlockedPreviousDay,
    ];
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(count.vendorName, style: _title(context)),
      Text(_day(s, count.businessDate), style: _meta(context)),
      _gap(context, 4),
      Text(count.confirmed ? s.confirmedByOffice : s.awaitingOfficeCheck,
          style: _status(
              context, count.confirmed ? MNColors.success : MNColors.warning)),
      _gap(context, 8),
      // Expected and difference exist only once the server fixed them.
      if (count.lines.isNotEmpty)
        for (final l in count.lines) _ResultLine(line: l, strings: s)
      else if (count.countedLines.isNotEmpty) ...[
        Text(s.closingVendorCounted, style: _meta(context)),
        for (final l in count.countedLines)
          Text('${l.name} · ${_qty(l.counted)}', style: _body(context)),
      ],
      if (!count.confirmed && blockers.isNotEmpty) ...[
        _gap(context),
        MNNote('${s.closingBlocked} ${blockers.join(', ')}'),
      ],
      if (error != null) ...[
        _gap(context),
        MNNote(error!, error: true),
      ],
      if (!count.confirmed) ...[
        _gap(context),
        MNButton(s.confirmCount,
            busy: busy, onPressed: count.blocked || busy ? null : onConfirm),
      ],
    ]));
  }
}

class _ResultLine extends StatelessWidget {
  final OfficeClosingLine line;
  final Strings strings;
  const _ResultLine({required this.line, required this.strings});
  @override
  Widget build(BuildContext context) {
    final s = strings;
    final d = line.difference;
    // Shortage in the error colour, surplus in the warning colour.
    final color = d < 0
        ? MNColors.error
        : d > 0
            ? MNColors.warning
            : OwnerStyle.muted;
    return Padding(
        padding: EdgeInsets.only(bottom: OwnerStyle.px(context, 6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.name, style: _body(context)),
          Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${s.closingExpected} ${_qty(line.expected)} · '
                        '${s.closingCounted} ${_qty(line.counted)} · '),
                TextSpan(
                    text: '${s.closingDifference} ${_signed(d)}',
                    style: _status(context, color)),
              ]),
              style: _meta(context)),
        ]));
  }
}

// Problems -------------------------------------------------------------------------------

class OfficeVerificationProblemsScreen extends ConsumerStatefulWidget {
  final String stationId;
  const OfficeVerificationProblemsScreen({super.key, required this.stationId});
  @override
  ConsumerState<OfficeVerificationProblemsScreen> createState() =>
      _VerificationProblemsState();
}

class _VerificationProblemsState
    extends ConsumerState<OfficeVerificationProblemsScreen> {
  bool _resolved = false;
  OfficeException? _selected;

  Future<void> _resolve(OfficeException problem) async {
    final s = ref.read(stringsProvider);
    if (problem.kind == 'receipt_mismatch' &&
        (stockAccess(ref).review || stockAccess(ref).transitLoss)) {
      final result = await showMNSheet<String>(context,
          builder: (_) => ReceiptMismatchSheet(problem: problem));
      if (result == null) return;
      _afterChange(ref, widget.stationId);
      setState(() {
        _selected = null;
        _resolved = true;
      });
      if (mounted) _toast(context, s.mismatchResolved(result));
      return;
    }

    final settled = await showMNSheet<bool>(context,
        builder: (_) => ResolveProblemSheet(problem: problem));
    if (settled == null) return;
    _afterChange(ref, widget.stationId);
    setState(() {
      _selected = null;
      _resolved = settled;
    });
    if (mounted) {
      _toast(context, settled ? s.problemResolved : s.problemSentForApproval);
    }
  }

  Future<void> _setStandardCost() async {
    await context.push(MNRoutes.officePerformanceSettings);
    if (!mounted) return;
    _afterChange(ref, widget.stationId);
    setState(() {
      _selected = null;
      _resolved = false;
    });
  }

  void _lateEntrySaved(bool settled) {
    _afterChange(ref, widget.stationId);
    setState(() {
      _selected = null;
      _resolved = settled;
    });
    final s = ref.read(stringsProvider);
    _toast(context, settled ? s.problemResolved : s.problemSentForApproval);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final allowed = _access(ref).verify;
    final openValue = ref.watch(stationProblemsProvider(widget.stationId));
    final resolvedValue = _resolved
        ? ref.watch(resolvedStationProblemsProvider(widget.stationId))
        : null;
    final openCount = openValue.valueOrNull?.length ?? 0;
    final problem = _selected;
    if (problem != null) {
      final auth = ref.watch(officeSessionProvider).valueOrNull;
      final owner = auth is OfficeSignedIn && auth.profile.isOwner;
      final canResolveMismatch =
          stockAccess(ref).review || stockAccess(ref).transitLoss;
      final canResolve = problem.status == 'open' &&
          problem.kind != 'late_entry' &&
          problem.kind != 'missing_agreed_price' &&
          (problem.kind != 'receipt_mismatch' || canResolveMismatch) &&
          problem.resolutions.isNotEmpty;
      return OwnerPage(
          title: s.problemKind(problem.kind),
          subtitle: Text(s.problemDetails,
              style: OwnerStyle.text(context, 16, color: OwnerStyle.muted)),
          headingSize: 26,
          contentGap: 8,
          strings: s,
          onBack: () => setState(() => _selected = null),
          child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
              child: _ProblemDetails(
                  problem: problem,
                  onResolve: canResolve ? () => _resolve(problem) : null,
                  onSetStandardCost: owner && problem.status == 'open'
                      ? _setStandardCost
                      : null,
                  onLateEntrySaved: _lateEntrySaved,
                  onLateEntryCancel: () => setState(() => _selected = null))));
    }

    return OwnerPage(
        title: s.problems,
        subtitle: Text(s.problemOpenCount(openCount),
            style: OwnerStyle.text(context, 16, color: OwnerStyle.muted)),
        headingSize: 26,
        contentGap: 8,
        trailing: OwnerHelp(message: s.problemsHelp, compact: true),
        strings: s,
        onRefresh: allowed
            ? () => _resolved
                ? ref.refresh(
                    resolvedStationProblemsProvider(widget.stationId).future)
                : ref.refresh(stationProblemsProvider(widget.stationId).future)
            : null,
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
            child: !allowed
                ? MNNote(s.notAllowed)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        _ProblemsTabs(
                            selected: _resolved ? 1 : 0,
                            openLabel: s.problemOpenTab(openCount),
                            resolvedLabel: s.problemResolvedTab,
                            onSelect: (index) =>
                                setState(() => _resolved = index == 1)),
                        _gap(context),
                        OwnerAsyncView(
                            value: _resolved ? resolvedValue! : openValue,
                            onRetry: () => ref.invalidate(_resolved
                                ? resolvedStationProblemsProvider(
                                    widget.stationId)
                                : stationProblemsProvider(widget.stationId)),
                            isEmpty: (rows) => rows.isEmpty,
                            empty: (_) => MNNote(
                                _resolved
                                    ? s.problemNoResolved
                                    : s.noOpenProblems,
                                tone: MNNoteTone.info),
                            data: (rows) => _ProblemList(
                                problems: rows,
                                strings: s,
                                onOpen: (problem) =>
                                    setState(() => _selected = problem))),
                      ])));
  }
}

class _ProblemsTabs extends StatelessWidget {
  final int selected;
  final String openLabel, resolvedLabel;
  final ValueChanged<int> onSelect;
  const _ProblemsTabs(
      {required this.selected,
      required this.openLabel,
      required this.resolvedLabel,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(OwnerStyle.px(context, 4)),
      decoration: BoxDecoration(
          color: OwnerStyle.scoreTabs,
          borderRadius: BorderRadius.circular(OwnerStyle.px(context, 12))),
      child: Row(children: [
        for (final (index, label) in [openLabel, resolvedLabel].indexed)
          Expanded(
              child: Material(
                  color:
                      index == selected ? OwnerStyle.white : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(OwnerStyle.px(context, 10)),
                  child: InkWell(
                      borderRadius:
                          BorderRadius.circular(OwnerStyle.px(context, 10)),
                      onTap: () => onSelect(index),
                      child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: OwnerStyle.px(context, 44)),
                          child: Center(
                              child: Text(label,
                                  style: OwnerStyle.text(context, 14,
                                      weight: index == selected ? 600 : 400,
                                      color: OwnerStyle.muted))))))),
      ]));
}

class _ProblemList extends StatelessWidget {
  final List<OfficeException> problems;
  final Strings strings;
  final ValueChanged<OfficeException> onOpen;
  const _ProblemList(
      {required this.problems, required this.strings, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<OfficeException>>{};
    for (final problem in problems) {
      final key = problem.kind == 'missing_agreed_price'
          ? [
              problem.kind,
              problem.stationId ?? '',
              problem.vendorId ?? '',
              problem.openedAt?.toIso8601String() ?? problem.id,
            ].join('|')
          : problem.id;
      (groups[key] ??= []).add(problem);
    }
    return Column(
        children: groups.values
            .map((items) => Padding(
                padding: EdgeInsets.only(bottom: OwnerStyle.px(context, 10)),
                child: _ProblemGroup(
                    problems: items, strings: strings, onOpen: onOpen)))
            .toList());
  }
}

class _ProblemGroup extends StatefulWidget {
  final List<OfficeException> problems;
  final Strings strings;
  final ValueChanged<OfficeException> onOpen;
  const _ProblemGroup(
      {required this.problems, required this.strings, required this.onOpen});

  @override
  State<_ProblemGroup> createState() => _ProblemGroupState();
}

class _ProblemGroupState extends State<_ProblemGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.problems;
    final problem = items.first;
    final s = widget.strings;
    final grouped = items.length > 1 &&
        problem.kind == 'missing_agreed_price' &&
        problem.status == 'open';
    final color = switch (problem.severity) {
      'critical' => MNColors.error,
      'info' => OwnerStyle.muted,
      _ => MNColors.warning,
    };
    return OwnerCard(
        child: Column(children: [
      InkWell(
          onTap: grouped
              ? () => setState(() => _expanded = !_expanded)
              : () => widget.onOpen(problem),
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: OwnerStyle.px(context, 80)),
              child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: OwnerStyle.px(context, 16),
                      vertical: OwnerStyle.px(context, 12)),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(
                              grouped
                                  ? s.problemCountProducts(items.length)
                                  : s.problemKind(problem.kind),
                              style: _title(context)),
                          if (problem.vendorName != null)
                            Text(problem.vendorName!, style: _body(context)),
                          Text(s.openedAt(_when(s, problem.openedAt)),
                              style: _meta(context)),
                        ])),
                    SizedBox(width: OwnerStyle.px(context, 8)),
                    _ProblemBadge(
                        label: s.severityName(problem.severity), color: color),
                    SizedBox(width: OwnerStyle.px(context, 8)),
                    Icon(
                        grouped
                            ? _expanded
                                ? Icons.expand_less
                                : Icons.chevron_right
                            : Icons.chevron_right,
                        color: OwnerStyle.muted,
                        size: OwnerStyle.px(context, 22)),
                  ])))),
      if (grouped && _expanded)
        for (final item in items) ...[
          Padding(
              padding: EdgeInsets.only(left: OwnerStyle.px(context, 16)),
              child: const Divider(height: 1, color: OwnerStyle.line)),
          InkWell(
              onTap: () => widget.onOpen(item),
              child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: OwnerStyle.px(context, 48)),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: OwnerStyle.px(context, 18)),
                      child: Row(children: [
                        Expanded(
                            child: Text(item.productName ?? s.problemProduct,
                                style: _body(context))),
                        Icon(Icons.chevron_right,
                            size: OwnerStyle.px(context, 20),
                            color: OwnerStyle.muted),
                      ])))),
        ],
    ]));
  }
}

class _ProblemBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ProblemBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.symmetric(
          horizontal: OwnerStyle.px(context, 9),
          vertical: OwnerStyle.px(context, 5)),
      decoration: BoxDecoration(
          color: OwnerStyle.scoreChip,
          borderRadius: BorderRadius.circular(OwnerStyle.px(context, 20))),
      child: Text(label, style: _meta(context).copyWith(color: color)));
}

class _ProblemDetails extends ConsumerWidget {
  final OfficeException problem;
  final VoidCallback? onResolve, onSetStandardCost;
  final ValueChanged<bool> onLateEntrySaved;
  final VoidCallback onLateEntryCancel;
  const _ProblemDetails(
      {required this.problem,
      required this.onLateEntrySaved,
      required this.onLateEntryCancel,
      this.onResolve,
      this.onSetStandardCost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final p = problem;
    final missingPrice = p.kind == 'missing_agreed_price';
    final lateEntry = p.kind == 'late_entry';
    final resolved = p.status == 'resolved';
    final autoCost = p.resolution == 'standard_cost_set';
    final rows = <(String, String)>[
      if (p.vendorName != null) (s.problemVendor, p.vendorName!),
      if (p.productName != null) (s.problemProduct, p.productName!),
      (s.bonusDate, _when(s, p.openedAt)),
      (s.problemType, s.severityName(p.severity)),
    ];
    if (p.stationName != null) rows.insert(2, (s.station, p.stationName!));
    final reason = p.detail['reason'];
    final reasons = p.detail['reasons'];
    final reasonList = [
      for (final item
          in reasons is List ? reasons : [if (reasons != null) reasons])
        if ('$item'.trim().isNotEmpty) '$item'.trim()
    ];
    final loss = num.tryParse('${p.detail['abnormal_loss_cost'] ?? ''}');
    final batches = p.detail['batches'];
    final note = p.detail['note'];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerCard(
          child: Padding(
              padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
              child: Column(children: [
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0) _gap(context, 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: OwnerStyle.px(context, 82),
                        child: Text(row.$1, style: _meta(context))),
                    Expanded(child: Text(row.$2, style: _body(context))),
                  ]),
                ],
              ]))),
      if (p.kind == 'stock_difference' && p.vendorName == null) ...[
        _gap(context),
        MNNote(s.stationDifferenceLine, tone: MNNoteTone.info),
      ],
      if (p.kind == 'oversold' && p.detail['backdated'] == true) ...[
        _gap(context),
        MNNote(s.oversoldBackdatedLine, tone: MNNoteTone.info),
      ],
      if (p.kind == 'possible_duplicate_entry') ...[
        _gap(context),
        MNNote(s.duplicateEntryLine, tone: MNNoteTone.warning),
      ],
      if (missingPrice && !resolved) ...[
        _gap(context),
        OwnerCard(
            child: Padding(
                padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MNIcon(MNIconData.info,
                          size: 20, color: OwnerStyle.muted),
                      SizedBox(width: OwnerStyle.px(context, 12)),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(s.problemAutoResolveTitle,
                                style: _body(context)
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(s.problemAutoResolveCost,
                                style: _meta(context)),
                            if (onSetStandardCost != null) ...[
                              _gap(context, 8),
                              TextButton(
                                  onPressed: onSetStandardCost,
                                  child: Text(s.problemSetStandardCost)),
                            ],
                          ])),
                    ]))),
      ],
      if (lateEntry && !resolved) ...[
        _gap(context),
        if (p.resolutions.isNotEmpty)
          _ProblemResolveForm(
              problem: p,
              onSaved: onLateEntrySaved,
              onCancel: onLateEntryCancel)
        else
          MNNote(s.problemNotResolved, tone: MNNoteTone.info),
      ] else if (p.resolutions.isNotEmpty &&
          !resolved &&
          !missingPrice &&
          onResolve != null) ...[
        _gap(context),
        OwnerCard(
            child: Padding(
                padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
                child: MNButton(s.problemResolve, onPressed: onResolve))),
      ],
      if (resolved) ...[
        _gap(context),
        OwnerCard(
            child: Padding(
                padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
                child: Text(s.resolutionName(p.resolution ?? 'reviewed'),
                    style: _status(context,
                        autoCost ? OwnerStyle.muted : MNColors.success)))),
      ],
      if (p.resolutionReason?.trim().isNotEmpty == true) ...[
        _gap(context),
        MNNote(p.resolutionReason!, tone: MNNoteTone.info),
      ],
      if (reason is String && reason.trim().isNotEmpty) ...[
        _gap(context),
        MNNote(s.reasonText(reason.trim()), tone: MNNoteTone.info),
      ],
      if (reasonList.isNotEmpty) ...[
        _gap(context),
        MNNote(s.reasonText(reasonList.join(', ')), tone: MNNoteTone.info),
      ],
      if (loss != null && loss > 0) ...[
        _gap(context),
        MNNote(s.abnormalLossText(formatTsh(loss.round())),
            tone: MNNoteTone.info),
      ],
      if (batches != null) ...[
        _gap(context),
        MNNote(s.batchesText('$batches'), tone: MNNoteTone.info),
      ],
      if (note is String && note.trim().isNotEmpty) ...[
        _gap(context),
        MNNote(note.trim(), tone: MNNoteTone.info),
      ],
      _gap(context, 18),
      Text(s.problemHistory, style: _title(context)),
      _gap(context, 8),
      OwnerCard(
          child: Padding(
              padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProblemHistoryRow(
                        title: s.problemOpened, date: _when(s, p.openedAt)),
                    if (resolved) ...[
                      const Divider(height: 18, color: OwnerStyle.line),
                      _ProblemHistoryRow(
                          title: autoCost
                              ? s.problemAutoResolveTitle
                              : s.problemResolvedHistory,
                          date: p.resolvedAt == null
                              ? s.notSet
                              : _when(s, p.resolvedAt),
                          detail: p.resolutionReason),
                    ],
                    if (!resolved &&
                        !missingPrice &&
                        !lateEntry &&
                        onResolve == null)
                      Text(s.problemNotResolved, style: _meta(context)),
                  ]))),
    ]);
  }
}

class _ProblemHistoryRow extends StatelessWidget {
  final String title, date;
  final String? detail;
  const _ProblemHistoryRow(
      {required this.title, required this.date, this.detail});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MNIcon(MNIconData.clock, size: 20, color: OwnerStyle.muted),
          SizedBox(width: OwnerStyle.px(context, 12)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: _body(context)),
                Text(date, style: _meta(context)),
                if (detail?.trim().isNotEmpty == true)
                  Text(detail!, style: _meta(context)),
              ])),
        ],
      );
}

class _ProblemResolveForm extends ConsumerStatefulWidget {
  final OfficeException problem;
  final ValueChanged<bool> onSaved;
  final VoidCallback onCancel;
  const _ProblemResolveForm(
      {required this.problem, required this.onSaved, required this.onCancel});

  @override
  ConsumerState<_ProblemResolveForm> createState() =>
      _ProblemResolveFormState();
}

class _ProblemResolveFormState extends ConsumerState<_ProblemResolveForm> {
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeApprovalsRepository).resolveException(widget.problem.id,
              resolution: widget.problem.resolutions.first,
              reason: _note.text.trim()));
      if (mounted) widget.onSaved(result.resolved);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final note = _note.text.trim();
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.problemResolve, style: _title(context)),
                  Text(s.problemNoteHelp, style: _meta(context)),
                  _gap(context, 8),
                  MNTextField(
                      label: s.problemNoteRequired,
                      controller: _note,
                      enabled: !_busy,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      inputFormatters: [LengthLimitingTextInputFormatter(140)]),
                  Align(
                      alignment: Alignment.centerRight,
                      child: Text('${_note.text.length}/140',
                          style: _meta(context))),
                  if (_error != null) ...[
                    _gap(context, 6),
                    MNNote(_error!, error: true),
                  ],
                  _gap(context, 8),
                  Row(children: [
                    Expanded(
                        child: MNButton.secondary(s.problemCancel,
                            onPressed: _busy ? null : widget.onCancel)),
                    SizedBox(width: OwnerStyle.px(context, 12)),
                    Expanded(
                        child: MNButton(s.problemResolve,
                            busy: _busy,
                            onPressed:
                                note.isNotEmpty && !_busy ? _save : null)),
                  ]),
                ])));
  }
}
