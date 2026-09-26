import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'components.dart';
import 'photo_picker.dart';

/// Matches the backend's stock video limit (OMOTERRA_STOCK_VIDEO_MAX_BYTES).
const stockVideoMaxBytes = 60 * 1024 * 1024;

/// One short video of the stock: record or choose it, upload it, replace or
/// remove it.
class StockVideoPicker extends ConsumerStatefulWidget {
  final String? video;
  final ValueChanged<String?> onChanged;

  /// False when the screen shows its own "Video" heading.
  final bool showHeader;
  const StockVideoPicker(
      {super.key,
      required this.video,
      required this.onChanged,
      this.showHeader = true});
  @override
  ConsumerState<StockVideoPicker> createState() => _StockVideoPickerState();
}

class _StockVideoPickerState extends ConsumerState<StockVideoPicker> {
  double? _progress;
  Object? _error;

  /// A paused upload: the chosen file and the server's upload id, so Resume
  /// continues from the last stored 5 MB part instead of from zero.
  XFile? _pausedFile;
  String? _pausedId;
  double _pausedAt = 0;

  Future<void> _pick() async {
    final s = context.s;
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(s.recordVideo),
                  onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: Text(s.chooseFromGallery),
                  onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ])));
    if (source == null) return;
    setState(() => _error = null);
    try {
      final file = await ImagePicker()
          .pickVideo(source: source, maxDuration: const Duration(minutes: 1));
      if (file == null) return;
      if (await file.length() > stockVideoMaxBytes) {
        throw ApiFailure(s.videoTooBig);
      }
      await _upload(file);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiFailure ? e : s.videoUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _upload(XFile file, {String? resumeId}) async {
    setState(() {
      _progress = resumeId == null ? 0 : _pausedAt;
      _error = null;
    });
    try {
      final url = await ref.read(repositoryProvider).uploadVideoInParts(
          await file.length(),
          (start, end) async {
            final part = BytesBuilder(copy: false);
            await for (final chunk in file.openRead(start, end)) {
              part.add(chunk);
            }
            return part.takeBytes();
          },
          resumeId: resumeId,
          onStarted: (id) => _pausedId = id,
          onProgress: (sent, total) {
            if (mounted && total > 0) setState(() => _progress = sent / total);
          });
      _pausedFile = _pausedId = null;
      final replaced = widget.video;
      widget.onChanged(url);
      discardUpload(ref, replaced);
    } on VideoUploadPaused catch (e) {
      _pausedFile = file;
      _pausedId = e.uploadId;
      _pausedAt = _progress ?? 0;
      rethrow;
    } catch (_) {
      // Rejected (not a video, too big): nothing to resume.
      _pausedFile = _pausedId = null;
      rethrow;
    }
  }

  Future<void> _resume() async {
    try {
      await _upload(_pausedFile!, resumeId: _pausedId);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = _progress != null;
    final s = context.s;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.showHeader) ...[
        Text(s.videoOptional, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(s.videoHint,
            style: const TextStyle(fontSize: 12, color: OColors.secondary)),
        const SizedBox(height: 12),
      ],
      if (widget.video != null && !uploading) ...[
        StockVideoTile(widget.video!),
        TextButton(
            onPressed: () async {
              if (!await confirmRemove(context, video: true) || !mounted) {
                return;
              }
              final removed = widget.video;
              widget.onChanged(null);
              discardUpload(ref, removed);
            },
            child: Text(s.removeVideo)),
      ],
      if (uploading) ...[
        LinearProgressIndicator(
            value: _progress, color: OColors.forest, minHeight: 6),
        const SizedBox(height: 6),
        Text(s.uploadingVideo(((_progress ?? 0) * 100).round())),
        const SizedBox(height: 8),
      ] else if (_pausedId != null) ...[
        LinearProgressIndicator(
            key: const Key('video_upload_paused'),
            value: _pausedAt,
            color: OColors.secondary,
            minHeight: 6),
        const SizedBox(height: 6),
        Text(s.uploadPausedAt((_pausedAt * 100).round())),
        const SizedBox(height: 8),
        OmoterraButton(s.resumeUpload, icon: Icons.refresh, onPressed: _resume),
        TextButton(onPressed: _pick, child: Text(s.chooseAnotherVideo)),
      ] else
        OmoterraButton(widget.video == null ? s.addVideo : s.replaceVideo,
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
          child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill,
                        size: 48, color: Colors.white),
                    const SizedBox(height: 6),
                    Text(context.s.watchVideo,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]))));
}

/// Plays a private `/media/…` video from a signed link (valid 30 minutes);
/// it streams and is not kept on the phone.
class StockVideoScreen extends ConsumerStatefulWidget {
  final String url;
  const StockVideoScreen(this.url, {super.key});
  @override
  ConsumerState<StockVideoScreen> createState() => _StockVideoScreenState();
}

class _StockVideoScreenState extends ConsumerState<StockVideoScreen> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final s = ref.read(stringsProvider);
    var gone = false;
    try {
      var url = widget.url;
      if (url.startsWith('/media/')) {
        final link = await ref.read(repositoryProvider).mediaLink(url);
        if (link == null) {
          gone = true;
          throw ApiFailure(s.videoGone);
        }
        url = link.url;
      }
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (e) {
      if (mounted) {
        setState(() => _error = gone ? e : ApiFailure(s.videoCantPlay));
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
