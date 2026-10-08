import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/gestures/seek_throttle.dart';

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  late List<int> seeks;
  late SeekThrottle throttle;

  // Each test cancels the throttle before it ends: a widget test may not
  // finish with a timer pending.
  setUp(() {
    seeks = [];
    throttle = SeekThrottle((position) => seeks.add(position.inMilliseconds));
  });

  testWidgets('seeks at once, then once per 80 ms to the latest position', (
    tester,
  ) async {
    throttle.request(ms(1000));
    expect(seeks, [1000]);

    await tester.pump(ms(30));
    throttle.request(ms(1100));
    await tester.pump(ms(30));
    throttle.request(ms(1200));
    expect(seeks, [1000], reason: 'cooling down');

    await tester.pump(ms(20));
    expect(seeks, [1000, 1200], reason: 'the latest, skipping 1100');

    await tester.pump(ms(80));
    expect(seeks, [1000, 1200], reason: 'nothing waiting');

    throttle.request(ms(1500));
    expect(seeks, [1000, 1200, 1500], reason: 'idle again: at once');
    throttle.cancel();
  });

  testWidgets('keeps a steady drag to about one seek per 80 ms', (
    tester,
  ) async {
    // A finger reporting every 16 ms for 320 ms.
    for (var frame = 0; frame < 20; frame++) {
      throttle.request(ms(1000 + 50 * frame));
      await tester.pump(ms(16));
    }
    await tester.pump(ms(80));

    expect(seeks.length, inInclusiveRange(4, 6));
    expect(seeks.last, 1000 + 50 * 19, reason: 'ends on the latest');
    throttle.cancel();
  });

  testWidgets('cancel drops a seek that is still waiting', (tester) async {
    throttle
      ..request(ms(1000))
      ..request(ms(2000))
      ..cancel();
    await tester.pump(ms(200));

    expect(seeks, [1000]);
  });
}
