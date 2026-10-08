import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_scroll_behavior.dart';

const int finger = 1;

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

/// A tracker for [finger] that has seen [samples] as (ms, dy) pairs.
LiftAwareVelocityTracker trackerWith(
  PointerLifts lifts,
  List<(int, double)> samples,
) {
  final tracker = LiftAwareVelocityTracker(
    const PointerDownEvent(pointer: finger),
    lifts,
  );
  for (final (time, dy) in samples) {
    tracker.addPosition(ms(time), Offset(0, dy));
  }
  return tracker;
}

/// [finger] lifting at [time] ms, as the platform stamped it.
PointerLifts liftedAt(int time, {int pointer = finger}) =>
    PointerLifts()
      ..record(PointerUpEvent(pointer: pointer, timeStamp: ms(time)));

/// A swipe up at 1000 px/s, sampled every [every] ms for [span] ms.
List<(int, double)> swipe({required int every, int span = 240}) => [
  for (var time = 0; time <= span; time += every) (time, -time.toDouble()),
];

void main() {
  group('LiftAwareVelocityTracker', () {
    testWidgets("agrees with Flutter's tracker on dense, prompt input", (
      tester,
    ) async {
      final samples = swipe(every: 8);
      final plain = VelocityTracker.withKind(PointerDeviceKind.touch);
      for (final (time, dy) in samples) {
        plain.addPosition(ms(time), Offset(0, dy));
      }

      final estimate = trackerWith(
        liftedAt(242),
        samples,
      ).getVelocityEstimate();

      expect(
        estimate!.pixelsPerSecond,
        plain.getVelocityEstimate()!.pixelsPerSecond,
      );
    });

    testWidgets('flings on sparse samples when the lift came promptly', (
      tester,
    ) async {
      // A busy main thread: one sample every 60 ms.
      final tracker = trackerWith(liftedAt(245), swipe(every: 60));

      final estimate = tracker.getVelocityEstimate()!;

      expect(estimate.pixelsPerSecond.dy, closeTo(-1000, 0.001));
      expect(estimate.offset, const Offset(0, -60));
      expect(estimate.duration, ms(60));
    });

    testWidgets('flings when a prompt lift is processed late', (tester) async {
      final tracker = trackerWith(liftedAt(242), swipe(every: 10));
      // The lift reaches Dart 80 ms after the last move did.
      await tester.pump(ms(80));

      final estimate = tracker.getVelocityEstimate()!;

      expect(estimate.pixelsPerSecond.dy, closeTo(-1000, 0.001));
    });

    testWidgets('a finger that rested before lifting has no velocity', (
      tester,
    ) async {
      final tracker = trackerWith(liftedAt(360), swipe(every: 10));
      await tester.pump(ms(120));

      expect(tracker.getVelocityEstimate()!.pixelsPerSecond, Offset.zero);
    });

    testWidgets("ignores another pointer's lift", (tester) async {
      final tracker = trackerWith(
        liftedAt(245, pointer: finger + 1),
        swipe(every: 60),
      );

      expect(tracker.getVelocityEstimate()!.pixelsPerSecond, Offset.zero);
    });
  });

  group('FeedScrollBehavior', () {
    Future<VelocityTracker> trackerFor(WidgetTester tester) async {
      late BuildContext context;
      // Material behaviours take the platform from the app's theme.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (built) {
              context = built;
              return const SizedBox();
            },
          ),
        ),
      );
      return FeedScrollBehavior(PointerLifts())
          .velocityTrackerBuilder(context)(const PointerDownEvent());
    }

    testWidgets('reads Android flings with the lift-aware tracker', (
      tester,
    ) async {
      expect(await trackerFor(tester), isA<LiftAwareVelocityTracker>());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("leaves iOS to Flutter's own fling tracker", (tester) async {
      expect(
        await trackerFor(tester),
        isA<IOSScrollViewFlingVelocityTracker>(),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
