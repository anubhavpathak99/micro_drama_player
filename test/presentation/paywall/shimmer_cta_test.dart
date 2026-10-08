import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/shimmer_cta.dart';

Future<void> pumpCta(
  WidgetTester tester, {
  CtaPhase phase = CtaPhase.idle,
  VoidCallback? onPressed,
  bool shimmer = true,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: ShimmerCta(
            label: 'Unlock Episode',
            phase: phase,
            onPressed: onPressed,
            shimmer: shimmer,
          ),
        ),
      ),
    ),
  ),
);

double pressScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(ShimmerCta),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  testWidgets('shows its label and reports taps', (tester) async {
    var taps = 0;
    await pumpCta(tester, onPressed: () => taps++);

    await tester.tap(find.text('Unlock Episode'));
    await tester.pump(const Duration(seconds: 1));

    expect(taps, 1);
  });

  testWidgets('sinks while held and springs back on release', (tester) async {
    await pumpCta(tester, onPressed: () {});

    final press = await tester.startGesture(
      tester.getCenter(find.byType(ShimmerCta)),
    );
    // Tap-down lands after the press timeout; the spring starts next frame.
    await tester.pump(kPressTimeout);
    await tester.pump(const Duration(milliseconds: 400));
    expect(pressScale(tester), moreOrLessEquals(0.95, epsilon: 0.01));

    await press.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(pressScale(tester), 1);
  });

  testWidgets('sweeps only during the first 30% of every 3 s', (tester) async {
    await pumpCta(tester);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(ShaderMask), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('does not sweep when held back', (tester) async {
    await pumpCta(tester, shimmer: false);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), findsNothing);
    }
  });

  testWidgets('does not sweep under reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpCta(tester);

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('becomes an inert spinner while busy', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCta(tester, phase: CtaPhase.busy);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Unlock Episode'), findsNothing);
    expect(find.bySemanticsLabel('Unlocking'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AnimatedContainer)),
      const Size.square(56),
    );
    semantics.dispose();
  });

  testWidgets('turns into a checkmark when done', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCta(tester, phase: CtaPhase.busy);
    await pumpCta(tester, phase: CtaPhase.done);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('Unlocked'), findsOneWidget);
    semantics.dispose();
  });
}
