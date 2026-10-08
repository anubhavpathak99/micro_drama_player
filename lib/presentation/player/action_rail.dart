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

class _RailToggleState extends State<RailToggle>
    with SingleTickerProviderStateMixin {
  // Unbounded, so the spring can overshoot full size.
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static const List<Shadow> _shadows = [
    Shadow(color: AppColors.scrim, blurRadius: 8),
  ];

  @override
  void didUpdateWidget(RailToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !context.reduceMotion) {
      unawaited(
        _scale.animateWith(SpringSimulation(MotionSprings.bouncy, 0.7, 1, 0)),
      );
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _handleTap() {
    unawaited(Haptics.toggle());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: widget.active,
    label: widget.label,
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
              child: Icon(
                widget.active ? widget.activeIcon : widget.icon,
                size: EpisodeLayout.railIcon,
                color: widget.active ? widget.activeColor : AppColors.onMedia,
                shadows: _shadows,
              ),
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
