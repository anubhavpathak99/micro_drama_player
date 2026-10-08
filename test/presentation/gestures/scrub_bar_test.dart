import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_bar.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_painter.dart';

import '../../support/fake_video.dart';
import '../../support/finger.dart';

/// What the bar asked of the player.
class ScrubLog {
  /// The player under the bar, when there is one.
  FakeVideoController? controller;
  int starts = 0;
  final List<int> seeks = [];
  final List<int> ends = [];
}

/// A [ScrubBar] over an 800 px wide page (a 768 px track), on a 15 s video
/// at 3 s: the playhead starts at 0.2. Like an episode in the feed, it sits
/// on the first page of a vertical [PageView].
Future<ScrubLog> pumpBar(
  WidgetTester tester, {
  bool withPlayer = true,
  bool accessibleNavigation = false,
}) async {
  if (accessibleNavigation) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final log = ScrubLog();
  final controller = log.controller = FakeVideoController(
    'ep-01',
    fromFile: true,
  );
  await controller.initialize();
  controller.value = controller.value.copyWith(
    position: const Duration(seconds: 3),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: PageView(
        scrollDirection: Axis.vertical,
        children: [
          ScrubBar(
            controller: withPlayer ? controller : null,
            onScrubStart: () => log.starts++,
            onSeek: (position) => log.seeks.add(position.inMilliseconds),
            onScrubEnd: (position) async =>
                log.ends.add(position.inMilliseconds),
            child: const ColoredBox(color: Colors.black),
          ),
          const ColoredBox(color: Colors.white),
        ],
      ),
    ),
  );
  return log;
}

Finder bubbleWith(String time) => find
    .ancestor(of: find.text(time), matching: find.byType(DecoratedBox))
    .first;

/// Records haptic feedback for the rest of the test.
List<Object?> recordHaptics(WidgetTester tester) {
  final haptics = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}

