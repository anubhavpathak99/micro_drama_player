import 'package:flutter/widgets.dart';

extension ReducedMotion on BuildContext {
  /// Whether the OS asks for reduced motion. Movement (scale, slide, sweep)
  /// should then become a plain fade, or nothing.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}

/// Folds iOS's Reduce Motion into [MediaQueryData.disableAnimations] for
/// everything below it.
///
/// Flutter sets [MediaQueryData.disableAnimations] only for Android's Remove
/// animations; iOS reports Reduce Motion separately. With this at the root,
/// the app reads one flag on both platforms.
class ReducedMotionScope extends StatefulWidget {
  const ReducedMotionScope({super.key, required this.child});

  final Widget child;

  @override
  State<ReducedMotionScope> createState() => _ReducedMotionScopeState();
}

class _ReducedMotionScopeState extends State<ReducedMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // MediaQuery only rebuilds for the features it carries, so follow
  // Reduce Motion here.
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = View.of(context)
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduceMotion,
      ),
      child: widget.child,
    );
  }
}
