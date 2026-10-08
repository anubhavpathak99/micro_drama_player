import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/heart_burst.dart';

const Offset tapped = Offset(120, 300);

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

HeartBurst burst({int seed = 1, Duration bornAt = Duration.zero}) =>
    HeartBurst.random(tapped, bornAt: bornAt, random: math.Random(seed));

void main() {
  group('the heart', () {
    test('pops past full size to 1.2× and settles before it drifts', () {
      final heart = burst();
      var peak = 0.0;
      var peakAt = 0;
      for (var at = 0; at <= 400; at++) {
        final scale = heart.heartAt(ms(at)).scale;
        if (scale > peak) {
          peak = scale;
          peakAt = at;
        }
      }

      expect(heart.heartAt(Duration.zero).scale, 0);
      expect(peak, moreOrLessEquals(1.2, epsilon: 0.01));
      expect(peakAt, inInclusiveRange(110, 160));
      expect(heart.heartAt(ms(400)).scale, moreOrLessEquals(1, epsilon: 0.015));
    });

    test('sits where the finger landed until it starts to leave', () {
      final heart = burst();

      for (final at in [0, 150, 400]) {
        final pose = heart.heartAt(ms(at));
        expect(pose.center, tapped);
        expect(pose.opacity, 1);
      }
    });

    test('drifts up 60 px and fades out over its last 500 ms', () {
      final heart = burst();

      final halfway = heart.heartAt(ms(650));
      expect(halfway.center.dx, tapped.dx);
      expect(halfway.center.dy, lessThan(tapped.dy));
      expect(halfway.center.dy, greaterThan(tapped.dy - 60));
      expect(halfway.opacity, inExclusiveRange(0, 1));

      final gone = heart.heartAt(MotionDurations.heartLifetime);
      expect(gone.center, tapped.translate(0, -MotionValues.heartDrift));
      expect(gone.opacity, 0);
      expect(gone.scale, 1);
    });

    test('is done after its 900 ms lifetime, counted from its birth', () {
      final heart = burst(bornAt: const Duration(seconds: 5));

      expect(heart.heartAt(const Duration(seconds: 5)).scale, 0);
      expect(heart.isDoneAt(ms(5899)), isFalse);
      expect(heart.isDoneAt(ms(5900)), isTrue);
    });

    test('tilts up to 15° either way, differently each time', () {
      final tilts = [
        for (var seed = 0; seed < 50; seed++) burst(seed: seed).tilt,
      ];

      for (final tilt in tilts) {
        expect(tilt.abs(), lessThanOrEqualTo(MotionValues.heartMaxTilt));
      }
      expect(tilts.any((tilt) => tilt < -0.1), isTrue);
      expect(tilts.any((tilt) => tilt > 0.1), isTrue);
      expect(burst().heartAt(ms(200)).rotation, burst().tilt);
    });
  });

  group('the sparks', () {
    test('are 6 to 8 small hearts spread all around', () {
      final counts = <int>{};
      for (var seed = 0; seed < 50; seed++) {
        final sparks = burst(seed: seed).sparks;
        counts.add(sparks.length);

        final angles = [for (final spark in sparks) spark.direction.direction]
          ..sort();
        final gaps = [
          for (var i = 1; i < angles.length; i++) angles[i] - angles[i - 1],
          angles.first + 2 * math.pi - angles.last,
        ];
        final even = 2 * math.pi / sparks.length;
        for (final gap in gaps) {
          expect(gap, inInclusiveRange(even / 2, even * 1.5));
        }
        for (final spark in sparks) {
          expect(spark.direction.distance, moreOrLessEquals(1));
          expect(spark.size, lessThan(0.25));
        }
      }

      expect(counts, {6, 7, 8});
    });

    test('fly out from the heart and fade by 450 ms', () {
      final heart = burst();

      for (final spark in heart.sparks) {
        final launch = heart.sparkAt(spark, Duration.zero);
        final midway = heart.sparkAt(spark, ms(200));
        final landed = heart.sparkAt(spark, MotionDurations.heartSparks);

        double distance(Offset at) => (at - tapped).distance;
        expect(distance(launch.center), lessThan(HeartBurst.size / 2));
        expect(distance(midway.center), greaterThan(distance(launch.center)));
        expect(
          distance(landed.center) - distance(launch.center),
          moreOrLessEquals(MotionValues.heartSparkTravel * spark.reach),
        );
        expect(launch.opacity, 1);
        expect(landed.opacity, 0);
        expect(landed.scale, lessThan(launch.scale));
      }
    });
  });

  group('a calm heart, for reduced motion', () {
    HeartBurst calm() => HeartBurst.random(
      tapped,
      bornAt: Duration.zero,
      random: math.Random(1),
      calm: true,
    );

    test('has no tilt and no sparks', () {
      expect(calm().tilt, 0);
      expect(calm().sparks, isEmpty);
    });

    test('only fades in and out, full size, where it landed', () {
      final heart = calm();

      for (final at in [0, 75, 150, 500, 700, 900]) {
        final pose = heart.heartAt(ms(at));
        expect(pose.center, tapped);
        expect(pose.scale, 1);
        expect(pose.rotation, 0);
      }
      expect(heart.heartAt(Duration.zero).opacity, 0);
      expect(heart.heartAt(ms(75)).opacity, inExclusiveRange(0, 1));
      expect(heart.heartAt(MotionDurations.reducedMotionFade).opacity, 1);
      expect(heart.heartAt(MotionDurations.heartLifetime).opacity, 0);
    });
  });
}
