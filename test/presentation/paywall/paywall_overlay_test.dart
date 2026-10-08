import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';
import 'package:micro_drama_interactive_player/data/video_controller_factory.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/paywall_overlay.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/shimmer_cta.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_ads.dart';
import '../../support/fake_unlocks.dart';
import '../../support/fake_video.dart';
import '../../support/surfaces.dart';

// These tests run the real feed, player pool and paywall on fake players.

const Key cardKey = Key('paywall-card');

Future<FakeVideoControllerFactory> pumpFeed(
  WidgetTester tester, {
  FakeUnlockRepository? unlocks,
  bool reduceMotion = false,
}) async {
  usePhoneSurface(tester);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final players = FakeVideoControllerFactory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        unlockRepositoryProvider.overrideWithValue(
          unlocks ?? FakeUnlockRepository(),
        ),
        videoControllerFactoryProvider.overrideWithValue(players),
        videoCacheProvider.overrideWithValue(FakeVideoCache()),
        adRepositoryProvider.overrideWithValue(FakeAdRepository()),
        analyticsProvider.overrideWithValue(FakeAnalytics()),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return players;
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FeedScreen)));

String currentId(WidgetTester tester) =>
    containerOf(tester).read(feedControllerProvider).value!.currentId;

/// Lets the feed settle: the page snaps, then the paywall's entrance runs.
/// The feed shimmers forever, so this pumps fixed time instead of waiting
/// for idle. A new animation's first frame is its start, hence the extra
/// pump.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Flings one page and lets it settle.
Future<void> fling(WidgetTester tester, {bool forward = true}) async {
  await tester.fling(
    find.byType(PageView),
    Offset(0, forward ? -400 : 400),
    1500,
  );
  await settle(tester);
}

/// From the first page to E7: E1 E2 E3 AD E4 E5 E6 AD E7.
Future<void> goToLockedEpisode(WidgetTester tester) async {
  for (var page = 0; page < 8; page++) {
    await fling(tester);
  }
  expect(currentId(tester), 'ep-07');
}

/// How far the card's top sits above the bottom of E7's page: negative when
/// hidden below it, the visible card height at rest.
double cardRise(WidgetTester tester) {
  final page = tester.getRect(
    find.byKey(const ValueKey('ep-07'), skipOffstage: false),
  );
  final card = tester.getRect(find.byKey(cardKey, skipOffstage: false));
  return page.bottom - card.top;
}

/// The card's rise at rest: its full height minus the part kept below the
/// screen edge for the spring's overshoot.
double restingRise(WidgetTester tester) =>
    tester.getSize(find.byKey(cardKey, skipOffstage: false)).height - 80;

