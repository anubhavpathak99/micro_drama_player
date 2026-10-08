import 'dart:async';

import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// Paces a scrub's seeks: the first goes out at once, then at most one per
/// [interval], always to the latest position asked for. The picture keeps
/// up with the finger without flooding the player.
final class SeekThrottle {
  SeekThrottle(this._seek, {this.interval = MotionGestures.scrubSeekInterval});

  final void Function(Duration position) _seek;
  final Duration interval;

  Timer? _cooldown;
  Duration? _pending;

  /// Asks for a seek to [position].
  void request(Duration position) {
    if (_cooldown != null) {
      _pending = position;
      return;
    }
    _seek(position);
    _cooldown = Timer(interval, _cooledDown);
  }

  /// Drops a seek that is still waiting. The caller makes the final one.
  void cancel() {
    _cooldown?.cancel();
    _cooldown = null;
    _pending = null;
  }

  void _cooledDown() {
    _cooldown = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) request(pending);
  }
}
