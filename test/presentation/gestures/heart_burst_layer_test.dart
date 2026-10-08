import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/heart_burst.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/heart_burst_layer.dart';

import '../../support/finger.dart';

const int seed = 7;
const Offset middle = Offset(400, 300);
const Offset button = Offset(40, 40);

/// What the layer and the button under it reported.
class Reports {
  int singles = 0;
  int hearts = 0;
  int buttons = 0;
}

/// The layer over a page with a button in its top-left corner.
Future<Reports> pumpLayer(
  WidgetTester tester, {
  bool enabled = true,
  bool reduceMotion = false,
  bool withButton = true,
}) async {
  final reports = Reports();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: HeartBurstLayer(
            enabled: enabled,
            onSingleTap: () => reports.singles++,
            onHeart: () => reports.hearts++,
            random: math.Random(seed),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (withButton)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: () => reports.buttons++,
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return reports;
}

/// The one painter that draws every heart.
Finder painter() => find
    .descendant(
      of: find.byType(HeartBurstLayer),
      matching: find.byType(CustomPaint),
    )
    .last;

/// The sparks of the first [count] hearts the layer will make.
List<int> sparkCounts(int count) {
  final random = math.Random(seed);
  return [
    for (var i = 0; i < count; i++)
      HeartBurst.random(
        Offset.zero,
        bornAt: Duration.zero,
        random: random,
      ).sparks.length,
  ];
}

void main() {
  group('a single tap', () {
    testWidgets('counts once the double-tap window passes, not before', (
      tester,
    ) async {
      final reports = await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.tap(middle);
      await finger.wait(270);
      expect(reports.singles, 0);

      await finger.wait(20);
      expect(reports.singles, 1);
      expect(reports.hearts, 0);
    });

    testWidgets('goes at once when a swipe follows it', (tester) async {
      final reports = await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.tap(middle);
      await finger.wait(50);
      await finger.drag(middle, const Offset(0, -300));
      expect(reports.singles, 1, reason: 'well inside the window');

      await finger.wait(400);
      expect(reports.singles, 1);
      expect(reports.hearts, 0);
    });

    testWidgets('reaches assistive technologies as one immediate action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final reports = await pumpLayer(tester, withButton: false);

      final node = tester.getSemantics(find.byType(HeartBurstLayer));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);

      expect(reports.singles, 1);
      semantics.dispose();
    });
  });

  group('a double tap', () {
    testWidgets('puts up a heart instead of a single tap', (tester) async {
      final reports = await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.doubleTap(middle);
      expect(reports.hearts, 1);

      await finger.wait(400);
      expect(reports.singles, 0);
    });

    testWidgets('then every rapid tap adds a heart, wherever it lands', (
      tester,
    ) async {
      final reports = await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.doubleTap(middle);
      await finger.wait(100);
      await finger.tap(middle.translate(150, 200));
      await finger.wait(100);
      await finger.tap(middle.translate(-200, -150));

      expect(reports.hearts, 3);
      await finger.wait(400);
      expect(reports.singles, 0);
    });

    testWidgets('is not a swipe', (tester) async {
      final reports = await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.drag(middle, const Offset(0, -300));
      await finger.wait(100);
      await finger.drag(middle, const Offset(0, -300));
      await finger.wait(400);

      expect(reports.hearts, 0);
      expect(reports.singles, 0);
    });

    testWidgets('leaves a button on top its own taps', (tester) async {
      final reports = await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.doubleTap(button);
      await finger.wait(400);

      expect(reports.buttons, 2);
      expect(reports.hearts, 0);
      expect(reports.singles, 0);
    });

    testWidgets('does nothing while the layer is disabled', (tester) async {
      final reports = await pumpLayer(tester, enabled: false);
      final finger = Finger(tester);

      await finger.doubleTap(middle);
      await finger.wait(400);
      expect(reports.hearts, 0);
      expect(reports.singles, 0);

      await finger.tap(button);
      expect(reports.buttons, 1, reason: 'taps pass straight through');
    });
  });

  group('hearts', () {
    testWidgets('are painted where the finger landed, sparks and all', (
      tester,
    ) async {
      await pumpLayer(tester);
      final finger = Finger(tester);

      const landed = Offset(500, 200);
      await finger.doubleTap(landed);
      await finger.wait(100);

      expect(
        painter(),
        paintsExactlyCountTimes(#drawPath, sparkCounts(1).single + 1),
      );
      expect(
        painter(),
        paints
          ..shadow()
          ..path(includes: [landed], excludes: [landed.translate(0, 120)]),
      );
    });

    testWidgets('of a combo share the one painter', (tester) async {
      await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.doubleTap(middle);
      await finger.wait(100);
      await finger.tap(middle.translate(150, 0));
      await finger.wait(50);

      final [first, second] = sparkCounts(2);
      expect(painter(), paintsExactlyCountTimes(#drawPath, first + second + 2));
    });

    testWidgets('clear away once faded, and the ticker stops', (tester) async {
      await pumpLayer(tester);
      final finger = Finger(tester);

      await finger.doubleTap(middle);
      await finger.wait(100);
      expect(tester.hasRunningAnimations, isTrue);

      await finger.wait(900);
      expect(painter(), paintsExactlyCountTimes(#drawPath, 0));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('only fade, without sparks, under reduced motion', (
      tester,
    ) async {
      await pumpLayer(tester, reduceMotion: true);
      final finger = Finger(tester);

      await finger.doubleTap(middle);
      await finger.wait(200);

      expect(painter(), paintsExactlyCountTimes(#drawPath, 1));
    });
  });
}
