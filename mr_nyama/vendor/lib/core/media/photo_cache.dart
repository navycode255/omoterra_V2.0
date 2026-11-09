import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Server photos of people and stations, kept once fetched.
///
/// Their links are signed, so each server answer carries a different address
/// for the same photo. The object's path does not change, and it ends in a
/// hash of the photo's content, so a new photo always has a new path: the
/// path identifies the picture, and a kept copy never goes stale.
String photoIdentity(String url) {
  final uri = Uri.tryParse(url);
  return uri == null || !uri.hasAuthority
      ? url
      : '${uri.scheme}://${uri.authority}${uri.path}';
}

/// The copies on this phone, in the app's cache folder (which the phone may
/// empty when it is short of space; the photo is then fetched again).
class PhotoStore {
  static const _maxBytes = 10 * 1024 * 1024;

  /// Null without a cache folder: photos are then kept in memory only.
  @visibleForTesting
  static Future<Directory?> Function() directory = _defaultDirectory;
  @visibleForTesting
  static Future<Uint8List> Function(String url) download = _download;

  static Future<Directory?> _defaultDirectory() async {
    try {
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}/photos');
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _download(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > _maxBytes) {
        await response.drain<void>();
        throw HttpException('Photo not available', uri: Uri.parse(url));
      }
      return await consolidateHttpClientResponseBytes(response);
    } finally {
      client.close();
    }
  }

  static Future<File?> _file(String url) async {
    final folder = await directory();
    if (folder == null) return null;
    final name = sha256.convert(utf8.encode(photoIdentity(url)));
    return File('${folder.path}/$name');
  }

  /// The kept copy, or the photo from the server (kept from then on). A copy
  /// that cannot be written is not an error: the photo still shows.
  static Future<Uint8List> read(String url) async {
    final file = await _file(url);
    try {
      if (file != null && await file.exists()) return await file.readAsBytes();
    } on FileSystemException {
      // Fetched again below.
    }
    final bytes = await download(url);
    if (file != null && bytes.isNotEmpty) {
      try {
        await file.parent.create(recursive: true);
        // Whole files only: a killed app never leaves half a photo behind.
        final part = File('${file.path}.part');
        await part.writeAsBytes(bytes, flush: true);
        await part.rename(file.path);
      } on FileSystemException {
        // Next time it is fetched again.
      }
    }
    return bytes;
  }

  /// Drops one copy, when it cannot be decoded.
  static Future<void> forget(String url) async {
    final file = await _file(url);
    try {
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing more to do.
    }
  }

  /// Signing out leaves no one's photos on the phone.
  static Future<void> clear() async {
    try {
      final folder = await directory();
      if (folder != null && await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } on FileSystemException {
      // The phone empties its cache folder in time.
    }
  }
}

/// A person's or station's photo. Two links to the same photo are the same
/// image, so Flutter's image cache answers at once however often the list
/// behind them is fetched, and [PhotoStore] answers after a restart.
class CachedPhoto extends ImageProvider<CachedPhoto> {
  final String url;
  final String identity;
  CachedPhoto(this.url) : identity = photoIdentity(url);

  @override
  Future<CachedPhoto> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
          CachedPhoto key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
          codec: _load(key, decode), scale: 1, debugLabel: key.identity);

  Future<ui.Codec> _load(CachedPhoto key, ImageDecoderCallback decode) async {
    try {
      final bytes = await PhotoStore.read(key.url);
      try {
        return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      } catch (_) {
        await PhotoStore.forget(key.url);
        rethrow;
      }
    } catch (_) {
      // A failure is not kept: the next time it is shown, it tries again.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedPhoto && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;
}
