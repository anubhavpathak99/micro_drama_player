import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
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

/// What the feed controller needs from the page view: a seam over its
/// PageController, so removals can keep the page on screen still and tests
/// can stand in a fake.
abstract interface class FeedPager {
  /// Whether a drag, fling or animation is moving the feed.
  bool get isScrolling;

  /// Animates to page [index]. Reports the new page through the usual page
  /// change, and completes when the move ends or is interrupted.
  Future<void> animateToPage(int index);

  /// Moves to page [index] at once, within the current frame.
  void jumpToPage(int index);
}

/// Loads the catalog, composes the feed, tracks the page on screen, and
/// removes ad slots that could not be filled without a visible jump.
class FeedController extends AsyncNotifier<FeedState> {
  List<Episode> _episodes = const [];
  final Set<String> _removedSlots = {};
  final Set<String> _failedSlots = {};
  FeedPager? _pager;
  bool _removing = false;

  @override
  Future<FeedState> build() async {
    _episodes = await ref.watch(episodeRepositoryProvider).fetchEpisodes();
    final items = _compose();
    if (items.isEmpty) throw StateError('The episode catalog is empty');
    return FeedState(items: items, currentId: items.first.id);
  }

  /// Marks the page with [id] as the one on screen. Unknown ids are ignored.
  void setCurrent(String id) {
    final feed = state.value;
    if (feed == null || feed.currentId == id || feed.indexOf(id) < 0) return;
    state = AsyncData(feed.withCurrent(id));
  }

  /// Connects the page view whose pages this feed drives.
  void attachPager(FeedPager pager) => _pager = pager;

  void detachPager(FeedPager pager) {
    if (identical(_pager, pager)) _pager = null;
  }

  /// The ad slot [slotId] could not be filled: take it out of the feed. How
  /// depends on where it sits relative to the page on screen:
  ///
  /// * ahead: recompose without it; the page on screen is unaffected.
  /// * on screen: move on to the next page, then take it out behind.
  /// * behind: take it out and step the pager back one page in the same
  ///   frame, so the page on screen doesn't move.
  ///
  /// While the feed is moving, removal waits for [onSettled].
  void onAdSlotFailed(String slotId) {
    _failedSlots.add(slotId);
    unawaited(_removeFailedSlots());
  }

  /// The feed came to rest: finish removals that had to wait.
  void onSettled() => unawaited(_removeFailedSlots());

  Future<void> _removeFailedSlots() async {
    if (_removing) return;
    _removing = true;
    try {
      while (true) {
        final feed = state.value;
        final pager = _pager;
        if (feed == null || (pager?.isScrolling ?? false)) return;
        final slotId = _failedSlots
            .where((id) => feed.indexOf(id) >= 0)
            .firstOrNull;
        if (slotId == null) return;

        final slot = feed.indexOf(slotId);
        final current = feed.currentIndex;
        if (slot == current && pager != null) {
          // On the failed slot: leave it first, so it ends up behind.
          await pager.animateToPage(current + 1);
          if (state.value?.currentId == slotId) return; // Interrupted.
          continue;
        }

        _failedSlots.remove(slotId);
        _removeSlot(slotId);
        if (slot < current) pager?.jumpToPage(current - 1);
      }
    } finally {
      _removing = false;
    }
  }

  void _removeSlot(String slotId) {
    final feed = state.value!;
    _removedSlots.add(slotId);
    final items = _compose();
    // Without a pager nothing is on screen to keep still: the page after the
    // slot takes its place.
    final currentId = feed.currentId == slotId
        ? items[feed.currentIndex.clamp(0, items.length - 1)].id
        : feed.currentId;
    state = AsyncData(FeedState(items: items, currentId: currentId));
  }

  List<FeedItem> _compose() => composeFeed(
    _episodes,
    adStates: {for (final id in _removedSlots) id: AdSlotState.failed},
  );
}

final AsyncNotifierProvider<FeedController, FeedState> feedControllerProvider =
    AsyncNotifierProvider(FeedController.new);
