import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/paywall_motion.dart';

void main() {
  group('pageVisibility', () {
    test('is 1 on the page, 0 a page or more away, linear between', () {
      expect(pageVisibility(page: 8, index: 8), 1);
      expect(pageVisibility(page: 7.75, index: 8), 0.75);
      expect(pageVisibility(page: 8.5, index: 8), 0.5);
      expect(pageVisibility(page: 7, index: 8), 0);
      expect(pageVisibility(page: 2, index: 8), 0);
    });
  });

  group('peekProgress', () {
    test('follows visibility up to the peek share', () {
      expect(peekProgress(0), 0);
      expect(peekProgress(0.5), MotionValues.paywallPeek / 2);
      expect(peekProgress(1), MotionValues.paywallPeek);
      expect(peekProgress(4), MotionValues.paywallPeek);
    });
  });

  group('ctaSweep', () {
    test('crosses the button during the first 30% of the period', () {
      expect(ctaSweep(0), 0);
      expect(ctaSweep(0.15), moreOrLessEquals(0.5, epsilon: 0.01));
      expect(ctaSweep(0.2999), moreOrLessEquals(1, epsilon: 0.01));
    });

    test('only moves forward while sweeping', () {
      var previous = -1.0;
      for (var cycle = 0.0; cycle < 0.3; cycle += 0.01) {
        final sweep = ctaSweep(cycle)!;
        expect(sweep, greaterThanOrEqualTo(previous));
        previous = sweep;
      }
    });

    test('rests for the remaining 70%', () {
      for (final cycle in [0.3, 0.5, 0.99]) {
        expect(ctaSweep(cycle), isNull, reason: '$cycle');
      }
    });
  });

  group('stagger', () {
    test('starts each item 60 ms after the previous, for 300 ms', () {
      const count = 4;
      final total = staggerDuration(count).inMilliseconds;
      expect(total, 3 * 60 + 300);

      for (var index = 0; index < count; index++) {
        final interval = staggerInterval(index, count: count);
        expect(
          interval.begin * total,
          moreOrLessEquals(index * 60.0, epsilon: 1e-6),
        );
        expect(
          (interval.end - interval.begin) * total,
          moreOrLessEquals(300, epsilon: 1e-6),
        );
      }
      expect(staggerInterval(count - 1, count: count).end, 1);
    });
  });
}
