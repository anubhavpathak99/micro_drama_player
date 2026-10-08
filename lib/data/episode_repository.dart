import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';

/// Source of the episode catalog.
abstract interface class EpisodeRepository {
  /// Every episode, in playback order.
  Future<List<Episode>> fetchEpisodes();
}

/// Reads the catalog bundled with the app at [assetPath].
final class AssetEpisodeRepository implements EpisodeRepository {
  AssetEpisodeRepository({
    AssetBundle? bundle,
    this.assetPath = defaultAssetPath,
  }) : _bundle = bundle ?? rootBundle;

  static const String defaultAssetPath = 'assets/episodes.json';

  final AssetBundle _bundle;
  final String assetPath;

  @override
  Future<List<Episode>> fetchEpisodes() async =>
      parseEpisodeCatalog(await _bundle.loadString(assetPath));
}

/// The app's [EpisodeRepository]. Tests override it.
final Provider<EpisodeRepository> episodeRepositoryProvider = Provider(
  (ref) => AssetEpisodeRepository(),
);

/// Parses catalog JSON into an unmodifiable list sorted by episode number.
///
/// Throws a [FormatException] for a malformed entry, a video URL that is not
/// absolute HTTPS, or a duplicate id or number. Everything downstream keys
/// off episode ids, so they must be unique.
List<Episode> parseEpisodeCatalog(String source) {
  final entries = switch (jsonDecode(source)) {
    {'episodes': final List<Object?> entries} => entries,
    _ => throw const FormatException(
      'The catalog must be an object with an "episodes" list',
    ),
  };
  final episodes = [for (final entry in entries) _parseEpisode(entry)]
    ..sort((a, b) => a.number.compareTo(b.number));

  final ids = <String>{};
  final numbers = <int>{};
  for (final episode in episodes) {
    if (!ids.add(episode.id)) {
      throw FormatException('Duplicate episode id "${episode.id}"');
    }
    if (!numbers.add(episode.number)) {
      throw FormatException('Duplicate episode number ${episode.number}');
    }
  }
  return List.unmodifiable(episodes);
}

Episode _parseEpisode(Object? json) => switch (json) {
  {
    'id': final String id,
    'number': final int number,
    'title': final String title,
    'videoUrl': final String videoUrl,
    'poster': final String poster,
    'durationMs': final int durationMs,
    'premium': final bool premium,
  }
      when id.isNotEmpty && number > 0 && durationMs > 0 =>
    Episode(
      id: id,
      number: number,
      title: title,
      videoUrl: _parseHttpsUrl(videoUrl),
      posterAsset: poster,
      duration: Duration(milliseconds: durationMs),
      isPremium: premium,
    ),
  _ => throw FormatException('Invalid episode entry', json),
};

Uri _parseHttpsUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) {
    throw FormatException('Video URL must be absolute HTTPS', raw);
  }
  return uri;
}
