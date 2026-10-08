import 'package:micro_drama_interactive_player/domain/episode.dart';

/// One full-screen page of the vertical feed.
///
/// Pages are addressed by [id], never by index: an ad slot that fails to fill
/// leaves the feed and shifts every index after it, but no id changes.
sealed class FeedItem {
  const FeedItem();

  /// Feed-unique identity, used for widget keys, page lookup and resource
  /// ownership (players, ads).
  String get id;
}

/// A page that plays an [Episode].
final class EpisodeItem extends FeedItem {
  const EpisodeItem(this.episode);

  final Episode episode;

  @override
  String get id => episode.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodeItem && other.episode == episode;

  @override
  int get hashCode => episode.hashCode;

  @override
  String toString() => 'EpisodeItem(${episode.id})';
}

/// A page reserved for a full-screen ad between two episodes.
final class AdSlotItem extends FeedItem {
  const AdSlotItem({required this.slotId, required this.afterEpisode});

  /// The slot for the ad break that follows episode number [episodeNumber].
  factory AdSlotItem.after(int episodeNumber) => AdSlotItem(
    slotId: slotIdAfter(episodeNumber),
    afterEpisode: episodeNumber,
  );

  /// Id of the slot that follows episode number [episodeNumber].
  ///
  /// It depends only on that episode, so a slot keeps its id, and the ad
  /// loaded for it, every time the feed is recomposed.
  static String slotIdAfter(int episodeNumber) => 'ad-after-$episodeNumber';

  final String slotId;

  /// Number of the episode this ad break follows.
  final int afterEpisode;

  @override
  String get id => slotId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdSlotItem &&
          other.slotId == slotId &&
          other.afterEpisode == afterEpisode;

  @override
  int get hashCode => Object.hash(slotId, afterEpisode);

  @override
  String toString() => 'AdSlotItem($slotId)';
}
