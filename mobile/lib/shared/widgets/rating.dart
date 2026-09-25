import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/repository.dart';
import '../../core/theme/theme.dart';
import 'components.dart';

const _star = Color(0xFFE8A317);

/// Five stars, filled to [value] (halves shown for averages like 4.5).
class StarRow extends StatelessWidget {
  final double value;
  final double size;
  const StarRow(this.value, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = value - i;
        return Icon(
            fill >= .75
                ? Icons.star_rounded
                : fill >= .25
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: _star);
      }));
}

/// Compact rating for listing cards: "★ 4.7 (12)", or "New supplier" until
/// there are enough ratings to show an average.
class RatingBadge extends StatelessWidget {
  final Map<String, dynamic>? rating;
  const RatingBadge(this.rating, {super.key});
  @override
  Widget build(BuildContext context) {
    final average = (rating?['rating'] as num?)?.toDouble();
    if (average == null) {
      return const Text('New supplier',
          style: TextStyle(fontSize: 11, color: OColors.secondary));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 14, color: _star),
      const SizedBox(width: 2),
      Text(average.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      Text(' (${rating?['ratings'] ?? 0})',
          style: const TextStyle(fontSize: 11, color: OColors.secondary)),
    ]);
  }
}

/// The supplier's track record on the listing page: buyer rating,
/// deliveries through Omoterra, and how much passed Omoterra's quality check.
class ReputationStrip extends StatelessWidget {
  final Map<String, dynamic>? reputation;
  const ReputationStrip(this.reputation, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = reputation ?? const {};
    final average = (r['rating'] as num?)?.toDouble();
    final deliveries = (r['deliveries'] as num?)?.toInt() ?? 0;
    final quality = (r['quality_passed'] as num?)?.toInt();
    Widget stat(String value, String label, {Widget? leading}) => Expanded(
            child: Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading, const SizedBox(width: 3)],
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OColors.forest)),
          ]),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: OColors.secondary)),
        ]));
    return Container(
        key: const Key('reputation_strip'),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OColors.border)),
        child: Row(children: [
          stat(
              average == null ? 'New' : average.toStringAsFixed(1),
              average == null
                  ? 'Not enough ratings yet'
                  : '${r['ratings']} buyer ratings',
              leading: average == null
                  ? null
                  : const Icon(Icons.star_rounded, size: 17, color: _star)),
          stat('$deliveries', deliveries == 1 ? 'delivery' : 'deliveries'),
          stat(quality == null ? '—' : '$quality%', 'passed quality check'),
        ]));
  }
}

/// On a delivered order: pick 1–5 stars and optionally say why. Shows the
/// buyer's rating afterwards, still editable while the backend allows it.
class RateOrderCard extends ConsumerStatefulWidget {
  final String orderId;
  final Map<String, dynamic>? rating;
  final bool canRate;
  final VoidCallback onRated;
  const RateOrderCard(
      {super.key,
      required this.orderId,
      required this.rating,
      required this.canRate,
      required this.onRated});
  @override
  ConsumerState<RateOrderCard> createState() => _RateOrderCardState();
}

class _RateOrderCardState extends ConsumerState<RateOrderCard> {
  late int stars = (widget.rating?['stars'] as num?)?.toInt() ?? 0;
  late final comment =
      TextEditingController(text: '${widget.rating?['comment'] ?? ''}');
  late bool editing = widget.rating == null;
  bool busy = false;
  Object? error;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write(
          '/orders/${widget.orderId}/rating',
          {'stars': stars, 'comment': comment.text.trim()});
      if (!mounted) return;
      setState(() => editing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thank you. Your rating helps other buyers.')));
      widget.onRated();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return Surface(
          child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your rating',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          StarRow(stars.toDouble(), size: 20),
          if (comment.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comment.text),
          ],
        ])),
        if (widget.canRate)
          TextButton(
              onPressed: () => setState(() => editing = true),
              child: const Text('Edit')),
      ]));
    }
    return Surface(
        key: const Key('rate_order_card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How was this order?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
              'Your rating builds the supplier’s reputation. Suppliers never see who rated them.',
              style: TextStyle(fontSize: 12, color: OColors.secondary)),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                  button: true,
                  label: '$i star${i == 1 ? '' : 's'}',
                  selected: stars == i,
                  child: InkResponse(
                      radius: 24,
                      onTap: busy ? null : () => setState(() => stars = i),
                      child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                              i <= stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 36,
                              color: _star)))),
            const SizedBox(width: 8),
            Flexible(
                child: Text(_labels[stars],
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: comment,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                  hintText:
                      'What went well, or what could be better? (optional)')),
          if (error != null) ErrorState(error!),
          OmoterraButton(
              widget.rating == null ? 'Submit rating' : 'Update rating',
              busy: busy,
              onPressed: stars == 0 ? null : submit),
        ]));
  }
}
