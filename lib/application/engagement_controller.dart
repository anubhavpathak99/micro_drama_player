import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A set of episode ids the user has switched on, such as likes or saves.
class EpisodeFlags extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Flips the flag for [episodeId].
  void toggle(String episodeId) => state = state.contains(episodeId)
      ? ({...state}..remove(episodeId))
      : {...state, episodeId};

  /// Switches the flag on for [episodeId]; a no-op when it already is.
  void add(String episodeId) {
    if (!state.contains(episodeId)) state = {...state, episodeId};
  }
}

/// Episodes the user liked.
final NotifierProvider<EpisodeFlags, Set<String>> likedEpisodesProvider =
    NotifierProvider(EpisodeFlags.new);

/// Episodes the user saved to their list.
final NotifierProvider<EpisodeFlags, Set<String>> savedEpisodesProvider =
    NotifierProvider(EpisodeFlags.new);
