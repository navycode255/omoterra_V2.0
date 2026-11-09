import '../../shared/widgets/icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/offline_unlock.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/note.dart';
import 'count_entry_screen.dart';
import '../../shared/widgets/radio_mark.dart';
import '../../shared/widgets/states.dart';
import '../sales/checkout.dart';
import '../sales/sales_store.dart';
import 'closing_status.dart';
import 'closing_store.dart';
import 'frozen_count.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/filter_sheet.dart';
import '../../shared/widgets/sheet.dart';

/// Today's closing count for the signed-in vendor, if already saved.
final todayClosingProvider = StreamProvider.autoDispose<ClosingView?>((ref) {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return Stream.value(null);
  return ref.watch(closingStoreProvider).watchForDay(
      vendorId: auth.profile.id,
      stationKey: auth.profile.stationKey,
      businessDay: businessDate(ref.watch(clockProvider)()));
});

final closingForDateProvider =
    StreamProvider.autoDispose.family<ClosingView?, DateTime>((ref, day) {
  final auth = ref.watch(sessionProvider).valueOrNull;
  if (auth is! SignedIn) return Stream.value(null);
  return ref.watch(closingStoreProvider).watchForDay(
      vendorId: auth.profile.id,
      stationKey: auth.profile.stationKey,
      businessDay: day);
});

/// Funga Siku: count every tracked product, check the summary, confirm.
/// Once saved, today's count is read-only on the phone.
class ClosingScreen extends ConsumerStatefulWidget {
  const ClosingScreen({super.key});

  @override
  ConsumerState<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends ConsumerState<ClosingScreen> {
  /// Counts start empty so every product is actually counted.
  final _counted = <String, int>{};
  final _reasons = <String, String>{};
  final _notes = <String, String>{};
  /// Frozen: the count can no longer change; differences are now shown. Held
  /// on the phone from the freeze until the save, and used for everything in
  /// between: figures, products, expected figures and the day.
  FrozenCount? _snapshot;
  bool _loaded = false;
  bool get _frozen => _snapshot != null;
  final _noteControllers = <String, TextEditingController>{};
  DateTime? _selectedDate;
  int _filterStatus = 0;

  @override
  void initState() {
    super.initState();
    _loadFrozen();
  }

  /// A count frozen earlier goes straight back to its frozen step.
  Future<void> _loadFrozen() async {
    FrozenCount? held;
    try {
      final auth = ref.read(sessionProvider).valueOrNull;
      if (auth is SignedIn) {
        final today = businessDate(ref.read(clockProvider)());
        held = await ref.read(frozenCountStoreProvider).pending(
            vendorId: auth.profile.id,
            stationKey: auth.profile.stationKey,
            yesterday: today.subtract(const Duration(days: 1)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loaded = true;
          if (held != null) _hold(held);
        });
      }
    }
  }

  void _hold(FrozenCount count) {
    _snapshot = count;
    _counted
      ..clear()
      ..addAll(count.counted);
  }

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// [saved]: a stored count exists, so its differences may be filtered.
  /// While counting, no filter may reveal the expected figure.
  Future<void> _filter({bool saved = false}) async {
    final strings = ref.read(stringsProvider);
    final today = businessDate(ref.read(clockProvider)());
    var day = _selectedDate ?? today;
    var status = _filterStatus;
    final yesterday = today.subtract(const Duration(days: 1));
    final applied = await showMNSheet<bool>(context,
        builder: (sheetContext) => StatefulBuilder(builder: (context, update) {
              final custom = day != today && day != yesterday;
              return MNFilterSheet(
                  title: strings.filterCount,
                  applyLabel: strings.applyFilters,
                  onApply: () => Navigator.pop(sheetContext, true),
                  onReset: () => update(() {
                        day = today;
                        status = 0;
                      }),
                  children: [
                    MNFilterGroup(title: strings.dateLabel, children: [
                      for (final (value, label) in [
                        (today, strings.todayLabel),
                        (yesterday, strings.yesterdayLabel),
                      ])
                        MNFilterOption(
                            label: label,
                            mark: MNFilterMark.radio,
                            selected: day == value,
                            onTap: () => update(() => day = value)),
                      MNFilterOption(
                          label: strings.customDate,
                          mark: MNFilterMark.calendar,
                          selected: custom,
                          detail: custom ? strings.date(day) : null,
                          onTap: () async {
                            final selected = await showMNDateWheelSheet(context,
                                initial: day,
                                first: DateTime.utc(2020),
                                last: today);
                            if (selected != null) update(() => day = selected);
                          }),
                    ]),
                    MNFilterGroup(title: strings.statusLabel, children: [
                      for (final (i, label) in [
                        strings.allRecords,
                        strings.countedLabel,
                        strings.notYetCounted,
                        if (saved) strings.withDifference
                      ].indexed)
                        MNFilterOption(
                            label: label,
                            mark: MNFilterMark.radio,
                            selected: status == i,
                            onTap: () => update(() => status = i)),
                    ]),
                  ]);
            }));
    if (applied == true && mounted) {
      setState(() {
        _selectedDate = day;
        _filterStatus = status;
      });
    }
  }

  bool _busy = false;
  String? _error;

  Future<void> _freeze(List<Product> products, DateTime day) async {
    final strings = ref.read(stringsProvider);
    final auth = ref.read(sessionProvider).valueOrNull;
    if (auth is! SignedIn) return;
    final yes = await showMNConfirmDialog(context,
        sheet: true,
        title: strings.freezeTitle,
        message: strings.freezeBody,
        confirmLabel: strings.freezeContinue,
        cancelLabel: strings.freezeBack);
    if (!yes || !mounted) return;
    final count = FrozenCount(
        countId: const Uuid().v4(),
        day: dateKey(day),
        frozenAt: ref.read(clockProvider)(),
        lines: [
          for (final p in products)
            FrozenLine(p.id, p.name, _counted[p.id]!, p.remaining!)
        ]);
    try {
      // On the phone first: the expected figures show only once this is kept.
      await ref.read(frozenCountStoreProvider).save(
          vendorId: auth.profile.id,
          stationKey: auth.profile.stationKey,
          count: count);
      if (mounted) setState(() => _hold(count));
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveNotDone);
    }
  }

