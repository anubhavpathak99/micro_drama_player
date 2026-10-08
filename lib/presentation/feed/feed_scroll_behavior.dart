import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// The feed's scroll behaviour. On Android, flings are read by a
/// [LiftAwareVelocityTracker], which needs the lift times that [lifts]
/// collects.
class FeedScrollBehavior extends MaterialScrollBehavior {
  const FeedScrollBehavior(this.lifts);

  final PointerLifts lifts;

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) =>
      switch (getPlatform(context)) {
        TargetPlatform.android => (event) => LiftAwareVelocityTracker(
          event,
          lifts,
        ),
        _ => super.velocityTrackerBuilder(context),
      };
}

/// When the latest pointer lifted, by the platform's timestamp.
///
/// Fed by a [Listener] around the feed. A listener sees the lift before
/// any gesture recognizer does, so a drag's velocity tracker can read the
/// lift time while the drag ends.
final class PointerLifts {
  int? _pointer;
  Duration? _timeStamp;

  void record(PointerUpEvent event) {
    _pointer = event.pointer;
    _timeStamp = event.timeStamp;
  }

  /// When [pointer] lifted, if it has.
  Duration? of(int pointer) => pointer == _pointer ? _timeStamp : null;
}

/// A [VelocityTracker] that tells a fling from a stop by the platform's
/// timestamps, so a quick swipe still flings while the main thread is busy.
///
/// Under load Android batches touch samples, and Flutter keeps only the
/// newest of each batch. A fast swipe then arrives as a few samples more
/// than [MotionGestures.stillBeforeLift] apart, and its lift is processed
/// late. Flutter's tracker reads both as a finger that stopped, reports no
/// velocity, and the page snaps back. Ad pages show it most: moving their
/// platform view keeps the main thread busy.
///
/// So when the standard estimate is zero, this tracker checks the lift's
/// timestamp. If the finger lifted within [MotionGestures.stillBeforeLift]
/// of its last sample, it was still moving. The velocity is then the
/// average over the last [MotionGestures.flingWindow] of samples, reaching
/// back at least one sample.
class LiftAwareVelocityTracker extends VelocityTracker {
  LiftAwareVelocityTracker(PointerEvent start, this._lifts)
    : _pointer = start.pointer,
      super.withKind(start.kind);

  /// As many samples as Flutter's tracker keeps.
  static const int _capacity = 20;

  final PointerLifts _lifts;
  final int _pointer;
  final List<({Duration time, Offset position})> _samples = [];

  @override
  void addPosition(Duration time, Offset position) {
    super.addPosition(time, position);
    if (_samples.length == _capacity) _samples.removeAt(0);
    _samples.add((time: time, position: position));
  }

  @override
  VelocityEstimate? getVelocityEstimate() {
    final estimate = super.getVelocityEstimate();
    if (estimate == null || estimate.pixelsPerSecond != Offset.zero) {
      return estimate;
    }
    final liftedAt = _lifts.of(_pointer);
    if (liftedAt == null || _samples.length < 2) return estimate;
    final newest = _samples.last;
    if (liftedAt - newest.time > MotionGestures.stillBeforeLift) {
      return estimate;
    }

    var oldest = _samples[_samples.length - 2];
    for (final sample in _samples.reversed.skip(2)) {
      if (newest.time - sample.time > MotionGestures.flingWindow) break;
      oldest = sample;
    }
    final elapsed = newest.time - oldest.time;
    if (elapsed <= Duration.zero) return estimate;
    final offset = newest.position - oldest.position;
    return VelocityEstimate(
      pixelsPerSecond:
          offset * (Duration.microsecondsPerSecond / elapsed.inMicroseconds),
      confidence: 1,
      duration: elapsed,
      offset: offset,
    );
  }
}
