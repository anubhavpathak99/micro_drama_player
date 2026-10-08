import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_page.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';
import 'package:micro_drama_interactive_player/presentation/shared/shimmer.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_video.dart';

Future<FakePlayerPool> pumpEpisode(
  WidgetTester tester,
  PlayerPoolState state, {
  Episode? episode,
}) async {
  final pool = FakePlayerPool(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playerPoolProvider.overrideWith(() => pool)],
      child: MaterialApp(
        home: ShimmerScope(
          child: EpisodePage(episode: episode ?? fakeEpisode(1)),
        ),
      ),
    ),
  );
  return pool;
}

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
      await tester.pump(const Duration(milliseconds: 300));

      expect(pool.calls, ['toggle ep-01']);
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
    });

    testWidgets('marks a locked episode as premium', (tester) async {
      await pumpEpisode(
        tester,
        const PlayerPoolState(),
        episode: fakeEpisode(7, isPremium: true),
      );

      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('the like button toggles its state', (tester) async {
      await pumpEpisode(tester, const PlayerPoolState());

      await tester.tap(find.bySemanticsLabel('Like'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });
}
