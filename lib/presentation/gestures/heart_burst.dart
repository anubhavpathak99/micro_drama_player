import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/physics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// Where a particle is at one moment and how it looks there.
///
/// `scale` multiplies [HeartBurst.size]; `rotation` is in radians.
typedef ParticlePose = ({
  Offset center,
  double scale,
  double rotation,
  double opacity,
});

/// One of the small hearts a new heart throws out.
final class HeartSpark {
  const HeartSpark({
    required this.direction,
    required this.reach,
    required this.size,
  });

  /// Unit vector it flies along.
  final Offset direction;

  /// Share of [MotionValues.heartSparkTravel] it covers.
  final double reach;

  /// Its size at launch, as a share of [HeartBurst.size].
  final double size;
}

/// One double-tap heart and the burst of small hearts around it, as a
/// function of time.
///
/// The heart pops in on [MotionSprings.heartPop], tilted by [tilt], then
/// spends its last [MotionDurations.heartFade] drifting up and fading out.
/// Its [sparks] fly out radially over [MotionDurations.heartSparks].
/// A [calm] heart, for reduced motion, only fades in and out where it
/// landed.
final class HeartBurst {
  HeartBurst({
    required this.origin,
    required this.bornAt,
    required this.tilt,
    required this.sparks,
    this.calm = false,
  });

  /// A heart at [origin] with a random tilt and 6 to 8 sparks spread
  /// around it, or a [calm] one with neither.
  factory HeartBurst.random(
    Offset origin, {
    required Duration bornAt,
    required math.Random random,
    bool calm = false,
  }) {
    if (calm) {
      return HeartBurst(
        origin: origin,
        bornAt: bornAt,
        tilt: 0,
        sparks: const [],
        calm: true,
      );
    }
    final count = 6 + random.nextInt(3);
    final spacing = 2 * math.pi / count;
    final turn = random.nextDouble() * spacing;
    return HeartBurst(
      origin: origin,
      bornAt: bornAt,
      tilt: (random.nextDouble() * 2 - 1) * MotionValues.heartMaxTilt,
      sparks: [
        for (var i = 0; i < count; i++)
          HeartSpark(
            // Evenly spread, each nudged by up to a quarter of the spacing.
            direction: Offset.fromDirection(
              turn + spacing * (i + (random.nextDouble() - 0.5) / 2),
            ),
            reach: 0.75 + random.nextDouble() * 0.25,
            size: 0.14 + random.nextDouble() * 0.08,
          ),
      ],
    );
  }

  /// Width of a heart at full size, in logical pixels.
  static const double size = 96;

  /// How far from the heart's centre the sparks set off, in logical pixels.
  static const double _sparkStart = size * 0.3;

  // Every heart pops from zero at rest, so one simulation serves them all.
  static final SpringSimulation _pop = SpringSimulation(
    MotionSprings.heartPop,
    0,
    1,
    0,
    snapToEnd: true,
  );

  /// Where the finger landed, in the layer's coordinates.
  final Offset origin;

  /// When the heart appeared, on the layer's clock.
  final Duration bornAt;

  /// Its tilt, in radians.
  final double tilt;

  final List<HeartSpark> sparks;

  /// Reduced motion: no pop, tilt, drift or sparks.
  final bool calm;

  /// Whether the heart has faded out completely by [now].
  bool isDoneAt(Duration now) => now - bornAt >= MotionDurations.heartLifetime;

  /// The heart at [now].
  ParticlePose heartAt(Duration now) {
    final age = now - bornAt;
    final leaving = _progress(
      age - (MotionDurations.heartLifetime - MotionDurations.heartFade),
      MotionDurations.heartFade,
    );
    if (calm) {
      final arriving = _progress(age, MotionDurations.reducedMotionFade);
      return (
        center: origin,
        scale: 1,
        rotation: 0,
        opacity: math.min(arriving, 1 - leaving),
      );
    }
    final away = MotionCurves.exit.transform(leaving);
    return (
      center: origin.translate(0, -MotionValues.heartDrift * away),
      scale: _pop.x(age.inMicroseconds / Duration.microsecondsPerSecond),
      rotation: tilt,
      opacity: 1 - away,
    );
  }

  /// [spark], one of [sparks], at [now].
  ParticlePose sparkAt(HeartSpark spark, Duration now) {
    final flight = _progress(now - bornAt, MotionDurations.heartSparks);
    final distance =
        _sparkStart +
        MotionValues.heartSparkTravel *
            spark.reach *
            MotionCurves.enter.transform(flight);
    return (
      center: origin + spark.direction * distance,
      scale: spark.size * (1 - flight / 2),
      rotation: tilt,
      opacity: 1 - MotionCurves.exit.transform(flight),
    );
  }

  /// How far [elapsed] is through [span], from 0 to 1.
  static double _progress(Duration elapsed, Duration span) =>
      (elapsed.inMicroseconds / span.inMicroseconds).clamp(0.0, 1.0);
}
