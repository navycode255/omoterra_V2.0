import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import 'components.dart';

/// Lets the user choose a gallery photo and uploads it. Returns its
/// `/media/…` URL, or null when they cancel.
Future<String?> pickAndUploadPhoto(WidgetRef ref) async {
  final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88);
  if (image == null) return null;
  final bytes = await image.readAsBytes();
  if (bytes.length > 8 * 1024 * 1024) {
    throw ApiFailure(ref.read(stringsProvider).photoTooBig);
  }
  return ref
      .read(repositoryProvider)
      .uploadPhoto(bytes, path: ref.read(photoUploadPathProvider));
}

/// Asks before a photo or video is removed; true only when the user agrees.
Future<bool> confirmRemove(BuildContext context, {bool video = false}) async {
  final s = context.s;
  return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(s.removeThisQ(video)),
                  content: Text(s.removeBody(video)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.cancel)),
                    TextButton(
                        key: const Key('confirm_remove'),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.removeWhat(video))),
                  ])) ??
      false;
}

/// Tells the server the user took an upload back, so its file is deleted.
/// One still saved on stock or a request stays until that record is saved
/// without it. Best effort: the server also clears unused uploads hourly.
void discardUpload(WidgetRef ref, String? url) {
  if (url == null ||
      !url.startsWith('/media/') ||
      ref.read(photoUploadPathProvider) != '/media') {
    return;
  }
  ref
      .read(repositoryProvider)
      .write(url, {}, method: 'DELETE')
      .then((_) {}, onError: (_) {});
}

class PhotoPicker extends ConsumerStatefulWidget {
  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final int limit;
  const PhotoPicker(
      {super.key,
      required this.photos,
      required this.onChanged,
      this.limit = 8});
  @override
  ConsumerState<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends ConsumerState<PhotoPicker> {
  bool busy = false;
  Object? error;
  Future<void> removeLast() async {
    if (!await confirmRemove(context) || !mounted) return;
    final last = widget.photos.last;
    widget.onChanged(widget.photos.sublist(0, widget.photos.length - 1));
    discardUpload(ref, last);
  }

  Future<void> upload() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final url = await pickAndUploadPhoto(ref);
      if (url != null && mounted) widget.onChanged([...widget.photos, url]);
    } catch (e) {
      if (mounted) {
        setState(() => error =
            e is ApiFailure ? e : ref.read(stringsProvider).photoUploadFailed);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.photoPickerHint),
      const SizedBox(height: 16),
      if (widget.photos.isNotEmpty) ...[
        ProductImage(widget.photos),
        const SizedBox(height: 8),
        Text(s.photosSwipe(widget.photos.length)),
        TextButton(
            onPressed: busy ? null : removeLast, child: Text(s.removeLastPhoto))
      ],
      if (widget.photos.length < widget.limit)
        OmoterraButton(s.addPhoto,
            secondary: true, busy: busy, onPressed: upload),
      if (error != null) ErrorState(error!),
    ]);
  }
}
