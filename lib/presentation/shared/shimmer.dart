import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';

/// Shares one shimmer animation with every [ShimmerSweep] below it, so all
/// skeletons sweep in sync on a single ticker. The ticker runs only while at
/// least one sweep is mounted.
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  static ShimmerScopeState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ShimmerInherited>()?.state;

  @override
  State<ShimmerScope> createState() => ShimmerScopeState();
}

class ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionDurations.skeletonShimmer,
  );
  int _sweeps = 0;

  /// Linear progress through the current pass, from 0 to 1.
  Animation<double> get progress => _controller;

  void attach() {
    if (_sweeps++ == 0) unawaited(_controller.repeat());
  }

  void detach() {
    if (--_sweeps == 0) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerInherited(state: this, child: widget.child);
}

class _ShimmerInherited extends InheritedWidget {
  const _ShimmerInherited({required this.state, required super.child});

  final ShimmerScopeState state;

  @override
  bool updateShouldNotify(_ShimmerInherited oldWidget) =>
      oldWidget.state != state;
}

/// Colors [child]'s shapes with a diagonal highlight sweeping across them.
///
/// [child] only provides coverage, so paint it opaque; the colors come from
/// the sweep. Under reduced motion the highlight stays parked off-surface.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  ShimmerScopeState? _scope;
  AnimationController? _fallback;
  Animation<double>? _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !context.reduceMotion;
    final scope = animate ? ShimmerScope.maybeOf(context) : null;
    if (scope != _scope) {
      _scope?.detach();
      _scope = scope?..attach();
    }
    if (animate && scope == null) {
      final fallback = _fallback ??= AnimationController(
        vsync: this,
        duration: MotionDurations.skeletonShimmer,
      );
      if (!fallback.isAnimating) unawaited(fallback.repeat());
    } else {
      _fallback?.stop();
    }
    _progress = animate ? scope?.progress ?? _fallback : null;
  }

  @override
  void dispose() {
    _scope?.detach();
    _fallback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The shapes are rasterized once; only the mask changes per frame.
    final shapes = RepaintBoundary(child: widget.child);
    final progress = _progress;
    if (progress == null) return _mask(0, shapes);
    return AnimatedBuilder(
      animation: progress,
      builder: (context, shapes) =>
          _mask(MotionCurves.sweep.transform(progress.value), shapes!),
      child: shapes,
    );
  }

  Widget _mask(double progress, Widget shapes) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        AppColors.skeleton,
        AppColors.skeletonHighlight,
        AppColors.skeleton,
      ],
      stops: const [0.35, 0.5, 0.65],
      transform: _DiagonalSlide(progress),
    ).createShader(bounds),
    child: shapes,
  );
}

/// Moves the highlight band from before the surface's top-left corner
/// (progress 0) to past its bottom-right corner (progress 1).
class _DiagonalSlide extends GradientTransform {
  const _DiagonalSlide(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final offset = progress * 2 - 1;
    return Matrix4.translationValues(
      bounds.width * offset,
      bounds.height * offset,
      0,
    );
  }
}
