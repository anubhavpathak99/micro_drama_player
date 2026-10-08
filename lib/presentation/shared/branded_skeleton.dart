import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';
import 'package:micro_drama_interactive_player/presentation/shared/brand_mark.dart';
import 'package:micro_drama_interactive_player/presentation/shared/shimmer.dart';

/// Branded loading ghost, used instead of a spinner: the app's mark, plus
/// placeholders where the episode caption, action rail and progress track
/// will appear. A diagonal shimmer sweeps across all of it.
class BrandedSkeleton extends StatelessWidget {
  const BrandedSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: ShimmerSweep(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GhostPainter(insets: MediaQuery.paddingOf(context)),
      ),
    ),
  );
}

/// Paints the ghost's shapes in opaque white. They only provide coverage:
/// [ShimmerSweep] supplies the colors.
class _GhostPainter extends CustomPainter {
  const _GhostPainter({required this.insets});

  final EdgeInsets insets;

  static final Paint _fill = Paint()..color = const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      brandMarkPath(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: EpisodeLayout.brandMark,
          height: EpisodeLayout.brandMark,
        ),
      ),
      _fill,
    );

    final bottom = size.height - insets.bottom;

    // Caption: the episode chip above one line of title.
    const left = EpisodeLayout.gutter;
    final captionWidth =
        size.width -
        left -
        EpisodeLayout.railRight -
        EpisodeLayout.railWidth -
        EpisodeLayout.railGap;
    final titleTop =
        bottom - EpisodeLayout.captionBottom - EpisodeLayout.titleLineHeight;
    _bar(canvas, left, titleTop + 2, captionWidth * 0.72, 20);
    _bar(
      canvas,
      left,
      titleTop - EpisodeLayout.chipGap - EpisodeLayout.chipHeight,
      52,
      EpisodeLayout.chipHeight,
      radius: 6,
    );

    // Rail: two buttons, each an icon over a short label.
    final railCenter =
        size.width - EpisodeLayout.railRight - EpisodeLayout.railWidth / 2;
    var buttonTop =
        bottom - EpisodeLayout.railBottom - EpisodeLayout.railButtonHeight;
    for (var i = 0; i < 2; i++) {
      final iconTop = buttonTop + EpisodeLayout.railButtonPadding;
      canvas.drawCircle(
        Offset(railCenter, iconTop + EpisodeLayout.railIcon / 2),
        EpisodeLayout.railIcon / 2 + 2,
        _fill,
      );
      final labelTop =
          iconTop + EpisodeLayout.railIcon + EpisodeLayout.railLabelGap;
      _bar(canvas, railCenter - 14, labelTop + 4, 28, 8);
      buttonTop -= EpisodeLayout.railButtonHeight + EpisodeLayout.railSpacing;
    }

    // Progress track.
    _bar(
      canvas,
      left,
      bottom - EpisodeLayout.progressBottom - EpisodeLayout.progressHeight,
      size.width - left * 2,
      EpisodeLayout.progressHeight,
    );
  }

  void _bar(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height, {
    double? radius,
  }) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      Radius.circular(radius ?? height / 2),
    ),
    _fill,
  );

  @override
  bool shouldRepaint(_GhostPainter oldDelegate) => oldDelegate.insets != insets;
}
