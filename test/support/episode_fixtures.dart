import 'package:micro_drama_interactive_player/domain/episode.dart';

/// A test episode with the catalog's id scheme (`ep-07`).
Episode fakeEpisode(int number, {bool isPremium = false}) {
  final id = 'ep-${number.toString().padLeft(2, '0')}';
  return Episode(
    id: id,
    number: number,
    title: 'Episode $number',
    videoUrl: Uri.parse('https://example.com/$id.mp4'),
    posterAsset: 'assets/posters/$id.jpg',
    duration: const Duration(seconds: 15),
    isPremium: isPremium,
  );
}

/// Episodes 1 to [count] in order, with episode 7 premium like the catalog.
List<Episode> fakeEpisodes([int count = 10]) => [
  for (var number = 1; number <= count; number++)
    fakeEpisode(number, isPremium: number == 7),
];
