import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/debug_settings.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';
import 'package:micro_drama_interactive_player/data/video_controller_factory.dart';
import 'package:micro_drama_interactive_player/presentation/debug/debug_panel.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_logo.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_ads.dart';
import '../../support/fake_unlocks.dart';
import '../../support/fake_video.dart';
import '../../support/surfaces.dart';

// The panel over the real feed, pool and paywall, on fake players and ads.

Future<void> pumpFeed(WidgetTester tester, FakeUnlockRepository unlocks) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        unlockRepositoryProvider.overrideWithValue(unlocks),
        videoControllerFactoryProvider.overrideWithValue(
          FakeVideoControllerFactory(),
        ),
        videoCacheProvider.overrideWithValue(FakeVideoCache()),
        adRepositoryProvider.overrideWithValue(FakeAdRepository()),
        analyticsProvider.overrideWithValue(FakeAnalytics()),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Opens the panel the way a developer does: a long press on the logo.
Future<void> openPanel(WidgetTester tester) async {
  await tester.longPress(find.byType(FeedLogo));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(FeedScreen, skipOffstage: false)),
);

DebugSettings settingsOf(WidgetTester tester) =>
    containerOf(tester).read(debugSettingsProvider);

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(
        of: find.byType(DebugPanel),
        matching: find.byType(Scrollable),
      ),
    );

void main() {
  testWidgets('a long press on the logo opens the panel', (tester) async {
    await pumpFeed(tester, FakeUnlockRepository());

    await openPanel(tester);

    expect(find.byType(DebugPanel), findsOneWidget);
    expect(find.text('Feed stops at ep-07'), findsOneWidget);
  });

  testWidgets('the switches drive the debug settings', (tester) async {
    await pumpFeed(tester, FakeUnlockRepository());
    await openPanel(tester);

    await tester.tap(find.text('Force ad no-fill'));
    await tester.tap(find.text('Slow network'));
    await tester.tap(find.text('Performance overlay'));
    await tester.pump();

    expect(
      settingsOf(tester),
      const DebugSettings(
        forceAdNoFill: true,
        slowNetwork: true,
        performanceOverlay: true,
      ),
    );

    await tester.tap(find.text('Slow network'));
    await tester.pump();
    expect(settingsOf(tester).slowNetwork, isFalse);
  });

  testWidgets('Jump to E6 closes the panel on E6', (tester) async {
    await pumpFeed(tester, FakeUnlockRepository());
    await openPanel(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Jump'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DebugPanel), findsNothing);
    expect(
      containerOf(tester).read(feedControllerProvider).value!.currentId,
      'ep-06',
    );
    expect(tester.getRect(find.byKey(const ValueKey('ep-06'))).top, 0);
  });

  testWidgets('Reset unlock locks E7 again', (tester) async {
    final unlocks = FakeUnlockRepository({'ep-07'});
    await pumpFeed(tester, unlocks);
    await openPanel(tester);
    expect(find.text('Nothing locked'), findsOneWidget);

    await tester.tap(find.text('Reset unlock'));
    await tester.pump();

    expect(unlocks.resets, 1);
    expect(find.text('Feed stops at ep-07'), findsOneWidget);
    expect(
      containerOf(tester).read(paywallControllerProvider).lockedItemId,
      'ep-07',
    );
  });

  testWidgets('Unlock opens E7 without the paywall', (tester) async {
    final unlocks = FakeUnlockRepository();
    await pumpFeed(tester, unlocks);
    await openPanel(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pump();

    expect(unlocks.unlockedIds(), {'ep-07'});
    expect(find.text('Nothing locked'), findsOneWidget);
  });

  testWidgets('Simulate no-fill shows that ad, then skips past it', (
    tester,
  ) async {
    await pumpFeed(tester, FakeUnlockRepository());
    await openPanel(tester);
    await scrollTo(tester, find.text('ad-after-3'));
    FeedState feed() => containerOf(tester).read(feedControllerProvider).value!;

    await tester.tap(find.widgetWithText(TextButton, 'Simulate no-fill').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DebugPanel), findsNothing);
    expect(feed().currentId, 'ad-after-3');

    // The failure lands, the ad fades, and the feed moves on.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(MotionDurations.adNoFillFade);
    await tester.pump();
    await tester.pump(
      MotionDurations.adNoFillSkip + const Duration(milliseconds: 16),
    );
    await tester.pump();

    expect(feed().indexOf('ad-after-3'), -1);
    expect(feed().currentId, 'ep-04');
  });

  testWidgets('shows the live players and the page on screen', (tester) async {
    await pumpFeed(tester, FakeUnlockRepository());
    // Tall enough to show the whole panel without scrolling.
    tester.view.physicalSize = const Size(1080, 9000);
    await tester.pump();
    await openPanel(tester);

    expect(find.widgetWithText(ListTile, 'Live players'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Locked: no player'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'E1 · Episode 1'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'E2 · Episode 2'))
          .selected,
      isFalse,
    );
  });

  testWidgets('screen readers can open the panel from the logo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpFeed(tester, FakeUnlockRepository());

    expect(
      find.semantics.byLabel('Micro Drama').evaluate().single,
      isSemantics(
        hasLongPressAction: true,
        onLongPressHint: 'open developer options',
      ),
    );
    tester.semantics.longPress(find.semantics.byLabel('Micro Drama'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DebugPanel), findsOneWidget);
    semantics.dispose();
  });
}
