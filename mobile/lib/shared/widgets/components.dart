import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/theme/theme.dart';
import '../models/domain.dart';
import 'brand_image.dart';
import 'supply_art.dart';

String label(String value) => value
    .split('_')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');
String amount(Object? value) =>
    NumberFormat('#,##0.##').format(num.tryParse('$value') ?? 0);
String tsh(Object? value) => 'TZS ${amount(value)}';
const categories = [
  'broilers',
  'local_chicken',
  'goats',
  'cattle',
  'chicken_meat',
  'beef',
  'goat_meat'
];
String unitFor(String c) => ['broilers', 'local_chicken'].contains(c)
    ? 'bird'
    : ['goats', 'cattle'].contains(c)
        ? 'animal'
        : 'kg';

class OmoterraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool busy, secondary;
  const OmoterraButton(this.text,
      {super.key, this.onPressed, this.busy = false, this.secondary = false});
  @override
  Widget build(BuildContext context) => secondary
      ? OutlinedButton(
          onPressed: busy ? null : onPressed,
          child: Text(busy ? 'Please wait…' : text))
      : FilledButton(
          onPressed: busy ? null : onPressed,
          child: Text(busy ? 'Please wait…' : text));
}

class OmoterraTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final int lines;
  final bool requiredField;
  const OmoterraTextField(this.label, this.controller,
      {super.key, this.keyboard, this.lines = 1, this.requiredField = true});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
          validator: (value) =>
              requiredField && (value == null || value.trim().isEmpty)
                  ? 'Enter ${label.toLowerCase()}'
                  : null));
}

class Surface extends StatelessWidget {
  final Widget child;
  final Color color;
  const Surface({super.key, required this.child, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OColors.border)),
      child: child);
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const SectionHeader(this.title, {super.key, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!))
      ]));
}

class StatusText extends StatelessWidget {
  final String status;
  const StatusText(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Text('●  ${label(status)}',
      style: TextStyle(
          fontSize: 12,
          color: ['cancelled', 'failed', 'rejected'].contains(status)
              ? OColors.error
              : status == 'needs_confirmation'
                  ? OColors.warning
                  : OColors.secondary));
}

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? retry;
  const ErrorState(this.error, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$error', style: const TextStyle(color: OColors.error)),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Try again'))
      ]));
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final Widget? action;
  const EmptyState(this.title, this.message, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Surface(
      color: OColors.pale,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SupplyArt('crate', size: 70, surface: false),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message),
        if (action != null) ...[const SizedBox(height: 24), action!]
      ]));
}

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Loading content',
      child: Column(
          children: List.generate(
              3,
              (i) => Container(
                  height: i == 0 ? 160 : 88,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: OColors.soft,
                      borderRadius: BorderRadius.circular(16))))));
}

class ResourceView extends ConsumerWidget {
  final String path;
  final Widget Function(dynamic) builder;
  const ResourceView(this.path, {super.key, required this.builder});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resourceProvider(path));
    if (state.hasError && state.hasValue) {
      return Column(children: [
        ErrorState(state.error!,
            retry: () => ref.invalidate(resourceProvider(path))),
        builder(state.value)
      ]);
    }
    return state.when(
        skipLoadingOnRefresh: true,
        data: builder,
        loading: () => const LoadingSkeleton(),
        error: (e, _) =>
            ErrorState(e, retry: () => ref.invalidate(resourceProvider(path))));
  }
}

/// Maps a listing category onto a photography slot in assets/images/.
String _slot(String category) => const {
      'chicken_meat': 'meat',
      'beef': 'meat',
      'goat_meat': 'meat',
    }[category] ??
    category;

class ProductImage extends StatelessWidget {
  final List<String> photos;
  final double height;
  final String category;
  const ProductImage(this.photos,
      {super.key, this.height = 150, this.category = 'crate'});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
          height: height,
          width: double.infinity,
          child: photos.isEmpty
              // No backend photo yet: fall back to supplied category
              // photography, then to the in-app vector artwork.
              ? BrandImage('category_${_slot(category)}',
                  fallbackArt: category, height: height)
              : PageView(
                  children: photos.map((photo) {
                  final ownApi = photo.startsWith('/media/');
                  final url = ownApi ? '$apiUrl$photo' : photo;
                  if (!ownApi) {
                    return CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: OColors.soft),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_outlined));
                  }
                  // Private images use only memory caching; never persist unapproved stock photos.
                  return FutureBuilder<String?>(
                      future: storage.read(key: 'session'),
                      builder: (context, token) {
                        if (!token.hasData) {
                          return Container(color: OColors.soft);
                        }
                        return Image.network(url,
                            fit: BoxFit.cover,
                            headers: {'Authorization': 'Bearer ${token.data}'},
                            errorBuilder: (_, __, ___) => const Center(
                                child:
                                    Icon(Icons.image_not_supported_outlined)));
                      });
                }).toList())));
}

