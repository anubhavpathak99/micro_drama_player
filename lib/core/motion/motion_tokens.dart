import 'dart:math' as math;

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
  /// expanding scrub bar, the time bubble, the play/pause glyph leaving.
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

  /// Feed page settling after a swipe. Stiffer than Flutter's default page
  /// spring and critically damped, so a page lands fast and never peeks past
  /// its edge.
  static final SpringDescription pageSnap =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 280),
      );

  /// A double-tap heart popping in: from nothing to 1.2× at about 135 ms,
  /// settled at full size by 400 ms, when it starts to drift away.
  static final SpringDescription heartPop =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 240),
        bounce: 0.544,
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

  /// A heart drifting up while it fades out: the last part of its life.
  static const Duration heartFade = Duration(milliseconds: 500);

  /// The small hearts bursting out of a new heart, from launch to gone.
  static const Duration heartSparks = Duration(milliseconds: 450);

  /// One pass of the skeleton shimmer.
  static const Duration skeletonShimmer = Duration(milliseconds: 1400);

  /// How long a wait must last before the skeleton appears. Shorter waits
  /// show nothing, so the skeleton never flashes.
  static const Duration skeletonDelay = Duration(milliseconds: 150);

  /// Once shown, the skeleton stays at least this long, so a wait that ends
  /// just after it appeared doesn't blink.
  static const Duration skeletonMinimum = Duration(milliseconds: 300);

  /// One sweep of the highlight across the Unlock button.
  static const Duration ctaShimmerSweep = Duration(milliseconds: 900);

  /// Start-to-start time between two Unlock button sweeps.
  static const Duration ctaShimmerInterval = Duration(seconds: 3);

  /// Delay between consecutive items of a staggered entrance.
  static const Duration staggerStep = Duration(milliseconds: 60);

  /// How long each staggered item takes to fade in and rise.
  static const Duration staggerItem = Duration(milliseconds: 300);

  /// One full turn of the Unlock button's spinner.
  static const Duration spinnerTurn = Duration(milliseconds: 900);

  /// Drawing the checkmark once an unlock succeeds.
  static const Duration checkmarkDraw = Duration(milliseconds: 280);

  /// How long the checkmark holds before the paywall card leaves.
  static const Duration unlockCelebration = Duration(milliseconds: 520);

  /// The paywall card dropping away while the blur clears.
  static const Duration paywallDismiss = Duration(milliseconds: 320);

  /// An unfilled ad page's skeleton fading out before the feed moves on.
  static const Duration adNoFillFade = Duration(milliseconds: 180);

  /// The feed moving off an unfilled ad page to the next one.
  static const Duration adNoFillSkip = Duration(milliseconds: 360);

  /// Crossfade that replaces movement when the OS asks for reduced motion.
  static const Duration reducedMotionFade = Duration(milliseconds: 150);
}

/// Thresholds used to read gestures: fling or stop, single or double tap.
abstract final class MotionGestures {
  /// A second tap that lands within this long of the first one lifting is
  /// a double tap. A single tap waits this long before it counts.
  static const Duration doubleTapWindow = Duration(milliseconds: 280);

  /// The farthest a double tap's second tap may land from its first, in
  /// logical pixels.
  static const double doubleTapSlop = 40;

  /// A finger that rests this long before lifting has stopped, so its lift
  /// is not a fling. The same threshold as Flutter's own velocity tracker.
  static const Duration stillBeforeLift = Duration(milliseconds: 40);

  /// How far back a fling's velocity is measured from the last touch
  /// sample. The same window as Flutter's own velocity tracker.
  static const Duration flingWindow = Duration(milliseconds: 100);
}

/// Distances, scales and strengths that animations move between.
abstract final class MotionValues {
  /// Backdrop blur behind the paywall card, at full strength.
  static const double paywallBlurSigma = 20;

  /// Share of the paywall card already showing when its page has scrolled
  /// fully into view, before the entrance spring takes over.
  static const double paywallPeek = 0.3;

  /// How far a staggered item rises while it fades in, in logical pixels.
  static const double staggerRise = 12;

  /// Scale of a button held down.
  static const double pressScale = 0.95;

  /// How far a double-tap heart rises while it fades, in logical pixels.
  static const double heartDrift = 60;

  /// The most a double-tap heart tilts either way, in radians (15°).
  static const double heartMaxTilt = 15 * math.pi / 180;

  /// How far the small hearts of a burst fly, in logical pixels.
  static const double heartSparkTravel = 56;
}
