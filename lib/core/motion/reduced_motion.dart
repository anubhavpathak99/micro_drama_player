import 'package:flutter/widgets.dart';

extension ReducedMotion on BuildContext {
  /// Whether the OS asks for reduced motion. Movement (scale, slide, sweep)
  /// should then become a plain fade, or nothing.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
