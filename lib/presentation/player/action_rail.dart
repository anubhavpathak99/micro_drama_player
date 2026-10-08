import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/engagement_controller.dart';
import 'package:micro_drama_interactive_player/core/haptics/haptics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';

/// The right-hand column of episode actions.
class ActionRail extends ConsumerWidget {
  const ActionRail({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(
      likedEpisodesProvider.select((ids) => ids.contains(episodeId)),
    );
    final saved = ref.watch(
      savedEpisodesProvider.select((ids) => ids.contains(episodeId)),
    );
    return SizedBox(
      width: EpisodeLayout.railWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RailToggle(
            label: 'Like',
            icon: Icons.favorite_border_rounded,
            activeIcon: Icons.favorite_rounded,
            activeColor: AppColors.accent,
            active: liked,
            onPressed: () =>
                ref.read(likedEpisodesProvider.notifier).toggle(episodeId),
          ),
          const SizedBox(height: EpisodeLayout.railSpacing),
          RailToggle(
            label: 'Save',
            icon: Icons.bookmark_border_rounded,
            activeIcon: Icons.bookmark_rounded,
            activeColor: AppColors.premium,
            active: saved,
            onPressed: () =>
                ref.read(savedEpisodesProvider.notifier).toggle(episodeId),
          ),
        ],
      ),
    );
  }
}

/// A rail button that switches between an outline and a filled icon, and
/// pops with a spring when it switches on.
class RailToggle extends StatefulWidget {
  const RailToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;
  final bool active;
  final VoidCallback onPressed;

  @override
  State<RailToggle> createState() => _RailToggleState();
}

class _RailToggleState extends State<RailToggle> with TickerProviderStateMixin {
  // Unbounded, so the spring can overshoot full size.
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  // Under reduced motion the icons crossfade instead: 0 shows the outline,
  // 1 the filled icon. Preserve keeps the fade at its length when Android's
  // Remove animations is on, rather than cutting it to a single frame.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: MotionDurations.reducedMotionFade,
    value: widget.active ? 1 : 0,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    // Back to a single icon once a crossfade ends.
    _fill.addStatusListener((_) {
      if (mounted && !_fill.isAnimating) setState(() {});
    });
  }

  static const List<Shadow> _shadows = [
    Shadow(color: AppColors.scrim, blurRadius: 8),
  ];

  @override
  void didUpdateWidget(RailToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (context.reduceMotion) {
      unawaited(widget.active ? _fill.forward() : _fill.reverse());
      return;
    }
    _fill.value = widget.active ? 1 : 0;
    if (widget.active) {
      unawaited(
        _scale.animateWith(
          SpringSimulation(MotionSprings.bouncy, 0.7, 1, 0, snapToEnd: true),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _fill.dispose();
    super.dispose();
  }

  Widget _icon({required bool active}) => Icon(
    active ? widget.activeIcon : widget.icon,
    size: EpisodeLayout.railIcon,
    color: active ? widget.activeColor : AppColors.onMedia,
    shadows: _shadows,
  );

  void _handleTap() {
    unawaited(Haptics.toggle());
    widget.onPressed();
  }

  // The node carries its own tap: excludeSemantics also hides the gesture
  // detector's, which screen readers need to press the button.
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    toggled: widget.active,
    label: widget.label,
    onTap: _handleTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: EpisodeLayout.railButtonPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: _fill.isAnimating
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        FadeTransition(
                          opacity: ReverseAnimation(_fill),
                          child: _icon(active: false),
                        ),
                        FadeTransition(
                          opacity: _fill,
                          child: _icon(active: true),
                        ),
                      ],
                    )
                  : _icon(active: widget.active),
            ),
            const SizedBox(height: EpisodeLayout.railLabelGap),
            SizedBox(
              height: EpisodeLayout.railLabelHeight,
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.onMedia,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: _shadows,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
