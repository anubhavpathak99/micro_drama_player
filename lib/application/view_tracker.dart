import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

/// Logs what the user lands on: every episode page (`episode_view`) and,
/// for a locked episode, its paywall (`paywall_shown`). Ad pages log their
/// own events.
///
/// Keep it alive by listening to it while the feed is on screen.
final Provider<void> viewTrackerProvider = Provider((ref) {
  ref.listen(feedControllerProvider.select((feed) => feed.value?.current), (
    _,
    current,
  ) {
    if (current is! EpisodeItem) return;
    final feed = ref.read(feedControllerProvider).value!;
    final locked = ref
        .read(paywallControllerProvider)
        .isLocked(current.episode);
    final analytics = ref.read(analyticsProvider)
      ..log(AnalyticsEvents.episodeView, {
        'episode': current.id,
        'position': feed.currentIndex,
        'locked': locked,
      });
    if (locked) {
      analytics.log(AnalyticsEvents.paywallShown, {'episode': current.id});
    }
  }, fireImmediately: true);
});
