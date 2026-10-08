import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/engagement_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/presentation/player/action_rail.dart';

import '../../support/fake_ads.dart';

/// The rail for ep-01, logging into the returned analytics.
Future<FakeAnalytics> pumpRail(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final analytics = FakeAnalytics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [analyticsProvider.overrideWithValue(analytics)],
      child: const MaterialApp(
        home: Center(child: ActionRail(episodeId: 'ep-01')),
      ),
    ),
  );
  return analytics;
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ActionRail)));

double likeScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(RailToggle).first,
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  testWidgets('like pops with a spring and swaps its icon at once', (
    tester,
  ) async {
    await pumpRail(tester);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(likeScale(tester), isNot(moreOrLessEquals(1, epsilon: 0.01)));
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(likeScale(tester), 1);
  });

  testWidgets('under reduced motion the icons crossfade, with no spring', (
    tester,
  ) async {
    await pumpRail(tester, reduceMotion: true);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(MotionDurations.reducedMotionFade ~/ 2);

    expect(likeScale(tester), 1);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.pump(MotionDurations.reducedMotionFade);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('a tap likes the episode and logs it from the button', (
    tester,
  ) async {
    final analytics = await pumpRail(tester);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump(const Duration(seconds: 1));

    expect(containerOf(tester).read(likedEpisodesProvider), {'ep-01'});
    expect(analytics.parametersOf('like'), [
      {'episode': 'ep-01', 'liked': true, 'source': 'button'},
    ]);
  });

  testWidgets('screen readers see toggle buttons they can press', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRail(tester);

    expect(
      tester.getSemantics(find.byType(RailToggle).first),
      isSemantics(
        label: 'Like',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Save'));
    await tester.pump(const Duration(seconds: 1));

    expect(containerOf(tester).read(savedEpisodesProvider), {'ep-01'});
    expect(
      tester.getSemantics(find.byType(RailToggle).last),
      isSemantics(label: 'Save', isToggled: true),
    );
    semantics.dispose();
  });
}
