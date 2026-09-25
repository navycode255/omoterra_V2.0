import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/routing/back_navigation.dart';
import '../../core/theme/theme.dart';
import '../models/domain.dart';
import 'brand_image.dart';
import 'rating.dart';
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
  'layers',
  'goats',
  'cattle',
  'chicken_meat',
  'beef',
  'goat_meat',
  'eggs',
];
String unitFor(String c) => ['broilers', 'local_chicken', 'layers'].contains(c)
    ? 'bird'
    : ['goats', 'cattle'].contains(c)
        ? 'animal'
        : c == 'eggs'
            ? 'tray'
            : 'kg';

class OmoterraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool busy, secondary;
  final IconData? icon;
  const OmoterraButton(this.text,
      {super.key,
      this.onPressed,
      this.busy = false,
      this.secondary = false,
      this.icon});
  @override
  Widget build(BuildContext context) {
    final label = Text(busy ? 'Please wait…' : text);
    if (icon == null) {
      return secondary
          ? OutlinedButton(onPressed: busy ? null : onPressed, child: label)
          : FilledButton(onPressed: busy ? null : onPressed, child: label);
    }
    final iconWidget = Icon(icon, size: 19);
    return secondary
        ? OutlinedButton.icon(
            onPressed: busy ? null : onPressed, icon: iconWidget, label: label)
        : FilledButton.icon(
            onPressed: busy ? null : onPressed, icon: iconWidget, label: label);
  }
}

class OmoterraPickerOption<T> {
  final T value;
  final Widget title;
  final String? subtitle;
  final IconData? icon;
  const OmoterraPickerOption(
      {required this.value, required this.title, this.subtitle, this.icon});
}

/// One branded selection sheet shared by form selects and the app role menu.
Future<T?> showOmoterraPicker<T>(
  BuildContext context, {
  required String title,
  required List<OmoterraPickerOption<T>> options,
  required T selected,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .76),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: OColors.border,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: OColors.ink))),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(height: 1),
            Flexible(
                child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final option = options[index];
                final active = option.value == selected;
                return Material(
                  color: active ? OColors.soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, option.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      child: Row(children: [
                        if (option.icon != null) ...[
                          Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: active ? Colors.white : OColors.pale,
                                  borderRadius: BorderRadius.circular(11)),
                              child: Icon(option.icon,
                                  color: OColors.forest, size: 20)),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              DefaultTextStyle(
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: OColors.ink),
                                  child: option.title),
                              if (option.subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(option.subtitle!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: OColors.secondary)),
                              ],
                            ])),
                        if (active)
                          const Icon(Icons.check_circle_rounded,
                              color: OColors.forest, size: 21),
                      ]),
                    ),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );

class OmoterraDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const OmoterraDropdown(
      {super.key,
      required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = items.where((item) => item.value == value).firstOrNull;
    final options = items
        .where((item) => item.value != null)
        .map((item) => OmoterraPickerOption<T>(
              value: item.value as T,
              title: item.child,
            ))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        label: '$label: ${value.toString()}',
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onChanged == null
              ? null
              : () async {
                  final choice = await showOmoterraPicker<T>(context,
                      title: label, options: options, selected: value);
                  if (choice != null) onChanged!(choice);
                },
          child: InputDecorator(
            isEmpty: selected == null,
            decoration: InputDecoration(
              labelText: label,
              enabled: onChanged != null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: OColors.forest),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: OColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: OColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: OColors.forest, width: 1.5)),
            ),
            child: selected?.child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class OmoterraActionDropdown extends StatelessWidget {
  final Widget child;
  final String title;
  final String selected;
  final List<OmoterraPickerOption<String>> options;
  final ValueChanged<String> onSelected;
  const OmoterraActionDropdown(
      {super.key,
      required this.child,
      required this.title,
      required this.selected,
      required this.options,
      required this.onSelected});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          final choice = await showOmoterraPicker<String>(context,
              title: title, options: options, selected: selected);
          if (choice != null) onSelected(choice);
        },
        child: child,
      );
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
              : ['needs_confirmation', 'pending_review'].contains(status)
                  ? OColors.warning
                  : status == 'live'
                      ? OColors.positive
                      : OColors.secondary));
}

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? retry;
  final String? title;
  final String? message;
  const ErrorState(this.error,
      {super.key, this.retry, this.title, this.message});
  @override
  Widget build(BuildContext context) {
    final copy = _friendlyErrorCopy(error);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 116,
          child: Stack(alignment: Alignment.center, children: [
            const SupplyArt('crate', size: 112, surface: false),
            Positioned(
              top: 2,
              right: 28,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Color(0xFFFCE3E1), shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    color: OColors.error, size: 22),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(title ?? copy.$1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message ?? copy.$2,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OColors.secondary,
                )),
        if (retry != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Never show raw transport exceptions or server responses to customers.
String friendlyErrorMessage(Object error) => _friendlyErrorCopy(error).$2;

(String, String) _friendlyErrorCopy(Object error) {
  final raw = error is ApiFailure ? error.message : '';
  final text = raw.toLowerCase();
  if (text.contains('temporarily unavailable') ||
      text.contains('trouble loading right now')) {
    return (
      'Omoterra is having a short delay',
      'We couldn’t load this just now. Please try again shortly.'
    );
  }
  if (text.contains('session has expired')) {
    return (
      'Please sign in again',
      'Your sign-in has expired. Sign in to continue.'
    );
  }
  if (text == 'not found' || text.contains('status code 404')) {
    return (
      'We couldn’t find this just now',
      'Refresh and try again. If the problem continues, try again later.'
    );
  }
  if (text.contains('no longer available') || text.contains('not available')) {
    return (
      'This is no longer available',
      'Choose another option and try again.'
    );
  }
  if (text.contains('preview mode') ||
      text.contains('api_base_url') ||
      text.contains('backend') ||
      text.contains('server') ||
      text.contains('http') ||
      text.contains('exception') ||
      text.contains('status code') ||
      text.contains('request failed')) {
    return (
      'We couldn’t complete that',
      'Please check your connection and try again. If the problem continues, try again later.'
    );
  }
  if (raw.isNotEmpty && raw.length < 180 && !raw.contains('\n')) {
    return ('Please check this information', raw);
  }
  return (
    'We couldn’t load this just now',
    'Check your internet connection, then try again.'
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final Widget? action;
  const EmptyState(this.title, this.message, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Surface(
      color: OColors.pale,
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SupplyArt('crate', size: 70, surface: false),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: action!)
        ]
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
    if (state.hasError) {
      return ErrorState(state.error!,
          retry: () => ref.invalidate(resourceProvider(path)));
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
///
/// cattle and beef both use category_cow.jpg: the live animal and its meat
/// are the same source animal, and no separate carcass/cut photo exists yet.
/// chicken_meat and goat_meat have no dedicated cut photography either, so
/// they borrow the closest live-animal photo rather than falling back to the
/// plain vector icon; swap in category_chicken_meat.jpg /
/// category_goat_meat.jpg when photos exist.
String _slot(String category) =>
    const {
      'cattle': 'cow',
      'beef': 'cow',
      'chicken_meat': 'broilers',
      'goat_meat': 'goats',
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
                Stack(children: [
                  SizedBox(
                      width: 92,
                      child: Hero(
                          tag: listing.id,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ProductImage(listing.photos,
                                  category: listing.category, height: 92)))),
                  Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .92),
                              borderRadius: BorderRadius.circular(9)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: OColors.positive,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('In stock',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: OColors.positive)),
                          ]))),
                ]),
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
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: OColors.muted),
                        const SizedBox(width: 2),
                        Flexible(
                            child: Text(listing.region,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall)),
                        const SizedBox(width: 8),
                        RatingBadge(listing.supplierRating),
                      ]),
                      const SizedBox(height: 10),
                      // The whole card is already tappable (see the InkWell
                      // above), so the price stands alone here with the full
                      // width to itself instead of sharing the row with a
                      // redundant View button.
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                              '${tsh(listing.price)} / ${listing.unitType}',
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: OColors.forest))),
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

/// iOS-style chevron back button. Used instead of Material's arrow so every
/// screen in the app — not just onboarding — shares the same back affordance.
class BackChevron extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color color;
  const BackChevron({super.key, this.onPressed, this.color = OColors.ink});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: color))));
}

/// Drop-in replacement for [AppBar] used across the app so every screen with
/// a back arrow gets the same [BackChevron] instead of Material's default
/// arrow. Pass `leading` explicitly only to override or suppress it (e.g. a
/// root screen with nothing to pop back to).
class OmoterraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final double elevation;
  const OmoterraAppBar(
      {super.key,
      this.title,
      this.leading,
      this.actions,
      this.centerTitle = false,
      this.backgroundColor,
      this.elevation = 0});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
      title: title,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: elevation,
      actions: actions,
      leading: leading ??
          (ModalRoute.of(context)?.canPop == true ||
                  RouteBackGuard.fallbackOf(context) != null
              ? const Padding(
                  padding: EdgeInsets.only(left: 12), child: BackChevron())
              : null),
      leadingWidth: leading == null ? 60 : null);
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
