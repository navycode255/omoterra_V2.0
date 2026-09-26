import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';
import '../../shared/widgets/stock_video.dart';
import '../../shared/widgets/supply_art.dart';
import 'inventory_screens.dart';
import 'stock_media_screen.dart';

final _askedConfirm = StateProvider<Set<String>>((ref) => const {});

class StockDetail extends ConsumerWidget {
  final String id;

  /// Opened from a "confirm your stock" reminder: ask straight away.
  final bool askConfirm;
  const StockDetail(this.id, {super.key, this.askConfirm = false});
  Future<void> action(BuildContext context, WidgetRef ref,
      Map<String, dynamic> row, String action) async {
    final s = ref.read(stringsProvider);
    await omoterraSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action == 'confirm' ? s.confirmStock : s.pauseListing,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(action == 'confirm'
              ? s.stillAvailableQ(
                  stockUnits(row['quantity_available'], row['unit_type'], s))
              : s.pauseListingBody),
          const SizedBox(height: 24),
          DataForm(
              path: '/supplier/stock/$id',
              method: 'PATCH',
              fixed: {'action': action},
              fields: const [],
              button: action == 'confirm'
                  ? s.confirmQty(amount(row['quantity_available']))
                  : s.pauseListing,
              onSuccess: (_) {
                refreshStock(ref, id);
                Navigator.pop(context);
              }),
          if (action == 'confirm')
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/stock/$id/correct');
                },
                child: Text(s.countIsDifferent)),
        ]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(s.stockDetailsTitle,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: OColors.ink)),
            actions: [
              IconButton(
                  tooltip: s.refreshStock,
                  onPressed: () => refreshStock(ref, id),
                  icon: const Icon(Icons.refresh))
            ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ResourceView('/supplier/stock/$id',
              builder: (row) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (askConfirm &&
                            !ref.read(_askedConfirm).contains(id) &&
                            ![
                              'pending_review',
                              'rejected',
                              'paused',
                              'changes_requested'
                            ].contains(row['listing_status']))
                          _AskOnce(() {
                            // Once per stock: reloading after the answer must not ask again.
                            ref.read(_askedConfirm.notifier).state = {
                              ...ref.read(_askedConfirm),
                              id
                            };
                            action(context, ref, Map<String, dynamic>.from(row),
                                'confirm');
                          }),
                        StockGallery(List<String>.from(row['photos']),
                            category: '${row['category']}'),
                        if (row['video'] != null) ...[
                          const SizedBox(height: 10),
                          StockVideoTile(row['video']),
                        ],
                        const SizedBox(height: 18),
                        Text(s.label(row['category']),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    fontSize: 30, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        _StatusLine('${row['listing_status']}'),
                        if (row['listing_status'] == 'changes_requested')
                          _ChangesRequested(
                              id: id, note: '${row['review_note'] ?? ''}'),
                        const SizedBox(height: 16),
                        _Totals(row),
                        const SizedBox(height: 16),
                        _RecordSale(
                            enabled:
                                num.parse('${row['quantity_available']}') > 0,
                            onPressed: () => context.push('/stock/$id/sell')),
                        const SizedBox(height: 26),
                        _heading(context, s.manageYourStock),
                        _Card(children: [
                          _ManageRow(
                              art: const SupplyArt('history', size: 40),
                              title: s.correctStockCount,
                              onTap: () => context.push('/stock/$id/correct')),
                          _ManageRow(
                              art: const SupplyArt('crate', size: 40),
                              title: s.addStockReceived,
                              onTap: () => context.push('/stock/$id/add')),
                          _ManageRow(
                              art: const Icon(Icons.image_outlined,
                                  color: OColors.forest, size: 24),
                              title: s.photosAndVideo,
                              onTap: () => context.push('/stock/$id/media')),
                          _ManageRow(
                              art: const Icon(Icons.pending_actions_outlined,
                                  color: OColors.forest, size: 24),
                              title: s.stockHistory,
                              onTap: () => context.push('/stock/$id/history')),
                        ]),
                        const SizedBox(height: 26),
                        _heading(context, s.stockInformation),
                        _Card(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            children: [
                              _Info(
                                  s.recordedTotal,
                                  stockUnits(row['quantity_total'],
                                      row['unit_type'], s)),
                              _Info(s.askingPriceShort,
                                  '${tsh(row['farmer_asking_price_per_unit'])} / ${s.unit('${row['unit_type']}', 1)}'),
                              _Info(s.regionLabel, '${row['region']}'),
                              if ((row['specs'] as Map?)?.isNotEmpty ??
                                  false) ...[
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(height: 1)),
                                for (final spec in _specs(
                                    Map<String, dynamic>.from(row['specs']), s))
                                  _Info(spec.$1, spec.$2),
                              ],
                            ]),
                        // Confirming or pausing only applies to approved stock.
                        if (row['approved'] != false &&
                            !['pending_review', 'rejected', 'changes_requested']
                                .contains(row['listing_status'])) ...[
                          const SizedBox(height: 24),
                          OmoterraButton(s.confirmAvailability,
                              secondary: true,
                              onPressed: () =>
                                  action(context, ref, row, 'confirm')),
                          TextButton(
                              onPressed: () =>
                                  action(context, ref, row, 'pause'),
                              child: Text(s.pauseListing)),
                        ],
                      ]))
        ]));
  }
}

Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800)));

