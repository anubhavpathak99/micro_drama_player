import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

/// Builds the feed from [episodes], which must already be in playback order.
///
/// An ad break follows every [adEvery]-th episode, provided the episode after
/// the break is numbered at most [maxAdsBeforeEpisode]. The feed never ends
/// on an ad. With the defaults, ten episodes give:
///
/// `E1 E2 E3 AD E4 E5 E6 AD E7 E8 E9 E10`
///
/// A slot whose state in [adStates] is [AdSlotState.failed] is left out, so
/// a no-fill closes its gap. Ids come from content, not position, so an item
/// that stays in the feed keeps its id across recompositions.
List<FeedItem> composeFeed(
  List<Episode> episodes, {
  Map<String, AdSlotState> adStates = const {},
  int adEvery = 3,
  int maxAdsBeforeEpisode = 7,
}) {
  if (adEvery < 1) {
    throw ArgumentError.value(adEvery, 'adEvery', 'must be at least 1');
  }

  final feed = <FeedItem>[];
  for (final (index, episode) in episodes.indexed) {
    feed.add(EpisodeItem(episode));

    final next = index + 1 < episodes.length ? episodes[index + 1] : null;
    final breakDue =
        episode.number % adEvery == 0 &&
        next != null &&
        next.number <= maxAdsBeforeEpisode;
    if (!breakDue) continue;

    final slot = AdSlotItem.after(episode.number);
    if (adStates[slot.slotId] != AdSlotState.failed) feed.add(slot);
  }

  assert(
    feed.map((item) => item.id).toSet().length == feed.length,
    'Feed ids must be unique: $feed',
  );
  return List.unmodifiable(feed);
}
