import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Creates video controllers: the single place that sets player options, and
/// a seam that lets tests count and fake every controller.
abstract interface class VideoControllerFactory {
  VideoPlayerController fromFile(File file);

  VideoPlayerController fromNetwork(Uri url);
}

final class DefaultVideoControllerFactory implements VideoControllerFactory {
  const DefaultVideoControllerFactory();

  // The clips are silent, so they must not interrupt the user's own audio.
  static VideoPlayerOptions get _options =>
      VideoPlayerOptions(mixWithOthers: true);

  @override
  VideoPlayerController fromFile(File file) =>
      VideoPlayerController.file(file, videoPlayerOptions: _options);

  @override
  VideoPlayerController fromNetwork(Uri url) =>
      VideoPlayerController.networkUrl(url, videoPlayerOptions: _options);
}

final Provider<VideoControllerFactory> videoControllerFactoryProvider =
    Provider((ref) => const DefaultVideoControllerFactory());
