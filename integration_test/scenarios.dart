import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/core/diagnostics/lifecycle_log.dart';
import 'package:micro_drama_interactive_player/main.dart' as app;
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';

/// Drives the real app (real players, real test ads) through the
/// interactions the performance audit measures.
class Scenarios {
  Scenarios(this.tester);

  final WidgetTester tester;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(FeedScreen)));

  FeedState get feed => container.read(feedControllerProvider).value!;

  /// The feed item just before [id], whatever ads are left around it.
  String itemBefore(String id) => feed.items[feed.indexOf(id) - 1].id;

  Future<void> launch() async {
    await app.main();
    // The first episode starts and the first ad slot loads.
    await wait(const Duration(seconds: 6));
  }

  /// Lets real time pass while frames keep coming.
  Future<void> wait(Duration duration) => tester.pump(duration);

  Future<void> swipe({bool forward = true}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(0, forward ? -600 : 600),
      2500,
    );
    await wait(const Duration(milliseconds: 800));
  }

  /// Swipes until [id] is the current page.
  Future<void> goTo(String id) async {
    for (var swipes = 0; swipes < 30 && feed.currentId != id; swipes++) {
      await swipe(forward: feed.indexOf(id) > feed.currentIndex);
    }
    expect(feed.currentId, id);
  }

  /// Four swipes down the feed (across the first ad) and four back up.
  Future<void> swipes() async {
    for (var page = 0; page < 4; page++) {
      await swipe();
    }
    for (var page = 0; page < 4; page++) {
      await swipe(forward: false);
    }
  }

  /// A scrub forward, then one back.
  Future<void> scrub() async {
    final page = find.byType(PageView);
    await tester.timedDrag(
      page,
      const Offset(320, 0),
      const Duration(milliseconds: 900),
    );
    await wait(const Duration(milliseconds: 600));
    await tester.timedDrag(
      page,
      const Offset(-240, 0),
      const Duration(milliseconds: 700),
    );
    await wait(const Duration(seconds: 1));
  }

  /// A double tap, then two more taps of combo, then the hearts fade.
  Future<void> doubleTapCombo() async {
    final centre = tester.getCenter(find.byType(PageView));
    for (final offset in const [
      Offset.zero,
      Offset.zero,
      Offset(80, -120),
      Offset(-90, 140),
    ]) {
      await tester.tapAt(centre + offset);
      await wait(const Duration(milliseconds: 90));
    }
    await wait(const Duration(milliseconds: 1500));
  }

  /// From the page before the locked episode: onto the paywall, its
  /// entrance and a shimmer sweep of the Unlock button.
  Future<void> openPaywall() async {
    await swipe();
    await wait(const Duration(seconds: 3));
  }

  /// Memory and live native objects right now.
  Map<String, Object> memorySample(String label) => {
    'label': label,
    'rss_mb': _megabytes(ProcessInfo.currentRss),
    'image_cache_mb': _megabytes(
      PaintingBinding.instance.imageCache.currentSizeBytes,
    ),
    'live_players': LifecycleLog.live(LifecycleKind.player),
    'live_ads': LifecycleLog.live(LifecycleKind.ad),
    'players_created': LifecycleLog.created(LifecycleKind.player),
    'ads_created': LifecycleLog.created(LifecycleKind.ad),
  };

  static double _megabytes(int bytes) =>
      (bytes / (1024 * 1024) * 10).roundToDouble() / 10;
}
