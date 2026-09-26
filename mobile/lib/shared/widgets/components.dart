import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/back_navigation.dart';
import '../../core/theme/theme.dart';
import '../media_cache.dart';
import '../models/domain.dart';
import 'brand_image.dart';
import 'decor.dart';
import 'rating.dart';
import 'supply_art.dart';

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
    final label = Text(busy ? context.s.pleaseWait : text);
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
                    tooltip: context.s.close,
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
                  ? context.s.enterField(label)
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
  Widget build(BuildContext context) => Text('●  ${context.s.status(status)}',
      style: TextStyle(
          fontSize: 12,
          color: ['cancelled', 'failed', 'rejected'].contains(status)
              ? OColors.error
              : ['needs_confirmation', 'pending_review', 'changes_requested']
                      .contains(status)
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

  /// Shows the retry button busy, so a tap visibly does something.
  final bool retrying;
  const ErrorState(this.error,
      {super.key, this.retry, this.title, this.message, this.retrying = false});
  @override
  Widget build(BuildContext context) {
    final copy = _friendlyErrorCopy(error, context.s);
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
              // Stays green (not greyed out) so the spinner reads as progress.
              onPressed: retrying ? () {} : retry,
              icon: retrying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded),
              label: Text(retrying ? context.s.retrying : context.s.retry),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Never show raw transport exceptions or server responses to customers.
String friendlyErrorMessage(Object error, Strings s) =>
    _friendlyErrorCopy(error, s).$2;

(String, String) _friendlyErrorCopy(Object error, Strings s) {
  final raw = error is ApiFailure ? error.message : '';
  final text = raw.toLowerCase();
  final status = error is ApiFailure ? error.status : null;
  switch (error is ApiFailure ? error.kind : null) {
    case FailureKind.unavailable:
      return (s.errDelayTitle, s.errDelayBody);
    case FailureKind.sessionExpired:
      return (s.errSignInTitle, s.errSignInBody);
    case FailureKind.staffSessionExpired:
      return (s.errSignInTitle, s.errStaffSignInBody);
    case FailureKind.offline:
      return (s.errOfflineTitle, s.errOfflineBody);
    case FailureKind.videoPaused:
      return (s.errOfflineTitle, s.errVideoPaused);
    case FailureKind.notConfigured:
      return (s.errFailedTitle, s.errFailedBody);
    case null:
      break;
  }
  // Server answers are told apart by status, not wording: the server writes
  // its reason in the member's language (Accept-Language / saved language).
  if (status == 401) return (s.errSignInTitle, s.errSignInBody);
  if (status == 404) {
    // FastAPI's own "Not Found" means an unknown route; a reason from
    // Omoterra (stock or demand that has gone) is worth showing as written.
    return text == 'not found' || raw.isEmpty || raw.length >= 180
        ? (s.errNotFoundTitle, s.errNotFoundBody)
        : (s.errGoneTitle, raw);
  }
  if (status != null && status >= 500) return (s.errDelayTitle, s.errDelayBody);
  // Raw transport or framework text must never reach a customer.
  if (text.contains('preview mode') ||
      text.contains('api_base_url') ||
      text.contains('backend') ||
      text.contains('server') ||
      text.contains('http') ||
      text.contains('exception') ||
      text.contains('status code') ||
      text.contains('request failed')) {
    return (s.errFailedTitle, s.errFailedBody);
  }
  if (raw.isNotEmpty && raw.length < 180 && !raw.contains('\n')) {
    return (s.errCheckTitle, raw);
  }
  return (s.errLoadTitle, s.errLoadBody);
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final Widget? action;
  const EmptyState(this.title, this.message, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF1F6F2)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6EEE9)),
          boxShadow: [
            BoxShadow(
                color: OColors.forest.withValues(alpha: .05),
                blurRadius: 16,
                offset: const Offset(0, 5))
          ]),
      child: Stack(children: [
        // Hills, clouds and sprigs behind the message, as in the design.
        const Positioned.fill(child: HillsBackdrop()),
        const Positioned(
            left: 14,
            bottom: 6,
            child: LeafSprig(size: 44, angle: -.2, color: Color(0xFFD5E7DA))),
        const Positioned(
            right: 20,
            bottom: 4,
            child: LeafSprig(size: 26, angle: .2, color: Color(0xFFDDEDE1))),
        Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 190,
                      height: 110,
                      child: Stack(alignment: Alignment.center, children: [
                        // Leaves behind the crate, sprigs either side.
                        Positioned(
                            right: 44,
                            top: 0,
                            child: LeafSprig(
                                size: 56, angle: .2, color: Color(0xFF9FC3A6))),
                        Positioned(
                            left: 6,
                            bottom: 14,
                            child: LeafSprig(size: 40, angle: -.2)),
                        Positioned(
                            right: 8,
                            bottom: 14,
                            child: LeafSprig(size: 34, angle: .2)),
                        SupplyArt('crate', size: 92, surface: false),
                      ])),
                  const SizedBox(height: 14),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: OColors.ink,
                          letterSpacing: -.3)),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: OColors.secondary)),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: action!)
                  ]
                ])),
      ]));
}

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: context.s.loadingContent,
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
              : LayoutBuilder(builder: (context, box) {
                  // Decode at the size shown, not the 1600px upload: a card
                  // thumbnail then holds ~0.3 MB of pixels instead of ~7.7 MB.
                  final cacheWidth = (box.maxWidth.isFinite
                          ? box.maxWidth
                          : MediaQuery.sizeOf(context).width) *
                      MediaQuery.devicePixelRatioOf(context);
                  return PageView(
                      children: photos.map((photo) {
                    if (!photo.startsWith('/media/')) {
                      return CachedNetworkImage(
                          imageUrl: photo,
                          memCacheWidth: cacheWidth.round(),
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: OColors.soft),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.image_not_supported_outlined));
                    }
                    return _MediaPhoto(photo,
                        category: category,
                        height: height,
                        cacheWidth: cacheWidth.round());
                  }).toList());
                })));
}

