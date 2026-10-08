import 'dart:typed_data';

/// Blurs RGBA [pixels] ([width] × [height]) with [passes] box blurs of
/// [radius] along each axis. Three passes come close to a gaussian with a
/// sigma of about `radius + 0.5`. Edge pixels repeat outwards, so a frame
/// doesn't darken at its borders.
///
/// Pure and allocation-light, so it can run in a background isolate.
Uint8List boxBlurRgba(
  Uint8List pixels,
  int width,
  int height,
  int radius, {
  int passes = 3,
}) {
  assert(pixels.length == width * height * 4, 'Expected RGBA pixels');
  final result = Uint8List.fromList(pixels);
  if (radius <= 0 || width == 0 || height == 0) return result;
  final scratch = Uint8List(result.length);
  for (var pass = 0; pass < passes; pass++) {
    _blurLines(result, scratch, width, height, radius, horizontal: true);
    _blurLines(scratch, result, width, height, radius, horizontal: false);
  }
  return result;
}

/// One box blur of every row (or column) of [from] into [to].
void _blurLines(
  Uint8List from,
  Uint8List to,
  int width,
  int height,
  int radius, {
  required bool horizontal,
}) {
  final lines = horizontal ? height : width;
  final length = horizontal ? width : height;
  // Byte distance between neighbours along a line, and between lines.
  final along = horizontal ? 4 : width * 4;
  final across = horizontal ? width * 4 : 4;
  final window = radius * 2 + 1;
  int at(int index) => index < 0
      ? 0
      : index >= length
      ? length - 1
      : index;

  for (var line = 0; line < lines; line++) {
    final start = line * across;
    for (var channel = 0; channel < 4; channel++) {
      final base = start + channel;
      var sum = 0;
      for (var i = -radius; i <= radius; i++) {
        sum += from[base + at(i) * along];
      }
      for (var i = 0; i < length; i++) {
        to[base + i * along] = (sum + window ~/ 2) ~/ window;
        sum +=
            from[base + at(i + radius + 1) * along] -
            from[base + at(i - radius) * along];
      }
    }
  }
}
