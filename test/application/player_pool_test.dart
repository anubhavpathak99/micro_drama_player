import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/debug_settings.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';
import 'package:micro_drama_interactive_player/data/video_controller_factory.dart';

import '../support/episode_fixtures.dart';
import '../support/fake_ads.dart';
import '../support/fake_unlocks.dart';
import '../support/fake_video.dart';

/// A container wired to fakes, with the feed loaded and the pool running.
class PoolHarness {
  PoolHarness({
    Set<String> cachedEpisodeIds = const {},
    FakeUnlockRepository? unlocks,
  }) : cache = FakeVideoCache(cachedEpisodeIds: cachedEpisodeIds),
       unlocks = unlocks ?? FakeUnlockRepository() {
    container = ProviderContainer.test(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        videoControllerFactoryProvider.overrideWithValue(factory),
        videoCacheProvider.overrideWithValue(cache),
        unlockRepositoryProvider.overrideWithValue(this.unlocks),
        analyticsProvider.overrideWithValue(analytics),
      ],
    );
  }

  final FakeVideoControllerFactory factory = FakeVideoControllerFactory();
  final FakeAnalytics analytics = FakeAnalytics();
  final FakeVideoCache cache;
  final FakeUnlockRepository unlocks;
  late final ProviderContainer container;

  PlayerPoolState get pool => container.read(playerPoolProvider);
  PlayerPool get players => container.read(playerPoolProvider.notifier);
  PaywallController get paywall =>
      container.read(paywallControllerProvider.notifier);
  List<String> get ids => [
    for (final item in container.read(feedControllerProvider).value!.items)
      item.id,
  ];

  Future<void> start() async {
    await container.read(feedControllerProvider.future);
    container.listen(playerPoolProvider, (_, _) {});
    await settle();
  }

  Future<void> goTo(String id) async {
    container.read(feedControllerProvider.notifier).setCurrent(id);
    await settle();
  }
}

/// Lets the fakes' async work (cache lookups, initialize, seek) finish.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<PoolHarness> started({Set<String> cachedEpisodeIds = const {}}) async {
  final harness = PoolHarness(cachedEpisodeIds: cachedEpisodeIds);
  await harness.start();
  return harness;
}

