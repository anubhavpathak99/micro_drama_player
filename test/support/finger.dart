import 'package:flutter_test/flutter_test.dart';

/// Taps and drags whose pointer timestamps follow the test clock.
///
/// The tester's own taps stamp every event with zero, which can't tell a
/// double tap from two taps a second apart.
class Finger {
  Finger(this.tester);

  final WidgetTester tester;
  Duration _now = Duration.zero;

  /// Lets [milliseconds] pass, on the clock and in the timestamps, a 16 ms
  /// frame at a time.
  Future<void> wait(int milliseconds) async {
    for (var left = milliseconds; left > 0; left -= _frame) {
      final step = Duration(milliseconds: left < _frame ? left : _frame);
      await tester.pump(step);
      _now += step;
    }
  }

  static const int _frame = 16;

  /// Lands at [at] and lifts 50 ms later.
  Future<void> tap(Offset at) async {
    final gesture = await tester.createGesture();
    await gesture.down(at, timeStamp: _now);
    await wait(50);
    await gesture.up(timeStamp: _now);
  }

  /// Two taps at [at], the second landing 100 ms after the first lifts.
  Future<void> doubleTap(Offset at) async {
    await tap(at);
    await wait(100);
    await tap(at);
  }

  /// Presses at [from] and drags [by] over 80 ms.
  Future<void> drag(Offset from, Offset by) async {
    final gesture = await tester.createGesture();
    await gesture.down(from, timeStamp: _now);
    for (var step = 0; step < 5; step++) {
      await wait(16);
      await gesture.moveBy(by / 5, timeStamp: _now);
    }
    await gesture.up(timeStamp: _now);
  }
}
