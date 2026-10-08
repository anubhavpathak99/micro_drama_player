import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/tap_sequence.dart';

const Offset here = Offset(100, 200);

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

/// A finger landing at [at] ms and lifting 60 ms later.
List<TapAction> tap(TapSequence taps, int at, [Offset position = here]) {
  taps.pointerDown();
  return taps.tap(down: ms(at), up: ms(at + 60), position: position);
}

Matcher single(Offset position) =>
    isA<SingleTap>().having((t) => t.position, 'position', position);

Matcher heart(Offset position, {required bool startsCombo}) => isA<HeartTap>()
    .having((t) => t.position, 'position', position)
    .having((t) => t.startsCombo, 'startsCombo', startsCombo);

void main() {
  late TapSequence taps;

  setUp(() => taps = TapSequence());

  group('a single tap', () {
    test('waits for the window, then counts', () {
      expect(tap(taps, 0), isEmpty);

      expect(taps.windowLapsed(), [single(here)]);
    });

    test('counts once: the window lapsing again does nothing', () {
      tap(taps, 0);
      taps.windowLapsed();

      expect(taps.windowLapsed(), isEmpty);
    });

    test('waits for a finger still down when the window lapses', () {
      tap(taps, 0);
      taps.pointerDown();

      expect(taps.windowLapsed(), isEmpty);
    });

    test('goes at once when a drag or a control takes the next touch', () {
      tap(taps, 0);
      taps.pointerDown();

      expect(taps.abandon(), [single(here)]);
    });

    test('is dropped by a reset', () {
      tap(taps, 0);
      taps.reset();

      expect(taps.windowLapsed(), isEmpty);
    });
  });

  group('a double tap', () {
    test('is a second tap within 280 ms and 40 px', () {
      tap(taps, 0);

      final second = here.translate(30, 0);
      expect(tap(taps, 300, second), [heart(second, startsCombo: true)]);
      expect(taps.inCombo, isTrue);
      expect(taps.windowLapsed(), isEmpty, reason: 'no single tap left');
    });

    test('counts at exactly 280 ms and 40 px', () {
      tap(taps, 0);

      final second = here.translate(24, 32);
      expect(tap(taps, 60 + 280, second), [heart(second, startsCombo: true)]);
    });

    test('times the gap from the first lift to the second touch', () {
      taps.pointerDown();
      taps.tap(down: ms(0), up: ms(400), position: here);

      expect(tap(taps, 650), [heart(here, startsCombo: true)]);
    });

    test('lands when its finger was down as the window lapsed', () {
      tap(taps, 0);
      taps
        ..pointerDown()
        ..windowLapsed();

      expect(taps.tap(down: ms(200), up: ms(400), position: here), [
        heart(here, startsCombo: true),
      ]);
    });

    test('is not a second tap 281 ms later: two single taps', () {
      tap(taps, 0);

      expect(tap(taps, 60 + 281), [single(here)]);
      expect(taps.windowLapsed(), [single(here)]);
    });

    test('is not a second tap 41 px away: two single taps', () {
      tap(taps, 0);

      final far = here.translate(41, 0);
      expect(tap(taps, 200, far), [single(here)]);
      expect(taps.windowLapsed(), [single(far)]);
    });
  });

  group('a combo', () {
    test('adds a heart for every rapid tap, wherever it lands', () {
      tap(taps, 0);
      tap(taps, 200);

      const elsewhere = Offset(300, 600);
      expect(tap(taps, 400, elsewhere), [heart(elsewhere, startsCombo: false)]);
      expect(tap(taps, 600), [heart(here, startsCombo: false)]);
    });

    test('ends when the taps stop for a window', () {
      tap(taps, 0);
      tap(taps, 200);

      expect(taps.windowLapsed(), isEmpty);
      expect(taps.inCombo, isFalse);
      expect(tap(taps, 1000), isEmpty, reason: 'a fresh first tap');
    });

    test('ends with a tap that comes too late', () {
      tap(taps, 0);
      tap(taps, 200);

      expect(tap(taps, 260 + 281), isEmpty);
      expect(taps.inCombo, isFalse);
      expect(taps.windowLapsed(), [single(here)]);
    });

    test('ends when a drag takes the next touch', () {
      tap(taps, 0);
      tap(taps, 200);
      taps.pointerDown();

      expect(taps.abandon(), isEmpty);
      expect(taps.inCombo, isFalse);
    });
  });
}
