import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';

import '../support/episode_fixtures.dart';
import '../support/fake_video.dart';

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
}
