import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';

/// Pumps a probe under the app's MediaQuery, with or without the scope,
/// and returns what it read on its last build.
Future<bool Function()> pumpProbe(
  WidgetTester tester, {
  bool scoped = true,
}) async {
  late bool reduceMotion;
  final probe = Builder(
    builder: (context) {
      reduceMotion = context.reduceMotion;
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    MediaQuery.fromView(
      view: tester.view,
      child: scoped ? ReducedMotionScope(child: probe) : probe,
    ),
  );
  return () => reduceMotion;
}

void useFeatures(WidgetTester tester, FakeAccessibilityFeatures features) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = features;
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  testWidgets("Android's Remove animations reduces motion", (tester) async {
    useFeatures(
      tester,
      const FakeAccessibilityFeatures(disableAnimations: true),
    );

    final reduceMotion = await pumpProbe(tester);

    expect(reduceMotion(), isTrue);
  });

  testWidgets("the scope adds iOS's Reduce Motion, which MediaQuery lacks", (
    tester,
  ) async {
    useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));

    expect((await pumpProbe(tester, scoped: false))(), isFalse);
    expect((await pumpProbe(tester))(), isTrue);
  });

  testWidgets('follows Reduce Motion as it changes', (tester) async {
    final reduceMotion = await pumpProbe(tester);
    expect(reduceMotion(), isFalse);

    useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));
    await tester.pump();
    expect(reduceMotion(), isTrue);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(reduceMotion(), isFalse);
  });
}
