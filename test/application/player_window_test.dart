import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/application/player_window.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

import '../support/episode_fixtures.dart';

void main() {
  // E1 E2 E3 AD E4 E5 E6 AD E7 E8 E9 E10, with E7 premium.
  final feed = composeFeed(fakeEpisodes());
  bool premiumLocked(Episode episode) => episode.isPremium;
  bool nothingLocked(Episode _) => false;

  Set<String> windowAt(String id, {bool Function(Episode)? isLocked}) =>
      playerWindow(feed, id, isLocked: isLocked ?? premiumLocked);

  group('playerWindow', () {
    test('holds the current page, then the next, then the previous', () {
      expect(windowAt('ep-05').toList(), ['ep-05', 'ep-06', 'ep-04']);
    });

    test('stops at the ends of the feed', () {
      expect(windowAt('ep-01').toList(), ['ep-01', 'ep-02']);
      expect(windowAt('ep-10').toList(), ['ep-10', 'ep-09']);
    });

    test('gives ad pages no player', () {
      expect(windowAt('ep-03').toList(), ['ep-03', 'ep-02']);
      expect(windowAt(AdSlotItem.slotIdAfter(3)).toList(), ['ep-04', 'ep-03']);
    });

    test('never includes a locked episode', () {
      for (final item in feed) {
        expect(windowAt(item.id), isNot(contains('ep-07')), reason: item.id);
      }
    });

    test('preloads nothing past a locked current episode', () {
      expect(windowAt('ep-07'), isEmpty);
    });

    test('includes the episode once it is unlocked', () {
      expect(windowAt('ep-07', isLocked: nothingLocked).toList(), [
        'ep-07',
        'ep-08',
      ]);
    });

    test('never holds more than three players', () {
      for (final item in feed) {
        expect(
          windowAt(item.id, isLocked: nothingLocked).length,
          lessThanOrEqualTo(3),
          reason: item.id,
        );
      }
    });

    test('is empty for an id that is not in the feed', () {
      expect(windowAt('missing'), isEmpty);
    });
  });
}
