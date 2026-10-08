import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

/// Ids of the episodes that should hold a video player while the page with
/// [currentId] is on screen, most urgent first: the current page, then the
/// next one, then the previous one.
///
/// Only pages next to the current one qualify, so there are never more than
/// three. Ads never get a player. Locked episodes never get one either, and
/// nothing after a locked current page is preloaded, because the paywall
/// makes it unreachable.
Set<String> playerWindow(
  List<FeedItem> items,
  String currentId, {
  required bool Function(Episode episode) isLocked,
}) {
  final current = items.indexWhere((item) => item.id == currentId);
  if (current < 0) return const {};

  final window = <String>{};
  void consider(int index) {
    if (index < 0 || index >= items.length) return;
    if (items[index] case EpisodeItem(:final episode) when !isLocked(episode)) {
      window.add(episode.id);
    }
  }

  consider(current);
  final blocksForward = switch (items[current]) {
    EpisodeItem(:final episode) => isLocked(episode),
    AdSlotItem() => false,
  };
  if (!blocksForward) consider(current + 1);
  consider(current - 1);
  return window;
}
