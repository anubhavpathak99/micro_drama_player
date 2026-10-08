import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_scroll_physics.dart';
import 'package:micro_drama_interactive_player/presentation/feed/paywall_lock_physics.dart';

const double viewport = 800;
const int lockedPage = 8;
const double limit = lockedPage * viewport;

/// Synthetic metrics for a feed of twelve full-screen pages.
ScrollMetrics metricsAt(double pixels) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: viewport * 11,
  pixels: pixels,
  viewportDimension: viewport,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 3,
);

void main() {
  // Stacked the way the feed builds it: the lock on top of the feed paging.
  final physics = const PaywallLockPhysics(lockedPage: lockedPage)
      .applyTo(const FeedPageScrollPhysics(parent: ClampingScrollPhysics()));

  double overscrollFor(double from, double to) =>
      physics.applyBoundaryConditions(metricsAt(from), to);

  double? settlesAt(double from, double velocity) =>
      physics.createBallisticSimulation(metricsAt(from), velocity)?.x(10);

  group('PaywallLockPhysics drags', () {
    test('clamps forward movement past the locked page', () {
      expect(overscrollFor(limit - 300, limit + 200), 200);
    });

    test('allows no forward movement from the locked page', () {
      expect(overscrollFor(limit, limit + 50), 50);
    });

    test('lets forward movement up to the locked page through', () {
      expect(overscrollFor(limit - 300, limit), 0);
    });

    test('leaves backward movement free', () {
      expect(overscrollFor(limit, limit - 500), 0);
      expect(overscrollFor(limit - 300, 0), 0);
    });

    test('keeps the parent clamping at the start of the feed', () {
      expect(overscrollFor(0, -40), -40);
    });
  });

  group('PaywallLockPhysics flings', () {
    test('a fling from the page before lands on the locked page', () {
      expect(
        settlesAt(limit - viewport, 2000),
        moreOrLessEquals(limit, epsilon: 0.5),
      );
    });

    test('even the fastest fling never passes the locked page', () {
      final simulation = physics.createBallisticSimulation(
        metricsAt(limit - viewport * 0.4),
        8000,
      )!;

      for (var t = 0.0; t < 3; t += 0.002) {
        expect(simulation.x(t), lessThanOrEqualTo(limit + 0.5));
      }
      expect(simulation.x(10), moreOrLessEquals(limit, epsilon: 0.5));
    });

    test('a forward fling from the locked page goes nowhere', () {
      expect(settlesAt(limit, 3000) ?? limit, moreOrLessEquals(limit));
    });

    test('a backward fling from the locked page leaves it', () {
      expect(
        settlesAt(limit - viewport * 0.2, -1500),
        moreOrLessEquals(limit - viewport, epsilon: 0.5),
      );
    });

    test('pages normally before the lock', () {
      expect(
        settlesAt(viewport * 2.2, 1500),
        moreOrLessEquals(viewport * 3, epsilon: 0.5),
      );
    });
  });

  group('PaywallLockPhysics composition', () {
    test('applyTo keeps the locked page and stacks the ancestor beneath', () {
      final applied = const PaywallLockPhysics(lockedPage: 3)
          .applyTo(const ClampingScrollPhysics());

      expect(applied.lockedPage, 3);
      expect(applied.parent, isA<ClampingScrollPhysics>());
    });

    test("settles with its parent's snap spring", () {
      expect(physics.spring, same(MotionSprings.pageSnap));
    });

    test('measures the lock in pages of the live viewport', () {
      expect(physics.maxPageExtent(metricsAt(0)), limit);
      expect(
        physics.maxPageExtent(
          PageMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 4000,
            pixels: 0,
            viewportDimension: 1000,
            axisDirection: AxisDirection.down,
            viewportFraction: 0.5,
            devicePixelRatio: 3,
          ),
        ),
        lockedPage * 500,
      );
    });
  });
}
