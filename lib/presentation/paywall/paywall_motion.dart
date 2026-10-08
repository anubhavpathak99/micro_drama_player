import 'package:flutter/animation.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// How much of the page at [index] is on screen while the feed sits at
/// [page] (a fractional page index): 1 when it fills the screen, 0 when it is
/// a full page or more away.
double pageVisibility({required double page, required int index}) =>
    (1 - (index - page).abs()).clamp(0.0, 1.0);

/// Position of the paywall card while its page scrolls in: it follows the
/// page's [visibility] up to [MotionValues.paywallPeek], where the entrance
/// spring takes over.
double peekProgress(double visibility) =>
    MotionValues.paywallPeek * visibility.clamp(0.0, 1.0);

/// Where the Unlock button's highlight is, [cycle] of the way through one
/// shimmer period: crossing from 0 to 1 during the sweep at the start of the
/// period, and null (parked, invisible) for the rest of it.
double? ctaSweep(double cycle) {
  final sweepEnd =
      MotionDurations.ctaShimmerSweep.inMicroseconds /
      MotionDurations.ctaShimmerInterval.inMicroseconds;
  if (cycle < 0 || cycle >= sweepEnd) return null;
  return Interval(0, sweepEnd, curve: MotionCurves.sweep).transform(cycle);
}

/// Length of a staggered entrance of [count] items: each starts
/// [MotionDurations.staggerStep] after the previous one and takes
/// [MotionDurations.staggerItem].
Duration staggerDuration(int count) =>
    MotionDurations.staggerStep * (count - 1) + MotionDurations.staggerItem;

/// The part of a [staggerDuration] animation in which item [index] of
/// [count] fades in and rises.
Interval staggerInterval(int index, {required int count}) {
  final total = staggerDuration(count).inMicroseconds;
  final start = MotionDurations.staggerStep * index;
  final end = start + MotionDurations.staggerItem;
  return Interval(
    start.inMicroseconds / total,
    end.inMicroseconds / total,
    curve: MotionCurves.enter,
  );
}
