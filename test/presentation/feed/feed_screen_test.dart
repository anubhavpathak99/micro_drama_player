import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_page.dart';
import 'package:micro_drama_interactive_player/presentation/shared/app_route_observer.dart';

import '../../support/episode_fixtures.dart';
import '../../support/fake_video.dart';

Future<FakePlayerPool> pumpFeed(WidgetTester tester) async {
  final pool = FakePlayerPool();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(
          FakeEpisodeRepository(fakeEpisodes()),
        ),
        playerPoolProvider.overrideWith(() => pool),
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

String currentId(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FeedScreen)))
        .read(feedControllerProvider)
        .value!
        .currentId;

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

    await tester.tap(find.text('DEV'));
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
}
