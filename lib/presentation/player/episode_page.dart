import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/engagement_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/haptics/haptics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/heart_burst_layer.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/paywall_overlay.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_overlay.dart';
import 'package:micro_drama_interactive_player/presentation/player/play_pause_indicator.dart';
import 'package:micro_drama_interactive_player/presentation/player/playback_error_view.dart';
import 'package:micro_drama_interactive_player/presentation/player/video_surface.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';
import 'package:micro_drama_interactive_player/presentation/shared/delayed_flag.dart';
import 'package:video_player/video_player.dart';

/// One episode page, from bottom to top: the bundled poster, the video
/// (fading in on its first frame), the loading skeleton, the overlay chrome,
/// the play/pause glyph and, on failure, an in-place retry.
///
/// A tap anywhere outside the rail toggles playback once the double-tap
/// window has passed. A double tap likes the episode with a burst of hearts.
class EpisodePage extends ConsumerStatefulWidget {
  const EpisodePage({super.key, required this.episode});

  final Episode episode;

  @override
  ConsumerState<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends ConsumerState<EpisodePage> {
  final DelayedFlag _loading = DelayedFlag(
    delay: MotionDurations.skeletonDelay,
    minimumOn: MotionDurations.skeletonMinimum,
  );
  PlayerSlot? _slot;
  bool _active = false;
  VideoPlayerController? _observed;
  Duration? _lastPosition;

  String get _id => widget.episode.id;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      playerPoolProvider.select(
        (pool) => (slot: pool.slots[_id], active: pool.activeId == _id),
      ),
      (_, next) => _onPlayerChanged(next.slot, active: next.active),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _observe(null);
    _loading.dispose();
    super.dispose();
  }

  void _onPlayerChanged(PlayerSlot? slot, {required bool active}) {
    _slot = slot;
    _active = active;
    _observe(switch (slot) {
      PlayerReady(:final controller) => controller,
      _ => null,
    });
    _updateLoading();
  }

  void _observe(VideoPlayerController? controller) {
    if (identical(controller, _observed)) return;
    _observed?.removeListener(_updateLoading);
    _observed = controller?..addListener(_updateLoading);
    _lastPosition = null;
  }

  // Loading means the user is on this page with nothing to watch yet. The
  // flag debounces it, so the skeleton never flashes.
  void _updateLoading() => _loading.update(
    _active &&
        switch (_slot) {
          PlayerLoading() => true,
          PlayerReady(:final controller) => _isStalled(controller.value),
          PlayerFailed() || null => false,
        },
  );

  // Trust the buffering flag only while playback should run and the picture
  // is frozen: some platforms leave it set after playback has resumed.
  bool _isStalled(VideoPlayerValue value) {
    final advanced = value.position != _lastPosition;
    _lastPosition = value.position;
    return value.isPlaying && value.isBuffering && !advanced;
  }

  // Every heart of a double tap and its combo. Liking is idempotent: the
  // episode stays liked however many hearts go up.
  void _like() {
    ref.read(likedEpisodesProvider.notifier).add(_id);
    unawaited(Haptics.toggle());
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final slot = ref.watch(
      playerPoolProvider.select((pool) => pool.slots[_id]),
    );
    final paused = ref.watch(
      playerPoolProvider.select(
        (pool) => pool.activeId == _id && pool.userPaused,
      ),
    );
    // Behind the paywall (locked, or unlocking until its exit finishes) the
    // card replaces the episode chrome.
    final gated = ref.watch(
      paywallControllerProvider.select((paywall) => paywall.isLocked(episode)),
    );
    final pool = ref.read(playerPoolProvider.notifier);

    return HeartBurstLayer(
      enabled: !gated,
      onSingleTap: slot is PlayerReady ? () => pool.togglePlayback(_id) : null,
      onHeart: _like,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Poster(asset: episode.posterAsset),
          if (slot case PlayerReady(:final controller))
            VideoSurface(key: ObjectKey(controller), controller: controller),
          FadeReveal(visible: _loading, child: const _LoadingLayer()),
          ValueListenableBuilder<bool>(
            valueListenable: _loading,
            builder: (context, loading, chrome) => IgnorePointer(
              ignoring: loading || gated,
              child: AnimatedOpacity(
                opacity: loading || gated ? 0 : 1,
                duration: MotionDurations.medium,
                curve: MotionCurves.fade,
                child: chrome,
              ),
            ),
            child: EpisodeOverlay(episode: episode),
          ),
          PlayPauseIndicator(paused: paused),
          if (slot is PlayerFailed)
            PlaybackErrorView(onRetry: () => pool.retry(_id)),
          if (episode.isPremium) PaywallOverlay(episode: episode),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    frameBuilder: (context, image, frame, wasSynchronouslyLoaded) =>
        wasSynchronouslyLoaded
        ? image
        : AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: MotionDurations.fast,
            curve: MotionCurves.fade,
            child: image,
          ),
    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surface),
  );
}

class _LoadingLayer extends StatelessWidget {
  const _LoadingLayer();

  @override
  Widget build(BuildContext context) => const Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(color: AppColors.scrim),
      BrandedSkeleton(),
    ],
  );
}
