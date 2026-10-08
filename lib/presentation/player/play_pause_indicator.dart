import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';

/// A play glyph that pops in while the user has paused, and shrinks away
/// when playback resumes.
class PlayPauseIndicator extends StatefulWidget {
  const PlayPauseIndicator({super.key, required this.paused});

  final bool paused;

  @override
  State<PlayPauseIndicator> createState() => _PlayPauseIndicatorState();
}

class _PlayPauseIndicatorState extends State<PlayPauseIndicator>
    with SingleTickerProviderStateMixin {
  // Unbounded, so the spring can overshoot full size.
  late final AnimationController _presence = AnimationController.unbounded(
    vsync: this,
    value: widget.paused ? 1 : 0,
  );

  @override
  void didUpdateWidget(PlayPauseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused == oldWidget.paused) return;
    final target = widget.paused ? 1.0 : 0.0;
    if (context.reduceMotion) {
      unawaited(_presence.animateTo(target, duration: MotionDurations.fast));
    } else {
      unawaited(
        _presence.animateWith(
          SpringSimulation(
            widget.paused ? MotionSprings.bouncy : MotionSprings.snappy,
            _presence.value,
            target,
            0,
            snapToEnd: true,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleFrom = context.reduceMotion ? 1.0 : 0.6;
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _presence,
          builder: (context, glyph) {
            final presence = _presence.value;
            if (presence <= 0) return const SizedBox.shrink();
            return Opacity(
              opacity: presence.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scaleFrom + (1 - scaleFrom) * presence,
                child: glyph,
              ),
            );
          },
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 72,
            color: Color(0xD9FFFFFF),
            semanticLabel: 'Paused',
            shadows: [Shadow(color: AppColors.scrim, blurRadius: 16)],
          ),
        ),
      ),
    );
  }
}