/// A private `/media/…` photo. The server is asked for a signed link each
/// time it is shown, so a photo this member may no longer see is refused and
/// removed from the phone; the bytes come from the disk cache when present
/// (keyed by media id, since links change every time), otherwise from the
/// signed link once. Offline, the cached copy still shows (media_cache.dart).
class _MediaPhoto extends ConsumerStatefulWidget {
  final String photo;
  final String category;
  final double height;
  final int cacheWidth;
  const _MediaPhoto(this.photo,
      {required this.category, required this.height, required this.cacheWidth});
  @override
  ConsumerState<_MediaPhoto> createState() => _MediaPhotoState();
}

class _MediaPhotoState extends ConsumerState<_MediaPhoto> {
  late Future<SignedMedia?> _link;

  Future<SignedMedia?> _resolve() async {
    final link =
        await signedMediaLink(ref.read(repositoryProvider), widget.photo);
    if (link == null) {
      // Refused: never keep a copy of media this member may not see.
      await mediaCache
          .removeFile(mediaCacheKey(widget.photo))
          .catchError((_) {});
    }
    return link;
  }

  @override
  void initState() {
    super.initState();
    _link = _resolve();
  }

  @override
  void didUpdateWidget(_MediaPhoto old) {
    super.didUpdateWidget(old);
    if (old.photo != widget.photo) _link = _resolve();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SignedMedia?>(
      future: _link,
      builder: (context, link) {
        if (link.connectionState != ConnectionState.done) {
          return Container(color: OColors.soft);
        }
        if (!link.hasError && link.data == null) {
          return BrandImage('category_${_slot(widget.category)}',
              fallbackArt: widget.category, height: widget.height);
        }
        return CachedNetworkImage(
            // Unreachable: only a copy already on this phone can show.
            imageUrl: link.data?.url ?? 'offline:${widget.photo}',
            cacheKey: mediaCacheKey(widget.photo),
            cacheManager: mediaCache,
            memCacheWidth: widget.cacheWidth,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: OColors.soft),
            errorWidget: (_, __, ___) =>
                _PhotoUnavailable(widget.category, widget.height));
      });
}

