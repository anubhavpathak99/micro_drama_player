import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/engagement_controller.dart';

void main() {
  group('EpisodeFlags', () {
    test('toggle switches a flag on and off', () {
      final container = ProviderContainer.test();
      final likes = container.read(likedEpisodesProvider.notifier);

      likes.toggle('ep-01');
      expect(container.read(likedEpisodesProvider), {'ep-01'});

      likes.toggle('ep-01');
      expect(container.read(likedEpisodesProvider), isEmpty);
    });

    test('add only switches a flag on', () {
      final container = ProviderContainer.test();
      final likes = container.read(likedEpisodesProvider.notifier);

      likes
        ..add('ep-01')
        ..add('ep-01');

      expect(container.read(likedEpisodesProvider), {'ep-01'});
    });

    test('likes and saves are independent', () {
      final container = ProviderContainer.test();

      container.read(savedEpisodesProvider.notifier).toggle('ep-01');

      expect(container.read(savedEpisodesProvider), {'ep-01'});
      expect(container.read(likedEpisodesProvider), isEmpty);
    });
  });
}
