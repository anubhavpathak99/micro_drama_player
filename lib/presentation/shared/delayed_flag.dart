import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// A flag that follows its input, but turns on late and turns off no sooner
/// than allowed.
///
/// It turns on only after the input has stayed on for [delay]. Once on, it
/// stays on for at least [minimumOn]. Short waits therefore show nothing, and
/// a wait that ends right after its indicator appeared doesn't blink.
class DelayedFlag extends ValueNotifier<bool> {
  DelayedFlag({required this.delay, this.minimumOn = Duration.zero})
    : super(false);

  final Duration delay;
  final Duration minimumOn;

  bool _input = false;
  Timer? _showTimer;
  Timer? _holdTimer;

  /// Feeds the latest input.
  void update(bool input) {
    if (input == _input) return;
    _input = input;
    if (input) {
      if (!value) _showTimer = Timer(delay, _show);
    } else {
      _showTimer?.cancel();
      _showTimer = null;
      if (_holdTimer == null) value = false;
    }
  }

  void _show() {
    _showTimer = null;
    value = true;
    if (minimumOn > Duration.zero) _holdTimer = Timer(minimumOn, _release);
  }

  void _release() {
    _holdTimer = null;
    if (!_input) value = false;
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }
}

/// Fades [child] in and out with [visible]. While hidden, [child] is out of
/// the tree, so it runs no tickers and catches no taps.
class FadeReveal extends StatelessWidget {
  const FadeReveal({super.key, required this.visible, required this.child});

  final ValueListenable<bool> visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: visible,
    builder: (context, shown, _) => AnimatedSwitcher(
      duration: MotionDurations.fast,
      switchInCurve: MotionCurves.fade,
      switchOutCurve: MotionCurves.fade,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: shown
          ? KeyedSubtree(key: const ValueKey(true), child: child)
          : const SizedBox.shrink(key: ValueKey(false)),
    ),
  );
}

/// Shows [child] only if this widget stays in the tree past the skeleton
/// delay, so a quick load never flashes a placeholder.
class DelayedReveal extends StatefulWidget {
  const DelayedReveal({super.key, required this.child});

  final Widget child;

  @override
  State<DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<DelayedReveal> {
  final DelayedFlag _visible = DelayedFlag(delay: MotionDurations.skeletonDelay)
    ..update(true);

  @override
  void dispose() {
    _visible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeReveal(visible: _visible, child: widget.child);
}