/// The specs a supplier entered, labelled and with their units.
List<(String, String)> _specs(Map<String, dynamic> specs, Strings s) {
  String? readable(String key, Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return null;
    return switch (key) {
      'avg_weight_kg' || 'weight_kg' => '$text kg',
      'age_weeks' => s.weeksCount(text),
      'ready_date' => s.dateText(text),
      'live_or_dressed' || 'form' => s.label(text),
      _ => text,
    };
  }

  final names = {
    'avg_weight_kg': s.avgWeight,
    'weight_kg': s.weight,
    'breed_type': s.breed,
    'live_or_dressed': s.form,
    'form': s.form,
    'age_weeks': s.age,
    'ready_date': s.readyDateShort,
  };
  return [
    for (final entry in specs.entries)
      if (readable(entry.key, entry.value) case final value?)
        (names[entry.key] ?? s.label(entry.key), value)
  ];
}

/// The status in words, coloured by what it means for buyers.
class _StatusLine extends StatelessWidget {
  final String status;
  const _StatusLine(this.status);
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'live' => OColors.positive,
      'rejected' => OColors.error,
      'pending_review' ||
      'needs_confirmation' ||
      'changes_requested' =>
        const Color(0xFFD9822B),
      _ => OColors.secondary,
    };
    final text = context.s.status(status);
    return Text(text.isEmpty ? text : text[0] + text.substring(1).toLowerCase(),
        style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color));
  }
}

/// Available, reserved and sold, side by side on a pale card.
class _Totals extends StatelessWidget {
  final Map row;
  const _Totals(this.row);
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget column(IconData? icon, String title, String key, bool strong) =>
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Shrinks on narrow phones rather than cutting the word off.
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: OColors.forest),
                  const SizedBox(width: 5),
                ],
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, color: OColors.secondary)),
              ])),
          const SizedBox(height: 6),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(amount(row[key]),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                      color: OColors.ink))),
        ]));
    const divider = SizedBox(
        height: 56,
        child: VerticalDivider(width: 18, color: Color(0xFFD6E3DA)));
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF6F1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0ECE4))),
        child: Row(children: [
          SupplyArt(
              switch ('${row['unit_type']}') {
                'animal' => 'cattle',
                'tray' => 'eggs',
                'kg' => 'goat_meat',
                _ => 'broilers',
              },
              size: 46),
          const SizedBox(width: 12),
          column(null, s.availableStat, 'quantity_available', true),
          divider,
          column(Icons.schedule, s.reservedStat, 'quantity_reserved', false),
          divider,
          column(Icons.bar_chart, s.soldStat, 'quantity_sold', false),
        ]));
  }
}

/// Record a sale, with the note about Omoterra deliveries behind its ⓘ.
class _RecordSale extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _RecordSale({required this.enabled, required this.onPressed});
  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: enabled ? onPressed : null,
                child: Text(context.s.recordASale))),
        Positioned(
            right: 6,
            child: InfoButton(
                color: enabled ? Colors.white : OColors.secondary,
                title: context.s.recordingSales,
                message: context.s.recordingSalesBody)),
      ]);
}

/// A white rounded card holding rows, as in Manage your stock.
class _Card extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  const _Card(
      {required this.children,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

class _ManageRow extends StatelessWidget {
  final Widget art;
  final String title;
  final VoidCallback onTap;
  const _ManageRow(
      {required this.art, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xFFEFF6F1), shape: BoxShape.circle),
                child: art),
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 16, color: OColors.ink))),
            const Icon(Icons.chevron_right, color: OColors.ink),
          ])));
}

class _Info extends StatelessWidget {
  final String name, value;
  const _Info(this.name, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 9,
            child: Text(name,
                style:
                    const TextStyle(fontSize: 15, color: OColors.secondary))),
        Expanded(
            flex: 11,
            child: Text(value,
                style: const TextStyle(fontSize: 15, color: OColors.ink))),
      ]));
}

/// What Omoterra asked to change, and the way to send the stock back.
class _ChangesRequested extends ConsumerWidget {
  final String id, note;
  const _ChangesRequested({required this.id, required this.note});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF6E5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF2D9A6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_note, color: Color(0xFFB26A00)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(ref.s.omoterraAskedChanges,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: OColors.ink))),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(note,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, color: OColors.ink)),
        ],
        const SizedBox(height: 14),
        OmoterraButton(ref.s.updatePhotosVideo,
            secondary: true, onPressed: () => context.push('/stock/$id/media')),
        const SizedBox(height: 8),
        DataForm(
            path: '/supplier/stock/$id',
            method: 'PATCH',
            fixed: const {'action': 'resubmit'},
            fields: const [],
            button: ref.s.sendBackForReview,
            onSuccess: (_) {
              refreshStock(ref, id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ref.read(stringsProvider).sentBackForReview)));
            }),
      ]));
}

/// Runs [ask] once, after the first frame that shows the stock.
class _AskOnce extends StatefulWidget {
  final VoidCallback ask;
  const _AskOnce(this.ask);
  @override
  State<_AskOnce> createState() => _AskOnceState();
}

class _AskOnceState extends State<_AskOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.ask();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
