import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';
import 'package:video_player/video_player.dart';

/// Which end of the video a scrub is held against, if either.
enum ScrubEdge {
  start,
  end,
  none;

  static ScrubEdge of(double target) => target <= 0
      ? ScrubEdge.start
      : target >= 1
      ? ScrubEdge.end
      : ScrubEdge.none;
}

/// [target] after a drag of [dx] along a track [trackWidth] wide: the
/// track's full width spans the whole video. Held between 0 and 1, so
/// dragging back from past an end moves off it at once.
double scrubTargetAfter(double target, double dx, double trackWidth) =>
    trackWidth <= 0 ? target : (target + dx / trackWidth).clamp(0.0, 1.0);

/// The left edge of a time bubble [width] wide, centred on [fingerX] but
/// kept [inset] clear of both edges of an area [span] wide.
double bubbleLeft({
  required double fingerX,
  required double width,
  required double span,
  double inset = EpisodeLayout.gutter,
}) => math.max(inset, math.min(fingerX - width / 2, span - inset - width));

/// Everything the scrub bar shows besides the player itself: the scrub
/// under way, and the springs that open the track and its time bubble.
///
/// It notifies on each change, up to once a frame while a spring runs, so a
/// painter can follow it while no widget rebuilds. During playback it is
/// quiet: the track repaints from the player's own position reports. The
/// bubble's position and animation are exposed separately, so its layout
/// only runs during a scrub.
class ScrubState extends ChangeNotifier {
  ScrubState({required TickerProvider vsync})
    : _bar = AnimationController.unbounded(vsync: vsync),
      _bubble = AnimationController.unbounded(vsync: vsync),
      _presence = AnimationController(
        vsync: vsync,
        duration: MotionDurations.medium,
      ) {
    _bar.addListener(notifyListeners);
    _presence.addListener(notifyListeners);
  }

  final AnimationController _bar;
  final AnimationController _bubble;
  final AnimationController _presence;
  final ValueNotifier<double> _finger = ValueNotifier(0);

  VideoPlayerController? _controller;

  bool _scrubbing = false;
  bool _settling = false;
  double _target = 0;
  bool _disposed = false;

  /// A scrub is under way.
  bool get scrubbing => _scrubbing;

  /// Where the scrub is aiming, from 0 to 1.
  double get target => _target;

  /// How far open the track is: 0 at rest, 1 while scrubbing.
  double get expansion => _bar.value;

  /// How far the track has faded in since its player arrived, from 0 to 1.
  double get presence => _presence.value;

  /// The finger's x during a scrub, for the time bubble.
  ValueListenable<double> get finger => _finger;

  /// The time bubble's presence: 0 hidden, 1 shown. Springs past 1 on its
  /// way in.
  Animation<double> get bubble => _bubble;

  /// Where the playhead is drawn, from 0 to 1. During a scrub, and until its
  /// final seek lands, that is the scrub's target. Otherwise it is the
  /// player's last reported position.
  ///
  /// The player reports about every 100 ms, so the bar moves in small steps.
  /// Moving it smoothly in between would take a frame every vsync, doubling
  /// the frames, and the GPU work, of a 30 fps video.
  double get played {
    if (_scrubbing || _settling) return _target;
    final value = _controller?.value;
    final duration = value?.duration.inMicroseconds ?? 0;
    if (value == null || duration <= 0) return 0;
    return (value.position.inMicroseconds / duration).clamp(0.0, 1.0);
  }

  /// Follows [controller] from now on. The track fades in when a player
  /// first arrives, and goes when it does.
  void attach(VideoPlayerController? controller) {
    if (identical(controller, _controller)) return;
    _controller = controller;
    if (controller == null) {
      _presence.value = 0;
    } else if (_presence.value == 0) {
      unawaited(_presence.forward());
    }
  }

  /// A scrub starts at [target], with the finger at [fingerX].
  void begin({
    required double target,
    required double fingerX,
    required bool reduceMotion,
  }) {
    _scrubbing = true;
    _settling = false;
    _target = target;
    _finger.value = fingerX;
    _animate(_bar, MotionSprings.snappy, 1, reduceMotion: reduceMotion);
    _animate(_bubble, MotionSprings.bouncy, 1, reduceMotion: reduceMotion);
    notifyListeners();
  }

  /// The scrub moved to [target], with the finger at [fingerX].
  void move({required double target, required double fingerX}) {
    _target = target;
    _finger.value = fingerX;
    notifyListeners();
  }

  /// The finger lifted. The track and bubble close, and the playhead holds
  /// at the target until [settled].
  void release({required bool reduceMotion}) {
    if (!_scrubbing) return;
    _scrubbing = false;
    _settling = true;
    _animate(_bar, MotionSprings.snappy, 0, reduceMotion: reduceMotion);
    _animate(_bubble, MotionSprings.snappy, 0, reduceMotion: reduceMotion);
    notifyListeners();
  }

  /// The scrub's final seek has landed: the playhead follows the player
  /// again.
  void settled() {
    if (_disposed || !_settling) return;
    _settling = false;
    notifyListeners();
  }

  static void _animate(
    AnimationController controller,
    SpringDescription spring,
    double target, {
    required bool reduceMotion,
  }) {
    unawaited(
      reduceMotion
          ? controller.animateTo(
              target,
              duration: MotionDurations.reducedMotionFade,
            )
          : controller.animateWith(
              SpringSimulation(
                spring,
                controller.value,
                target,
                controller.velocity,
                snapToEnd: true,
              ),
            ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _bar.dispose();
    _bubble.dispose();
    _presence.dispose();
    _finger.dispose();
    super.dispose();
  }
}
