import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/paywall_motion.dart';

/// What the Unlock button is doing.
enum CtaPhase {
  /// Waiting for a tap: the label, with a highlight sweeping every 3 s.
  idle,

  /// Purchase in flight: collapsed to a circle around a spinner.
  busy,

  /// Purchased: the spinner has turned into a checkmark.
  done,
}

/// The paywall's primary button. While [CtaPhase.idle] a highlight sweeps
/// across it once per [MotionDurations.ctaShimmerInterval]; a press sinks it
/// on a spring; later phases morph it into a spinner, then a checkmark.
class ShimmerCta extends StatefulWidget {
  const ShimmerCta({
    super.key,
    required this.label,
    required this.phase,
    this.onPressed,
    this.shimmer = true,
  });

  final String label;
  final CtaPhase phase;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether the highlight may sweep. The paywall turns it off while its
  /// card isn't settled on screen, so no ticker runs for nothing.
  final bool shimmer;

  @override
  State<ShimmerCta> createState() => _ShimmerCtaState();
}

class _ShimmerCtaState extends State<ShimmerCta> with TickerProviderStateMixin {
  static const double _height = 56;

  // One shimmer period: the highlight sweeps in its first part, then rests.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: MotionDurations.ctaShimmerInterval,
  )..addListener(_trackSweep);

  // Button scale; unbounded so the release spring can overshoot.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: MotionDurations.spinnerTurn,
  );

  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: MotionDurations.checkmarkDraw,
  );

  // The highlight's position, or null while it rests. Changes only during
  // the sweep, so the resting part of each period repaints nothing.
  final ValueNotifier<double?> _sweep = ValueNotifier(null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(ShimmerCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase == CtaPhase.done && oldWidget.phase != CtaPhase.done) {
      unawaited(_check.forward(from: 0));
    }
    _syncAnimations();
  }

  @override
  void dispose() {
    _cycle.dispose();
    _press.dispose();
    _spin.dispose();
    _check.dispose();
    _sweep.dispose();
    super.dispose();
  }

  void _syncAnimations() {
    final sweeps =
        widget.shimmer &&
        widget.phase == CtaPhase.idle &&
        !context.reduceMotion;
    if (sweeps && !_cycle.isAnimating) {
      unawaited(_cycle.repeat());
    } else if (!sweeps && _cycle.isAnimating) {
      _cycle
        ..stop()
        ..value = 0;
    }

    if (widget.phase == CtaPhase.busy && !_spin.isAnimating) {
      unawaited(_spin.repeat());
    } else if (widget.phase != CtaPhase.busy) {
      _spin.stop();
    }
    if (widget.phase == CtaPhase.done && context.reduceMotion) _check.value = 1;
  }

  void _trackSweep() => _sweep.value = ctaSweep(_cycle.value);

  void _pressDown(TapDownDetails _) {
    if (widget.onPressed == null || context.reduceMotion) return;
    unawaited(
      _press.animateWith(
        SpringSimulation(
          MotionSprings.snappy,
          _press.value,
          MotionValues.pressScale,
          0,
          snapToEnd: true,
        ),
      ),
    );
  }

  void _pressUp() {
    if (_press.value == 1) return;
    unawaited(
      _press.animateWith(
        SpringSimulation(
          MotionSprings.bouncy,
          _press.value,
          1,
          0,
          snapToEnd: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.phase != CtaPhase.idle;
    return Semantics(
      container: true,
      button: true,
      enabled: widget.onPressed != null,
      label: switch (widget.phase) {
        CtaPhase.idle => widget.label,
        CtaPhase.busy => 'Unlocking',
        CtaPhase.done => 'Unlocked',
      },
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: _pressDown,
        onTapUp: (_) => _pressUp(),
        onTapCancel: _pressUp,
        onTap: widget.onPressed,
        child: ScaleTransition(
          scale: _press,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ValueListenableBuilder<double?>(
                valueListenable: _sweep,
                builder: (context, sweep, button) => sweep == null
                    ? button!
                    : ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) =>
                            _highlight(sweep).createShader(bounds),
                        child: button,
                      ),
                child: AnimatedContainer(
                  duration: context.reduceMotion
                      ? Duration.zero
                      : MotionDurations.medium,
                  curve: MotionCurves.standard,
                  width: collapsed ? _height : constraints.maxWidth,
                  height: _height,
                  decoration: const ShapeDecoration(
                    color: AppColors.premium,
                    shape: StadiumBorder(),
                  ),
                  child: AnimatedSwitcher(
                    duration: MotionDurations.fast,
                    child: _face(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face() => switch (widget.phase) {
    CtaPhase.idle => Center(
      key: const ValueKey(CtaPhase.idle),
      child: Text(
        widget.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          color: AppColors.background,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    CtaPhase.busy => Center(
      key: const ValueKey(CtaPhase.busy),
      child: SizedBox.square(
        dimension: 24,
        child: CustomPaint(painter: _SpinnerPainter(_spin)),
      ),
    ),
    CtaPhase.done => Center(
      key: const ValueKey(CtaPhase.done),
      child: SizedBox.square(
        dimension: 26,
        child: CustomPaint(painter: _CheckPainter(_check)),
      ),
    ),
  };

  static LinearGradient _highlight(double sweep) => LinearGradient(
    begin: const Alignment(-1, -0.6),
    end: const Alignment(1, 0.6),
    colors: const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
    stops: const [0.35, 0.5, 0.65],
    transform: _HorizontalSlide(sweep),
  );
}

/// Slides the highlight from beyond the button's left edge (0) to beyond
/// its right edge (1).
class _HorizontalSlide extends GradientTransform {
  const _HorizontalSlide(this.sweep);

  final double sweep;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (sweep * 2 - 1), 0, 0);
}

/// A rotating arc, drawn in the button's text color.
class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.turn) : super(repaint: turn);

  final Animation<double> turn;

  static final Paint _stroke = Paint()
    ..color = AppColors.background
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawArc(
    (Offset.zero & size).deflate(1.5),
    turn.value * 2 * math.pi,
    1.5 * math.pi,
    false,
    _stroke,
  );

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => oldDelegate.turn != turn;
}

/// A checkmark that draws itself as [progress] runs from 0 to 1.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static final Paint _stroke = Paint()
    ..color = AppColors.background
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.84, size.height * 0.28);
    final drawn = MotionCurves.enter.transform(progress.value);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * drawn), _stroke);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
