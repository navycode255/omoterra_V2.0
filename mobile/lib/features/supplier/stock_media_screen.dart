import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/photo_picker.dart';
import '../../shared/widgets/stock_video.dart';
import 'inventory_screens.dart';

/// The supplier's own photos and video for one stock listing.
class StockMediaScreen extends ConsumerWidget {
  final String id;
  const StockMediaScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: const OmoterraAppBar(title: Text('Photos & video')),
      body: ResourceView('/supplier/stock/$id',
          builder: (row) => _StockMediaForm(
              id: id, row: Map<String, dynamic>.from(row as Map))));
}

class _StockMediaForm extends ConsumerStatefulWidget {
  final String id;
  final Map<String, dynamic> row;
  const _StockMediaForm({required this.id, required this.row});
  @override
  ConsumerState<_StockMediaForm> createState() => _StockMediaFormState();
}

class _StockMediaFormState extends ConsumerState<_StockMediaForm> {
  late List<String> photos = List<String>.from(widget.row['photos'] ?? []);
  late String? video = widget.row['video'] as String?;
  bool busy = false;
  Object? error;

  bool get changed =>
      video != widget.row['video'] ||
      photos.join('|') != List<String>.from(widget.row['photos']).join('|');
  bool get reviewed =>
      !['pending_review', 'rejected'].contains(widget.row['listing_status']);

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
              ? 'Saved — Omoterra will review the new photos and video before buyers see this stock again.'
              : 'Photos and video saved.')));
      context.canPop() ? context.pop() : context.go('/stock/${widget.id}');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        PhotoPicker(
            photos: photos, onChanged: (v) => setState(() => photos = v)),
        const SizedBox(height: 28),
        StockVideoPicker(
            video: video, onChanged: (v) => setState(() => video = v)),
        const SizedBox(height: 24),
        if (reviewed && changed)
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Saving sends this stock back to Omoterra review. Buyers won’t see it until it is approved again.',
                  key: Key('media_review_notice'))),
        if (error != null) ErrorState(error!),
        OmoterraButton('Save photos & video',
            busy: busy, onPressed: changed ? save : null),
      ]);
}
