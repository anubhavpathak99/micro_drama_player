import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:video_player/video_player.dart';

/// Renders a pooled controller with cover fit, fading in over the poster
/// once the first frame has been rendered.
///
/// The poster is the video's first frame, so the handoff is invisible: the
/// fade only hides the blank texture a player shows before decoding.
class VideoSurface extends StatefulWidget {
  const VideoSurface({super.key, required this.controller});

  /// Must be initialized. Key the widget by controller, so a new controller
  /// starts hidden again.
  final VideoPlayerController controller;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  final ValueNotifier<bool> _hasFrame = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkFirstFrame);
    _checkFirstFrame();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkFirstFrame);
    _hasFrame.dispose();
    super.dispose();
  }

  // The plugin has no first-frame event. Position only moves past zero once
  // frames are being decoded, so the first such tick is the signal.
  void _checkFirstFrame() {
    final value = widget.controller.value;
    if (value.isInitialized && value.position > Duration.zero) {
      _hasFrame.value = true;
      widget.controller.removeListener(_checkFirstFrame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.controller.value.size;
    return ValueListenableBuilder<bool>(
      valueListenable: _hasFrame,
      builder: (context, hasFrame, video) => AnimatedOpacity(
        opacity: hasFrame ? 1 : 0,
        duration: MotionDurations.posterCrossfade,
        curve: MotionCurves.fade,
        child: video,
      ),
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(widget.controller),
        ),
      ),
    );
  }
}
