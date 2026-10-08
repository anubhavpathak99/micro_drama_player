import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/presentation/debug/debug_panel.dart';
import 'package:micro_drama_interactive_player/presentation/shared/brand_mark.dart';

/// The brand at the top of the feed. It steps aside on ad pages, which
/// belong to the advertiser (and keep their badges clear), and with the
/// episode chrome while a scrub runs.
///
/// In debug and profile builds a long press opens the debug panel. Release
/// builds have no panel unless built with `--dart-define=DEBUG_PANEL=true`,
/// as review builds are.
class FeedLogo extends ConsumerWidget {
  const FeedLogo({super.key});

  static const bool _developerOptions =
      kDebugMode || kProfileMode || bool.fromEnvironment('DEBUG_PANEL');

  static const List<Shadow> _shadows = [
    Shadow(color: AppColors.scrim, blurRadius: 8),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrubbing = ref.watch(
      playerPoolProvider.select((pool) => pool.scrubbing),
    );
    final onAd = ref.watch(
      feedControllerProvider.select(
        (feed) => feed.value?.current is AdSlotItem,
      ),
    );
    final openPanel = _developerOptions
        ? () => unawaited(openDebugPanel(context))
        : null;
    return IgnorePointer(
      ignoring: scrubbing || onAd,
      // Timed like the episode chrome: out of the way fast when a scrub
      // starts, otherwise at the usual pace.
      child: AnimatedOpacity(
        opacity: scrubbing || onAd ? 0 : 1,
        duration: scrubbing ? MotionDurations.fast : MotionDurations.medium,
        curve: MotionCurves.fade,
        child: _logo(openPanel),
      ),
    );
  }

  // One node for screen readers, carrying the long press itself:
  // excludeSemantics hides the gesture detector's.
  static Widget _logo(VoidCallback? openPanel) => Semantics(
    container: true,
    label: 'Micro Drama',
    onLongPress: openPanel,
    onLongPressHint: openPanel == null ? null : 'open developer options',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: openPanel,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 22),
            SizedBox(width: 8),
            Text(
              'Micro Drama',
              style: TextStyle(
                color: AppColors.onMedia,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                shadows: _shadows,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
