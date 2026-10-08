import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/engagement_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';

import '../support/fake_ads.dart';

/// A container whose analytics land in [analytics].
ProviderContainer containerLogging(FakeAnalytics analytics) =>
    ProviderContainer.test(
      overrides: [analyticsProvider.overrideWithValue(analytics)],
    );

void main() {
  group('EpisodeFlags', () {
    test('toggle switches a flag on and off', () {
      final container = containerLogging(FakeAnalytics());
      final likes = container.read(likedEpisodesProvider.notifier);

      likes.toggle('ep-01');
      expect(container.read(likedEpisodesProvider), {'ep-01'});

      likes.toggle('ep-01');
      expect(container.read(likedEpisodesProvider), isEmpty);
    });

    test('add only switches a flag on', () {
      final container = containerLogging(FakeAnalytics());
      final likes = container.read(likedEpisodesProvider.notifier);

      likes
        ..add('ep-01')
        ..add('ep-01');

      expect(container.read(likedEpisodesProvider), {'ep-01'});
    });

    test('likes and saves are independent', () {
      final container = containerLogging(FakeAnalytics());

      container.read(savedEpisodesProvider.notifier).toggle('ep-01');

      expect(container.read(savedEpisodesProvider), {'ep-01'});
      expect(container.read(likedEpisodesProvider), isEmpty);
    });
  });

  group('like analytics', () {
    test('logs each change of a like with where it came from', () {
      final analytics = FakeAnalytics();
      containerLogging(analytics).read(likedEpisodesProvider.notifier)
        ..add('ep-01', source: FlagSource.doubleTap)
        ..add('ep-01', source: FlagSource.doubleTap)
        ..toggle('ep-01');

      expect(analytics.parametersOf('like'), [
        {'episode': 'ep-01', 'liked': true, 'source': 'double_tap'},
        {'episode': 'ep-01', 'liked': false, 'source': 'button'},
      ]);
    });

    test('saves are not logged', () {
      final analytics = FakeAnalytics();

      containerLogging(analytics).read(savedEpisodesProvider.notifier)
        ..toggle('ep-01')
        ..add('ep-02');

      expect(analytics.events, isEmpty);
    });
  });
}
