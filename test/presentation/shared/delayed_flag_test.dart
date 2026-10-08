import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/shared/delayed_flag.dart';

const Duration delay = Duration(milliseconds: 150);
const Duration minimumOn = Duration(milliseconds: 300);

/// Runs [body] on fake time with a fresh flag, then disposes it. testWidgets
/// rejects timers still pending when the body ends, so disposal must happen
/// inside the body.
void testFlag(
  String description,
  Future<void> Function(WidgetTester tester, DelayedFlag flag) body,
) {
  testWidgets(description, (tester) async {
    final flag = DelayedFlag(delay: delay, minimumOn: minimumOn);
    await body(tester, flag);
    flag.dispose();
  });
}

void main() {
  testFlag('turns on only after the delay', (tester, flag) async {
    flag.update(true);

    await tester.pump(const Duration(milliseconds: 149));
    expect(flag.value, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(flag.value, isTrue);
  });

  testFlag('a wait shorter than the delay never shows', (tester, flag) async {
    flag.update(true);
    await tester.pump(const Duration(milliseconds: 100));

    flag.update(false);
    await tester.pump(const Duration(seconds: 1));

    expect(flag.value, isFalse);
  });

  testFlag('stays on for the minimum time once shown', (tester, flag) async {
    flag.update(true);
    await tester.pump(delay);

    flag.update(false);
    await tester.pump(const Duration(milliseconds: 299));
    expect(flag.value, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    expect(flag.value, isFalse);
  });

  testFlag('turns off at once after the minimum time', (tester, flag) async {
    flag.update(true);
    await tester.pump(delay + minimumOn);

    flag.update(false);

    expect(flag.value, isFalse);
  });

  testFlag('stays on when the input returns during the hold', (
    tester,
    flag,
  ) async {
    flag.update(true);
    await tester.pump(delay);

    flag
      ..update(false)
      ..update(true);
    await tester.pump(const Duration(seconds: 1));

    expect(flag.value, isTrue);
  });
}
