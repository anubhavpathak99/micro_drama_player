import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';

import '../support/episode_fixtures.dart';
import '../support/fake_video.dart';

const String firstSlot = 'ad-after-3';
const String secondSlot = 'ad-after-6';

/// Stands in for the page view: records moves and, like the real one,
/// reports the page it lands on through setCurrent.
class FakePager implements FeedPager {
  FakePager(this.container);

  final ProviderContainer container;
  final List<String> moves = [];
  bool scrolling = false;

  /// False simulates a move the user interrupted before it landed.
  bool followsMoves = true;

  @override
  bool get isScrolling => scrolling;

  @override
  Future<void> animateToPage(int index) async {
    moves.add('animate $index');
    if (followsMoves) _report(index);
  }

  @override
  void jumpToPage(int index) {
    moves.add('jump $index');
    _report(index);
  }

  void _report(int index) {
    final feed = container.read(feedControllerProvider).value!;
    container
        .read(feedControllerProvider.notifier)
        .setCurrent(feed.items[index].id);
  }
}

ProviderContainer containerWith(List<Episode> episodes) =>
    ProviderContainer.test(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(episodes),
        ),
      ],
    );

void main() {
  group('FeedController', () {
    test('composes the catalog and starts on the first page', () async {
      final container = containerWith(fakeEpisodes());

      final feed = await container.read(feedControllerProvider.future);

      expect(feed.items, hasLength(12));
      expect(feed.items[3].id, 'ad-after-3');
      expect(feed.currentId, 'ep-01');
    });

    test('moves to a known page and ignores unknown ids', () async {
      final container = containerWith(fakeEpisodes());
      await container.read(feedControllerProvider.future);
      final controller = container.read(feedControllerProvider.notifier);

      controller.setCurrent('ad-after-3');
      expect(
        container.read(feedControllerProvider).value!.currentId,
        'ad-after-3',
      );

      controller.setCurrent('missing');
      expect(
        container.read(feedControllerProvider).value!.currentId,
        'ad-after-3',
      );
    });

    test('treats an empty catalog as an error', () async {
      final container = containerWith(const []);

      await expectLater(
        container.read(feedControllerProvider.future),
        throwsA(anything),
      );
      expect(container.read(feedControllerProvider).error, isA<StateError>());
    });
  });

  group('FeedState', () {
    // E1 E2 E3 AD E4 …: E4 sits at index 4.
    final feed = FeedState(
      items: composeFeed(fakeEpisodes()),
      currentId: 'ep-04',
    );

    test('looks pages up by id', () {
      expect(feed.indexOf('ep-04'), 4);
      expect(feed.indexOf('missing'), -1);
      expect(feed.currentIndex, 4);
      expect(feed.current.id, 'ep-04');
    });

    test('finds episodes by id, but not ad slots', () {
      expect(feed.episodeById('ep-04')?.number, 4);
      expect(feed.episodeById('ad-after-3'), isNull);
      expect(feed.episodeById('missing'), isNull);
    });

    test('changes the current page without touching the items', () {
      final moved = feed.withCurrent('ep-05');

      expect(moved.currentId, 'ep-05');
      expect(moved.items, same(feed.items));
    });
  });

  group('FeedController ad no-fill', () {
    Future<(ProviderContainer, FakePager)> feedAt(String currentId) async {
      final container = containerWith(fakeEpisodes());
      await container.read(feedControllerProvider.future);
      final controller = container.read(feedControllerProvider.notifier)
        ..setCurrent(currentId);
      final pager = FakePager(container);
      controller.attachPager(pager);
      return (container, pager);
    }

    FeedState feedOf(ProviderContainer container) =>
        container.read(feedControllerProvider).value!;

    test('a slot more than a page ahead is simply recomposed away', () async {
      final (container, pager) = await feedAt('ep-01');

      container
          .read(feedControllerProvider.notifier)
          .onAdSlotFailed(secondSlot);
      await pumpEventQueue();

      expect(feedOf(container).indexOf(secondSlot), -1);
      expect(feedOf(container).currentId, 'ep-01');
      expect(pager.moves, isEmpty);
    });

    test('the next slot is recomposed away too while the feed rests', () async {
      final (container, pager) = await feedAt('ep-03');

      container.read(feedControllerProvider.notifier).onAdSlotFailed(firstSlot);
      await pumpEventQueue();

      expect(feedOf(container).indexOf(firstSlot), -1);
      expect(feedOf(container).currentIndex, 2);
      expect(pager.moves, isEmpty);
    });

    test(
      'on the slot: moves to the next page, then removes it behind',
      () async {
        final (container, pager) = await feedAt(firstSlot);

        container
            .read(feedControllerProvider.notifier)
            .onAdSlotFailed(firstSlot);
        await pumpEventQueue();

        // Animate onto E4 (page 4), then remove the slot and step back to page
        // 3, where E4 now sits: the screen doesn't move.
        expect(pager.moves, ['animate 4', 'jump 3']);
        expect(feedOf(container).indexOf(firstSlot), -1);
        expect(feedOf(container).currentId, 'ep-04');
        expect(feedOf(container).currentIndex, 3);
      },
    );

    test(
      'a slot behind is removed with a jump back in the same step',
      () async {
        final (container, pager) = await feedAt('ep-05');

        container
            .read(feedControllerProvider.notifier)
            .onAdSlotFailed(firstSlot);
        await pumpEventQueue();

        expect(pager.moves, ['jump 4']);
        expect(feedOf(container).currentId, 'ep-05');
        expect(feedOf(container).currentIndex, 4);
      },
    );

    test('waits for the feed to stop before removing anything', () async {
      final (container, pager) = await feedAt('ep-05');
      final controller = container.read(feedControllerProvider.notifier);
      pager.scrolling = true;

      controller.onAdSlotFailed(firstSlot);
      await pumpEventQueue();
      expect(feedOf(container).indexOf(firstSlot), 3);

      pager.scrolling = false;
      controller.onSettled();
      await pumpEventQueue();
      expect(feedOf(container).indexOf(firstSlot), -1);
      expect(pager.moves, ['jump 4']);
    });

    test('stops if the move off the slot is interrupted', () async {
      final (container, pager) = await feedAt(firstSlot);
      pager.followsMoves = false;

      container.read(feedControllerProvider.notifier).onAdSlotFailed(firstSlot);
      await pumpEventQueue();

      expect(pager.moves, ['animate 4']);
      expect(feedOf(container).indexOf(firstSlot), 3, reason: 'retried later');
    });

    test('without a page view the next page takes the slot\'s place', () async {
      final container = containerWith(fakeEpisodes());
      await container.read(feedControllerProvider.future);
      final controller = container.read(feedControllerProvider.notifier)
        ..setCurrent(firstSlot);

      controller.onAdSlotFailed(firstSlot);
      await pumpEventQueue();

      expect(feedOf(container).currentId, 'ep-04');
    });
  });
}
