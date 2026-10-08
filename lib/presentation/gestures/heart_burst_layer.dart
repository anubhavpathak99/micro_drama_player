import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/heart_burst.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/tap_sequence.dart';

/// Double-tap to like, over an episode page.
///
/// Taps are read by a [TapSequence] from their pointer timestamps. A single
/// tap reaches [onSingleTap] once the double-tap window has passed with no
/// second tap. A double tap, and every rapid tap after it, puts up a heart
/// where the finger landed and calls [onHeart]. The taps compete in the
/// gesture arena like any other, so a swipe still pages the feed and the
/// buttons on top keep their taps.
///
/// Hearts are particles, not widgets: one [CustomPainter] draws them all,
/// repainted by a [Ticker] that runs only while a heart is on screen.
class HeartBurstLayer extends StatefulWidget {
  const HeartBurstLayer({
    super.key,
    this.enabled = true,
    this.onSingleTap,
    required this.onHeart,
    this.random,
    required this.child,
  });

  /// When false, taps go straight to [child], as behind the paywall.
  final bool enabled;

  /// A single tap. Null when a single tap has nothing to do.
  final VoidCallback? onSingleTap;

  /// A heart went up: the double tap, and every tap of the combo after it.
  final VoidCallback onHeart;

  /// Picks each heart's tilt and burst. Seed it for repeatable hearts.
  final math.Random? random;

  final Widget child;

  @override
  State<HeartBurstLayer> createState() => _HeartBurstLayerState();
}

class _HeartBurstLayerState extends State<HeartBurstLayer>
    with SingleTickerProviderStateMixin {
  final TapSequence _taps = TapSequence();
  Timer? _window;

  final List<HeartBurst> _bursts = [];
  final _Clock _clock = _Clock();
  late final Ticker _ticker = createTicker(_tick);
  late final _HeartBurstPainter _painter = _HeartBurstPainter(_bursts, _clock);
  late final math.Random _random = widget.random ?? math.Random();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Drawn now, while the page appears, rather than on the first double
    // tap: their one-off render would cost that heart's first frame.
    _painter.sprites = _HeartSprites.of(MediaQuery.devicePixelRatioOf(context));
  }

  @override
  void didUpdateWidget(HeartBurstLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _window?.cancel();
      _taps.reset();
    }
  }

  @override
  void dispose() {
    _window?.cancel();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) => _taps.pointerDown();

  void _tapped(PointerDownEvent down, PointerUpEvent up) {
    _window?.cancel();
    _window = Timer(MotionGestures.doubleTapWindow, _windowLapsed);
    _run(
      _taps.tap(
        down: down.timeStamp,
        up: up.timeStamp,
        position: down.localPosition,
      ),
    );
  }

  void _abandoned() {
    _window?.cancel();
    _run(_taps.abandon());
  }

  void _windowLapsed() => _run(_taps.windowLapsed());

  void _run(List<TapAction> actions) {
    if (!mounted) return;
    for (final action in actions) {
      switch (action) {
        case SingleTap():
          widget.onSingleTap?.call();
        case HeartTap(:final position):
          _spawn(position);
          widget.onHeart();
      }
    }
  }

  void _spawn(Offset position) {
    if (!_ticker.isActive) {
      _clock.now = Duration.zero;
      unawaited(_ticker.start());
    }
    _bursts.add(
      HeartBurst.random(
        position,
        bornAt: _clock.now,
        random: _random,
        calm: context.reduceMotion,
      ),
    );
  }

  void _tick(Duration elapsed) {
    _bursts.removeWhere((burst) => burst.isDoneAt(elapsed));
    if (_bursts.isEmpty) _ticker.stop();
    _clock.advance(elapsed);
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      if (widget.enabled)
        _TapRecognizer: GestureRecognizerFactoryWithHandlers<_TapRecognizer>(
          () => _TapRecognizer(debugOwner: this),
          (recognizer) => recognizer
            ..onPointerDown = _pointerDown
            ..onTapped = _tapped
            ..onAbandoned = _abandoned,
        ),
    },
    // Assistive technologies tap once to play or pause, with no wait.
    semantics: _TapSemantics(widget.enabled ? widget.onSingleTap : null),
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: RepaintBoundary(child: CustomPaint(painter: _painter)),
        ),
      ],
    ),
  );
}

