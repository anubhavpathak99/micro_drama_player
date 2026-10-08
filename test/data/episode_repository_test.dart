import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';

Map<String, Object?> validEntry([Map<String, Object?> overrides = const {}]) =>
    {
      'id': 'ep-01',
      'number': 1,
      'title': 'Pilot',
      'videoUrl': 'https://example.com/ep-01.mp4',
      'poster': 'assets/posters/ep-01.jpg',
      'durationMs': 15000,
      'premium': false,
      ...overrides,
    };

String catalogOf(List<Map<String, Object?>> entries) =>
    jsonEncode({'episodes': entries});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled catalog', () {
    late List<Episode> episodes;

    setUpAll(() async {
      episodes = await AssetEpisodeRepository().fetchEpisodes();
    });

    test('has episodes 1 to 10 with unique ids', () {
      expect(
        [for (final e in episodes) e.number],
        [for (var n = 1; n <= 10; n++) n],
      );
      expect({for (final e in episodes) e.id}, hasLength(10));
    });

    test('paywalls episode 7 only', () {
      expect(
        [
          for (final e in episodes)
            if (e.isPremium) e.number,
        ],
        [7],
      );
    });

    test('streams short clips over HTTPS', () {
      for (final episode in episodes) {
        expect(episode.videoUrl.scheme, 'https', reason: episode.id);
        expect(
          episode.duration,
          lessThanOrEqualTo(const Duration(seconds: 20)),
          reason: episode.id,
        );
      }
    });

    test('bundles a poster for every episode', () async {
      for (final episode in episodes) {
        final poster = await rootBundle.load(episode.posterAsset);
        expect(poster.lengthInBytes, greaterThan(0), reason: episode.id);
      }
    });
  });

  group('parseEpisodeCatalog', () {
    test('maps every field', () {
      final [episode] = parseEpisodeCatalog(
        catalogOf([
          validEntry({'premium': true}),
        ]),
      );

      expect(
        episode,
        Episode(
          id: 'ep-01',
          number: 1,
          title: 'Pilot',
          videoUrl: Uri.parse('https://example.com/ep-01.mp4'),
          posterAsset: 'assets/posters/ep-01.jpg',
          duration: const Duration(seconds: 15),
          isPremium: true,
        ),
      );
    });

    test('sorts episodes by number', () {
      final episodes = parseEpisodeCatalog(
        catalogOf([
          validEntry({'id': 'ep-02', 'number': 2}),
          validEntry(),
        ]),
      );

      expect([for (final e in episodes) e.id], ['ep-01', 'ep-02']);
    });

    test('rejects a catalog without an episodes list', () {
      for (final source in ['[]', '{}', '{"episodes": {}}', 'null']) {
        expect(
          () => parseEpisodeCatalog(source),
          throwsFormatException,
          reason: source,
        );
      }
    });

    test('rejects malformed entries', () {
      final broken = <String, Object?>{
        'not an object': 'ep-01',
        'missing title': validEntry()..remove('title'),
        'number as string': validEntry({'number': '1'}),
        'zero number': validEntry({'number': 0}),
        'empty id': validEntry({'id': ''}),
        'non-positive duration': validEntry({'durationMs': 0}),
        'premium as string': validEntry({'premium': 'yes'}),
        'http video': validEntry({'videoUrl': 'http://example.com/a.mp4'}),
        'relative video': validEntry({'videoUrl': '/videos/a.mp4'}),
      };

      for (final MapEntry(key: reason, value: entry) in broken.entries) {
        expect(
          () => parseEpisodeCatalog(
            jsonEncode({
              'episodes': [entry],
            }),
          ),
          throwsFormatException,
          reason: reason,
        );
      }
    });

    test('rejects duplicate ids', () {
      final source = catalogOf([
        validEntry(),
        validEntry({'number': 2}),
      ]);

      expect(() => parseEpisodeCatalog(source), throwsFormatException);
    });

    test('rejects duplicate numbers', () {
      final source = catalogOf([
        validEntry(),
        validEntry({'id': 'ep-02'}),
      ]);

      expect(() => parseEpisodeCatalog(source), throwsFormatException);
    });

    test('returns an unmodifiable list', () {
      final episodes = parseEpisodeCatalog(catalogOf([validEntry()]));

      expect(episodes.clear, throwsUnsupportedError);
    });
  });
}
