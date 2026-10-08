import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/domain/playback_time.dart';

void main() {
  test('reads minutes and seconds, zero-padded', () {
    expect(formatPlaybackTime(Duration.zero), '00:00');
    expect(formatPlaybackTime(const Duration(seconds: 5)), '00:05');
    expect(formatPlaybackTime(const Duration(seconds: 15)), '00:15');
    expect(formatPlaybackTime(const Duration(minutes: 1, seconds: 5)), '01:05');
    expect(
      formatPlaybackTime(const Duration(minutes: 59, seconds: 59)),
      '59:59',
    );
  });

  test('adds hours from an hour up', () {
    expect(formatPlaybackTime(const Duration(hours: 1)), '1:00:00');
    expect(
      formatPlaybackTime(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '2:03:04',
    );
  });

  test('rounds down to the whole second', () {
    expect(formatPlaybackTime(const Duration(milliseconds: 5999)), '00:05');
  });

  test('reads a negative time as zero', () {
    expect(formatPlaybackTime(const Duration(seconds: -3)), '00:00');
  });
}
