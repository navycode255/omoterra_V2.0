import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../core/api/repository.dart';

/// Private Omoterra photos (`/media/…`) kept on this phone after their first
/// download, so a photo is downloaded once and screens still show it when the
/// server can't be reached. A media id's bytes never change, so a cached copy
/// never goes stale; only the ones not opened for [stalePeriod] are dropped.
///
/// Only media the server agreed to sign for this member is downloaded, and a
/// photo the server stops signing (stock withdrawn, account changed) is
/// removed from the phone the next time it is shown. The files sit in the
/// app's private cache folder, never the gallery, and are emptied on sign-in,
/// sign-out and account deletion.
BaseCacheManager mediaCache = CacheManager(Config('omoterra_media',
    stalePeriod: const Duration(days: 60), maxNrOfCacheObjects: 500));

/// Swap the cache in widget tests, where the disk plugins aren't available.
@visibleForTesting
set debugMediaCache(BaseCacheManager cache) => mediaCache = cache;

/// Keyed by media id, not URL: the same photo stays cached whichever API
/// address or sign-in token fetched it.
String mediaCacheKey(String url) => 'media:${url.split('/').last}';

final _links = <String, Future<SignedMedia?>>{};
final _expiry = <String, DateTime>{};

/// A signed link for [url], reused until a minute before it expires so a
/// scrolling list asks the server once per photo, not once per rebuild.
Future<SignedMedia?> signedMediaLink(
    OmoterraRepository repository, String url) {
  final expires = _expiry[url];
  if (_links.containsKey(url) &&
      (expires == null ||
          expires.isAfter(DateTime.now().add(const Duration(minutes: 1))))) {
    return _links[url]!;
  }
  _expiry.remove(url);
  final link = _links[url] = repository.mediaLink(url);
  link.then<void>((signed) {
    // Refusals are asked again next time: the stock may be approved by then.
    if (signed == null) {
      _links.remove(url);
    } else {
      _expiry[url] = signed.expiresAt;
    }
  }, onError: (Object _) {
    _links.remove(url);
  });
  return link;
}

Future<void> clearMediaCache() async {
  _links.clear();
  _expiry.clear();
  try {
    await mediaCache.emptyCache();
  } catch (_) {
    // Nothing cached yet, or no disk on this platform: nothing to clear.
  }
}
