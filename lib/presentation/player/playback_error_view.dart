import 'package:flutter/material.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';

/// Shown in place when an episode can't be played: the dimmed poster stays
/// visible behind a message and a retry button.
class PlaybackErrorView extends StatelessWidget {
  const PlaybackErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.scrim,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: AppColors.onMediaMuted,
          ),
          const SizedBox(height: 12),
          Text(
            "Couldn't play this episode",
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.onMedia),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
