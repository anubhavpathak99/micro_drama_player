import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/engagement_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_page.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';
import 'package:micro_drama_interactive_player/presentation/shared/shimmer.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_unlocks.dart';
import '../../support/fake_video.dart';
import '../../support/finger.dart';
import '../../support/surfaces.dart';

Future<FakePlayerPool> pumpEpisode(
  WidgetTester tester,
  PlayerPoolState state, {
  Episode? episode,
}) async {
  final pool = FakePlayerPool(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        unlockRepositoryProvider.overrideWithValue(FakeUnlockRepository()),
        playerPoolProvider.overrideWith(() => pool),
      ],
      child: MaterialApp(
        home: ShimmerScope(
          child: EpisodePage(episode: episode ?? fakeEpisode(1)),
        ),
      ),
    ),
  );
  return pool;
}

Set<String> likedIds(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(EpisodePage)))
        .read(likedEpisodesProvider);

Future<FakeVideoController> readyController() async {
  final controller = FakeVideoController('ep-01', fromFile: true);
  await controller.initialize();
  return controller;
}

void main() {
  group('EpisodePage loading', () {
    testWidgets('shows the skeleton only once loading passes 150 ms', (
      tester,
    ) async {
      await pumpEpisode(
        tester,
        const PlayerPoolState(
          slots: {'ep-01': PlayerLoading()},
          activeId: 'ep-01',
        ),
      );

      await tester.pump(const Duration(milliseconds: 149));
      expect(find.byType(BrandedSkeleton), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(BrandedSkeleton), findsOneWidget);
    });

    testWidgets('a quick load never shows the skeleton', (tester) async {
      final pool = await pumpEpisode(
        tester,
        const PlayerPoolState(
          slots: {'ep-01': PlayerLoading()},
          activeId: 'ep-01',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      pool.emit(
        PlayerPoolState(
          slots: {'ep-01': PlayerReady(await readyController())},
          activeId: 'ep-01',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BrandedSkeleton), findsNothing);
    });

    testWidgets('a neighbour that is still loading shows just its poster', (
      tester,
    ) async {
      await pumpEpisode(
        tester,
        const PlayerPoolState(
          slots: {'ep-01': PlayerLoading()},
          activeId: 'ep-02',
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BrandedSkeleton), findsNothing);
    });
  });

  group('EpisodePage controls', () {
    testWidgets('a tap toggles playback once the player is ready', (
      tester,
    ) async {
      final pool = await pumpEpisode(
        tester,
        PlayerPoolState(
          slots: {'ep-01': PlayerReady(await readyController())},
          activeId: 'ep-01',
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(EpisodePage)));
      // It waits out the double-tap window first.
      await tester.pump(const Duration(milliseconds: 200));
      expect(pool.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      expect(pool.calls, ['toggle ep-01']);
    });

    testWidgets('a double tap likes the episode instead of pausing it', (
      tester,
    ) async {
      final pool = await pumpEpisode(
        tester,
        PlayerPoolState(
          slots: {'ep-01': PlayerReady(await readyController())},
          activeId: 'ep-01',
        ),
      );
      final finger = Finger(tester);

      await finger.doubleTap(tester.getCenter(find.byType(EpisodePage)));
      await finger.wait(1000);

      expect(likedIds(tester), {'ep-01'});
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(pool.calls, isEmpty);
    });

    testWidgets('a double tap answers with a light haptic per heart', (
      tester,
    ) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpEpisode(tester, const PlayerPoolState());
      final finger = Finger(tester);
      final center = tester.getCenter(find.byType(EpisodePage));

      await finger.doubleTap(center);
      await finger.wait(100);
      await finger.tap(center);
      await finger.wait(1000);

      expect(haptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
      ]);
      expect(likedIds(tester), {'ep-01'}, reason: 'liked once, kept liked');
    });

    testWidgets('a locked episode takes no likes from taps', (tester) async {
      usePhoneSurface(tester);
      await pumpEpisode(
        tester,
        const PlayerPoolState(),
        episode: fakeEpisode(7, isPremium: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final finger = Finger(tester);

      await finger.doubleTap(const Offset(180, 120));
      await finger.wait(1000);

      expect(likedIds(tester), isEmpty);
    });

    testWidgets('shows the play glyph while paused by the user', (
      tester,
    ) async {
      await pumpEpisode(
        tester,
        PlayerPoolState(
          slots: {'ep-01': PlayerReady(await readyController())},
          activeId: 'ep-01',
          userPaused: true,
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('a failed player offers an in-place retry', (tester) async {
      final pool = await pumpEpisode(
        tester,
        const PlayerPoolState(
          slots: {'ep-01': PlayerFailed('Source missing')},
          activeId: 'ep-01',
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(pool.calls, ['retry ep-01']);
      expect(find.text('Episode 1'), findsOneWidget);
    });
  });

  group('EpisodePage overlay', () {
    testWidgets('shows the episode number and title', (tester) async {
      await pumpEpisode(tester, const PlayerPoolState());

      expect(find.text('EP 1'), findsOneWidget);
      expect(find.text('Episode 1'), findsOneWidget);
      // The chip hugs its label instead of stretching across the caption.
      final chip = find
          .ancestor(of: find.text('EP 1'), matching: find.byType(Container))
          .first;
      expect(tester.getSize(chip).width, lessThan(100));
    });

    testWidgets('covers a locked episode with the paywall', (tester) async {
      usePhoneSurface(tester);
      await pumpEpisode(
        tester,
        const PlayerPoolState(),
        episode: fakeEpisode(7, isPremium: true),
      );
      // The entrance starts after the first frame, then springs in.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Unlock Episode').hitTestable(), findsOneWidget);
      expect(find.text('EP 7').hitTestable(), findsNothing);
    });

    testWidgets('the like button toggles its state', (tester) async {
      await pumpEpisode(tester, const PlayerPoolState());

      await tester.tap(find.bySemanticsLabel('Like'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });
}
