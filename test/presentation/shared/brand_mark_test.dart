import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/shared/brand_mark.dart';

void main() {
  test('cuts a play glyph out of a rounded badge', () {
    final path = brandMarkPath(const Rect.fromLTWH(0, 0, 100, 100));

    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 100, 100));
    expect(path.contains(const Offset(10, 50)), isTrue, reason: 'badge');
    expect(path.contains(const Offset(50, 50)), isFalse, reason: 'glyph');
    expect(path.contains(const Offset(1, 1)), isFalse, reason: 'corner');
  });

  testWidgets('paints the mark in its color, and repaints in a new one', (
    tester,
  ) async {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);

    await tester.pumpWidget(const Center(child: BrandMark(color: red)));
    expect(tester.getSize(find.byType(BrandMark)), const Size.square(24));
    expect(find.byType(BrandMark), paints..path(color: red));

    await tester.pumpWidget(const Center(child: BrandMark(color: blue)));
    expect(find.byType(BrandMark), paints..path(color: blue));
  });
}
