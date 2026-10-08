import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';

/// Page snapping for the feed, using [MotionSprings.pageSnap]: stiffer than
/// Flutter's default page spring and critically damped, so a swipe lands
/// fast and never peeks past the page edge.
///
/// PageView wraps the physics it is given in its own [PageScrollPhysics].
/// That one asks its parent for the spring, so overriding [spring] here is
/// enough to retune every page settle.
class FeedPageScrollPhysics extends PageScrollPhysics {
  const FeedPageScrollPhysics({super.parent});

  @override
  FeedPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      FeedPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => MotionSprings.pageSnap;
}
