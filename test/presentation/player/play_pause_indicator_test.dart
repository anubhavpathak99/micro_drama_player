import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/player/play_pause_indicator.dart';

Future<void> pumpIndicator(
  WidgetTester tester, {
  required bool paused,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: PlayPauseIndicator(paused: paused),
    ),
  ),
);

Finder within(Type type) => find.descendant(
  of: find.byType(PlayPauseIndicator),
  matching: find.byType(type),
);

// The x scale: Transform.scale leaves z at 1.
double glyphScale(WidgetTester tester) =>
    tester.widget<Transform>(within(Transform)).transform.entry(0, 0);

double glyphOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(within(Opacity)).opacity;

void main() {
  testWidgets('pausing pops the glyph in with a spring', (tester) async {
    await pumpIndicator(tester, paused: false);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await pumpIndicator(tester, paused: true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(glyphScale(tester), inExclusiveRange(0.6, 1));

    // The bouncy spring rings for a little over a second.
    await tester.pump(const Duration(seconds: 2));
    expect(glyphScale(tester), 1);
    expect(glyphOpacity(tester), 1);
  });

  testWidgets('under reduced motion it fades in at full size', (tester) async {
    await pumpIndicator(tester, paused: false, reduceMotion: true);

    await pumpIndicator(tester, paused: true, reduceMotion: true);
    await tester.pump(MotionDurations.fast ~/ 2);
    expect(glyphScale(tester), 1);
    expect(glyphOpacity(tester), inExclusiveRange(0, 1));

    await tester.pump(MotionDurations.fast);
    expect(glyphOpacity(tester), 1);
  });

  testWidgets('resuming takes the glyph away', (tester) async {
    await pumpIndicator(tester, paused: true);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await pumpIndicator(tester, paused: false);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });
}
