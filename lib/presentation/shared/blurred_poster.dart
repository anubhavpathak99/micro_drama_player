import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/core/imaging/box_blur.dart';

/// Width a poster is blurred at: small enough to blur on the CPU in a
/// couple of milliseconds. The blur hides the upscaling that follows.
const int _blurWidth = 64;

/// Box radius at that width. Three passes make a sigma of about 3.5 px
/// there, which across a phone screen comes to the paywall's 20-point blur.
const int _blurRadius = 3;

/// A poster asset shrunk and heavily blurred, once and off the UI thread.
///
/// Drawn as an image it costs one texture a frame. A live [BackdropFilter]
/// over the same poster re-blurs the whole screen every frame, which on a
/// mid-range phone's GPU was the paywall's main cost.
final blurredPosterProvider = FutureProvider.autoDispose
    .family<ui.Image, String>((ref, asset) async {
      final image = await _blur(asset);
      ref.onDispose(image.dispose);
      return image;
    });

Future<ui.Image> _blur(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: _blurWidth,
  );
  final small = (await codec.getNextFrame()).image;
  codec.dispose();
  final width = small.width;
  final height = small.height;
  final rgba = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
  small.dispose();
  final pixels = rgba!.buffer.asUint8List();
  final blurred = await Isolate.run(
    () => boxBlurRgba(pixels, width, height, _blurRadius),
  );

  final buffer = await ui.ImmutableBuffer.fromUint8List(blurred);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final decoder = await descriptor.instantiateCodec();
  final image = (await decoder.getNextFrame()).image;
  decoder.dispose();
  descriptor.dispose();
  buffer.dispose();
  return image;
}

/// [asset], blurred, covering its box. Draws nothing until the blur is
/// ready, which is usually before the page scrolls into view.
class BlurredPoster extends ConsumerWidget {
  const BlurredPoster({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(blurredPosterProvider(asset))) {
        AsyncData(:final value) => RawImage(
          image: value,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
        _ => const SizedBox.shrink(),
      };
}