class ListingCard extends StatelessWidget {
  final SupplyListing listing;
  final VoidCallback onTap;
  const ListingCard(this.listing, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OColors.border)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 92,
                    child: Hero(
                        tag: listing.id,
                        child: ProductImage(listing.photos,
                            category: listing.category, height: 92))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text(label(listing.category),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700))),
                        const Icon(Icons.favorite_border,
                            size: 19, color: OColors.muted),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${listing.specs['avg_weight_kg'] != null ? '${listing.specs['avg_weight_kg']} kg · ' : ''}${amount(listing.available)} available',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(listing.region,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('${tsh(listing.price)} / ${listing.unitType}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OColors.forest)),
                    ])),
              ]))));
}

class CategoryCard extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback onTap;
  const CategoryCard(this.category,
      {super.key, this.selected = false, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: selected ? OColors.soft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: selected ? OColors.forest : OColors.border,
                      width: selected ? 1.5 : 1)),
              child: Column(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BrandImage('category_${_slot(category)}',
                        fallbackArt: category, height: 74)),
                const SizedBox(height: 8),
                Text(label(category),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))
              ]))));
}

class MoneySummary extends StatelessWidget {
  final Map<String, String> rows;
  const MoneySummary(this.rows, {super.key});
  @override
  Widget build(BuildContext context) => Surface(
      child: Column(
          children: rows.entries
              .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(e.key)),
                    const SizedBox(width: 12),
                    Flexible(
                        child: Text(e.value,
                            textAlign: TextAlign.end,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)))
                  ])))
              .toList()));
}

class OrderProgress extends StatelessWidget {
  final String status;
  const OrderProgress(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') return const StatusText('cancelled');
    const steps = ['confirmed', 'preparing', 'on_the_way', 'delivered'];
    final current = steps.indexOf(status);
    return Column(
        children: List.generate(
            steps.length,
            (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= current ? OColors.forest : OColors.soft),
                      child: Icon(i < current ? Icons.check : Icons.circle,
                          size: 12,
                          color: i <= current ? Colors.white : OColors.muted)),
                  const SizedBox(width: 16),
                  Text(label(steps[i]),
                      style: TextStyle(
                          fontWeight:
                              i == current ? FontWeight.w700 : FontWeight.w400))
                ]))));
  }
}

Future<T?> omoterraSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(child: child)));

class OmoterraDateField extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final bool pastAllowed;
  const OmoterraDateField(this.title, this.controller,
      {super.key, this.pastAllowed = false});
  @override
  State<OmoterraDateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<OmoterraDateField> {
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: widget.controller,
          readOnly: true,
          decoration: InputDecoration(
              labelText: widget.title,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 19)),
          validator: (value) =>
              DateTime.tryParse(value ?? '') == null ? 'Choose a date' : null,
          onTap: () async {
            final now = DateTime.now();
            final earliest = widget.pastAllowed
                ? DateTime(now.year - 3)
                : DateTime(now.year, now.month, now.day);
            final latest =
                widget.pastAllowed ? now : now.add(const Duration(days: 730));
            final initial = DateTime.tryParse(widget.controller.text) ?? now;
            final picked = await showDatePicker(
                context: context,
                initialDate: initial.isBefore(earliest)
                    ? earliest
                    : initial.isAfter(latest)
                        ? latest
                        : initial,
                firstDate: earliest,
                lastDate: latest);
            if (picked != null && mounted) {
              setState(() => widget.controller.text =
                  picked.toIso8601String().split('T').first);
            }
          }));
}

/// iOS-style chevron back button. Used instead of Material's arrow so the
/// onboarding screens match the design.
class BackChevron extends StatelessWidget {
  final VoidCallback? onPressed;
  const BackChevron({super.key, this.onPressed});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.arrow_back_ios_new,
                  size: 20, color: OColors.ink))));
}

/// Lets the system back gesture leave the app from a root screen. Without it
/// a route with nothing to pop simply swallows the gesture and the app can
/// never be backed out of.
class ExitOnBack extends StatelessWidget {
  final Widget child;
  const ExitOnBack({super.key, required this.child});
  @override
  Widget build(BuildContext context) => PopScope(
      // Nothing above this route, so let the platform handle the pop and
      // move the app to the background.
      canPop: true,
      child: child);
}
