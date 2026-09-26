import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import '../../shared/widgets/photo_picker.dart';
import '../../shared/widgets/stock_video.dart';
import 'inventory_screens.dart';

/// The supplier's own photos and video for one stock listing.
class StockMediaScreen extends ConsumerWidget {
  final String id;
  const StockMediaScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
          body: Stack(children: [
        const Positioned.fill(child: PageLeaves()),
        SafeArea(
            child: ResourceView('/supplier/stock/$id',
                builder: (row) => _StockMediaForm(
                    id: id, row: Map<String, dynamic>.from(row as Map)))),
      ]));
}

/// Swipeable stock photos with page dots, and a delete button on each photo
/// when [onDelete] is given.
class StockGallery extends StatefulWidget {
  final List<String> photos;
  final String category;
  final double height;
  final ValueChanged<int>? onDelete;
  const StockGallery(this.photos,
      {super.key, required this.category, this.height = 230, this.onDelete});
  @override
  State<StockGallery> createState() => _StockGalleryState();
}

class _StockGalleryState extends State<StockGallery> {
  final _pages = PageController();
  int page = 0;

  @override
  void didUpdateWidget(StockGallery old) {
    super.didUpdateWidget(old);
    if (page >= widget.photos.length && widget.photos.isNotEmpty) {
      page = widget.photos.length - 1;
      _pages.jumpToPage(page);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
          height: widget.height,
          child: Stack(fit: StackFit.expand, children: [
            if (widget.photos.isEmpty)
              ProductImage(const [],
                  category: widget.category, height: widget.height)
            else
              PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => page = i),
                  children: [
                    for (final photo in widget.photos)
                      ProductImage([photo], height: widget.height)
                  ]),
            if (widget.photos.length > 1)
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < widget.photos.length; i++)
                          AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withValues(alpha: i == page ? 1 : .55),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black26, blurRadius: 4)
                                  ])),
                      ])),
            if (widget.onDelete != null && widget.photos.isNotEmpty)
              Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                      color: Colors.white.withValues(alpha: .92),
                      shape: const CircleBorder(),
                      child: IconButton(
                          tooltip: context.s.removeThisPhoto,
                          icon: const Icon(Icons.delete_outline,
                              color: OColors.forest),
                          onPressed: () => widget.onDelete!(page)))),
          ])));
}

class _StockMediaForm extends ConsumerStatefulWidget {
  final String id;
  final Map<String, dynamic> row;
  const _StockMediaForm({required this.id, required this.row});
  @override
  ConsumerState<_StockMediaForm> createState() => _StockMediaFormState();
}

class _StockMediaFormState extends ConsumerState<_StockMediaForm> {
  static const _limit = 8;
  late List<String> photos = List<String>.from(widget.row['photos'] ?? []);
  late String? video = widget.row['video'] as String?;
  bool busy = false, uploading = false;
  Object? error;

  bool get changed =>
      video != widget.row['video'] ||
      photos.join('|') != List<String>.from(widget.row['photos']).join('|');
  bool get reviewed =>
      !['pending_review', 'rejected'].contains(widget.row['listing_status']);

  Future<void> _addPhoto() async {
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final url = await pickAndUploadPhoto(ref);
      if (url != null && mounted) setState(() => photos = [...photos, url]);
    } catch (e) {
      if (mounted) {
        setState(() => error =
            e is ApiFailure ? e : ref.read(stringsProvider).photoUploadFailed);
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _removePhoto(int i) async {
    if (!await confirmRemove(context) || !mounted) return;
    final url = photos[i];
    setState(() => photos = [...photos]..removeAt(i));
    discardUpload(ref, url);
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write(
          '/supplier/stock/${widget.id}/media',
          {'photos': photos, 'video': video},
          method: 'PUT');
      refreshStock(ref, widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reviewed
              ? ref.read(stringsProvider).mediaSavedForReview
              : ref.read(stringsProvider).mediaSaved)));
      context.canPop() ? context.pop() : context.go('/stock/${widget.id}');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(children: [
            const BackChevron(),
            const SizedBox(width: 12),
            // Wraps rather than overflowing with large text.
            Expanded(
                child: Text(s.photosAndVideo,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6))),
          ]),
          const SizedBox(height: 10),
          Text(s.showSupplyClearly,
              style: const TextStyle(
                  fontSize: 15, height: 1.4, color: OColors.secondary)),
          const SizedBox(height: 22),
          StockGallery(photos,
              category: '${widget.row['category']}', onDelete: _removePhoto),
          const SizedBox(height: 12),
          Text(photos.isEmpty ? s.noPhotosYet : s.photoCount(photos.length),
              style: const TextStyle(fontSize: 15, color: OColors.ink)),
          const SizedBox(height: 14),
          if (photos.length < _limit)
            OmoterraButton(photos.isEmpty ? s.addPhoto : s.addAnotherPhoto,
                icon: Icons.image_outlined,
                secondary: true,
                busy: uploading,
                onPressed: _addPhoto),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(height: 1, color: Color(0xFFE3EAE6))),
          Row(children: [
            Text(s.video,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFE6EFE9),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(s.optionalBadge,
                    style: const TextStyle(
                        fontSize: 12.5, color: OColors.forest))),
          ]),
          const SizedBox(height: 6),
          Text(s.addShortClip,
              style: const TextStyle(fontSize: 15, color: OColors.secondary)),
          const SizedBox(height: 14),
          StockVideoPicker(
              showHeader: false,
              video: video,
              onChanged: (v) => setState(() => video = v)),
          const SizedBox(height: 24),
          if (reviewed && changed)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(s.savingSendsBack,
                    key: const Key('media_review_notice'),
                    style: const TextStyle(
                        fontSize: 13, color: OColors.secondary))),
          if (error != null) ErrorState(error!),
          FilledButton(
              onPressed: busy || !changed ? null : save,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(busy ? s.saving : s.saveChanges),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward, size: 20),
              ])),
        ]);
  }
}
