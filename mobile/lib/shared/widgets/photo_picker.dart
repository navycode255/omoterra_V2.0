import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/repository.dart';
import 'components.dart';

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
  Future<void> upload() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 88);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw const ApiFailure('Choose a photo smaller than 8 MB.');
      }
      final url = await ref.read(repositoryProvider).uploadPhoto(bytes);
      if (mounted) widget.onChanged([...widget.photos, url]);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure
            ? e
            : 'We could not upload this photo. Check gallery permission and your connection, then retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Use clear photos of the supply. Keep people, contact details and signs out of the image.'),
        const SizedBox(height: 16),
        if (widget.photos.isNotEmpty) ...[
          ProductImage(widget.photos),
          const SizedBox(height: 8),
          Text('${widget.photos.length} photo(s) · swipe to view'),
          TextButton(
              onPressed: busy
                  ? null
                  : () => widget.onChanged(
                      widget.photos.sublist(0, widget.photos.length - 1)),
              child: const Text('Remove last photo'))
        ],
        if (widget.photos.length < widget.limit)
          OmoterraButton('Add photo',
              secondary: true, busy: busy, onPressed: upload),
        if (error != null) ErrorState(error!),
      ]);
}
