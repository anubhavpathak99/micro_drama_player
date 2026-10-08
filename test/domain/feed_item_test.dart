import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

import '../support/episode_fixtures.dart';

void main() {
  group('EpisodeItem', () {
    test('takes its id from the episode', () {
      expect(EpisodeItem(fakeEpisode(7)).id, 'ep-07');
    });

    test('is equal when its episode is equal', () {
      expect(EpisodeItem(fakeEpisode(1)), EpisodeItem(fakeEpisode(1)));
      expect(EpisodeItem(fakeEpisode(1)), isNot(EpisodeItem(fakeEpisode(2))));
    });

    test('hashes like its equal, so sets and selects see one page', () {
      expect({
        EpisodeItem(fakeEpisode(1)),
        EpisodeItem(fakeEpisode(1)),
      }, hasLength(1));
      expect('${EpisodeItem(fakeEpisode(1))}', 'EpisodeItem(ep-01)');
    });
  });

  group('AdSlotItem', () {
    test('derives a deterministic id from the episode it follows', () {
      final slot = AdSlotItem.after(3);

      expect(slot.id, 'ad-after-3');
      expect(slot.afterEpisode, 3);
      expect(AdSlotItem.after(3), slot);
    });

    test('never shares an id with an episode', () {
      expect(AdSlotItem.after(3).id, isNot(EpisodeItem(fakeEpisode(3)).id));
    });

    test('hashes like its equal and differs from other slots', () {
      expect({AdSlotItem.after(3), AdSlotItem.after(3)}, hasLength(1));
      expect(AdSlotItem.after(3), isNot(AdSlotItem.after(6)));
      expect('${AdSlotItem.after(3)}', 'AdSlotItem(ad-after-3)');
    });
  });
}
