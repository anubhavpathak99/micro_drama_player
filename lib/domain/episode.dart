/// One episode of the micro-drama series.
///
/// The feed keys pages and assigns players by [id], so an episode keeps its
/// page and its player no matter where it sits in the feed. Equality compares
/// every field, so a metadata change still reaches listeners.
final class Episode {
  const Episode({
    required this.id,
    required this.number,
    required this.title,
    required this.videoUrl,
    required this.posterAsset,
    required this.duration,
    this.isPremium = false,
  });

  /// Stable identifier, such as `ep-07`.
  final String id;

  /// 1-based position in the series. Ads never take a number.
  final int number;

  final String title;

  /// Remote MP4 to stream.
  final Uri videoUrl;

  /// Bundled poster: the video's first frame, available offline.
  final String posterAsset;

  /// Duration from the catalog. Once a player has loaded the video, its own
  /// duration is authoritative.
  final Duration duration;

  /// Whether the episode stays behind the paywall until it is unlocked.
  final bool isPremium;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Episode &&
          other.id == id &&
          other.number == number &&
          other.title == title &&
          other.videoUrl == videoUrl &&
          other.posterAsset == posterAsset &&
          other.duration == duration &&
          other.isPremium == isPremium;

  @override
  int get hashCode => Object.hash(
    id,
    number,
    title,
    videoUrl,
    posterAsset,
    duration,
    isPremium,
  );

  @override
  String toString() => 'Episode($id, #$number${isPremium ? ', premium' : ''})';
}
