import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';

/// The page for an ad slot: the branded skeleton while the ad loads, then
/// the ad's own full-screen native view.
///
/// There is deliberately no episode gesture layer here. Taps reach the ad
/// (its call to action), while vertical drags still page the feed.
class AdPage extends ConsumerWidget {
  const AdPage({super.key, required this.slot});

  final AdSlotItem slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      adPreloaderProvider.select((slots) => slots[slot.slotId]),
    );
    final state = status?.state ?? AdSlotState.idle;
    final ad = switch (state) {
      AdSlotState.loaded || AdSlotState.shown => status?.ad,
      _ => null,
    };

    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ad != null)
            KeyedSubtree(key: ObjectKey(ad), child: ad.buildView()),
          // Waiting: the skeleton. A failed slot fades it out while the feed
          // moves on.
          AnimatedSwitcher(
            duration: MotionDurations.adNoFillFade,
            switchInCurve: MotionCurves.fade,
            switchOutCurve: MotionCurves.fade,
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: ad == null && state != AdSlotState.failed
                ? const _AdSkeleton(key: ValueKey('skeleton'))
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ],
      ),
    );
  }
}

class _AdSkeleton extends StatelessWidget {
  const _AdSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
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
