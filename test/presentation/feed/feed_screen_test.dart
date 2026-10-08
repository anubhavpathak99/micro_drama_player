import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_logo.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_page.dart';
import 'package:micro_drama_interactive_player/presentation/shared/app_route_observer.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_ads.dart';
import '../../support/fake_unlocks.dart';
import '../../support/fake_video.dart';

Future<FakePlayerPool> pumpFeed(
  WidgetTester tester, {
  List<Episode>? episodes,
  FakeUnlockRepository? unlocks,
}) async {
  final pool = FakePlayerPool();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(episodes ?? fakeEpisodes()),
        ),
        unlockRepositoryProvider.overrideWithValue(
          unlocks ?? FakeUnlockRepository(),
        ),
        playerPoolProvider.overrideWith(() => pool),
        adRepositoryProvider.overrideWithValue(FakeAdRepository()),
        analyticsProvider.overrideWithValue(FakeAnalytics()),
      ],
      child: MaterialApp(
        navigatorObservers: [appRouteObserver],
        home: const FeedScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pool;
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FeedScreen)));

/// Flings one page up (forward) or down (back), then lets the page settle.
/// Ad pages shimmer forever, so this pumps a fixed time instead of settling.
Future<void> fling(WidgetTester tester, {bool forward = true}) async {
  await tester.fling(
    find.byType(PageView),
    Offset(0, forward ? -300 : 300),
    1500,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

String currentId(WidgetTester tester) =>
    containerOf(tester).read(feedControllerProvider).value!.currentId;

void main() {
  testWidgets('opens on the first episode', (tester) async {
    await pumpFeed(tester);

    expect(find.text('Episode 1'), findsOneWidget);
    expect(currentId(tester), 'ep-01');
  });

  testWidgets('keys every page by its item id', (tester) async {
    await pumpFeed(tester);

    expect(find.byKey(const ValueKey('ep-01')), findsOneWidget);
    // The next page is built ahead of time for implicit scrolling.
    expect(
      find.byKey(const ValueKey('ep-02'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a swipe makes the next page current, then rewinds', (
    tester,
  ) async {
    final pool = await pumpFeed(tester);

    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();

    expect(currentId(tester), 'ep-02');
    expect(pool.calls, contains('rewind'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ep-02')),
        matching: find.byType(EpisodePage),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pauses while another route covers the feed', (tester) async {
    final pool = await pumpFeed(tester);

    await tester.longPress(find.byType(FeedLogo));
    await tester.pumpAndSettle();
    expect(pool.calls, contains('suspend routeCovered'));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(pool.calls.last, 'resume routeCovered');
  });

  testWidgets('pauses while the app is in the background', (tester) async {
    final pool = await pumpFeed(tester);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(pool.calls, contains('suspend appInactive'));

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(pool.calls.last, 'resume appInactive');
  });

  group('swipes on a busy main thread', () {
    // Android under load delivers a swipe as a few samples, 60 ms apart.
    // 240 px is less than half the 600 px page, so only a fling turns it.
    Future<void> sparseSwipeUp(
      WidgetTester tester, {
      required Duration restBeforeLift,
    }) async {
      final gesture = await tester.createGesture();
      await gesture.down(tester.getCenter(find.byType(PageView)));
      for (var step = 1; step <= 4; step++) {
        await gesture.moveBy(
          const Offset(0, -60),
          timeStamp: Duration(milliseconds: 60 * step),
        );
      }
      await tester.pump(restBeforeLift);
      await gesture.up(
        timeStamp: const Duration(milliseconds: 240) + restBeforeLift,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a quick swipe still turns the page', (tester) async {
      await pumpFeed(tester);

      await sparseSwipeUp(
        tester,
        restBeforeLift: const Duration(milliseconds: 5),
      );

      expect(currentId(tester), 'ep-02');
    });

    testWidgets('a swipe that rests before lifting settles back', (
      tester,
    ) async {
      await pumpFeed(tester);

      await sparseSwipeUp(
        tester,
        restBeforeLift: const Duration(milliseconds: 120),
      );

      expect(currentId(tester), 'ep-01');
    });
  });

  testWidgets('decodes posters up to two pages either side', (tester) async {
    await pumpFeed(tester);
    final context = tester.element(find.byType(PageView));
    Future<bool> cached(int episode) async {
      final number = episode.toString().padLeft(2, '0');
      final key = await AssetImage('assets/posters/ep-$number.jpg')
          .obtainKey(createLocalImageConfiguration(context));
      return PaintingBinding.instance.imageCache.statusForKey(key).tracked;
    }

    // On E1 (page 0): E2 and E3 lie ahead, then the ad and E4.
    expect(await cached(1), isTrue);
    expect(await cached(2), isTrue);
    expect(await cached(3), isTrue);
    expect(await cached(4), isFalse);

    // On E3 (page 2): E4 is now two pages away.
    await fling(tester);
    await fling(tester);
    expect(currentId(tester), 'ep-03');
    expect(await cached(4), isTrue);
    expect(await cached(5), isFalse);
  });

  testWidgets('a scrub starting or ending leaves the pages alone', (
    tester,
  ) async {
    final pool = await pumpFeed(tester);
    final rebuilt = <String>{};
    debugOnRebuildDirtyWidget = (element, _) =>
        rebuilt.add(element.widget.runtimeType.toString());
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    pool.emit(const PlayerPoolState(scrubbing: true));
    await tester.pump();
    pool.emit(const PlayerPoolState());
    await tester.pump();

    expect(rebuilt, isNot(contains('FeedPage')));
    expect(rebuilt, isNot(contains('EpisodePage')));
  });

  testWidgets('holds still while a scrub runs', (tester) async {
    final pool = await pumpFeed(tester);

    pool.emit(const PlayerPoolState(scrubbing: true));
    await tester.pump();
    await fling(tester);
    expect(currentId(tester), 'ep-01');

    pool.emit(const PlayerPoolState());
    await tester.pump();
    await fling(tester);
    expect(currentId(tester), 'ep-02');
  });

  group('paywall barrier', () {
    testWidgets('stops forward scrolling at the locked episode', (
      tester,
    ) async {
      await pumpFeed(tester);
      for (var page = 0; page < 8; page++) {
        await fling(tester);
      }
      expect(currentId(tester), 'ep-07');

      await fling(tester);
      expect(currentId(tester), 'ep-07');

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(currentId(tester), 'ep-07');
    });

    testWidgets('leaves backward scrolling free', (tester) async {
      await pumpFeed(tester);
      for (var page = 0; page < 8; page++) {
        await fling(tester);
      }

      await fling(tester, forward: false);

      expect(currentId(tester), 'ad-after-6');
    });

    testWidgets('lifts once the episode is unlocked', (tester) async {
      await pumpFeed(tester);
      for (var page = 0; page < 8; page++) {
        await fling(tester);
      }

      await containerOf(tester)
          .read(paywallControllerProvider.notifier)
          .unlock('ep-07');
      await tester.pump();
      await fling(tester);

      expect(currentId(tester), 'ep-08');
    });

    // Both lock positions use the same physics types. Scrollable only adopts
    // new physics on a type change, so this fails unless the new instance is
    // pushed through the scroll behaviour.
    testWidgets('moves to the next locked episode once one unlocks', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        episodes: [
          for (var n = 1; n <= 10; n++)
            fakeEpisode(n, isPremium: n == 7 || n == 9),
        ],
      );
      for (var page = 0; page < 8; page++) {
        await fling(tester);
      }

      await containerOf(tester)
          .read(paywallControllerProvider.notifier)
          .unlock('ep-07');
      await tester.pump();
      for (var page = 0; page < 4; page++) {
        await fling(tester);
      }

      expect(currentId(tester), 'ep-09');
    });

    testWidgets('sends the feed back when a lock returns behind it', (
      tester,
    ) async {
      await pumpFeed(tester, unlocks: FakeUnlockRepository({'ep-07'}));
      for (var page = 0; page < 9; page++) {
        await fling(tester);
      }
      expect(currentId(tester), 'ep-08');

      await containerOf(tester)
          .read(paywallControllerProvider.notifier)
          .reset();
      await tester.pump();

      expect(currentId(tester), 'ep-07');
    });
  });
}
