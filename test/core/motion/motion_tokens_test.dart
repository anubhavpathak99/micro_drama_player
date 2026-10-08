import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// Peak and 1 % settle time of a spring moving from 0 to 1, released at rest.
({double peak, Duration settle}) profile(SpringDescription spring) {
  final simulation = SpringSimulation(spring, 0, 1, 0);
  var peak = 0.0;
  var lastOutsideMs = 0;
  for (var ms = 0; ms <= 3000; ms++) {
    final x = simulation.x(ms / 1000);
    if (x > peak) peak = x;
    if ((x - 1).abs() > 0.01) lastOutsideMs = ms;
  }
  return (peak: peak, settle: Duration(milliseconds: lastOutsideMs));
}

void main() {
  group('MotionSprings', () {
    final snappy = profile(MotionSprings.snappy);
    final bouncy = profile(MotionSprings.bouncy);
    final gentle = profile(MotionSprings.gentle);

    test('snappy settles first, without visible overshoot', () {
      expect(snappy.peak, lessThan(1.01));
      expect(snappy.settle, lessThan(bouncy.settle));
      expect(snappy.settle, lessThan(gentle.settle));
    });

    test('bouncy overshoots visibly but not wildly', () {
      expect(bouncy.peak, inInclusiveRange(1.05, 1.2));
    });

    test('gentle never overshoots', () {
      expect(gentle.peak, lessThanOrEqualTo(1 + 1e-6));
    });

    test('every spring settles within a second', () {
      for (final spring in [snappy, bouncy, gentle]) {
        expect(spring.settle, lessThan(const Duration(seconds: 1)));
      }
    });

    test("pageSnap settles faster than Flutter's page spring, never past "
        'the edge', () {
      final pageSnap = profile(MotionSprings.pageSnap);
      // PageScrollPhysics' default spring.
      final flutterDefault = profile(
        SpringDescription.withDampingRatio(
          mass: 0.5,
          stiffness: 100,
          ratio: 1.1,
        ),
      );

      expect(pageSnap.peak, lessThanOrEqualTo(1 + 1e-6));
      expect(pageSnap.settle, lessThan(flutterDefault.settle));
    });
  });

  group('MotionDurations', () {
    test('a CTA sweep finishes before the next one starts', () {
      expect(
        MotionDurations.ctaShimmerSweep,
        lessThan(MotionDurations.ctaShimmerInterval),
      );
    });

    test('the skeleton waits, then holds long enough not to blink', () {
      expect(MotionDurations.skeletonDelay, const Duration(milliseconds: 150));
      expect(
        MotionDurations.skeletonMinimum,
        greaterThan(MotionDurations.fast),
      );
    });
  });
}
