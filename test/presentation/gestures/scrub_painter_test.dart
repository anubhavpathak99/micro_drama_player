import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_painter.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_state.dart';
import 'package:video_player/video_player.dart';

import '../../support/fake_video.dart';

// A 360 × 30 canvas: the track runs from x 16 to 344 along y 15.
const double width = 360;
const double left = 16;
const double track = width - left * 2;
const double centre = 15;

/// The track's rounded rect from [from] to [to], [height] thick.
RRect span(double from, double to, {double height = 3, double grow = 0}) =>
    RRect.fromLTRBR(
      left + track * from - grow,
      centre - height / 2 - grow,
      left + track * to + grow,
      centre + height / 2 + grow,
      Radius.circular(height / 2 + grow),
    );

/// A 15 s video at 3 s with its first 9 s buffered, under [ScrubPainter],
/// faded in.
Future<ScrubState> pumpTrack(
  WidgetTester tester, {
  bool initialized = true,
}) async {
  final controller = FakeVideoController('ep-01', fromFile: true);
  if (initialized) {
    await controller.initialize();
    controller.value = controller.value.copyWith(
      position: const Duration(seconds: 3),
      buffered: [DurationRange(Duration.zero, const Duration(seconds: 9))],
    );
  }
  final scrub = ScrubState(vsync: tester)..attach(controller);
  await tester.pumpWidget(
    Center(
      child: SizedBox(
        width: width,
        height: centre * 2,
        child: CustomPaint(
          painter: ScrubPainter(controller: controller, scrub: scrub),
        ),
      ),
    ),
  );
  await tester.pump(MotionDurations.medium);
  return scrub;
}

void main() {
  testWidgets('draws the track, the buffered part lighter, then the played '
      'part', (tester) async {
    final scrub = await pumpTrack(tester);

    expect(
      find.byType(CustomPaint),
      paints
        ..rrect(rrect: span(0, 1, grow: 1), color: const Color(0x33000000))
        ..rrect(rrect: span(0, 1), color: const Color(0x40FFFFFF))
        ..rrect(rrect: span(0, 0.6), color: const Color(0x73FFFFFF))
        ..rrect(rrect: span(0, 0.2), color: AppColors.accent),
    );
    expect(find.byType(CustomPaint), isNot(paints..circle()));

    scrub.dispose();
  });

  testWidgets('while scrubbing, opens to 10 px with a thumb at the target', (
    tester,
  ) async {
    final scrub = await pumpTrack(tester);

    scrub.begin(target: 0.5, fingerX: 100, reduceMotion: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byType(CustomPaint),
      paints
        ..rrect(rrect: span(0, 1, height: 10, grow: 1))
        ..rrect(rrect: span(0, 1, height: 10))
        ..rrect(rrect: span(0, 0.6, height: 10))
        ..rrect(rrect: span(0, 0.5, height: 10), color: AppColors.accent)
        ..circle(radius: 10.5, hasMaskFilter: false)
        ..circle(
          x: left + track * 0.5,
          y: centre,
          radius: 9,
          color: AppColors.onMedia,
        ),
    );

    scrub.release(reduceMotion: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CustomPaint), isNot(paints..circle()));

    scrub.dispose();
  });

  testWidgets('paints nothing until the player is ready', (tester) async {
    final scrub = await pumpTrack(tester, initialized: false);

    expect(find.byType(CustomPaint), paintsNothing);

    scrub.dispose();
  });
}
