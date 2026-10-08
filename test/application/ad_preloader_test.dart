import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/application/debug_settings.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/core/env/ad_config.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';

import '../support/episode_fixtures.dart';
import '../support/fake_ads.dart';
import '../support/fake_video.dart';

const String firstSlot = 'ad-after-3';
const String secondSlot = 'ad-after-6';

/// The feed (E1 E2 E3 AD E4 E5 E6 AD E7 …) with the preloader running on
/// fake ads.
class AdHarness {
  AdHarness([FakeAdBehavior behavior = FakeAdBehavior.fill])
    : ads = FakeAdRepository(behavior) {
    container = ProviderContainer.test(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        adRepositoryProvider.overrideWithValue(ads),
        analyticsProvider.overrideWithValue(analytics),
      ],
    );
  }

  final FakeAdRepository ads;
  final FakeAnalytics analytics = FakeAnalytics();
  late final ProviderContainer container;

  AdSlotState? stateOf(String slotId) =>
      container.read(adPreloaderProvider)[slotId]?.state;

  NativeAdHandle? adOf(String slotId) =>
      container.read(adPreloaderProvider)[slotId]?.ad;

  List<String> get feedIds => [
    for (final item in container.read(feedControllerProvider).value!.items)
      item.id,
  ];

  Future<void> start() async {
    await container.read(feedControllerProvider.future);
    container.listen(adPreloaderProvider, (_, _) {});
    await pumpEventQueue();
  }

  Future<void> goTo(String id) async {
    container.read(feedControllerProvider.notifier).setCurrent(id);
    await pumpEventQueue();
  }

  /// Walks page by page, as a user swiping would.
  Future<void> walk(List<String> ids) async {
    for (final id in ids) {
      await goTo(id);
    }
  }
}

