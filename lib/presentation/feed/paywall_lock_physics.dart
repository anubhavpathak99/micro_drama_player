import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Page physics that stop the feed at a locked page.
///
/// Moving forward stops at [lockedPage]: a drag can't pull past it, and a
/// fling settles on it. Moving backward is unchanged. The snap spring and
/// the behaviour at the feed's ends come from the parent physics.
///
/// Use with `PageView(pageSnapping: false)`. With page snapping on, PageView
/// wraps the given physics in its own [PageScrollPhysics], whose flings
/// never consult [createBallisticSimulation] here.
class PaywallLockPhysics extends PageScrollPhysics {
  const PaywallLockPhysics({required this.lockedPage, super.parent});

  /// Index of the locked page: the furthest page the feed can reach.
  final int lockedPage;

  /// Scroll offset of the locked page, in pixels.
  ///
  /// Derived from the live metrics rather than stored, so it stays correct
  /// when the viewport is resized.
  double maxPageExtent(ScrollMetrics position) {
    final fraction = position is PageMetrics ? position.viewportFraction : 1.0;
    return lockedPage * position.viewportDimension * fraction;
  }

  @override
  PaywallLockPhysics applyTo(ScrollPhysics? ancestor) =>
      PaywallLockPhysics(lockedPage: lockedPage, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final limit = maxPageExtent(position);
    // Moving forward past the locked page: everything beyond it is
    // overscroll, so the position stops exactly on the locked page.
    if (value > position.pixels && value > limit) {
      return value - math.max(position.pixels, limit);
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Page as if the feed ended at the locked page: a fling towards it
    // settles on it, and a forward fling from it goes nowhere.
    final limit = maxPageExtent(position);
    return super.createBallisticSimulation(
      limit < position.maxScrollExtent
          ? position.copyWith(maxScrollExtent: limit)
          : position,
      velocity,
    );
  }
}
