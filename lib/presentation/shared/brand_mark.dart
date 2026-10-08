import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';

/// The app's mark, filling [rect]: a rounded badge with a play glyph cut
/// out of it.
Path brandMarkPath(Rect rect) {
  final side = rect.shortestSide;
  final center = rect.center;
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(side * 0.28)))
    ..moveTo(center.dx - side * 0.12, center.dy - side * 0.19)
    ..lineTo(center.dx + side * 0.2, center.dy)
    ..lineTo(center.dx - side * 0.12, center.dy + side * 0.19)
    ..close();
}

/// The brand mark at [size], in [color].
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 24, this.color = AppColors.onMedia});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _BrandMarkPainter(color));
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    brandMarkPath(Offset.zero & size),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