void main() {
  testWidgets('a horizontal drag scrubs: one start, then an exact end', (
    tester,
  ) async {
    final log = await pumpBar(tester);
    final finger = Finger(tester);

    // Five 38.4 px moves: the first wins the drag from the feed, the other
    // four move the target by 0.2 of the video, to 0.4 of 15 s.
    await finger.drag(const Offset(400, 300), const Offset(192, 0));
    await finger.wait(100);

    expect(log.starts, 1);
    expect(log.ends, [6000]);
    expect(log.seeks, isNotEmpty);
    expect(log.seeks.last, lessThan(6000), reason: 'the end is exact');
  });

  testWidgets('seeks at most every 80 ms while the finger moves', (
    tester,
  ) async {
    final log = await pumpBar(tester);
    final gesture = await tester.startGesture(const Offset(100, 300));
    final seekTimes = <int>[];
    var now = 0;

    for (var frame = 0; frame < 30; frame++) {
      await gesture.moveBy(const Offset(12, 0));
      final before = log.seeks.length;
      await tester.pump(const Duration(milliseconds: 16));
      now += 16;
      for (var i = before; i < log.seeks.length; i++) {
        seekTimes.add(now);
      }
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));

    expect(log.seeks.length, inInclusiveRange(4, 8));
    for (var i = 1; i < seekTimes.length; i++) {
      expect(seekTimes[i] - seekTimes[i - 1], greaterThanOrEqualTo(64));
    }
    expect(log.ends, hasLength(1));
  });

  testWidgets('the time bubble follows the finger', (tester) async {
    await pumpBar(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    // A tenth of the track: 0.2 + 0.1 of 15 s is 4.5 s.
    await gesture.moveBy(const Offset(76.8, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:04 / 00:15'), findsOneWidget);
    expect(
      tester.getRect(bubbleWith('00:04 / 00:15')).center.dx,
      moreOrLessEquals(400 + 30 + 76.8, epsilon: 1),
    );

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the time bubble keeps 16 px clear of the screen edge', (
    tester,
  ) async {
    await pumpBar(tester);
    final gesture = await tester.startGesture(const Offset(80, 300));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-45, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 45 px back from 3 s: 0.2 - 45 / 768 of 15 s is 2.1 s.
    expect(
      tester.getRect(bubbleWith('00:02 / 00:15')).left,
      moreOrLessEquals(16, epsilon: 0.5),
    );

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('each end of the video ticks once', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpBar(tester);
    final gesture = await tester.startGesture(const Offset(100, 300));
    await gesture.moveBy(const Offset(20, 0));

    for (var frame = 0; frame < 10; frame++) {
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(haptics, hasLength(1), reason: 'still held at the end');

    for (var frame = 0; frame < 12; frame++) {
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('leaves vertical drags to the feed', (tester) async {
    final log = await pumpBar(tester);

    await Finger(tester).drag(const Offset(400, 300), const Offset(0, -400));
    await tester.pump(const Duration(seconds: 1));

    expect(log.starts, 0);
    expect(find.byType(ScrubBar).hitTestable(), findsNothing, reason: 'paged');
  });

  testWidgets('without a player there is no track and no scrubbing', (
    tester,
  ) async {
    final log = await pumpBar(tester, withPlayer: false);

    await Finger(tester).drag(const Offset(400, 300), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 100));

    expect(log.starts, 0);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is ScrubPainter,
      ),
      findsNothing,
    );
  });

  testWidgets('a scrub whose player goes away still ends', (tester) async {
    final log = ScrubLog();
    final controller = FakeVideoController('ep-01', fromFile: true);
    await controller.initialize();
    addTearDown(controller.dispose);
    Widget bar(FakeVideoController? player) => MaterialApp(
      home: ScrubBar(
        controller: player,
        onScrubStart: () => log.starts++,
        onSeek: (position) => log.seeks.add(position.inMilliseconds),
        onScrubEnd: (position) async => log.ends.add(position.inMilliseconds),
        child: const ColoredBox(color: Colors.black),
      ),
    );
    await tester.pumpWidget(bar(controller));
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(log.starts, 1);

    await tester.pumpWidget(bar(null));
    await tester.pump(const Duration(seconds: 1));

    expect(log.ends, hasLength(1), reason: 'playback is never left held');
    await gesture.up();
  });

  group('accessibility', () {
    final slider = find.semantics.byLabel('Playback position');

    testWidgets('reads as a slider with the time and 5 s steps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Playback position')),
        isSemantics(
          isSlider: true,
          value: '00:03 of 00:15',
          increasedValue: '00:08 of 00:15',
          decreasedValue: '00:00 of 00:15',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('increase and decrease scrub by 5 s, within the video', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final log = await pumpBar(tester);

      tester.semantics.increase(slider);
      await tester.pump();
      tester.semantics.decrease(slider);
      await tester.pump();

      expect(log.starts, 2, reason: 'each step holds playback like a drag');
      expect(log.ends, [8000, 0]);
      expect(log.seeks, isEmpty, reason: 'one exact seek per step');
      semantics.dispose();
    });

    testWidgets('the value follows playback while a screen reader is on', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final log = await pumpBar(tester, accessibleNavigation: true);
      final controller = log.controller!;

      controller.value = controller.value.copyWith(
        position: const Duration(milliseconds: 7400),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Playback position')),
        isSemantics(value: '00:07 of 00:15'),
      );
      semantics.dispose();
    });

    testWidgets('otherwise playback does not rebuild the semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final log = await pumpBar(tester);
      final controller = log.controller!;

      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 7),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Playback position')),
        isSemantics(value: '00:03 of 00:15'),
      );
      semantics.dispose();
    });

    testWidgets('without a player there is no slider', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, withPlayer: false);

      expect(find.bySemanticsLabel('Playback position'), findsNothing);
      semantics.dispose();
    });
  });
}
