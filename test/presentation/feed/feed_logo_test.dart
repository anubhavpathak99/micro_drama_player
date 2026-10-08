import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_logo.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_video.dart';

Future<FakePlayerPool> pumpLogo(WidgetTester tester) async {
  final pool = FakePlayerPool();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        playerPoolProvider.overrideWith(() => pool),
      ],
      child: const MaterialApp(home: Center(child: FeedLogo())),
    ),
  );
  return pool;
}

double logoOpacity(WidgetTester tester) => tester
    .renderObject<RenderAnimatedOpacity>(
      find.descendant(
        of: find.byType(FeedLogo),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity
    .value;

void main() {
  testWidgets('shows the brand', (tester) async {
    await pumpLogo(tester);

    expect(find.text('Micro Drama'), findsOneWidget);
    expect(logoOpacity(tester), 1);
  });

  testWidgets('steps aside while a scrub runs, then comes back', (
    tester,
  ) async {
    final pool = await pumpLogo(tester);

    pool.emit(const PlayerPoolState(scrubbing: true));
    await tester.pump();
    await tester.pump(MotionDurations.fast);
    expect(logoOpacity(tester), 0);
    expect(find.text('Micro Drama').hitTestable(), findsNothing);

    pool.emit(const PlayerPoolState());
    await tester.pump();
    await tester.pump(MotionDurations.medium);
    expect(logoOpacity(tester), 1);
    expect(find.text('Micro Drama').hitTestable(), findsOneWidget);
  });

  testWidgets('leaves ad pages to the advertiser', (tester) async {
    await pumpLogo(tester);
    final feed = ProviderScope.containerOf(
      tester.element(find.byType(FeedLogo)),
    ).read(feedControllerProvider.notifier);

    feed.setCurrent('ad-after-3');
    await tester.pump();
    await tester.pump(MotionDurations.medium);
    expect(logoOpacity(tester), 0);
    expect(find.text('Micro Drama').hitTestable(), findsNothing);

    feed.setCurrent('ep-04');
    await tester.pump();
    await tester.pump(MotionDurations.medium);
    expect(logoOpacity(tester), 1);
  });
}
