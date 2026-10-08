import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_scroll_physics.dart';

void main() {
  const viewport = 800.0;

  FixedScrollMetrics metricsAt(double pixels) => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: viewport * 5,
    pixels: pixels,
    viewportDimension: viewport,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 3,
  );

  // The feed turns PageView's own snapping off, so these physics snap.
  const physics = FeedPageScrollPhysics(parent: ClampingScrollPhysics());

  group('FeedPageScrollPhysics', () {
    test('snaps with the page-snap spring', () {
      expect(physics.spring, same(MotionSprings.pageSnap));
    });

    test('a flick lands exactly on the next page', () {
      final simulation = physics.createBallisticSimulation(
        metricsAt(viewport * 0.2),
        1200,
      )!;

      expect(simulation.x(5), moreOrLessEquals(viewport, epsilon: 0.5));
    });

    test('a slow release settles back on the current page', () {
      final simulation = physics.createBallisticSimulation(
        metricsAt(viewport * 0.3),
        0,
      )!;

      expect(simulation.x(5), moreOrLessEquals(0, epsilon: 0.5));
    });

    test('settles without passing the page edge', () {
      final simulation = physics.createBallisticSimulation(
        metricsAt(viewport * 0.6),
        3000,
      )!;

      for (var t = 0.0; t < 2; t += 0.004) {
        expect(simulation.x(t), lessThanOrEqualTo(viewport + 0.5));
      }
    });
  });
}
