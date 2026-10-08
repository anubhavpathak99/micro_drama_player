import 'package:flutter/material.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';

// Ad page: full-screen ad between episodes. Episode gestures are disabled
// here; the ad's own taps and CTA stay interactive.
//
// TODO: Load and render the slot's native ad. Until then the page shows the
// skeleton an ad displays while loading.

/// The page for an ad slot.
class AdPage extends StatelessWidget {
  const AdPage({super.key, required this.slot});

  final AdSlotItem slot;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: AppColors.background),
      const BrandedSkeleton(),
      Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: EpisodeLayout.gutter,
        child: const _SponsoredTag(),
      ),
    ],
  );
}

class _SponsoredTag extends StatelessWidget {
  const _SponsoredTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x33FFFFFF),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'Sponsored',
      style: TextStyle(
        color: AppColors.onMedia,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );
}
