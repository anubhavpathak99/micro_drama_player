import 'package:flutter/material.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/presentation/player/action_rail.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_layout.dart';

/// Chrome drawn over an episode: legibility scrims, the caption (episode
/// number and title) and the action rail. Only the rail takes taps; taps
/// anywhere else fall through to the page.
class EpisodeOverlay extends StatelessWidget {
  const EpisodeOverlay({super.key, required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: _Scrims()),
        Positioned(
          left: EpisodeLayout.gutter,
          right:
              EpisodeLayout.railRight +
              EpisodeLayout.railWidth +
              EpisodeLayout.railGap,
          bottom: insets.bottom + EpisodeLayout.captionBottom,
          child: IgnorePointer(child: _Caption(episode: episode)),
        ),
        Positioned(
          right: EpisodeLayout.railRight,
          bottom: insets.bottom + EpisodeLayout.railBottom,
          child: ActionRail(episodeId: episode.id),
        ),
      ],
    );
  }
}

const List<Shadow> _textShadows = [
  Shadow(color: AppColors.scrim, blurRadius: 12),
];

class _Caption extends StatelessWidget {
  const _Caption({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _Chip(label: 'EP ${episode.number}'),
      const SizedBox(height: EpisodeLayout.chipGap),
      Text(
        episode.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.onMedia,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: EpisodeLayout.titleLineHeight / 20,
          shadows: _textShadows,
        ),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: EpisodeLayout.chipHeight,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0x33FFFFFF),
      borderRadius: BorderRadius.circular(6),
    ),
    // widthFactor 1 keeps the chip as wide as its label.
    child: Center(
      widthFactor: 1,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.onMedia,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    ),
  );
}

/// Top and bottom gradients that keep white text legible on bright video.
class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      SizedBox(
        height: 140,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0x00000000)],
            ),
          ),
        ),
      ),
      Spacer(),
      SizedBox(
        height: 320,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x8C000000)],
            ),
          ),
        ),
      ),
    ],
  );
}