void main() {
  group('PlayerPool window', () {
    test('plays the first episode and parks the next one', () async {
      final h = await started();

      expect(h.pool.activeId, 'ep-01');
      expect(h.pool.slots.keys, ['ep-01', 'ep-02']);
      final first = h.factory.liveFor('ep-01')!;
      final next = h.factory.liveFor('ep-02')!;
      expect(first.value.isPlaying, isTrue);
      expect(first.value.isLooping, isTrue);
      expect(next.value.isPlaying, isFalse);
      expect(
        next.commands,
        containsAllInOrder(['initialize', 'setLooping true', 'seekTo 0']),
      );
    });

    test(
      'keeps at most three players while walking the feed both ways',
      () async {
        final h = await started();

        for (final id in [...h.ids, ...h.ids.reversed]) {
          await h.goTo(id);
          expect(
            h.factory.live.length,
            lessThanOrEqualTo(PlayerPool.maxPlayers),
            reason: 'on $id',
          );
        }
      },
    );

    test(
      'follows the current page and disposes what leaves the window',
      () async {
        final h = await started();

        await h.goTo('ep-02');
        expect(h.pool.slots.keys, unorderedEquals(['ep-01', 'ep-02', 'ep-03']));

        await h.goTo('ep-03'); // The next page is an ad: no player for it.
        expect(h.pool.slots.keys, unorderedEquals(['ep-02', 'ep-03']));
        expect(
          h.factory.createdFor('ep-01').every((c) => c.isDisposed),
          isTrue,
        );
      },
    );

    test('plays only the current episode', () async {
      final h = await started();

      await h.goTo('ep-02');

      expect(h.factory.liveFor('ep-02')!.value.isPlaying, isTrue);
      expect(h.factory.liveFor('ep-01')!.value.isPlaying, isFalse);
      expect(h.factory.liveFor('ep-03')!.value.isPlaying, isFalse);
    });

    test('pauses everything on an ad page and preloads both sides', () async {
      final h = await started();

      await h.goTo('ep-03');
      await h.goTo('ad-after-3');

      expect(h.pool.activeId, isNull);
      expect(h.pool.slots.keys, unorderedEquals(['ep-03', 'ep-04']));
      expect(h.factory.live.where((c) => c.value.isPlaying), isEmpty);
    });
  });

  group('PlayerPool paywall', () {
    test('never creates a controller for a locked episode', () async {
      final h = await started();

      for (final id in [...h.ids, ...h.ids.reversed]) {
        await h.goTo(id);
      }

      expect(h.factory.createdFor('ep-07'), isEmpty);
    });

    test('preloads nothing past a locked episode', () async {
      final h = await started();

      await h.goTo('ep-07');

      expect(h.pool.activeId, isNull);
      expect(h.pool.slots, isEmpty);
    });

    test('prepares the episode while it unlocks, without playing it', () async {
      final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
      final h = PoolHarness(unlocks: unlocks);
      await h.start();
      await h.goTo('ep-07');

      final unlocking = h.paywall.unlock('ep-07');
      await settle();

      final player = h.factory.liveFor('ep-07')!;
      expect(player.value.isInitialized, isTrue);
      expect(player.value.isPlaying, isFalse);
      expect(h.pool.activeId, isNull);

      unlocks.purchase!.complete();
      await unlocking;
      await settle();
      expect(h.pool.activeId, 'ep-07');
      expect(player.value.isPlaying, isTrue);
    });

    test('keeps the episode silent until the paywall has finished', () async {
      final h = await started();
      await h.goTo('ep-07');
      final exit = Completer<void>();

      final unlocking = h.paywall.unlock(
        'ep-07',
        onPurchased: () => exit.future,
      );
      await settle();
      expect(h.factory.liveFor('ep-07')!.value.isPlaying, isFalse);

      exit.complete();
      await unlocking;
      await settle();
      expect(h.factory.liveFor('ep-07')!.value.isPlaying, isTrue);
    });

    test('releases the prepared player when the purchase fails', () async {
      final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
      final h = PoolHarness(unlocks: unlocks);
      await h.start();
      await h.goTo('ep-07');

      final unlocking = h.paywall.unlock('ep-07');
      await settle();
      expect(h.factory.liveFor('ep-07'), isNotNull);

      unlocks.purchase!.completeError(StateError('Store unavailable'));
      await expectLater(unlocking, throwsStateError);
      await settle();
      expect(h.factory.liveFor('ep-07'), isNull);
    });

    test('creates and plays the player once the episode unlocks', () async {
      final h = await started();
      await h.goTo('ep-07');

      await h.paywall.unlock('ep-07');
      await settle();

      expect(h.pool.activeId, 'ep-07');
      expect(h.factory.liveFor('ep-07')!.value.isPlaying, isTrue);
      expect(h.pool.slots.keys, contains('ep-08'));
    });
  });

  group('PlayerPool sources', () {
    test('plays cached videos from disk and streams the rest', () async {
      final h = await started(cachedEpisodeIds: {'ep-02'});

      expect(h.factory.liveFor('ep-01')!.fromFile, isFalse);
      expect(h.factory.liveFor('ep-02')!.fromFile, isTrue);
    });

    test('caches a streamed video once it is ready', () async {
      final h = await started(cachedEpisodeIds: {'ep-02'});

      expect(h.cache.warmed, [Uri.parse('https://example.com/ep-01.mp4')]);
    });
  });

  group('PlayerPool failures', () {
    test('a failed load becomes PlayerFailed and retry starts over', () async {
      final h = PoolHarness();
      h.factory.failing.add('ep-01');
      await h.start();

      expect(h.pool.slots['ep-01'], isA<PlayerFailed>());
      expect(h.factory.createdFor('ep-01').single.isDisposed, isTrue);

      h.players.retry('ep-01');
      await settle();

      expect(h.pool.slots['ep-01'], isA<PlayerReady>());
      expect(h.factory.liveFor('ep-01')!.value.isPlaying, isTrue);
    });

    test('a playback error fails the slot and releases the player', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      first.value = first.value.copyWith(errorDescription: 'Decoder lost');
      expect(h.pool.slots['ep-01'], const PlayerFailed('Decoder lost'));

      await settle();
      expect(first.isDisposed, isTrue);
    });

    test('retry ignores a player that has not failed', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      h.players.retry('ep-01');
      await settle();

      expect(h.factory.liveFor('ep-01'), same(first));
    });
  });

  group('PlayerPool playback', () {
    test('a tap pauses and resumes; a new page plays regardless', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      h.players.togglePlayback('ep-01');
      await settle();
      expect(h.pool.userPaused, isTrue);
      expect(first.value.isPlaying, isFalse);

      h.players.togglePlayback('ep-01');
      await settle();
      expect(first.value.isPlaying, isTrue);

      h.players.togglePlayback('ep-01');
      await h.goTo('ep-02');
      expect(h.pool.userPaused, isFalse);
      expect(h.factory.liveFor('ep-02')!.value.isPlaying, isTrue);
    });

    test('a tap on a page that is not playing changes nothing', () async {
      final h = await started();

      h.players.togglePlayback('ep-02');

      expect(h.pool.userPaused, isFalse);
    });

    test('holds playback until every suspend reason has cleared', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      h.players
        ..suspend(SuspendReason.appInactive)
        ..suspend(SuspendReason.routeCovered);
      await settle();
      expect(h.pool.suspended, isTrue);
      expect(first.value.isPlaying, isFalse);

      h.players.resume(SuspendReason.appInactive);
      await settle();
      expect(first.value.isPlaying, isFalse);

      h.players.resume(SuspendReason.routeCovered);
      await settle();
      expect(h.pool.suspended, isFalse);
      expect(first.value.isPlaying, isTrue);
    });

    test('resuming keeps a pause the user made', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      h.players
        ..togglePlayback('ep-01')
        ..suspend(SuspendReason.appInactive)
        ..resume(SuspendReason.appInactive);
      await settle();

      expect(first.value.isPlaying, isFalse);
    });

    test('rewinds paused neighbours only when asked', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;
      first.value = first.value.copyWith(position: const Duration(seconds: 4));

      await h.goTo('ep-02');
      expect(first.value.position, const Duration(seconds: 4));

      h.players.rewindInactive();
      await settle();
      expect(first.value.position, Duration.zero);
    });

    test('disposing the pool disposes every controller', () async {
      final h = await started();
      expect(h.factory.live, isNotEmpty);

      h.container.dispose();
      await settle();

      expect(h.factory.live, isEmpty);
    });
  });
  group('PlayerPool scrubbing', () {
    test('holds playback, seeks, then plays on from where it ended', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      h.players.beginScrub('ep-01');
      await settle();
      expect(h.pool.scrubbing, isTrue);
      expect(first.value.isPlaying, isFalse);

      h.players.seek('ep-01', const Duration(seconds: 4));
      await settle();
      expect(first.value.position, const Duration(seconds: 4));

      await h.players.endScrub('ep-01', const Duration(milliseconds: 6500));
      await settle();
      expect(h.pool.scrubbing, isFalse);
      expect(first.value.isPlaying, isTrue);
      expect(
        first.commands,
        containsAllInOrder(['pause', 'seekTo 4000', 'seekTo 6500', 'play']),
      );
    });

    test('keeps a pause the user made', () async {
      final h = await started();
      final first = h.factory.liveFor('ep-01')!;

      h.players
        ..togglePlayback('ep-01')
        ..beginScrub('ep-01');
      await h.players.endScrub('ep-01', const Duration(seconds: 2));
      await settle();

      expect(first.value.isPlaying, isFalse);
      expect(first.value.position, const Duration(seconds: 2));
    });

    test('logs where each scrub started and ended', () async {
      final h = await started();
      await h.factory.liveFor('ep-01')!.seekTo(const Duration(seconds: 3));

      h.players
        ..beginScrub('ep-01')
        ..seek('ep-01', const Duration(seconds: 5));
      await h.players.endScrub('ep-01', const Duration(seconds: 9));
      // A stray end with no scrub under way logs nothing.
      await h.players.endScrub('ep-01', const Duration(seconds: 1));

      expect(h.analytics.parametersOf('scrub'), [
        {'episode': 'ep-01', 'from_ms': 3000, 'to_ms': 9000},
      ]);
    });

    test('only scrubs the episode that is playing', () async {
      final h = await started();
      final next = h.factory.liveFor('ep-02')!;

      h.players
        ..beginScrub('ep-02')
        ..seek('ep-02', const Duration(seconds: 4));
      await settle();

      expect(h.pool.scrubbing, isFalse);
      expect(next.commands, isNot(contains('seekTo 4000')));
    });
  });

  group('PlayerPool slow network', () {
    testWidgets('holds each player in loading for the simulated delay', (
      tester,
    ) async {
      final h = PoolHarness();
      h.container.read(debugSettingsProvider.notifier).setSlowNetwork(true);
      // On fake time settle() would wait forever, so pump instead.
      await h.container.read(feedControllerProvider.future);
      h.container.listen(playerPoolProvider, (_, _) {});
      await tester.pump();

      await tester.pump(
        DebugSettings.slowNetworkDelay - const Duration(milliseconds: 1),
      );
      expect(h.pool.slots['ep-01'], isA<PlayerLoading>());
      expect(h.factory.created, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(h.pool.slots['ep-01'], isA<PlayerReady>());
      expect(h.factory.liveFor('ep-01')!.value.isPlaying, isTrue);
    });

    testWidgets('a player that leaves during the delay is never created', (
      tester,
    ) async {
      final h = PoolHarness();
      h.container.read(debugSettingsProvider.notifier).setSlowNetwork(true);
      await h.container.read(feedControllerProvider.future);
      h.container.listen(playerPoolProvider, (_, _) {});
      await tester.pump();

      // ep-02 leaves the window (current ±1) when the feed jumps to ep-05.
      h.container.read(feedControllerProvider.notifier).setCurrent('ep-05');
      await tester.pump(DebugSettings.slowNetworkDelay);
      await tester.pump();

      expect(h.factory.createdFor('ep-01'), isEmpty);
      expect(h.factory.createdFor('ep-02'), isEmpty);
      expect(h.pool.slots['ep-05'], isA<PlayerReady>());
    });
  });
}
