import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

/// A payout Omoterra has sent that the supplier has not yet confirmed.
bool awaitsConfirmation(Map payout) =>
    payout['status'] == 'paid' && payout['supplier_confirmation'] != 'received';

/// Where the supplier's part of an order is, coloured by who acts next.
class OrderStageText extends StatelessWidget {
  final String stage;
  const OrderStageText(this.stage, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (stage) {
      'cancelled' || 'payout_disputed' => OColors.error,
      'payout_confirmed' => OColors.positive,
      'awaiting_buyer_payment' ||
      'awaiting_payout' ||
      'confirm_payout' =>
        OColors.warning,
      _ => OColors.secondary,
    };
    return Text('●  ${context.s.orderStage(stage)}',
        style: TextStyle(
            fontSize: 12.5, color: color, fontWeight: FontWeight.w600));
  }
}

/// Every step from order to confirmed payout (backend supplier_progress):
/// done steps are green, the step the order waits on is amber.
class OrderTimeline extends StatelessWidget {
  final Map order;
  const OrderTimeline(this.order, {super.key});

  String _note(Strings s, Map step) {
    final notes = <String>[];
    final key = step['key'];
    if (key == 'collection_scheduled' &&
        order['expected_collection_date'] != null) {
      notes.add(s.collectionOn(s.dateText(order['expected_collection_date'])));
    }
    if (key == 'collected' && order['accepted_quantity'] != null) {
      final unit = '${order['unit_type']}';
      String qty(Object? v) =>
          '${amount(v)} ${s.unit(unit, num.tryParse('$v'))}';
      final rejected = num.tryParse('${order['rejected_quantity']}') ?? 0;
      notes.add(s.acceptedRejected(qty(order['accepted_quantity']),
          rejected > 0 ? qty(order['rejected_quantity']) : ''));
    }
    final payouts = order['settlements'] as List? ?? const [];
    if (key == 'payout_sent' &&
        payouts.isNotEmpty &&
        payouts.first['paid_at'] != null) {
      final ref = payouts.first['payment_reference'];
      notes.add([
        tsh(payouts.first['total_payable']),
        if (ref != null) s.refText('$ref')
      ].join(' · '));
    }
    if (step['at'] != null) notes.add(s.dateText(step['at']));
    return notes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final steps = (order['steps'] as List? ?? const []).cast<Map>();
    final cancelled = order['stage'] == 'cancelled';
    final current = steps.firstWhere((step) => step['done'] != true,
        orElse: () => {})['key'];
    return Column(children: [
      for (final (index, step) in steps.indexed)
        IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 26,
              child: Column(children: [
                _Mark(
                    done: step['done'] == true,
                    current: !cancelled && step['key'] == current),
                if (index < steps.length - 1)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: step['done'] == true
                              ? OColors.positive
                              : OColors.border)),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 2),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.orderStep('${step['key']}'),
                            style: TextStyle(
                                fontWeight: step['done'] == true
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: step['done'] == true
                                    ? OColors.ink
                                    : OColors.muted)),
                        if (_note(s, step).isNotEmpty)
                          Text(_note(s, step),
                              style: const TextStyle(
                                  fontSize: 12.5, color: OColors.secondary)),
                      ]))),
        ])),
    ]);
  }
}

class _Mark extends StatelessWidget {
  final bool done, current;
  const _Mark({required this.done, required this.current});
  @override
  Widget build(BuildContext context) => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? OColors.positive : Colors.white,
          border: Border.all(
              color: done
                  ? OColors.positive
                  : current
                      ? OColors.warning
                      : OColors.border,
              width: current ? 3 : 2)),
      child:
          done ? const Icon(Icons.check, size: 14, color: Colors.white) : null);
}

/// "Did this payout reach you?" for one paid settlement. Saves the answer
/// and refreshes every screen that shows orders or payouts.
class PayoutConfirmCard extends ConsumerStatefulWidget {
  final Map payout;
  const PayoutConfirmCard(this.payout, {super.key});
  @override
  ConsumerState<PayoutConfirmCard> createState() => _PayoutConfirmCardState();
}

class _PayoutConfirmCardState extends ConsumerState<PayoutConfirmCard> {
  final _note = TextEditingController();
  bool _reporting = false, _busy = false;
  Object? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _answer(bool received) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = widget.payout['id'];
    try {
      await ref.read(repositoryProvider).write('/supplier/payouts/$id/confirm',
          {'received': received, 'note': received ? '' : _note.text.trim()});
      for (final path in [
        '/supplier/orders',
        '/supplier/payouts',
        '/supplier/payouts/$id',
        if (widget.payout['order_hold_id'] != null)
          '/supplier/orders/${widget.payout['order_hold_id']}',
      ]) {
        ref.invalidate(resourceProvider(path));
      }
      if (mounted) setState(() => _reporting = false);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final payout = widget.payout;
    final disputed = payout['supplier_confirmation'] == 'not_received';
    final ref_ = payout['payment_reference'];
    return Container(
        key: Key('payout_confirm_${payout['id']}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: disputed ? const Color(0xFFFCEFEF) : const Color(0xFFFDF6E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: disputed
                    ? const Color(0xFFF0CCCC)
                    : const Color(0xFFF4E2B6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              disputed
                  ? s.reportedNotReceived
                  : s.omoterraSentYou(tsh(payout['total_payable'])),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
              [
                if (payout['reference'] != null)
                  s.orderNo('${payout['reference']}'),
                s.sentOn(s.dateText(payout['paid_at'])),
                if (ref_ != null) s.refText('$ref_'),
              ].join(' · '),
              style: const TextStyle(color: OColors.secondary)),
          const SizedBox(height: 6),
          Text(disputed ? s.disputedHint : s.confirmPayoutHint,
              style: const TextStyle(
                  fontSize: 13, color: OColors.secondary, height: 1.45)),
          const SizedBox(height: 14),
          if (_reporting) ...[
            TextField(
                key: const Key('payout_note'),
                controller: _note,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                    labelText: s.whatHappened, hintText: s.whatHappenedHint)),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            ErrorState(_error!),
            const SizedBox(height: 8),
          ],
          if (_reporting)
            Row(children: [
              Expanded(
                  child: OmoterraButton(s.back,
                      secondary: true,
                      onPressed: _busy
                          ? null
                          : () => setState(() => _reporting = false))),
              const SizedBox(width: 10),
              Expanded(
                  child: OmoterraButton(s.reportNotReceived,
                      busy: _busy, onPressed: () => _answer(false))),
            ])
          else ...[
            OmoterraButton(disputed ? s.receivedNow : s.yesReceived,
                key: const Key('payout_received'),
                icon: Icons.check,
                busy: _busy,
                onPressed: () => _answer(true)),
            if (!disputed) ...[
              const SizedBox(height: 10),
              OmoterraButton(s.notReceived,
                  key: const Key('payout_not_received'),
                  secondary: true,
                  onPressed:
                      _busy ? null : () => setState(() => _reporting = true)),
            ],
          ],
        ]));
  }
}
