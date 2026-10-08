import 'package:flutter/animation.dart';

// Motion design tokens. Every spring, curve and duration in the app is defined
// here, so the motion language stays consistent and is tuned in one place.

/// Springs for motion that follows or answers a gesture.
///
/// A spring continues from the gesture's velocity instead of restarting a
/// fixed timeline, which is what makes interrupted motion feel physical.
/// Presets use SwiftUI's model: a perceptual duration plus a bounce from 0
/// (no overshoot) towards 1 (springier).
abstract final class MotionSprings {
  /// Quick, with no visible overshoot. For controls that track a finger: the
  /// expanding scrub bar, the time bubble, page settling.
  static final SpringDescription snappy =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 300),
        bounce: 0.15,
      );

  /// Visible overshoot for moments of delight: the double-tap heart and the
  /// paywall card's entrance.
  static final SpringDescription bouncy =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 500),
        bounce: 0.4,
      );

  /// Slow and soft, never overshoots. For large surfaces such as overlays.
  static final SpringDescription gentle =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 600),
      );
}

/// Easing for fixed-timeline animations: fades, crossfades and sweeps.
abstract final class MotionCurves {
  /// Elements entering: fast start, long soft landing.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);

  /// Elements leaving: gentle start, quick finish.
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Elements changing in place.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Opacity-only changes.
  static const Curve fade = Curves.easeOut;

  /// A highlight travelling across a surface (skeleton and CTA shimmer).
  static const Curve sweep = Curves.easeInOutSine;
}

/// Durations for fixed-timeline animations.
abstract final class MotionDurations {
  /// Press feedback and other micro-interactions.
  static const Duration instant = Duration(milliseconds: 100);

  /// Small elements appearing or disappearing, such as the time bubble.
  static const Duration fast = Duration(milliseconds: 150);

  /// Component-level changes, such as the play/pause glyph.
  static const Duration medium = Duration(milliseconds: 250);

  /// Large surfaces: overlays and scrims.
  static const Duration slow = Duration(milliseconds: 400);

  /// Poster-to-video crossfade once the first frame is ready.
  static const Duration posterCrossfade = Duration(milliseconds: 200);

  /// Whole life of a double-tap heart, from pop to fully faded.
  static const Duration heartLifetime = Duration(milliseconds: 900);

  /// One pass of the skeleton shimmer.
  static const Duration skeletonShimmer = Duration(milliseconds: 1400);

  /// One sweep of the highlight across the Unlock button.
  static const Duration ctaShimmerSweep = Duration(milliseconds: 900);

  /// Start-to-start time between two Unlock button sweeps.
  static const Duration ctaShimmerInterval = Duration(seconds: 3);

  /// Crossfade that replaces movement when the OS asks for reduced motion.
  static const Duration reducedMotionFade = Duration(milliseconds: 150);
}
