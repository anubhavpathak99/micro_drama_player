import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';

const String url = 'https://example.com/ep-01.mp4';

/// Serves [cached] from "disk" and holds each download open until the test
/// completes or fails it.
class FakeCacheManager implements BaseCacheManager {
  final Map<String, FileInfo> cached = {};
  final List<Completer<FileInfo>> downloads = [];

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => cached[key];

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    final download = Completer<FileInfo>();
    downloads.add(download);
    return download.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<FileInfo> fileInfo() async => FileInfo(
  await MemoryCacheSystem().createFile('ep-01.mp4'),
  FileSource.Online,
  DateTime(2030),
  url,
);

void main() {
  test('returns the cached copy of a url, or null', () async {
    final manager = FakeCacheManager();
    final cache = CacheManagerVideoCache(manager);
    expect(await cache.cachedFile(Uri.parse(url)), isNull);

    final info = manager.cached[url] = await fileInfo();

    expect((await cache.cachedFile(Uri.parse(url)))?.path, info.file.path);
  });

  test('downloads a url once while its download runs', () async {
    final manager = FakeCacheManager();
    final cache = CacheManagerVideoCache(manager)
      ..warm(Uri.parse(url))
      ..warm(Uri.parse(url));
    expect(manager.downloads, hasLength(1));

    manager.downloads.single.complete(await fileInfo());
    await pumpEventQueue();
    cache.warm(Uri.parse(url));

    expect(manager.downloads, hasLength(2));
  });

  test(
    'a failed download is dropped quietly, and the next warm-up retries',
    () async {
      final manager = FakeCacheManager();
      final cache = CacheManagerVideoCache(manager)..warm(Uri.parse(url));

      manager.downloads.single.completeError(
        const HttpExceptionWithStatus(503, 'Unavailable'),
      );
      await pumpEventQueue();
      cache.warm(Uri.parse(url));

      expect(manager.downloads, hasLength(2));
    },
  );
}
