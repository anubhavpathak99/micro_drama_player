import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

/// The composed feed and the page on screen.
///
/// The current page is tracked by id. Indices are derived on demand, so they
/// can never go stale when the feed changes shape.
@immutable
final class FeedState {
  FeedState({required this.items, required this.currentId})
    : _indexById = {for (final (index, item) in items.indexed) item.id: index} {
    assert(_indexById.containsKey(currentId), 'Unknown current id $currentId');
  }

  const FeedState._(this.items, this.currentId, this._indexById);

  final List<FeedItem> items;
  final String currentId;
  final Map<String, int> _indexById;

  /// Position of [id] in [items], or -1 when it isn't in the feed.
  int indexOf(String id) => _indexById[id] ?? -1;

  int get currentIndex => _indexById[currentId]!;

  FeedItem get current => items[currentIndex];

  /// The episode with [id], or null for ad slots and unknown ids.
  Episode? episodeById(String id) => switch (_indexById[id]) {
    final int index => switch (items[index]) {
      EpisodeItem(:final episode) => episode,
      AdSlotItem() => null,
    },
    null => null,
  };

  FeedState withCurrent(String id) => FeedState._(items, id, _indexById);
}

/// Loads the catalog, composes the feed, and tracks the page on screen.
class FeedController extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final episodes = await ref.watch(episodeRepositoryProvider).fetchEpisodes();
    final items = composeFeed(episodes);
    if (items.isEmpty) throw StateError('The episode catalog is empty');
    return FeedState(items: items, currentId: items.first.id);
  }

  /// Marks the page with [id] as the one on screen. Unknown ids are ignored.
  void setCurrent(String id) {
    final feed = state.value;
    if (feed == null || feed.currentId == id || feed.indexOf(id) < 0) return;
    state = AsyncData(feed.withCurrent(id));
  }
}

final AsyncNotifierProvider<FeedController, FeedState> feedControllerProvider =
    AsyncNotifierProvider(FeedController.new);