/// The time on the hearts' ticker. Notifies on every tick, so the painter
/// repaints even when the time hasn't moved, as on a ticker's first frame.
final class _Clock extends ChangeNotifier {
  Duration now = Duration.zero;

  void advance(Duration to) {
    now = to;
    notifyListeners();
  }
}

/// A tap recognizer that hands over the tap's pointer events, so taps can
/// be timed by the platform's timestamps, and says when a pointer it saw go
/// down doesn't become a tap.
final class _TapRecognizer extends BaseTapGestureRecognizer {
  _TapRecognizer({super.debugOwner});

  ValueChanged<PointerDownEvent>? onPointerDown;
  void Function(PointerDownEvent down, PointerUpEvent up)? onTapped;
  VoidCallback? onAbandoned;

  // The pointer reported down that hasn't been resolved yet.
  int? _open;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (_open == null && event.pointer == primaryPointer) {
      _open = event.pointer;
      onPointerDown?.call(event);
    }
  }

  @override
  void handleTapDown({required PointerDownEvent down}) {}

  @override
  void handleTapUp({
    required PointerDownEvent down,
    required PointerUpEvent up,
  }) {
    if (_open != down.pointer) return;
    _open = null;
    onTapped?.call(down, up);
  }

  // Comes after the arena was won, when the pointer then moves too far or
  // is cancelled.
  @override
  void handleTapCancel({
    required PointerDownEvent down,
    PointerCancelEvent? cancel,
    required String reason,
  }) => _abandon(down.pointer);

  // Comes when the arena went to someone else: a drag or a button.
  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _abandon(pointer);
  }

  void _abandon(int pointer) {
    if (_open != pointer) return;
    _open = null;
    onAbandoned?.call();
  }

  @override
  String get debugDescription => 'heart tap';
}

final class _TapSemantics extends SemanticsGestureDelegate {
  const _TapSemantics(this.onTap);

  final VoidCallback? onTap;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject.onTap = onTap;
  }
}

/// Paints every heart and spark in one pass, as sprites.
final class _HeartBurstPainter extends CustomPainter {
  _HeartBurstPainter(this._bursts, this._clock) : super(repaint: _clock);

  final List<HeartBurst> _bursts;
  final _Clock _clock;

  /// Set as soon as the layer knows its pixel ratio.
  _HeartSprites? sprites;

  static const List<Color> _sparkColors = [
    AppColors.accent,
    Color(0xFFFF8FAB),
    Color(0xFFFFD6E0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sprites = this.sprites;
    if (sprites == null) return;
    final now = _clock.now;
    for (final burst in _bursts) {
      for (final (index, spark) in burst.sparks.indexed) {
        final pose = burst.sparkAt(spark, now);
        _draw(
          canvas,
          sprites.spark,
          pose,
          side: HeartBurst.size * pose.scale * _HeartSprites.sparkSpan,
          tint: _sparkColors[index % _sparkColors.length],
        );
      }
      final heart = burst.heartAt(now);
      _draw(
        canvas,
        sprites.heart,
        heart,
        side: _HeartSprites.heartSide * heart.scale / _HeartSprites.heartScale,
      );
    }
  }

  /// [image] centred on [pose], [side] wide, tilted, faded and optionally
  /// tinted.
  static void _draw(
    Canvas canvas,
    ui.Image image,
    ParticlePose pose, {
    required double side,
    Color? tint,
  }) {
    if (pose.opacity <= 0 || side <= 0) return;
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, pose.opacity)
      ..filterQuality = FilterQuality.medium
      ..colorFilter = tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn);
    canvas
      ..save()
      ..translate(pose.center.dx, pose.center.dy)
      ..rotate(pose.rotation)
      ..drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HeartBurstPainter oldDelegate) =>
      !identical(oldDelegate._bursts, _bursts) ||
      !identical(oldDelegate._clock, _clock);
}

