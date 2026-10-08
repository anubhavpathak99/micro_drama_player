import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/app.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/data/video_cache.dart';
import 'package:micro_drama_interactive_player/data/video_controller_factory.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';

import 'support/fake_ads.dart';
import 'support/fake_unlocks.dart';
import 'support/fake_video.dart';

void main() {
  testWidgets('boots into the feed on the bundled first episode', (
    tester,
  ) async {
    final factory = FakeVideoControllerFactory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoCacheProvider.overrideWithValue(FakeVideoCache()),
          unlockRepositoryProvider.overrideWithValue(FakeUnlockRepository()),
          videoControllerFactoryProvider.overrideWithValue(factory),
          adRepositoryProvider.overrideWithValue(FakeAdRepository()),
          analyticsProvider.overrideWithValue(FakeAnalytics()),
        ],
        child: const MicroDramaApp(),
      ),
    );
    // Settles with a video playing: playback schedules no frames of its own.
    await tester.pumpAndSettle();

    expect(find.byType(FeedScreen), findsOneWidget);
    expect(find.text('Back in the City'), findsOneWidget);
    expect(factory.liveFor('1227')?.value.isPlaying, isTrue);
  });
}
