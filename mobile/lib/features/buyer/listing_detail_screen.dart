import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/domain.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/rating.dart';
import '../../shared/widgets/stock_video.dart';

class ListingDetail extends ConsumerStatefulWidget {
  final String id;
  const ListingDetail(this.id, {super.key});
  @override
  ConsumerState<ListingDetail> createState() => _ListingDetailState();
}

class _ListingDetailState extends ConsumerState<ListingDetail> {
  final quantity = TextEditingController(text: '1');
  String key = newKey();
  Reservation? hold;
  bool busy = false;
  Object? error;
  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  Future<void> reserve({bool checkout = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(repositoryProvider);
      if (hold == null) {
        final response = await api.write('/reservations',
            {'listing_id': widget.id, 'quantity': quantity.text},
            key: key);
        hold = Reservation.fromJson(Map<String, dynamic>.from(response));
      }
      if (hold!.status != 'active' ||
          hold!.expiresAt.isBefore(DateTime.now())) {
        hold = null;
        key = newKey();
        throw ApiFailure(ref.read(stringsProvider).reservationExpiredReselect);
      }
      if (checkout && mounted) {
        final id = hold!.id;
        await context.push('/checkout/$id');
        if (mounted) {
          hold = null;
          key = newKey();
          ref.invalidate(resourceProvider('/listings/${widget.id}'));
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeQuantity() async {
    if (hold != null) {
      setState(() => busy = true);
      try {
        await ref
            .read(repositoryProvider)
            .write('/reservations/${hold!.id}', {}, method: 'DELETE');
        if (mounted) {
          setState(() {
            hold = null;
            key = newKey();
          });
        }
      } catch (e) {
        if (mounted) setState(() => error = e);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        body: ResourceView('/listings/${widget.id}', builder: (data) {
      final listing = SupplyListing.fromJson(Map<String, dynamic>.from(data));
      final count = num.tryParse(quantity.text) ?? 0;
      final total = count * num.parse(listing.price);
      return Column(children: [
        Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
          // Full-bleed hero with floating controls, as drawn.
          Stack(children: [
            Hero(
                tag: listing.id,
                child: ProductImage(listing.photos,
                    category: listing.category, height: 300)),
            Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
                child: Row(children: [
                  _HeroButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  const _HeroButton(icon: Icons.favorite_border),
                ])),
          ]),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (listing.video != null) ...[
                      StockVideoTile(listing.video!),
                      const SizedBox(height: 16),
                    ],
                    Text(s.label(listing.category),
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                        '${tsh(listing.price)} / ${s.unit(listing.unitType, 1)}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: OColors.forest)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.check_circle,
                          size: 15, color: OColors.positive),
                      const SizedBox(width: 5),
                      Text(s.omoterraApproved,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: OColors.positive,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        '${amount(listing.available)} ${s.unit(listing.unitType, num.tryParse(listing.available))} ${s.available} · ${listing.region}',
                        style: const TextStyle(
                            fontSize: 13, color: OColors.secondary)),
                    const SizedBox(height: 18),
                    _SupplierCard(
                        alias: listing.supplier?['public_alias'] ??
                            s.supplyPartner,
                        region: listing.region,
                        approved: s.omoterraApproved),
                    const SizedBox(height: 10),
                    ReputationStrip(listing.supplier?['reputation']
                        as Map<String, dynamic>?),
                    const SizedBox(height: 20),
                    Text(s.specifications,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _SpecTable(listing.specs),
                    if (error != null) ErrorState(error!),
                    if (hold != null) ...[
                      const SizedBox(height: 12),
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: OColors.soft,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.lock_clock,
                                size: 17, color: OColors.forest),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(s.reservedFor15,
                                    style: const TextStyle(fontSize: 13))),
                            TextButton(
                                onPressed: busy ? null : changeQuantity,
                                child: Text(s.change)),
                          ])),
                    ],
                    const SizedBox(height: 8),
                    Center(
                        child: TextButton(
                            onPressed: () => context.push('/request'),
                            child: Text(s.needMore))),
                    const SizedBox(height: 8),
                  ])),
        ])),
        // Sticky quantity + Buy Now bar. Quantity and the total share the
        // top row; Buy Now gets its own full-width row below rather than
        // squeezing in beside them.
        Container(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: OColors.border))),
            child: Column(children: [
              Row(children: [
                _Stepper(
                    value: quantity.text,
                    enabled: hold == null && !busy,
                    onMinus: () => setState(() {
                          final v = num.tryParse(quantity.text) ?? 1;
                          quantity.text = (v > 1 ? v - 1 : 1).toString();
                        }),
                    onPlus: () => setState(() => quantity.text =
                        ((num.tryParse(quantity.text) ?? 0) + 1).toString())),
                const SizedBox(width: 12),
                // Expanded + FittedBox so a large total (a cow at
                // TZS 1,500,000, say) shrinks to fit next to the stepper
                // on a narrow phone instead of overflowing the row.
                Expanded(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tsh(total),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                              Text(s.orderTotal,
                                  style: const TextStyle(
                                      fontSize: 11, color: OColors.muted)),
                            ]))),
              ]),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: busy ? null : () => reserve(checkout: true),
                  child: Text(busy ? '…' : s.buyNow)),
            ])),
      ]);
    }));
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HeroButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 19, color: OColors.ink))));
}

class _SupplierCard extends StatelessWidget {
  final String alias, region, approved;
  const _SupplierCard(
      {required this.alias, required this.region, required this.approved});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: OColors.pale,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OColors.border)),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: OColors.soft, shape: BoxShape.circle),
            child: const Icon(Icons.agriculture_outlined,
                size: 21, color: OColors.forest)),
        const SizedBox(width: 12),
        // The approved badge lives in this Expanded column, below the alias,
        // rather than as a fixed-width element sharing the row — that forced
        // an overflow on narrow phones once the alias/region text needed
        // most of the row's width.
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(alias,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 3),
          Text(region,
              style: const TextStyle(fontSize: 12, color: OColors.secondary)),
          const SizedBox(height: 6),
          // Deliberately no contact control: buyers never reach suppliers direct.
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified, size: 15, color: OColors.positive),
            const SizedBox(width: 4),
            Flexible(
                child: Text(approved,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        color: OColors.positive,
                        fontWeight: FontWeight.w600))),
          ]),
        ])),
      ]));
}

class _SpecTable extends StatelessWidget {
  final Map<String, dynamic> specs;
  const _SpecTable(this.specs);
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OColors.border)),
      child: Column(
          children: specs.entries.toList().asMap().entries.map((row) {
        final last = row.key == specs.length - 1;
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                border: last
                    ? null
                    : const Border(bottom: BorderSide(color: OColors.border))),
            child: Row(children: [
              Expanded(
                  child: Text(context.s.label(row.value.key),
                      style: const TextStyle(
                          fontSize: 13, color: OColors.secondary))),
              Text('${row.value.value}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]));
      }).toList()));
}

class _Stepper extends StatelessWidget {
  final String value;
  final bool enabled;
  final VoidCallback onMinus, onPlus;
  const _Stepper(
      {required this.value,
      required this.enabled,
      required this.onMinus,
      required this.onPlus});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _StepButton(icon: Icons.remove, onTap: enabled ? onMinus : null),
        SizedBox(
            width: 34,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700))),
        _StepButton(icon: Icons.add, onTap: enabled ? onPlus : null),
      ]));
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: SizedBox(
          width: 36,
          height: 44,
          child: Icon(icon,
              size: 17,
              color: onTap == null ? OColors.muted : OColors.forest)));
}
