import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';

/// Where a flag was flipped from.
enum FlagSource {
  /// The rail's button.
  button,

  /// A double tap on the video.
  doubleTap,
}

/// A set of episode ids the user has switched on, such as likes or saves.
class EpisodeFlags extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Flips the flag for [episodeId].
  void toggle(String episodeId, {FlagSource source = FlagSource.button}) {
    final on = !state.contains(episodeId);
    state = on ? {...state, episodeId} : ({...state}..remove(episodeId));
    didChange(episodeId, on: on, source: source);
  }

  /// Switches the flag on for [episodeId]; a no-op when it already is.
  void add(String episodeId, {FlagSource source = FlagSource.button}) {
    if (state.contains(episodeId)) return;
    state = {...state, episodeId};
    didChange(episodeId, on: true, source: source);
  }

  /// The flag for [episodeId] changed to [on].
  void didChange(
    String episodeId, {
    required bool on,
    required FlagSource source,
  }) {}
}

/// Likes, which are logged as they change.
class LikedEpisodes extends EpisodeFlags {
  @override
  void didChange(
    String episodeId, {
    required bool on,
    required FlagSource source,
  }) => ref.read(analyticsProvider).log(AnalyticsEvents.like, {
    'episode': episodeId,
    'liked': on,
    'source': switch (source) {
      FlagSource.button => 'button',
      FlagSource.doubleTap => 'double_tap',
    },
  });
}

/// Episodes the user liked.
final NotifierProvider<LikedEpisodes, Set<String>> likedEpisodesProvider =
    NotifierProvider(LikedEpisodes.new);

/// Episodes the user saved to their list.
final NotifierProvider<EpisodeFlags, Set<String>> savedEpisodesProvider =
    NotifierProvider(EpisodeFlags.new);
