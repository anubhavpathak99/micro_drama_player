import 'package:flutter_test/flutter_test.dart';

import '../support/episode_fixtures.dart';

void main() {
  group('Episode', () {
    test('equal episodes share a hash code', () {
      expect(fakeEpisode(1), fakeEpisode(1));
      expect(fakeEpisode(1).hashCode, fakeEpisode(1).hashCode);
    });

    test('any field change breaks equality', () {
      expect(fakeEpisode(1), isNot(fakeEpisode(1, isPremium: true)));
      expect(fakeEpisode(1), isNot(fakeEpisode(2)));
    });
  });
}