/// A photo that isn't on this phone yet and can't be fetched now (offline,
/// or Omoterra unreachable): the category picture with a quiet note, never a
/// broken-image icon.
class _PhotoUnavailable extends StatelessWidget {
  final String category;
  final double height;
  const _PhotoUnavailable(this.category, this.height);
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        BrandImage('category_${_slot(category)}',
            fallbackArt: category, height: height),
        Positioned(
            left: 10,
            bottom: 10,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(context.s.photoOffline,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white)),
                ]))),
      ]);
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
                ]),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The name is never cut short: "In stock" sits beside
                            // it when there is room and drops just under it when
                            // not. Plain green text, no pill.
                            Expanded(
                                child: Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                  Text(context.s.label(listing.category),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  // A drawn dot: Manrope has no "●" glyph.
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                                color: OColors.positive,
                                                shape: BoxShape.circle)),
                                        const SizedBox(width: 5),
                                        Text(context.s.inStock,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.6,
                                                fontWeight: FontWeight.w600,
                                                color: OColors.positive)),
                                      ]),
                                ])),
                            const Icon(Icons.favorite_border,
                                size: 19, color: OColors.muted),
                          ]),
                      const SizedBox(height: 4),
                      Text(
                          '${listing.specs['avg_weight_kg'] != null ? '${listing.specs['avg_weight_kg']} kg · ' : ''}${context.s.nAvailable(amount(listing.available))}',
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
                              '${tsh(listing.price)} / ${context.s.unit(listing.unitType, 1)}',
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
                Text(context.s.label(category),
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
                  Text(context.s.label(steps[i]),
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

  /// May be left empty (e.g. a filter); shows a button to clear the date.
  final bool optional;
  const OmoterraDateField(this.title, this.controller,
      {super.key, this.pastAllowed = false, this.optional = false});
  @override
  State<OmoterraDateField> createState() => _DateFieldState();
}

/// [OmoterraDateField.controller] holds the date as the API takes it
/// (2026-09-27); the field shows it the way people read it (27 Sep 2026).
class _DateFieldState extends State<OmoterraDateField> {
  final _shown = TextEditingController();

  String _readable(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : context.s.date(date);
  }

  void _sync() => _shown.text = _readable(widget.controller.text);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  // Also runs when the language changes, so the month name follows it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OmoterraDateField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: _shown,
          readOnly: true,
          decoration: InputDecoration(
              labelText: widget.title,
              hintText: widget.optional ? context.s.anyDate : null,
              suffixIcon: widget.optional && widget.controller.text.isNotEmpty
                  ? IconButton(
                      tooltip: context.s.clearDate,
                      icon: const Icon(Icons.close, size: 19),
                      onPressed: () =>
                          setState(() => widget.controller.clear()))
                  : const Icon(Icons.calendar_today_outlined, size: 19)),
          validator: (_) {
            final value = widget.controller.text;
            return (widget.optional && value.isEmpty) ||
                    DateTime.tryParse(value) != null
                ? null
                : context.s.chooseDate;
          },
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

/// An ⓘ button that keeps explanations off the page: tapping it opens a
/// short pop-up with [title] and [message].
class InfoButton extends StatelessWidget {
  final String title, message;
  final Color? color;

  /// Replaces the default outline icon, e.g. a page's own ⓘ badge.
  final Widget? icon;
  const InfoButton(
      {super.key,
      required this.title,
      required this.message,
      this.color,
      this.icon});
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: title,
      icon: icon ?? Icon(Icons.info_outline, size: 28, color: color),
      onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(child: Text(message)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.s.ok)),
                  ])));
}
