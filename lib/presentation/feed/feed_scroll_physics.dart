import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// Page snapping for the feed, using [MotionSprings.pageSnap]: stiffer than
/// Flutter's default page spring and critically damped, so a swipe lands
/// fast and never peeks past the page edge.
///
/// The feed's PageView turns its own page snapping off, so these physics do
/// the snapping. Physics stacked on top, such as the paywall lock, ask their
/// parent for the spring and therefore settle with this one too.
class FeedPageScrollPhysics extends PageScrollPhysics {
  const FeedPageScrollPhysics({super.parent});

  @override
  FeedPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      FeedPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => MotionSprings.pageSnap;
}
