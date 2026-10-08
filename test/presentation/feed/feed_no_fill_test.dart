import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_ads.dart';
import '../../support/fake_unlocks.dart';
import '../../support/fake_video.dart';
import '../../support/surfaces.dart';

// The no-fill paths through the real feed screen and its PageController,
// checking that the page on screen never jumps.

const String firstSlot = 'ad-after-3';

Future<void> pumpFeed(WidgetTester tester, {bool reduceMotion = false}) async {
  usePhoneSurface(tester);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        unlockRepositoryProvider.overrideWithValue(FakeUnlockRepository()),
        playerPoolProvider.overrideWith(FakePlayerPool.new),
        adRepositoryProvider.overrideWithValue(FakeAdRepository()),
        analyticsProvider.overrideWithValue(FakeAnalytics()),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FeedScreen)));

FeedState feedOf(WidgetTester tester) =>
    containerOf(tester).read(feedControllerProvider).value!;

double pageOf(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

Future<void> flingForward(WidgetTester tester, int pages) async {
  for (var page = 0; page < pages; page++) {
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('on the failed slot: the feed moves on, then drops it', (
    tester,
  ) async {
    await pumpFeed(tester);
    await flingForward(tester, 3);
    expect(feedOf(tester).currentId, firstSlot);

    containerOf(tester)
        .read(adPreloaderProvider.notifier)
        .simulateNoFill(firstSlot);
    await tester.pump();
    await tester.pump(MotionDurations.adNoFillFade);
    await tester.pump();
    await tester.pump(
      MotionDurations.adNoFillSkip + const Duration(milliseconds: 16),
    );
    await tester.pump();

    expect(feedOf(tester).indexOf(firstSlot), -1);
    expect(feedOf(tester).currentId, 'ep-04');
    expect(pageOf(tester), 3, reason: 'the pager stepped back with the feed');
    expect(tester.getRect(find.byKey(const ValueKey('ep-04'))).top, 0);
  });

  testWidgets('behind the user: the slot goes without the page moving', (
    tester,
  ) async {
    await pumpFeed(tester);
    await flingForward(tester, 5);
    expect(feedOf(tester).currentId, 'ep-05');
    expect(pageOf(tester), 5);

    containerOf(tester)
        .read(adPreloaderProvider.notifier)
        .simulateNoFill(firstSlot);
    await tester.pump();

    expect(feedOf(tester).indexOf(firstSlot), -1);
    expect(feedOf(tester).currentId, 'ep-05');
    expect(pageOf(tester), 4);
    expect(tester.getRect(find.byKey(const ValueKey('ep-05'))).top, 0);
  });

  testWidgets('under reduced motion the next page replaces the slot in place', (
    tester,
  ) async {
    await pumpFeed(tester, reduceMotion: true);
    await flingForward(tester, 3);
    expect(feedOf(tester).currentId, firstSlot);
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    final pages = <double>[];
    void record() => pages.add(pager.page!);
    pager.addListener(record);
    addTearDown(() => pager.removeListener(record));

    containerOf(tester)
        .read(adPreloaderProvider.notifier)
        .simulateNoFill(firstSlot);
    await tester.pump();
    await tester.pump(MotionDurations.adNoFillFade);
    await tester.pump();

    expect(feedOf(tester).indexOf(firstSlot), -1);
    expect(feedOf(tester).currentId, 'ep-04');
    expect(pageOf(tester), 3);
    expect(
      pages.where((page) => page != page.roundToDouble()),
      isEmpty,
      reason: 'no scroll in between',
    );
    expect(tester.getRect(find.byKey(const ValueKey('ep-04'))).top, 0);
  });
}
