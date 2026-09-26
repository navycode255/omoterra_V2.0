import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
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
      return Text(context.s.newSupplier,
          style: const TextStyle(fontSize: 11, color: OColors.secondary));
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

/// The supplier's track record: buyer rating, deliveries through Omoterra,
/// and how much passed Omoterra's quality check. Shown to suppliers on their
/// ratings page and to buyers on a listing.
class ReputationStrip extends StatelessWidget {
  final Map<String, dynamic>? reputation;
  const ReputationStrip(this.reputation, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = reputation ?? const {};
    final s = context.s;
    final average = (r['rating'] as num?)?.toDouble();
    final count = (r['ratings'] as num?)?.toInt() ?? 0;
    final deliveries = (r['deliveries'] as num?)?.toInt() ?? 0;
    final quality = (r['quality_passed'] as num?)?.toInt();
    Widget stat(IconData icon, String value, String label) => Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 26, color: OColors.forest),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 21,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: OColors.forest)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: OColors.secondary)),
        ]));
    const divider = SizedBox(
        height: 64, child: VerticalDivider(width: 1, color: Color(0xFFE5ECE7)));
    return Container(
        key: const Key('reputation_strip'),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE6EEE9)),
            boxShadow: [
              BoxShadow(
                  color: OColors.forest.withValues(alpha: .06),
                  blurRadius: 18,
                  offset: const Offset(0, 6))
            ]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          stat(
              Icons.star_border,
              average == null ? s.newLabel : average.toStringAsFixed(1),
              average == null ? s.awaiting : s.nRatings(count)),
          divider,
          stat(Icons.local_shipping_outlined, '$deliveries', s.deliveries),
          divider,
          stat(Icons.verified_user_outlined,
              quality == null ? '—' : '$quality%', s.quality),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).ratingThanks)));
      widget.onRated();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    if (!editing) {
      return Surface(
          child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.yourRating,
              style: const TextStyle(fontWeight: FontWeight.w700)),
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
              child: Text(s.edit)),
      ]));
    }
    return Surface(
        key: const Key('rate_order_card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.howWasOrder,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(s.ratingPrivacy,
              style: const TextStyle(fontSize: 12, color: OColors.secondary)),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                  button: true,
                  label: s.nStars(i),
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
                child: Text(s.starLabel(stars),
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: comment,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(hintText: s.ratingCommentHint)),
          if (error != null) ErrorState(error!),
          OmoterraButton(
              widget.rating == null ? s.submitRating : s.updateRating,
              busy: busy,
              onPressed: stars == 0 ? null : submit),
        ]));
  }
}