void main() {
  testWidgets('landing on E7 shows the paywall and creates no player for it', (
    tester,
  ) async {
    final players = await pumpFeed(tester);

    await goToLockedEpisode(tester);

    expect(find.text('Unlock Episode').hitTestable(), findsOneWidget);
    expect(
      cardRise(tester),
      moreOrLessEquals(restingRise(tester), epsilon: 0.5),
    );
    expect(players.createdFor('ep-07'), isEmpty);
  });

  testWidgets('the card peeks in with its page and replays on every visit', (
    tester,
  ) async {
    await pumpFeed(tester);
    await goToLockedEpisode(tester);
    final atRest = restingRise(tester);

    await fling(tester, forward: false);
    expect(cardRise(tester), lessThan(0), reason: 'reset once out of view');

    final drag = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await drag.moveBy(const Offset(0, -40));
    await drag.moveBy(const Offset(0, -680));
    await tester.pump();
    final peek = cardRise(tester);
    expect(peek, greaterThan(0), reason: 'peeking above the page bottom');
    expect(peek, lessThan(atRest / 2), reason: 'not yet risen');

    await drag.up();
    await settle(tester);
    expect(currentId(tester), 'ep-07');
    expect(cardRise(tester), moreOrLessEquals(atRest, epsilon: 0.5));
  });

  testWidgets('unlocking prepares E7, then plays it once the paywall leaves', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
    final players = await pumpFeed(tester, unlocks: unlocks);
    await goToLockedEpisode(tester);

    await tester.tap(find.text('Unlock Episode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Unlocking'), findsOneWidget);
    final player = players.liveFor('ep-07');
    expect(player, isNotNull, reason: 'prepared during the purchase');
    expect(player!.value.isPlaying, isFalse);

    unlocks.purchase!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Unlocked'), findsOneWidget);
    expect(player.value.isPlaying, isFalse, reason: 'still celebrating');

    await tester.pump(MotionDurations.unlockCelebration);
    await tester.pump();
    // An animation only completes on a frame past its duration.
    await tester.pump(
      MotionDurations.paywallDismiss + const Duration(milliseconds: 16),
    );
    await tester.pump();
    expect(find.byKey(cardKey, skipOffstage: false), findsNothing);
    expect(player.value.isPlaying, isTrue);

    await fling(tester);
    expect(currentId(tester), 'ep-08', reason: 'the scroll lock is gone');
    semantics.dispose();
  });

  testWidgets('a failed purchase brings the button back with a message', (
    tester,
  ) async {
    final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
    final players = await pumpFeed(tester, unlocks: unlocks);
    await goToLockedEpisode(tester);

    await tester.tap(find.text('Unlock Episode'));
    await tester.pump();
    unlocks.purchase!.completeError(StateError('Store unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't unlock this episode. Try again."), findsOne);
    expect(find.text('Unlock Episode').hitTestable(), findsOneWidget);
    expect(players.liveFor('ep-07'), isNull);
  });

  testWidgets('watching an ad is not available yet', (tester) async {
    await pumpFeed(tester);
    await goToLockedEpisode(tester);

    await tester.tap(find.text('Watch an ad to unlock'));
    await tester.pump();

    expect(find.text('Rewarded unlocks are not available yet.'), findsOne);
  });

  testWidgets('an unlock from elsewhere sends the card away', (tester) async {
    final players = await pumpFeed(tester);
    await goToLockedEpisode(tester);

    await containerOf(tester)
        .read(paywallControllerProvider.notifier)
        .unlock('ep-07');
    await settle(tester);

    expect(find.byKey(cardKey, skipOffstage: false), findsNothing);
    expect(players.liveFor('ep-07')!.value.isPlaying, isTrue);
  });

  testWidgets('locking again puts the paywall back up', (tester) async {
    final players = await pumpFeed(
      tester,
      unlocks: FakeUnlockRepository({'ep-07'}),
    );
    await goToLockedEpisode(tester);
    expect(find.byKey(cardKey, skipOffstage: false), findsNothing);

    await containerOf(tester).read(paywallControllerProvider.notifier).reset();
    await settle(tester);

    expect(find.text('Unlock Episode').hitTestable(), findsOneWidget);
    expect(players.liveFor('ep-07'), isNull);
  });

  testWidgets('under reduced motion the card fades in without sliding', (
    tester,
  ) async {
    await pumpFeed(tester, reduceMotion: true);
    await goToLockedEpisode(tester);

    expect(cardRise(tester), moreOrLessEquals(restingRise(tester)));
    expect(
      find.descendant(
        of: find.byType(PaywallOverlay),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
    expect(find.text('Unlock Episode').hitTestable(), findsOneWidget);
  });

  testWidgets('screen readers hear the episode and price, and can unlock', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
    await pumpFeed(tester, unlocks: unlocks);
    await goToLockedEpisode(tester);
    final unlock = find.semantics.byLabel(
      r'Unlock episode 7, Episode 7, for $0.99',
    );

    expect(
      tester.getSemantics(find.byType(ShimmerCta)),
      isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
    );
    tester.semantics.tap(unlock);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Unlocking'), findsOneWidget);
    unlocks.purchase!.complete();
    await settle(tester);
    semantics.dispose();
  });

  testWidgets('logs the paywall when E7 comes on screen', (tester) async {
    await pumpFeed(tester);
    await goToLockedEpisode(tester);
    final analytics =
        containerOf(tester).read(analyticsProvider) as FakeAnalytics;

    expect(analytics.parametersOf('paywall_shown'), [
      {'episode': 'ep-07'},
    ]);
    expect(analytics.parametersOf('episode_view').last, {
      'episode': 'ep-07',
      'position': 8,
      'locked': true,
    });

    await tester.tap(find.text('Unlock Episode'));
    await settle(tester);
    expect(
      analytics.names,
      containsAllInOrder(['unlock_tap', 'unlock_success']),
    );
  });
}