/// The heart drawn once into images: the big heart with its gradient and
/// shadow, and a small white heart that sparks are tinted from.
///
/// Each particle is then one textured quad a frame. A heart path with a
/// live shadow cost a blur pass every frame, most of a double tap's GPU
/// time on a mid-range phone.
final class _HeartSprites {
  _HeartSprites(this.ratio)
    : heart = _render(ratio, heartSide, _drawHeart),
      spark = _render(ratio, _sparkSide, _drawSpark);

  /// Device pixels per logical pixel the images hold.
  final double ratio;
  final ui.Image heart;
  final ui.Image spark;

  /// The heart sprite holds the heart at this scale, so it stays sharp at
  /// the pop's 1.2× peak.
  static const double heartScale = 1.25;

  /// Room around the heart for its shadow, in logical pixels.
  static const double _shadowRoom = 16;

  /// Side of the heart sprite, in logical pixels.
  static const double heartSide =
      HeartBurst.size * heartScale + _shadowRoom * 2;

  /// Side of the spark sprite, in logical pixels: more than any spark.
  static const double _sparkSide = 32;

  /// The spark sprite's width over its heart's width.
  static const double sparkSpan = _sparkSide / (_sparkSide - 2);

  static const List<Color> _heartColors = [
    Color(0xFFFF7A9C),
    AppColors.accent,
    Color(0xFFE0245E),
  ];
  static const List<double> _heartStops = [0, 0.55, 1];
  static const Color _shadow = Color(0x73000000);
  static const double _shadowElevation = 8;

  static _HeartSprites? _shared;

  /// Sprites at [ratio], shared by every episode's layer.
  static _HeartSprites of(double ratio) {
    final shared = _shared;
    if (shared != null && shared.ratio == ratio) return shared;
    return _shared = _HeartSprites(ratio);
  }

  static void _drawHeart(Canvas canvas) {
    final heart = _scaled(_unitHeart, HeartBurst.size * heartScale);
    final bounds = heart.getBounds();
    canvas
      ..drawShadow(heart, _shadow, _shadowElevation, true)
      ..drawPath(
        heart,
        Paint()
          ..shader = ui.Gradient.linear(
            bounds.topCenter,
            bounds.bottomCenter,
            _heartColors,
            _heartStops,
          ),
      );
  }

  static void _drawSpark(Canvas canvas) => canvas.drawPath(
    _scaled(_unitHeart, _sparkSide - 2),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  /// A [side]-wide square image of [draw], centred on the origin.
  static ui.Image _render(
    double ratio,
    double side,
    void Function(Canvas canvas) draw,
  ) {
    final recorder = ui.PictureRecorder();
    draw(
      Canvas(recorder)
        ..scale(ratio)
        ..translate(side / 2, side / 2),
    );
    final picture = recorder.endRecording();
    final pixels = (side * ratio).ceil();
    final image = picture.toImageSync(pixels, pixels);
    picture.dispose();
    return image;
  }

  static Path _scaled(Path path, double factor) => path.transform(
    Float64List.fromList([
      factor, 0, 0, 0, //
      0, factor, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]),
  );
}

/// A heart one unit wide, centred on the origin. It is the outline of
/// Material's favorite icon, so it matches the rail's like button.
final Path _unitHeart = () {
  // The icon's outline spans x 2–22 and y 3–21.35 of its 24-unit box.
  Offset p(double x, double y) => Offset((x - 12) / 20, (y - 12.175) / 20);
  void cubic(Path path, Offset a, Offset b, Offset to) =>
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, to.dx, to.dy);

  final start = p(12, 21.35);
  final path = Path()..moveTo(start.dx, start.dy);
  final dip = p(10.55, 20.03);
  path.lineTo(dip.dx, dip.dy);
  cubic(path, p(5.4, 15.36), p(2, 12.28), p(2, 8.5));
  cubic(path, p(2, 5.42), p(4.42, 3), p(7.5, 3));
  cubic(path, p(9.24, 3), p(10.91, 3.81), p(12, 5.09));
  cubic(path, p(13.09, 3.81), p(14.76, 3), p(16.5, 3));
  cubic(path, p(19.58, 3), p(22, 5.42), p(22, 8.5));
  cubic(path, p(22, 12.28), p(18.6, 15.36), p(13.45, 20.04));
  return path..close();
}();
