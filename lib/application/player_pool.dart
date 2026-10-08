import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_window.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';
import 'package:micro_drama_interactive_player/data/video_controller_factory.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:video_player/video_player.dart';

/// Player state of one episode, as the UI sees it.
@immutable
sealed class PlayerSlot {
  const PlayerSlot();
}

/// Finding the video (disk cache or network) and initializing the player.
final class PlayerLoading extends PlayerSlot {
  const PlayerLoading();
}

/// Initialized and ready. Widgets may render and observe [controller]; only
/// the pool commands it (play, pause, seek, dispose).
final class PlayerReady extends PlayerSlot {
  const PlayerReady(this.controller);

  final VideoPlayerController controller;

  @override
  bool operator ==(Object other) =>
      other is PlayerReady && identical(other.controller, controller);

  @override
  int get hashCode => identityHashCode(controller);
}

/// Loading or playback failed. [PlayerPool.retry] starts over.
final class PlayerFailed extends PlayerSlot {
  const PlayerFailed(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is PlayerFailed && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// Why playback is on hold. It resumes once every reason has cleared.
enum SuspendReason {
  /// The app is not in the foreground.
  appInactive,

  /// Another route covers the feed.
  routeCovered,
}

/// What the UI needs to know about the pool.
@immutable
final class PlayerPoolState {
  const PlayerPoolState({
    this.slots = const {},
    this.activeId,
    this.userPaused = false,
    this.suspended = false,
  });

  /// One slot per episode inside the player window, keyed by episode id.
  final Map<String, PlayerSlot> slots;

  /// The episode that should be playing: the current page, unless that page
  /// is an ad or a locked episode.
  final String? activeId;

  /// The user paused [activeId] with a tap.
  final bool userPaused;

  /// Playback is on hold for at least one [SuspendReason].
  final bool suspended;
}

/// Owns every [VideoPlayerController] in the app.
///
/// It follows the feed: controllers exist only for the episodes in
/// [playerWindow] (the current page and its neighbours, at most
/// [maxPlayers]). Neighbours are initialized ahead of time and parked,
/// paused, on their first frame. Anything that leaves the window is disposed,
/// and a locked episode never gets a controller.
class PlayerPool extends Notifier<PlayerPoolState> {
  /// Upper bound on live controllers: the current page and its neighbours.
  static const int maxPlayers = 3;

  /// How long a video may take to initialize before it counts as failed.
  static const Duration initTimeout = Duration(seconds: 15);

  final Map<String, _Player> _players = {};
  final Set<SuspendReason> _suspensions = {};
  late VideoControllerFactory _factory;
  late VideoCache _cache;
  FeedState? _feed;
  String? _activeId;
  bool _userPaused = false;

  @override
  PlayerPoolState build() {
    _factory = ref.watch(videoControllerFactoryProvider);
    _cache = ref.watch(videoCacheProvider);
    ref.onDispose(_disposeAll);
    // Listen rather than watch: a rebuild would run onDispose and tear down
    // every controller on each page change.
    ref.listen(feedControllerProvider, (_, next) {
      _feed = next.value;
      _sync();
    });
    ref.listen(paywallControllerProvider, (_, _) => _sync());
    _feed = ref.read(feedControllerProvider).value;
    _reconcile();
    return _snapshot();
  }

  /// Pauses or resumes the playing episode on behalf of the user.
  void togglePlayback(String episodeId) {
    if (episodeId != _activeId) return;
    _userPaused = !_userPaused;
    _applyPlayback();
    _publish();
  }

  /// Starts over for an episode whose player failed.
  void retry(String episodeId) {
    if (_players[episodeId]?.slot is! PlayerFailed) return;
    _players.remove(episodeId)?.dispose();
    _sync();
  }

  /// Holds playback for [reason] until [resume] is called with it.
  void suspend(SuspendReason reason) {
    if (!_suspensions.add(reason)) return;
    _applyPlayback();
    _publish();
  }

  /// Clears [reason]. Playback continues once no reason is left.
  void resume(SuspendReason reason) {
    if (!_suspensions.remove(reason)) return;
    _applyPlayback();
    _publish();
  }

  /// Rewinds every paused neighbour to its first frame, so the next page
  /// the user swipes to starts from the beginning.
  ///
  /// Call it once the feed has stopped scrolling. Rewinding a page that is
  /// still partly visible would make it jump.
  void rewindInactive() {
    for (final player in _players.values) {
      final controller = player.readyController;
      if (controller == null || player.id == _activeId) continue;
      if (controller.value.position != Duration.zero) {
        unawaited(controller.seekTo(Duration.zero));
      }
    }
  }

  @visibleForTesting
  int get liveControllerCount =>
      _players.values.where((player) => player.controller != null).length;

  void _sync() {
    _reconcile();
    _publish();
  }

  void _reconcile() {
    final feed = _feed;
    final paywall = ref.read(paywallControllerProvider);
    final window = feed == null
        ? const <String>{}
        : playerWindow(feed.items, feed.currentId, isLocked: paywall.isLocked);

    for (final id in [..._players.keys]) {
      if (!window.contains(id)) _players.remove(id)?.dispose();
    }
    for (final id in window) {
      if (_players.containsKey(id)) continue;
      final player = _players[id] = _Player(feed!.episodeById(id)!);
      unawaited(_load(player));
    }
    assert(_players.length <= maxPlayers, 'Too many players: ${_players.keys}');

    final activeId = window.contains(feed?.currentId) ? feed!.currentId : null;
    if (activeId != _activeId) {
      _activeId = activeId;
      _userPaused = false;
    }
    _applyPlayback();
  }

  Future<void> _load(_Player player) async {
    final url = player.episode.videoUrl;
    try {
      final cached = await _cache.cachedFile(url);
      if (player.disposed) return;
      // Hard guard, independent of the window: never construct a controller
      // for a locked episode, not even a paused one.
      if (ref.read(paywallControllerProvider).isLocked(player.episode)) {
        _players.remove(player.id)?.dispose();
        _publish();
        return;
      }

      final controller = player.controller = cached != null
          ? _factory.fromFile(cached)
          : _factory.fromNetwork(url);
      await controller.initialize().timeout(initTimeout);
      if (player.disposed) return;
      await controller.setLooping(true);
      // Neighbours wait paused on their first frame for the swipe.
      if (player.id != _activeId) await controller.seekTo(Duration.zero);
      if (player.disposed) return;

      player.markReady(onUpdate: () => _checkForError(player));
      if (cached == null) _cache.warm(url);
      _applyPlayback();
      _publish();
    } on Object catch (error) {
      if (!player.disposed) _fail(player, error);
    }
  }

  void _checkForError(_Player player) {
    final error = player.readyController?.value.errorDescription;
    if (error != null) _fail(player, error);
  }

  void _fail(_Player player, Object error) {
    player
      ..release()
      ..slot = PlayerFailed('$error');
    _publish();
  }

  void _applyPlayback() {
    final mayPlay = !_userPaused && _suspensions.isEmpty;
    for (final player in _players.values) {
      final controller = player.readyController;
      if (controller == null) continue;
      final shouldPlay = mayPlay && player.id == _activeId;
      if (shouldPlay == controller.value.isPlaying) continue;
      unawaited(shouldPlay ? controller.play() : controller.pause());
    }
  }

  void _publish() {
    if (ref.mounted) state = _snapshot();
  }

  PlayerPoolState _snapshot() => PlayerPoolState(
    slots: Map.unmodifiable({
      for (final player in _players.values) player.id: player.slot,
    }),
    activeId: _activeId,
    userPaused: _userPaused,
    suspended: _suspensions.isNotEmpty,
  );

  void _disposeAll() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}

final NotifierProvider<PlayerPool, PlayerPoolState> playerPoolProvider =
    NotifierProvider(PlayerPool.new);

/// One episode's controller and its lifecycle inside the pool.
final class _Player {
  _Player(this.episode);

  final Episode episode;
  VideoPlayerController? controller;
  PlayerSlot slot = const PlayerLoading();
  bool disposed = false;
  VoidCallback? _onUpdate;

  String get id => episode.id;

  VideoPlayerController? get readyController =>
      slot is PlayerReady ? controller : null;

  void markReady({required VoidCallback onUpdate}) {
    final controller = this.controller!;
    slot = PlayerReady(controller);
    controller.addListener(_onUpdate = onUpdate);
  }

  /// Disposes the controller but keeps the slot, so a failure stays visible.
  void release() {
    final controller = this.controller;
    if (controller == null) return;
    if (_onUpdate case final onUpdate?) controller.removeListener(onUpdate);
    _onUpdate = null;
    this.controller = null;
    // Deferred: release can run inside the controller's own listener (an
    // error report), and a notifier must not be disposed while notifying.
    scheduleMicrotask(() => unawaited(controller.dispose()));
  }

  void dispose() {
    disposed = true;
    release();
  }
}
