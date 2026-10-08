import 'package:flutter/material.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';

// Feed screen: the vertical PageView of episodes and ads.
//
// TODO: Replace the placeholder with PageView.custom (SliverChildBuilderDelegate,
// findChildIndexCallback, ValueKey(item.id)) and the paywall lock physics.

/// Placeholder until the feed is built.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(
        'MICRO DRAMA',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: AppColors.onMediaMuted, letterSpacing: 6),
      ),
    ),
  );
}
