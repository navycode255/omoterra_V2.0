import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';

const _steps = [
  'open',
  'partially_matched',
  'fully_matched',
  'confirmed',
  'fulfilling',
  'completed',
];

int _currentStep(String status) => _steps.indexOf(switch (status) {
      'submitted' => 'open',
      'sourcing' => 'partially_matched',
      'supply_found' => 'fully_matched',
      _ => status,
    });

/// A buyer's supply request: where it stands, how much supply is secured,
/// and its details (editable until Omoterra starts securing supply).
class RequestDetail extends ConsumerWidget {
  final String id;
  const RequestDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(s.supplyRequest,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: OColors.ink))),
        body: Stack(children: [
          const Positioned(
              right: -40,
              top: 10,
              child: Leaf(size: 170, angle: .75, color: Color(0xFFEAF3EC))),
          const Positioned(
              right: -24,
              top: 120,
              child: Leaf(size: 110, angle: .35, color: Color(0xFFE4EFE7))),
          ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                ResourceView('/requests/$id', builder: (raw) {
                  final data = Map<String, dynamic>.from(raw as Map);
                  final status = '${data['status']}';
                  final quantity = num.tryParse('${data['quantity']}') ?? 0;
                  final secured =
                      num.tryParse('${data['secured_quantity']}') ?? 0;
                  final remaining =
                      num.tryParse('${data['remaining_quantity']}') ?? 0;
                  final units =
                      s.unit(unitFor('${data['category']}'), quantity);
                  final share = quantity == 0
                      ? 0.0
                      : (secured / quantity).clamp(0, 1).toDouble();
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Headline(),
                        const SizedBox(height: 6),
                        Text(s.requestNo(id.substring(0, 8).toUpperCase()),
                            style: const TextStyle(
                                fontSize: 16, color: OColors.secondary)),
                        const SizedBox(height: 28),
                        if (status == 'cancelled')
                          const _CancelledNotice()
                        else
                          _Timeline(current: _currentStep(status)),
                        const SizedBox(height: 22),
                        _ProgressCard(
                            secured: secured,
                            quantity: quantity,
                            remaining: remaining,
                            share: share),
                        const SizedBox(height: 14),
                        DecorCard(
                            padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                    child: Text(s.requestDetails,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: OColors.ink))),
                                if (data['editable'] == true)
                                  TextButton.icon(
                                      style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF0B5E3F)),
                                      onPressed: () => context.push(
                                          '/requests/$id/edit',
                                          extra: data),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      label: Text(s.editRequest)),
                              ]),
                              const SizedBox(height: 4),
                              for (final (i, row) in [
                                (
                                  Icons.egg_alt_outlined,
                                  s.supplyWord,
                                  s.label('${data['category']}')
                                ),
                                (
                                  null,
                                  s.quantity,
                                  '${amount(quantity)} $units'
                                ),
                                (
                                  Icons.calendar_today_outlined,
                                  s.neededByLabel,
                                  s.dateText(data['needed_by_date'])
                                ),
                                (
                                  Icons.location_on_outlined,
                                  s.deliveryAreaLabel,
                                  '${data['delivery_area']}'
                                ),
                                (
                                  Icons.check_circle_outline,
                                  s.secured,
                                  '${amount(secured)} / ${amount(quantity)}'
                                ),
                                (
                                  Icons.schedule,
                                  s.remaining,
                                  amount(remaining)
                                ),
                              ].indexed) ...[
                                if (i > 0)
                                  const Divider(
                                      height: 1,
                                      indent: 36,
                                      color: Color(0xFFEAEFEC)),
                                _DetailRow(
                                    icon: row.$1, label: row.$2, value: row.$3),
                              ],
                            ])),
                        if (data['converted_order_id'] != null) ...[
                          const SizedBox(height: 20),
                          OmoterraButton(s.trackYourOrder,
                              onPressed: () => context
                                  .go('/order/${data['converted_order_id']}')),
                        ],
                      ]);
                }),
              ]),
        ]));
  }
}

/// "We're on it." with the ⓘ that explains what happens next.
class _Headline extends StatelessWidget {
  const _Headline();
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Wraps rather than overflowing on narrow screens and large text.
        Expanded(
            child: Text(context.s.weAreOnIt,
                style: const TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: OColors.ink,
                    letterSpacing: -1))),
        // Opens the same explanation dialog as the other ⓘ buttons.
        InfoButton(
            title: context.s.whatHappensNext,
            message: context.s.whatHappensNextBody,
            icon: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xFF0B6B45), shape: BoxShape.circle),
                // A lowercase "i", as in the design.
                child: const Text('i',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)))),
      ]);
}

class _Timeline extends StatelessWidget {
  final int current;
  const _Timeline({required this.current});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, step) in _steps.indexed)
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                SizedBox(
                    width: 26,
                    child: Column(children: [
                      Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                              color: i <= current
                                  ? const Color(0xFF0B6B45)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: i <= current
                                  ? null
                                  : Border.all(
                                      color: const Color(0xFF9AA39E),
                                      width: 1.6)),
                          child: i <= current
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null),
                      if (i < _steps.length - 1)
                        Expanded(
                            child: CustomPaint(
                                painter: _DottedLine(),
                                size: const Size(2, double.infinity))),
                    ])),
                const SizedBox(width: 16),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 1, bottom: 18),
                        child: Text(context.s.requestStep(step),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: i <= current
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: OColors.ink)))),
              ])),
      ]);
}

class _DottedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9D3CD)
      ..strokeWidth = 1.2;
    for (var y = 4.0; y < size.height - 2; y += 5) {
      canvas.drawLine(
          Offset(size.width / 2, y), Offset(size.width / 2, y + 2.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFBEDED),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.cancel_outlined, color: OColors.error),
        const SizedBox(width: 10),
        Expanded(
            child: Text(context.s.requestCancelled,
                style: const TextStyle(color: OColors.ink))),
      ]));
}

class _ProgressCard extends StatelessWidget {
  final num secured, quantity, remaining;
  final double share;
  const _ProgressCard(
      {required this.secured,
      required this.quantity,
      required this.remaining,
      required this.share});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
          color: const Color(0xFFEFF6F1),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(context.s.supplyProgress,
                    style: const TextStyle(fontSize: 15, color: OColors.ink)),
                const SizedBox(height: 2),
                Text(context.s.securedOf(amount(secured), amount(quantity)),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: OColors.ink)),
              ])),
          Text(context.s.nRemaining(amount(remaining)),
              style: const TextStyle(fontSize: 13.5, color: OColors.secondary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: share,
                      minHeight: 7,
                      color: const Color(0xFF0B6B45),
                      backgroundColor: const Color(0xFFDDE9E1)))),
          const SizedBox(width: 12),
          Text('${(share * 100).round()}%',
              style: const TextStyle(fontSize: 13.5, color: OColors.secondary)),
        ]),
      ]));
}

class _DetailRow extends StatelessWidget {
  final IconData? icon;
  final String label, value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        SizedBox(
            width: 24,
            child: icon == null
                ? const CubeOutlineIcon(
                    size: 20, color: OColors.ink, stroke: 1.5)
                : Icon(icon, size: 21, color: OColors.ink)),
        const SizedBox(width: 12),
        Expanded(
            flex: 5,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 14.5, color: OColors.secondary))),
        Expanded(
            flex: 6,
            child: Text(value,
                style: const TextStyle(fontSize: 14.5, color: OColors.ink))),
      ]));
}
