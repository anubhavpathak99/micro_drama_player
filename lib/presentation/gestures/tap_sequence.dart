import 'dart:ui' show Offset;

import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// What a tap on an episode, or a run of them, comes to.
sealed class TapAction {
  const TapAction(this.position);

  /// Where the tap landed, in the episode's coordinates.
  final Offset position;
}

/// One tap with no second one after it: play or pause.
final class SingleTap extends TapAction {
  const SingleTap(super.position);
}

/// A double tap, or a tap that keeps a combo going: a heart.
final class HeartTap extends TapAction {
  const HeartTap(super.position, {required this.startsCombo});

  /// Whether this is the double tap itself rather than a tap after it.
  final bool startsCombo;
}

/// Reads taps as single taps, double taps and combos, using the platform's
/// pointer timestamps.
///
/// A tap stays pending for [window] after it lifts: a second tap that lands
/// in that time, within [slop] of it, makes a double tap. Otherwise it
/// becomes a single tap once the window lapses. After a double tap, every
/// tap that lands within [window] of the last one lifting adds a heart
/// wherever it lands, until the taps stop.
///
/// The caller reports the tap gestures and runs the clock: it calls
/// [windowLapsed] once [window] has passed since the last tap.
final class TapSequence {
  TapSequence({
    this.window = MotionGestures.doubleTapWindow,
    this.slop = MotionGestures.doubleTapSlop,
  });

  final Duration window;
  final double slop;

  ({Duration up, Offset position})? _last;
  bool _singlePending = false;
  bool _combo = false;
  bool _pointerDown = false;

  /// Whether a heart combo is running.
  bool get inCombo => _combo;

  /// A pointer touched down. A lapsing window waits for it to resolve.
  void pointerDown() => _pointerDown = true;

  /// The pointer that touched down at [down] lifted at [up] as a tap at
  /// [position].
  List<TapAction> tap({
    required Duration down,
    required Duration up,
    required Offset position,
  }) {
    _pointerDown = false;
    final last = _last;
    final actions = <TapAction>[];
    final inWindow = last != null && down - last.up <= window;
    final closeEnough =
        last != null && (position - last.position).distance <= slop;
    if (inWindow && (_combo || (_singlePending && closeEnough))) {
      actions.add(HeartTap(position, startsCombo: !_combo));
      _singlePending = false;
      _combo = true;
    } else {
      if (_singlePending) actions.add(SingleTap(last!.position));
      _singlePending = true;
      _combo = false;
    }
    _last = (up: up, position: position);
    return actions;
  }

  /// The pointer that touched down didn't make a tap: it dragged, it was
  /// cancelled, or a control on top took it. The sequence ends there.
  List<TapAction> abandon() {
    _pointerDown = false;
    return _close();
  }

  /// [window] has passed since the last tap lifted.
  List<TapAction> windowLapsed() => _pointerDown ? const [] : _close();

  /// Drops the sequence, including a pending single tap.
  void reset() {
    _pointerDown = false;
    _close();
  }

  List<TapAction> _close() {
    final last = _last;
    final actions = [
      if (_singlePending && last != null) SingleTap(last.position),
    ];
    _last = null;
    _singlePending = false;
    _combo = false;
    return actions;
  }
}
