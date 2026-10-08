import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/view_tracker.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';

import '../support/episode_fixtures.dart';
import '../support/fake_ads.dart';
import '../support/fake_unlocks.dart';
import '../support/fake_video.dart';

/// The feed (E1 E2 E3 AD E4 E5 E6 AD E7 …) with the view tracker running.
class ViewHarness {
  ViewHarness({Set<String> unlocked = const {}}) {
    container = ProviderContainer.test(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        unlockRepositoryProvider.overrideWithValue(
          FakeUnlockRepository(unlocked),
        ),
        analyticsProvider.overrideWithValue(analytics),
      ],
    );
  }

  final FakeAnalytics analytics = FakeAnalytics();
  late final ProviderContainer container;

  Future<void> start() async {
    container.listen(viewTrackerProvider, (_, _) {});
    await container.read(feedControllerProvider.future);
    await pumpEventQueue();
  }

  Future<void> walk(List<String> ids) async {
    for (final id in ids) {
      container.read(feedControllerProvider.notifier).setCurrent(id);
      await pumpEventQueue();
    }
  }
}

void main() {
  test('logs a view of the first episode once the feed loads', () async {
    final h = ViewHarness();
    await h.start();

    expect(h.analytics.names, ['episode_view']);
    expect(h.analytics.parametersOf('episode_view').single, {
      'episode': 'ep-01',
      'position': 0,
      'locked': false,
    });
  });

  test('logs each episode that comes on screen, but not ad pages', () async {
    final h = ViewHarness();
    await h.start();

    await h.walk(['ep-02', 'ep-03', 'ad-after-3', 'ep-04', 'ep-04', 'ep-03']);

    expect(h.analytics.parametersOf('episode_view'), [
      {'episode': 'ep-01', 'position': 0, 'locked': false},
      {'episode': 'ep-02', 'position': 1, 'locked': false},
      {'episode': 'ep-03', 'position': 2, 'locked': false},
      {'episode': 'ep-04', 'position': 4, 'locked': false},
      {'episode': 'ep-03', 'position': 2, 'locked': false},
    ]);
  });

  test('a locked episode logs its paywall along with the view', () async {
    final h = ViewHarness();
    await h.start();

    await h.walk(['ep-07']);

    expect(h.analytics.names, [
      'episode_view',
      'episode_view',
      'paywall_shown',
    ]);
    expect(h.analytics.parametersOf('episode_view').last, {
      'episode': 'ep-07',
      'position': 8,
      'locked': true,
    });
    expect(h.analytics.parametersOf('paywall_shown'), [
      {'episode': 'ep-07'},
    ]);
  });

  test('an unlocked premium episode logs a plain view', () async {
    final h = ViewHarness(unlocked: {'ep-07'});
    await h.start();

    await h.walk(['ep-07']);

    expect(h.analytics.parametersOf('episode_view').last, {
      'episode': 'ep-07',
      'position': 8,
      'locked': false,
    });
    expect(h.analytics.names, isNot(contains('paywall_shown')));
  });
}
