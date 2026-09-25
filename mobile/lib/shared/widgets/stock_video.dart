import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/repository.dart';
import '../../core/theme/theme.dart';
import 'components.dart';

/// Matches the backend's stock video limit (OMOTERRA_STOCK_VIDEO_MAX_BYTES).
const stockVideoMaxBytes = 60 * 1024 * 1024;

/// One short video of the stock: record or choose it, upload it, replace or
/// remove it.
class StockVideoPicker extends ConsumerStatefulWidget {
  final String? video;
  final ValueChanged<String?> onChanged;
  const StockVideoPicker(
      {super.key, required this.video, required this.onChanged});
  @override
  ConsumerState<StockVideoPicker> createState() => _StockVideoPickerState();
}

class _StockVideoPickerState extends ConsumerState<StockVideoPicker> {
  double? _progress;
  Object? _error;

  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Record a video'),
                  onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ])));
    if (source == null) return;
    setState(() => _error = null);
    try {
      final file = await ImagePicker()
          .pickVideo(source: source, maxDuration: const Duration(minutes: 1));
      if (file == null) return;
      if (await file.length() > stockVideoMaxBytes) {
        throw const ApiFailure(
            'Choose a video smaller than 60 MB — a clip under a minute is enough.');
      }
      setState(() => _progress = 0);
      final url = await ref.read(repositoryProvider).uploadVideo(
          path: kIsWeb ? null : file.path,
          bytes: kIsWeb ? await file.readAsBytes() : null,
          onProgress: (sent, total) {
            if (mounted && total > 0) setState(() => _progress = sent / total);
          });
      widget.onChanged(url);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiFailure
            ? e
            : 'We could not upload this video. Check camera or gallery permission and your connection, then retry.');
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = _progress != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Video (optional)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text(
          'A short clip of the animals or produce. Keep faces, phone numbers and signs out of it.',
          style: TextStyle(fontSize: 12, color: OColors.secondary)),
      const SizedBox(height: 12),
      if (widget.video != null && !uploading) ...[
        StockVideoTile(widget.video!),
        TextButton(
            onPressed: () => widget.onChanged(null),
            child: const Text('Remove video')),
      ],
      if (uploading) ...[
        LinearProgressIndicator(
            value: _progress, color: OColors.forest, minHeight: 6),
        const SizedBox(height: 6),
        Text('Uploading video… ${((_progress ?? 0) * 100).round()}%'),
        const SizedBox(height: 8),
      ] else
        OmoterraButton(widget.video == null ? 'Add video' : 'Replace video',
            icon: Icons.videocam_outlined, secondary: true, onPressed: _pick),
      if (_error != null) ErrorState(_error!),
    ]);
  }
}

/// A tappable card that opens the stock video full screen.
class StockVideoTile extends StatelessWidget {
  final String url;
  const StockVideoTile(this.url, {super.key});
  @override
  Widget build(BuildContext context) => Material(
      color: OColors.forest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => StockVideoScreen(url))),
          child: const SizedBox(
              height: 120,
              width: double.infinity,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
                    SizedBox(height: 6),
                    Text('Watch video',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]))));
}

/// Plays a private `/media/…` video with the signed-in session, like photos.
class StockVideoScreen extends StatefulWidget {
  final String url;
  const StockVideoScreen(this.url, {super.key});
  @override
  State<StockVideoScreen> createState() => _StockVideoScreenState();
}

class _StockVideoScreenState extends State<StockVideoScreen> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final token = await storage.read(key: 'session');
      final own = widget.url.startsWith('/media/');
      final controller = VideoPlayerController.networkUrl(
          Uri.parse(own ? '$apiUrl${widget.url}' : widget.url),
          httpHeaders: {
            if (own && token != null) 'Authorization': 'Bearer $token'
          });
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (e) {
      if (mounted) {
        setState(() => _error = const ApiFailure(
            'This video can’t play right now. Check your connection and retry.'));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: const OmoterraAppBar(
            backgroundColor: Colors.black,
            leading: Padding(
                padding: EdgeInsets.only(left: 12),
                child: BackChevron(color: Colors.white))),
        body: Center(
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: ErrorState(_error!))
                : controller == null
                    ? const CircularProgressIndicator(color: Colors.white)
                    : GestureDetector(
                        onTap: () => setState(() => controller.value.isPlaying
                            ? controller.pause()
                            : controller.play()),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                VideoPlayer(controller),
                                ValueListenableBuilder(
                                    valueListenable: controller,
                                    builder: (_, value, __) => value.isPlaying
                                        ? const SizedBox.shrink()
                                        : const Icon(Icons.play_circle_fill,
                                            size: 64, color: Colors.white70)),
                              ])),
                          VideoProgressIndicator(controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                  playedColor: OColors.forest)),
                        ]))));
  }
}
