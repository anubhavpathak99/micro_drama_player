import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Disk cache for episode videos.
abstract interface class VideoCache {
  /// The cached copy of [url], or null when it isn't on disk yet.
  Future<File?> cachedFile(Uri url);

  /// Downloads [url] into the cache in the background. Repeated calls for the
  /// same url while a download is running are ignored.
  void warm(Uri url);
}

/// [VideoCache] backed by flutter_cache_manager.
final class CacheManagerVideoCache implements VideoCache {
  CacheManagerVideoCache(this._manager);

  final BaseCacheManager _manager;
  final Set<Uri> _downloading = {};

  @override
  Future<File?> cachedFile(Uri url) async =>
      (await _manager.getFileFromCache(url.toString()))?.file;

  @override
  void warm(Uri url) {
    if (_downloading.add(url)) unawaited(_download(url));
  }

  Future<void> _download(Uri url) async {
    try {
      await _manager.downloadFile(url.toString());
    } on Object {
      // Best effort: the episode keeps streaming, and the next warm-up retries.
    } finally {
      _downloading.remove(url);
    }
  }
}

/// The app's [VideoCache]: one week of episodes, at most 40 files.
final Provider<VideoCache> videoCacheProvider = Provider(
  (ref) => CacheManagerVideoCache(
    CacheManager(
      Config(
        'episode_videos',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 40,
      ),
    ),
  ),
);
