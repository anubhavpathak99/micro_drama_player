import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

import '../support/episode_fixtures.dart';

/// Renders a feed as `E1 E2 E3 AD …`, so expectations read like the spec.
String shape(List<FeedItem> feed) => feed
    .map(
      (item) => switch (item) {
        EpisodeItem(:final episode) => 'E${episode.number}',
        AdSlotItem() => 'AD',
      },
    )
    .join(' ');

List<String> idsOf(List<FeedItem> feed) => [for (final item in feed) item.id];

void main() {
  final episodes = fakeEpisodes();
  final firstBreak = AdSlotItem.slotIdAfter(3);
  final secondBreak = AdSlotItem.slotIdAfter(6);

  group('composeFeed', () {
    test('puts an ad after every third episode, up to E7', () {
      final feed = composeFeed(episodes);

      expect(shape(feed), 'E1 E2 E3 AD E4 E5 E6 AD E7 E8 E9 E10');
      expect(feed.whereType<AdSlotItem>(), [
        AdSlotItem(slotId: firstBreak, afterEpisode: 3),
        AdSlotItem(slotId: secondBreak, afterEpisode: 6),
      ]);
    });

    test('omits a failed slot and keeps the other', () {
      expect(
        shape(
          composeFeed(episodes, adStates: {firstBreak: AdSlotState.failed}),
        ),
        'E1 E2 E3 E4 E5 E6 AD E7 E8 E9 E10',
      );
      expect(
        shape(
          composeFeed(episodes, adStates: {secondBreak: AdSlotState.failed}),
        ),
        'E1 E2 E3 AD E4 E5 E6 E7 E8 E9 E10',
      );
    });

    test('omits both slots when both fail', () {
      final feed = composeFeed(
        episodes,
        adStates: {
          firstBreak: AdSlotState.failed,
          secondBreak: AdSlotState.failed,
        },
      );

      expect(shape(feed), 'E1 E2 E3 E4 E5 E6 E7 E8 E9 E10');
    });

    test('keeps slots in every state other than failed', () {
      for (final state in AdSlotState.values) {
        if (state == AdSlotState.failed) continue;
        final feed = composeFeed(
          episodes,
          adStates: {firstBreak: state, secondBreak: state},
        );
        expect(
          shape(feed),
          'E1 E2 E3 AD E4 E5 E6 AD E7 E8 E9 E10',
          reason: '$state',
        );
      }
    });

    test('keeps ids stable across recomposition', () {
      final before = composeFeed(episodes);
      final after = composeFeed(
        episodes,
        adStates: {firstBreak: AdSlotState.failed},
      );
      final beforeById = {for (final item in before) item.id: item};

      // Every surviving item keeps its id and is unchanged...
      for (final item in after) {
        expect(beforeById[item.id], item, reason: item.id);
      }
      // ...and the failed slot is the only id that went away.
      expect(beforeById.keys.toSet().difference(idsOf(after).toSet()), {
        firstBreak,
      });
      // The same input always composes the same feed.
      expect(composeFeed(episodes), before);
    });

    test('gives every item a unique id', () {
      final ids = idsOf(composeFeed(episodes));

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('ads never take an episode number', () {
      final numbers = [
        for (final item in composeFeed(episodes))
          if (item case EpisodeItem(:final episode)) episode.number,
      ];

      expect(numbers, [for (var n = 1; n <= 10; n++) n]);
    });

    test('never ends the feed on an ad', () {
      final feed = composeFeed(fakeEpisodes(9), maxAdsBeforeEpisode: 100);

      expect(shape(feed), 'E1 E2 E3 AD E4 E5 E6 AD E7 E8 E9');
    });

    test('honours custom spacing and cut-off', () {
      final feed = composeFeed(
        fakeEpisodes(6),
        adEvery: 2,
        maxAdsBeforeEpisode: 5,
      );

      expect(shape(feed), 'E1 E2 AD E3 E4 AD E5 E6');
    });

    test('returns an empty feed for an empty catalog', () {
      expect(composeFeed(const []), isEmpty);
    });

    test('returns an unmodifiable list', () {
      final feed = composeFeed(episodes);

      expect(() => feed.add(AdSlotItem.after(1)), throwsUnsupportedError);
    });

    test('rejects an adEvery below 1', () {
      expect(() => composeFeed(episodes, adEvery: 0), throwsArgumentError);
    });
  });
}
