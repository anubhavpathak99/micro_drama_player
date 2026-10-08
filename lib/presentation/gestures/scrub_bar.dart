import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/haptics/haptics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/playback_time.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_painter.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_state.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/seek_throttle.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';
import 'package:video_player/video_player.dart';

/// Scrubbing for an episode page: a horizontal drag anywhere on [child]
/// seeks through the video, the track's width spanning all of it.
///
/// While a scrub runs, the progress track opens up and shows a thumb, and a
/// time bubble ("00:05 / 00:15") follows the finger. Seeks go out at most
/// every [MotionGestures.scrubSeekInterval], then exactly where the finger
/// lifts. Each end of the video answers with a haptic tick. Vertical drags
/// are left to the feed.
///
/// Without a [controller] (still loading, failed, or behind the paywall)
/// there is neither a track nor scrubbing.
class ScrubBar extends StatefulWidget {
  const ScrubBar({
    super.key,
    required this.controller,
    required this.onScrubStart,
    required this.onSeek,
    required this.onScrubEnd,
    required this.child,
  });

  /// The episode's initialized player, read for the track. Commands go
  /// through the callbacks.
  final VideoPlayerController? controller;

  /// A scrub started: playback should hold.
  final VoidCallback onScrubStart;

  /// A seek while the finger moves.
  final ValueChanged<Duration> onSeek;

  /// The finger lifted at a position: seek there exactly and let playback
  /// go on. The track holds the position until the returned future
  /// completes.
  final Future<void> Function(Duration position) onScrubEnd;

  final Widget child;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar> with TickerProviderStateMixin {
  late final ScrubState _scrub = ScrubState(vsync: this)
    ..attach(widget.controller);
  late final SeekThrottle _seeks = SeekThrottle(
    (position) => widget.onSeek(position),
  );
  final ValueNotifier<({String at, String of})> _time = ValueNotifier((
    at: '',
    of: '',
  ));
  ScrubPainter? _painter;
  ScrubEdge _edge = ScrubEdge.none;

  // The whole second the track's semantics announce. It only follows the
  // player while a screen reader is on, so playback rebuilds nothing
  // otherwise.
  final ValueNotifier<int> _announcedSecond = ValueNotifier(0);
  bool _announcing = false;

  /// Height of the box the track is painted in: room for the thumb and its
  /// shadow.
  static const double _trackBox = 2 * (EpisodeLayout.scrubThumbRadius + 6);

  /// How far one accessibility increase or decrease moves the video.
  static const Duration _accessibleStep = Duration(seconds: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _announce(MediaQuery.accessibleNavigationOf(context));
  }

  @override
  void didUpdateWidget(ScrubBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      // The player went away (or was replaced) under the finger.
      if (_scrub.scrubbing) unawaited(_end());
      _scrub.attach(widget.controller);
      _painter = null;
      if (_announcing) {
        oldWidget.controller?.removeListener(_followSecond);
        widget.controller?.addListener(_followSecond);
        _followSecond();
      }
    }
  }

  @override
  void dispose() {
    _seeks.cancel();
    if (_scrub.scrubbing) {
      // Never leave playback held by a scrub that can no longer end.
      final end = widget.onScrubEnd;
      final position = _positionOf(_scrub.target);
      scheduleMicrotask(() => unawaited(end(position)));
    }
    if (_announcing) widget.controller?.removeListener(_followSecond);
    _announcedSecond.dispose();
    _time.dispose();
    _scrub.dispose();
    super.dispose();
  }

  void _announce(bool on) {
    if (on == _announcing) return;
    _announcing = on;
    final controller = widget.controller;
    if (on) {
      controller?.addListener(_followSecond);
      _followSecond();
    } else {
      controller?.removeListener(_followSecond);
    }
  }

  void _followSecond() =>
      _announcedSecond.value = widget.controller?.value.position.inSeconds ?? 0;

  /// Moves playback by [step], for an assistive technology's increase or
  /// decrease: the same pause, exact seek and resume as a scrub.
  void _nudge(Duration step) {
    final value = widget.controller?.value;
    if (value == null || !value.isInitialized) return;
    widget.onScrubStart();
    unawaited(widget.onScrubEnd(_clamp(value.position + step, value.duration)));
  }

  static Duration _clamp(Duration time, Duration duration) => time.isNegative
      ? Duration.zero
      : time > duration
      ? duration
      : time;

  /// The track as a slider: where playback is, and five seconds either way.
  Widget _trackSemantics(Widget track) {
    final value = widget.controller!.value;
    final duration = value.duration;
    String reading(Duration time) =>
        '${formatPlaybackTime(time)} of ${formatPlaybackTime(duration)}';
    return Semantics(
      slider: true,
      label: 'Playback position',
      value: reading(value.position),
      increasedValue: reading(
        _clamp(value.position + _accessibleStep, duration),
      ),
      decreasedValue: reading(
        _clamp(value.position - _accessibleStep, duration),
      ),
      onIncrease: () => _nudge(_accessibleStep),
      onDecrease: () => _nudge(-_accessibleStep),
      child: track,
    );
  }