void main() {
  group('AdPreloader loading', () {
    test('loads the first slot at startup and the second from E4', () async {
      final h = AdHarness();
      await h.start();

      expect(h.stateOf(firstSlot), AdSlotState.loaded);
      expect(h.stateOf(secondSlot), AdSlotState.idle);

      await h.walk(['ep-02', 'ep-03', firstSlot]);
      expect(h.stateOf(secondSlot), AdSlotState.idle);

      await h.goTo('ep-04');
      expect(h.stateOf(secondSlot), AdSlotState.loaded);
    });

    test('logs requests and loads', () async {
      final h = AdHarness();
      await h.start();

      expect(h.analytics.names, ['ad_request', 'ad_loaded']);
      expect(h.analytics.parametersOf('ad_loaded').single, {
        'slot': firstSlot,
        'latency_ms': isA<int>(),
      });
    });

    test('logs impressions reported by the SDK', () async {
      final h = AdHarness();
      await h.start();

      h.ads.impressionCallbacks.single();

      expect(h.analytics.parametersOf('ad_impression'), [
        {'slot': firstSlot},
      ]);
    });
  });

  group('AdPreloader showing and releasing', () {
    test('marks an ad shown once its page is on screen', () async {
      final h = AdHarness();
      await h.start();

      await h.walk(['ep-02', 'ep-03', firstSlot]);

      expect(h.stateOf(firstSlot), AdSlotState.shown);
    });

    test('releases a shown ad two pages on, then loads a fresh one', () async {
      final h = AdHarness();
      await h.start();
      await h.walk(['ep-02', 'ep-03', firstSlot]);
      final shown = h.ads.served.single;

      await h.goTo('ep-04');
      expect(h.stateOf(firstSlot), AdSlotState.shown, reason: 'one page on');

      await h.goTo('ep-05');
      expect(h.stateOf(firstSlot), AdSlotState.disposed);
      expect(shown.isDisposed, isTrue);

      await h.walk(['ep-04', firstSlot]);
      expect(h.stateOf(firstSlot), AdSlotState.shown);
      expect(h.adOf(firstSlot), isNot(same(shown)), reason: 'never reused');
    });

    test('releases every ad when it goes away', () async {
      final h = AdHarness();
      await h.start();
      final loaded = h.ads.served.single;

      h.container.dispose();

      expect(loaded.isDisposed, isTrue);
    });
  });

  group('AdPreloader failures', () {
    test('a no-fill fails the slot and the feed drops it', () async {
      final h = AdHarness(FakeAdBehavior.noFill);
      await h.start();

      expect(h.stateOf(firstSlot), AdSlotState.failed);
      expect(h.feedIds, isNot(contains(firstSlot)));
      expect(h.analytics.parametersOf('ad_no_fill'), [
        {'slot': firstSlot, 'reason': 'no_fill'},
      ]);
    });

    testWidgets('a load slower than 8 s fails, and its late ad is released', (
      tester,
    ) async {
      final h = AdHarness(FakeAdBehavior.hang);
      // On fake time pumpEventQueue would wait forever, so pump instead.
      await h.container.read(feedControllerProvider.future);
      h.container.listen(adPreloaderProvider, (_, _) {});
      await tester.pump();

      await tester.pump(AdConfig.loadTimeout - const Duration(milliseconds: 1));
      expect(h.stateOf(firstSlot), AdSlotState.loading);

      await tester.pump(const Duration(milliseconds: 1));
      expect(h.stateOf(firstSlot), AdSlotState.failed);
      expect(
        h.analytics.parametersOf('ad_no_fill').single['reason'],
        'timeout',
      );

      final lateAd = FakeNativeAdHandle(99);
      h.ads.pending.single.complete(lateAd);
      await tester.pump();
      expect(lateAd.isDisposed, isTrue);
    });

    testWidgets("the SDK's start-up doesn't count against an ad's 8 s", (
      tester,
    ) async {
      final h = AdHarness();
      h.ads.initialization = Completer<void>();
      await h.container.read(feedControllerProvider.future);
      h.container.listen(adPreloaderProvider, (_, _) {});

      await tester.pump(const Duration(seconds: 10));
      expect(h.stateOf(firstSlot), AdSlotState.loading);
      expect(h.ads.requests, 0, reason: 'requested once the SDK is up');

      h.ads.initialization!.complete();
      await tester.pump();
      expect(h.stateOf(firstSlot), AdSlotState.loaded);
    });

    test(
      'a forced no-fill fails each request without asking the SDK',
      () async {
        final h = AdHarness();
        h.container.read(debugSettingsProvider.notifier).setForceAdNoFill(true);
        await h.start();

        expect(h.stateOf(firstSlot), AdSlotState.failed);
        expect(h.ads.requests, 0);
        expect(h.feedIds, isNot(contains(firstSlot)));
        expect(h.analytics.parametersOf('ad_no_fill'), [
          {'slot': firstSlot, 'reason': 'forced'},
        ]);
      },
    );

    test(
      'forcing no-fill keeps loaded ads and fails the next request',
      () async {
        final h = AdHarness();
        await h.start();

        h.container.read(debugSettingsProvider.notifier).setForceAdNoFill(true);
        await h.walk(['ep-02', 'ep-03', firstSlot, 'ep-04']);

        expect(h.stateOf(firstSlot), AdSlotState.shown);
        expect(h.stateOf(secondSlot), AdSlotState.failed);
        expect(h.feedIds, containsAllInOrder([firstSlot, 'ep-06', 'ep-07']));
        expect(h.feedIds, isNot(contains(secondSlot)));
      },
    );

    test('a simulated no-fill takes the same path', () async {
      final h = AdHarness();
      await h.start();
      final loaded = h.ads.served.single;

      h.container.read(adPreloaderProvider.notifier).simulateNoFill(firstSlot);
      await pumpEventQueue();

      expect(h.stateOf(firstSlot), AdSlotState.failed);
      expect(loaded.isDisposed, isTrue);
      expect(h.feedIds, isNot(contains(firstSlot)));
    });
  });
}
