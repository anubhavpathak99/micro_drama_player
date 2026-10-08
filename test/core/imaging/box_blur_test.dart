import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/imaging/box_blur.dart';

/// A [width] × [height] RGBA image, every pixel [rgba].
Uint8List filled(int width, int height, List<int> rgba) =>
    Uint8List.fromList([for (var i = 0; i < width * height; i++) ...rgba]);

int channel(Uint8List pixels, int width, int x, int y, int channel) =>
    pixels[(y * width + x) * 4 + channel];

void main() {
  test('leaves a flat image as it is, borders included', () {
    final image = filled(9, 7, [200, 120, 40, 255]);

    expect(boxBlurRgba(image, 9, 7, 3), image);
  });

  test('a radius of zero changes nothing', () {
    final image = filled(4, 4, [0, 0, 0, 255]);
    image[0] = 255;

    expect(boxBlurRgba(image, 4, 4, 0), image);
  });

  test('spreads a bright point evenly in every direction', () {
    const size = 21;
    final image = filled(size, size, [0, 0, 0, 255]);
    const centre = size ~/ 2;
    image[(centre * size + centre) * 4] = 255;

    final blurred = boxBlurRgba(image, size, size, 2);

    int red(int x, int y) => channel(blurred, size, x, y, 0);
    expect(red(centre, centre), lessThan(255));
    expect(red(centre + 3, centre), greaterThan(0));
    expect(red(centre + 3, centre), red(centre - 3, centre));
    expect(red(centre, centre + 3), red(centre, centre - 3));
    expect(red(centre + 3, centre), red(centre, centre + 3));
    expect(red(0, 0), 0, reason: 'too far to reach');
  });

  test('keeps the total brightness of a point well inside the frame', () {
    const size = 31;
    final image = filled(size, size, [0, 0, 0, 255]);
    image[(15 * size + 15) * 4] = 255;

    final blurred = boxBlurRgba(image, size, size, 2);
    var total = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        total += channel(blurred, size, x, y, 0);
      }
    }

    // Rounding each pass costs a little, never much.
    expect(total, inInclusiveRange(200, 300));
  });

  test('blurs each channel on its own and does not touch the input', () {
    final image = filled(5, 1, [10, 20, 30, 255]);
    final copy = Uint8List.fromList(image);
    image.setRange(8, 12, [250, 20, 30, 255]);
    final input = Uint8List.fromList(image);

    final blurred = boxBlurRgba(image, 5, 1, 1);

    expect(image, input);
    expect(channel(blurred, 5, 2, 0, 0), greaterThan(10));
    expect(channel(blurred, 5, 2, 0, 1), 20);
    expect(channel(blurred, 5, 2, 0, 3), 255);
    expect(copy, isNot(image));
  });
}