  bool _differs(Product p) =>
      p.remaining != null && _counted[p.id] != p.remaining;

  bool _complete(List<Product> products) => products.every((p) =>
      !_differs(p) ||
      (_reasons[p.id] != null && (_notes[p.id] ?? '').trim().isNotEmpty));

  Future<void> _save() async {
    final frozen = _snapshot;
    if (_busy || frozen == null) return;
    _busy = true;
    final strings = ref.read(stringsProvider);
    final auth = ref.read(sessionProvider).valueOrNull;
    try {
      if (auth is! SignedIn) return;
      final yes = await showMNConfirmDialog(context,
          sheet: true,
          title: strings.closeConfirmTitle,
          message: strings.closeConfirmBody,
          confirmLabel: strings.closeYes,
          cancelLabel: strings.stay);
      if (!yes || !mounted) return;
      await ref.read(closingStoreProvider).submit(
          countId: frozen.countId,
          vendorId: auth.profile.id,
          stationKey: auth.profile.stationKey,
          now: frozen.frozenAt,
          products: frozen.products,
          counted: frozen.counted,
          reasons: Map.of(_reasons),
          notes: Map.of(_notes),
          businessDay: frozen.businessDay,
          frozen: true);
      // Saved: the next visit finds the count (and clears this if it fails here).
      try {
        await ref.read(frozenCountStoreProvider).clear(
            vendorId: auth.profile.id,
            stationKey: auth.profile.stationKey,
            day: frozen.day);
      } catch (_) {}
      if (mounted) context.pushReplacement(MNRoutes.dayClosed);
    } on ClosingRefused catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.block) {
              ClosingBlock.missingProducts => strings.countAllFirst,
              ClosingBlock.alreadyClosed => strings.correctionsByOffice,
              _ => strings.saveNotDone,
            });
      }
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveNotDone);
    } finally {
      _busy = false;
    }
  }

  /// After freezing: counted, expected and difference; a reason and note
  /// only where they differ.
  Widget _frozenRow(Product p, Strings strings) {
    final counted = _counted[p.id]!;
    final expected = p.remaining;
    final differs = _differs(p);
    final note = _noteControllers.putIfAbsent(
        p.id, () => TextEditingController(text: _notes[p.id]));
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: MNSpace.x4, vertical: MNSpace.x3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.name, style: MNText.title),
        const SizedBox(height: 4),
        Wrap(spacing: 16, runSpacing: 4, children: [
          Text('${strings.countedFigure}: $counted', style: MNText.body),
          if (expected != null)
            Text('${strings.expectedRemaining}: $expected',
                style: MNText.body),
          if (differs)
            Text(
                '${strings.differenceLabel}: ${counted - expected! > 0 ? '+' : ''}${counted - expected}',
                style: MNText.label),
        ]),
        if (differs) ...[
          const SizedBox(height: 8),
          Text(strings.differenceReasonRequired, style: MNText.label),
          for (final option in {
            'sales': strings.countReasonSales,
            'damaged': strings.countReasonDamaged,
            'other': strings.countReasonOther
          }.entries)
            ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                leading: MNRadioMark(selected: _reasons[p.id] == option.key),
                title: Text(option.value, style: MNText.body),
                onTap: () => setState(() => _reasons[p.id] = option.key)),
          Text(strings.noteRequired, style: MNText.label),
          TextField(
              controller: note,
              maxLength: 100,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(hintText: strings.noteHint),
              onChanged: (v) => setState(() {
                    if (v.trim().isEmpty) {
                      _notes.remove(p.id);
                    } else {
                      _notes[p.id] = v.trim();
                    }
                  })),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    ref.watch(catalogRefreshProvider);
    final today = businessDate(ref.watch(clockProvider)());
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayState = ref.watch(yesterdayClosingProvider).valueOrNull;
    // Yesterday not closed and nothing done today: close yesterday first.
    final selectedDay = _snapshot?.businessDay ??
        _selectedDate ??
        (yesterdayState == YesterdayClosing.open ? yesterday : today);
    final pastDay = dateKey(selectedDay) != dateKey(today);
    final closable = _frozen ||
        !pastDay ||
        (dateKey(selectedDay) == dateKey(yesterday) &&
            yesterdayState == YesterdayClosing.open);
    final existing = ref.watch(closingForDateProvider(selectedDay));
    final catalogue = productsToCount(
        ref.watch(productsProvider).valueOrNull ?? const <Product>[]);
    final products = _snapshot?.products ?? catalogue;
    if (existing.valueOrNull != null) {
      return ClosingStatusScreen(
          view: existing.valueOrNull!,
          onFilter: () => _filter(saved: true),
          filterStatus: _filterStatus);
    }
    final count = products.where((p) => _counted[p.id] != null).length;
    final allCounted = count == products.length;
    return Scaffold(
        appBar: MNAppHeader(
            light: true,
            title: _frozen ? strings.reviewCount : strings.closeDay,
            actions: [
              MNWorkflowHelp(messages: [
                strings.closingOnlyCount,
                strings.correctionsByOffice
              ]),
              if (!_frozen)
                IconButton(
                    tooltip: strings.filter,
                    onPressed: _filter,
                    icon: const MNIcon(MNIconData.filter))
            ]),
        body: !_loaded || existing.isLoading
            ? const MNLoadingState()
            : products.isEmpty || !closable
                ? MNEmptyState(
                    icon: MNIconData.lock,
                    title: strings.noCount,
                    message: !pastDay
                        ? strings.catalogOffline
                        : dateKey(selectedDay) == dateKey(yesterday) &&
                                yesterdayState == YesterdayClosing.missed
                            ? strings.yesterdayMissed(strings.date(selectedDay))
                            : strings.correctionsByOffice)
                : ListView(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          MNSpace.x4, MNSpace.x4, MNSpace.x4, MNSpace.x2),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                                onTap: _frozen ? null : _filter,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(children: [
                                      const MNIcon(MNIconData.calendar,
                                          size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(
                                              pastDay
                                                  ? strings.closeDayFor(
                                                      strings.date(selectedDay))
                                                  : strings.today(selectedDay),
                                              style: MNText.label)),
                                      if (!_frozen)
                                        const MNIcon(MNIconData.down)
                                    ]))),
                            if (pastDay) ...[
                              const SizedBox(height: 8),
                              MNNote(strings.closeYesterdayBody(
                                  strings.date(selectedDay))),
                            ],
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      strings.countedProgress(
                                          count, products.length),
                                      style: MNText.title)),
                              Text(
                                  '${products.isEmpty ? 0 : (count * 100 / products.length).round()}%',
                                  style: MNText.meta),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: products.isEmpty
                                        ? 0
                                        : count / products.length,
                                    color: MNColors.red,
                                    backgroundColor: MNColors.disabled,
                                    minHeight: 7)),
                          ]),
                    ),
                    if (_frozen) ...[
                      Padding(
                          padding: const EdgeInsets.fromLTRB(
                              MNSpace.x4, 0, MNSpace.x4, MNSpace.x2),
                          child: MNNote(strings.frozenNote)),
                      for (final p in products) _frozenRow(p, strings),
                    ] else
                      for (final p
                          in products.where((p) => switch (_filterStatus) {
                                1 => _counted[p.id] != null,
                                2 => _counted[p.id] == null,
                                _ => true,
                              }))
                        _CountRow(
                          product: p,
                          value: _counted[p.id],
                          onChanged: (v) => setState(() {
                            _counted[p.id] = v.quantity;
                            _error = null;
                          }),
                        ),
                    Padding(
                      padding: const EdgeInsets.all(MNSpace.x4),
                      child: Column(children: [
                        if (_error != null) ...[
                          const SizedBox(height: MNSpace.x3),
                          MNNote(_error!, error: true),
                        ],
                      ]),
                    ),
                  ]),
        bottomNavigationBar: !_loaded || products.isEmpty || !closable
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
                  child: ref
                              .watch(offlineRecordingStoppedProvider)
                              .valueOrNull ==
                          true
                      // Offline time is over (policies §10.4).
                      ? MNNote(strings.offlineRecordingStopped)
                      : _frozen
                          ? MNButton(strings.saveAndClose,
                              onPressed: _complete(products) ? _save : null)
                          : MNButton(
                              allCounted
                                  ? strings.reviewCount
                                  : strings.continueCounting,
                              onPressed: () => allCounted
                                  ? _freeze(products, selectedDay)
                                  : setState(
                                      () => _error = strings.countAllFirst)),
                ),
              ),
    );
  }
}

/// One product while counting: its name and the count, never the expected
/// figure. Tapping opens the keypad. Starts empty ("—").
class _CountRow extends ConsumerWidget {
  final Product product;
  final int? value;
  final ValueChanged<CountEntry> onChanged;
  const _CountRow(
      {required this.product, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(product.name, style: MNText.title),
      subtitle: value == null
          ? Text(strings.notYetCounted, style: MNText.meta)
          : Text(strings.countedLabel, style: MNText.meta),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value == null ? '—' : '$value', style: MNText.title),
        const SizedBox(width: 16),
        MNIcon(value == null ? MNIconData.clock : MNIconData.okCircle,
            color: MNColors.muted, size: 20),
        const SizedBox(width: 8),
        const MNIcon(MNIconData.chevron, size: 20),
      ]),
      onTap: () async {
        final number = await Navigator.of(context).push<CountEntry>(
            MaterialPageRoute(
                builder: (_) => CountEntryScreen(
                    product: product,
                    initial: value)));
        if (number != null) onChanged(number);
      },
    );
  }
}
