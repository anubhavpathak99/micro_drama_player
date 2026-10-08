import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_state.dart';
import 'package:video_player/video_player.dart';

import '../../support/fake_video.dart';

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

/// An initialized 15 s video at [position].
Future<FakeVideoController> video({
  int position = 3000,
  bool playing = false,
}) async {
  final controller = FakeVideoController('ep-01', fromFile: true);
  await controller.initialize();
  controller.value = controller.value.copyWith(
    position: ms(position),
    isPlaying: playing,
  );
  return controller;
}

double fractionOf(int milliseconds) => milliseconds / 15000;

void main() {
  group('scrub geometry', () {
    test('an edge is either end of the video', () {
      expect(ScrubEdge.of(0), ScrubEdge.start);
      expect(ScrubEdge.of(1), ScrubEdge.end);
      expect(ScrubEdge.of(0.5), ScrubEdge.none);
    });

    test("the track's width spans the whole video", () {
      expect(scrubTargetAfter(0.5, 32.8, 328), moreOrLessEquals(0.6));
      expect(scrubTargetAfter(0.5, -164, 328), 0);
    });

    test('a target stops at the ends and leaves them at once', () {
      expect(scrubTargetAfter(0.9, 100, 328), 1);
      expect(scrubTargetAfter(1, -32.8, 328), moreOrLessEquals(0.9));
      expect(scrubTargetAfter(0, -50, 328), 0);
    });

    test('a track with no width leaves the target alone', () {
      expect(scrubTargetAfter(0.4, 20, 0), 0.4);
    });

    test('the bubble centres on the finger, 16 px clear of each side', () {
      expect(bubbleLeft(fingerX: 200, width: 100, span: 360), 150);
      expect(bubbleLeft(fingerX: 20, width: 100, span: 360), 16);
      expect(bubbleLeft(fingerX: 350, width: 100, span: 360), 244);
      expect(bubbleLeft(fingerX: 180, width: 400, span: 360), 16);
    });
  });

  group('ScrubState playhead', () {
    testWidgets("follows the player's position reports while playing", (
      tester,
    ) async {
      final scrub = ScrubState(vsync: tester);
      final controller = await video(playing: true);
      scrub.attach(controller);
      // Let the track's fade-in finish.
      await tester.pump();
      await tester.pump(MotionDurations.medium + ms(50));

      expect(scrub.played, fractionOf(3000));
      controller.value = controller.value.copyWith(position: ms(3300));
      expect(scrub.played, fractionOf(3300));

      // No ticker of its own: playback costs no extra frames.
      expect(tester.hasRunningAnimations, isFalse);

      scrub.dispose();
    });

    testWidgets('sits on the reported position while paused', (tester) async {
      final scrub = ScrubState(vsync: tester);
      scrub.attach(await video());

      await tester.pump();
      await tester.pump(ms(500));

      expect(scrub.played, fractionOf(3000));
      expect(tester.hasRunningAnimations, isFalse);

      scrub.dispose();
    });

    testWidgets('a scrub shows its target until the final seek lands', (
      tester,
    ) async {
      final scrub = ScrubState(vsync: tester);
      final controller = await video(playing: true);
      scrub.attach(controller);

      scrub.begin(target: 0.5, fingerX: 100, reduceMotion: false);
      expect(scrub.played, 0.5);
      scrub.move(target: 0.7, fingerX: 140);
      expect(scrub.played, 0.7);

      scrub.release(reduceMotion: false);
      controller.value = controller.value.copyWith(position: ms(3000));
      expect(scrub.played, 0.7, reason: 'the old position never flashes');

      await controller.seekTo(ms(10500));
      scrub.settled();
      expect(scrub.played, moreOrLessEquals(0.7));
      expect(scrub.scrubbing, isFalse);

      scrub.dispose();
    });
  });

  group('ScrubState springs', () {
    testWidgets('the track opens for a scrub and closes after it', (
      tester,
    ) async {
      final scrub = ScrubState(vsync: tester);
      scrub.attach(await video());

      scrub.begin(target: 0.2, fingerX: 100, reduceMotion: false);
      await tester.pump();
      await tester.pump(ms(100));
      expect(scrub.expansion, inExclusiveRange(0, 1));
      // The bubble's bouncier spring takes about a second to settle.
      await tester.pump(ms(1100));
      expect(scrub.expansion, 1);
      expect(scrub.bubble.value, 1);

      scrub.release(reduceMotion: false);
      await tester.pump();
      await tester.pump(ms(600));
      expect(scrub.expansion, 0);
      expect(scrub.bubble.value, 0);

      scrub.dispose();
    });

    testWidgets('the bubble springs in a little past full size', (
      tester,
    ) async {
      final scrub = ScrubState(vsync: tester);
      scrub.attach(await video());
      var peak = 0.0;
      scrub.bubble.addListener(() {
        if (scrub.bubble.value > peak) peak = scrub.bubble.value;
      });

      scrub.begin(target: 0.2, fingerX: 100, reduceMotion: false);
      await tester.pump();
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(ms(16));
      }

      expect(peak, inExclusiveRange(1, 1.15));

      scrub.dispose();
    });

    testWidgets('under reduced motion they fade instead of springing', (
      tester,
    ) async {
      final scrub = ScrubState(vsync: tester);
      scrub.attach(await video());
      var peak = 0.0;
      scrub.bubble.addListener(() {
        if (scrub.bubble.value > peak) peak = scrub.bubble.value;
      });

      scrub.begin(target: 0.2, fingerX: 100, reduceMotion: true);
      await tester.pump();
      await tester.pump(MotionDurations.reducedMotionFade);

      expect(scrub.expansion, 1);
      expect(peak, 1, reason: 'no overshoot');

      scrub.dispose();
    });

    testWidgets('the track fades in when its player arrives', (tester) async {
      final scrub = ScrubState(vsync: tester);
      expect(scrub.presence, 0);

      scrub.attach(await video());
      await tester.pump();
      await tester.pump(MotionDurations.medium);
      expect(scrub.presence, 1);

      scrub.attach(null);
      expect(scrub.presence, 0);

      scrub.dispose();
    });

    testWidgets('stays quiet during playback', (tester) async {
      final scrub = ScrubState(vsync: tester);
      final controller = await video(playing: true);
      scrub.attach(controller);
      // Let the track's fade-in finish.
      await tester.pump();
      await tester.pump(MotionDurations.medium + ms(50));
      var changes = 0;
      Listenable.merge([scrub, scrub.finger, scrub.bubble])
          .addListener(() => changes++);

      for (var report = 1; report <= 10; report++) {
        controller.value = controller.value.copyWith(
          position: ms(3000 + 100 * report),
        );
        await tester.pump(ms(100));
      }

      // The track repaints from the player itself; nothing here moves.
      expect(changes, 0);

      scrub.dispose();
    });
  });

  test('the scrub geometry reads VideoPlayerValue durations', () {
    // Guards the units the bar works in: a fraction of the duration.
    const value = VideoPlayerValue(duration: Duration(seconds: 15));
    expect(value.duration * 0.2, const Duration(seconds: 3));
  });
}