  Duration _positionOf(double target) =>
      (widget.controller?.value.duration ?? Duration.zero) * target;

  void _start(DragStartDetails details) {
    final value = widget.controller?.value;
    if (value == null || !value.isInitialized) return;
    final duration = value.duration.inMicroseconds;
    if (duration <= 0) return;
    final target = (value.position.inMicroseconds / duration).clamp(0.0, 1.0);
    _edge = ScrubEdge.of(target);
    _scrub.begin(
      target: target,
      fingerX: details.localPosition.dx,
      reduceMotion: context.reduceMotion,
    );
    _showTime();
    widget.onScrubStart();
  }

  void _update(DragUpdateDetails details) {
    if (!_scrub.scrubbing) return;
    final track = context.size!.width - EpisodeLayout.gutter * 2;
    final target = scrubTargetAfter(_scrub.target, details.delta.dx, track);
    _scrub.move(target: target, fingerX: details.localPosition.dx);
    _showTime();
    _seeks.request(_positionOf(target));
    final edge = ScrubEdge.of(target);
    if (edge != _edge && edge != ScrubEdge.none) unawaited(Haptics.tick());
    _edge = edge;
  }

  Future<void> _end() async {
    if (!_scrub.scrubbing) return;
    _seeks.cancel();
    final position = _positionOf(_scrub.target);
    _scrub.release(reduceMotion: context.reduceMotion);
    try {
      await widget.onScrubEnd(position);
    } finally {
      _scrub.settled();
    }
  }

  void _showTime() => _time.value = (
    at: formatPlaybackTime(_positionOf(_scrub.target)),
    of: formatPlaybackTime(widget.controller!.value.duration),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final insets = MediaQuery.paddingOf(context);
    final trackCentre =
        insets.bottom +
        EpisodeLayout.progressBottom +
        EpisodeLayout.progressHeight / 2;
    return RawGestureDetector(
      gestures: {
        if (controller != null)
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                () => HorizontalDragGestureRecognizer(debugOwner: this),
                (drag) => drag
                  ..onStart = _start
                  ..onUpdate = _update
                  ..onEnd = ((_) => unawaited(_end()))
                  ..onCancel = (() => unawaited(_end())),
              ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (controller != null) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: trackCentre - _trackBox / 2,
              height: _trackBox,
              child: ValueListenableBuilder<int>(
                valueListenable: _announcedSecond,
                builder: (context, _, track) => _trackSemantics(track!),
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _painter ??= ScrubPainter(
                        controller: controller,
                        scrub: _scrub,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomSingleChildLayout(
                  delegate: _BubbleLayout(
                    _scrub,
                    bottom:
                        trackCentre +
                        EpisodeLayout.progressHeightScrubbing / 2 +
                        EpisodeLayout.scrubBubbleGap,
                  ),
                  child: _TimeBubble(
                    presence: _scrub.bubble,
                    time: _time,
                    scaleIn: !context.reduceMotion,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Places the time bubble over the finger, [bottom] above the bottom edge,
/// kept clear of the screen's sides. It lays out again only when the finger
/// or the bubble moves.
class _BubbleLayout extends SingleChildLayoutDelegate {
  _BubbleLayout(this.scrub, {required this.bottom})
    : super(relayout: Listenable.merge([scrub.finger, scrub.bubble]));

  final ScrubState scrub;
  final double bottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    bubbleLeft(
      fingerX: scrub.finger.value,
      width: childSize.width,
      span: size.width,
    ),
    size.height - bottom - childSize.height,
  );

  @override
  bool shouldRelayout(_BubbleLayout oldDelegate) =>
      !identical(oldDelegate.scrub, scrub) || oldDelegate.bottom != bottom;
}

/// "00:05 / 00:15": the scrub's position over the video's length. It springs
/// in from slightly smaller, and only rebuilds when the shown time changes.
class _TimeBubble extends StatelessWidget {
  const _TimeBubble({
    required this.presence,
    required this.time,
    required this.scaleIn,
  });

  final Animation<double> presence;
  final ValueListenable<({String at, String of})> time;
  final bool scaleIn;

  static final Tween<double> _scale = Tween(
    begin: MotionValues.scrubBubbleScaleFrom,
    end: 1,
  );

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: presence,
    child: ScaleTransition(
      scale: scaleIn ? _scale.animate(presence) : kAlwaysCompleteAnimation,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xB3000000),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ValueListenableBuilder(
            valueListenable: time,
            builder: (context, time, _) => Text.rich(
              TextSpan(
                text: time.at,
                children: [
                  TextSpan(
                    text: ' / ${time.of}',
                    style: const TextStyle(color: AppColors.onMediaMuted),
                  ),
                ],
              ),
              style: const TextStyle(
                color: AppColors.onMedia,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                // Digits keep their width, so the bubble doesn't jitter.
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
