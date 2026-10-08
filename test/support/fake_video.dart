import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';
import 'package:micro_drama_interactive_player/data/video_controller_factory.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:video_player/video_player.dart';

/// Stands in for a platform video player: records commands and updates its
/// value the way a real controller does.
class FakeVideoController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoController(
    this.source, {
    required this.fromFile,
    this.failToInitialize = false,
  }) : super(const VideoPlayerValue(duration: Duration.zero));

  /// The url or file path the controller was created from.
  final String source;
  final bool fromFile;
  final bool failToInitialize;
  final List<String> commands = [];
  bool isDisposed = false;

  /// An uninitialized id, so `VideoPlayer` renders an empty box in tests.
  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  Future<void> initialize() async {
    commands.add('initialize');
    if (failToInitialize) {
      throw PlatformException(code: 'VideoError', message: 'Source missing');
    }
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 15),
      size: const Size(720, 1280),
    );
  }

  @override
  Future<void> play() async {
    commands.add('play');
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    commands.add('seekTo ${position.inMilliseconds}');
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setLooping(bool looping) async {
    commands.add('setLooping $looping');
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Creates [FakeVideoController]s and remembers every one of them.
class FakeVideoControllerFactory implements VideoControllerFactory {
  /// Episode ids whose next controller fails to initialize (once each).
  final Set<String> failing = {};
  final List<FakeVideoController> created = [];

  Iterable<FakeVideoController> get live =>
      created.where((controller) => !controller.isDisposed);

  /// The live controller playing [episodeId], if any.
  FakeVideoController? liveFor(String episodeId) => live
      .where((controller) => controller.source.contains(episodeId))
      .firstOrNull;

  /// Every controller ever created for [episodeId].
  Iterable<FakeVideoController> createdFor(String episodeId) =>
      created.where((controller) => controller.source.contains(episodeId));

  @override
  VideoPlayerController fromFile(File file) =>
      _create(file.path, fromFile: true);

  @override
  VideoPlayerController fromNetwork(Uri url) =>
      _create('$url', fromFile: false);

  FakeVideoController _create(String source, {required bool fromFile}) {
    final failure = failing.where(source.contains).firstOrNull;
    if (failure != null) failing.remove(failure);
    final controller = FakeVideoController(
      source,
      fromFile: fromFile,
      failToInitialize: failure != null,
    );
    created.add(controller);
    return controller;
  }
}

/// A disk cache that holds [cachedEpisodeIds] and records warm-ups.
class FakeVideoCache implements VideoCache {
  FakeVideoCache({this.cachedEpisodeIds = const {}});

  final Set<String> cachedEpisodeIds;
  final List<Uri> warmed = [];

  @override
  Future<File?> cachedFile(Uri url) async {
    final name = url.pathSegments.last;
    return cachedEpisodeIds.contains(name.split('.').first)
        ? File('/cache/$name')
        : null;
  }

  @override
  void warm(Uri url) => warmed.add(url);
}

class FakeEpisodeRepository implements EpisodeRepository {
  FakeEpisodeRepository(this.episodes);

  final List<Episode> episodes;

  @override
  Future<List<Episode>> fetchEpisodes() async => episodes;
}

/// A pool with a fixed state that records the commands it receives.
class FakePlayerPool extends PlayerPool {
  FakePlayerPool([this.initial = const PlayerPoolState()]);

  final PlayerPoolState initial;
  final List<String> calls = [];

  @override
  PlayerPoolState build() => initial;

  void emit(PlayerPoolState next) => state = next;

  @override
  void togglePlayback(String episodeId) => calls.add('toggle $episodeId');

  @override
  void retry(String episodeId) => calls.add('retry $episodeId');

  @override
  void beginScrub(String episodeId) => calls.add('scrub $episodeId');

  @override
  void seek(String episodeId, Duration position) =>
      calls.add('seek $episodeId ${position.inMilliseconds}');

  @override
  Future<void> endScrub(String episodeId, Duration position) async =>
      calls.add('end scrub $episodeId ${position.inMilliseconds}');

  @override
  void suspend(SuspendReason reason) => calls.add('suspend ${reason.name}');

  @override
  void resume(SuspendReason reason) => calls.add('resume ${reason.name}');

  @override
  void rewindInactive() => calls.add('rewind');
}
