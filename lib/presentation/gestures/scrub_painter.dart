import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/scrub_state.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';
import 'package:video_player/video_player.dart';

/// The progress track: the whole video faintly, what is buffered a little
/// lighter, the played part in the accent colour, and a thumb while
/// scrubbing.
///
/// It repaints straight from the player and the scrub, so playback rebuilds
/// no widgets. The track runs along the canvas's vertical centre, inset by
/// [EpisodeLayout.gutter] on both sides; give it a [RepaintBoundary].
class ScrubPainter extends CustomPainter {
  ScrubPainter({required this.controller, required this.scrub})
    : super(repaint: Listenable.merge([controller, scrub]));

  final VideoPlayerController controller;
  final ScrubState scrub;

  static const Color _shade = Color(0x33000000);
  static const Color _track = Color(0x40FFFFFF);
  static const Color _buffered = Color(0x73FFFFFF);
  static const Color _thumbHalo = Color(0x40000000);

  @override
  void paint(Canvas canvas, Size size) {
    final value = controller.value;
    final duration = value.duration.inMicroseconds;
    final presence = scrub.presence;
    if (!value.isInitialized || duration <= 0 || presence <= 0) return;

    final expansion = scrub.expansion;
    final height = lerpDouble(
      EpisodeLayout.progressHeight,
      EpisodeLayout.progressHeightScrubbing,
      expansion,
    )!;
    const left = EpisodeLayout.gutter;
    final width = size.width - left * 2;
    final centre = size.height / 2;
    final played = scrub.played;

    Paint paint(Color color) =>
        Paint()..color = color.withValues(alpha: color.a * presence);
    RRect span(double from, double to, {double grow = 0}) => RRect.fromLTRBR(
      left + width * from - grow,
      centre - height / 2 - grow,
      left + width * to + grow,
      centre + height / 2 + grow,
      Radius.circular(height / 2 + grow),
    );
    double fraction(Duration time) =>
        (time.inMicroseconds / duration).clamp(0.0, 1.0);

    // A faint shade around the track keeps it legible on bright video.
    canvas
      ..drawRRect(span(0, 1, grow: 1), paint(_shade))
      ..drawRRect(span(0, 1), paint(_track));
    for (final range in value.buffered) {
      canvas.drawRRect(
        span(fraction(range.start), fraction(range.end)),
        paint(_buffered),
      );
    }
    if (played > 0) canvas.drawRRect(span(0, played), paint(AppColors.accent));

    final thumb = EpisodeLayout.scrubThumbRadius * expansion;
    if (thumb > 0) {
      final at = Offset(left + width * played, centre);
      // A plain halo, not a blurred shadow: a blur would cost a render pass
      // every frame the thumb shows.
      canvas
        ..drawCircle(at, thumb + 1.5, paint(_thumbHalo))
        ..drawCircle(at, thumb, paint(AppColors.onMedia));
    }
  }

  @override
  bool shouldRepaint(ScrubPainter oldDelegate) =>
      !identical(oldDelegate.controller, controller) ||
      !identical(oldDelegate.scrub, scrub);
}
