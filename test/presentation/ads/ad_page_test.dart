import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/presentation/ads/ad_page.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';
import 'package:micro_drama_interactive_player/presentation/shared/shimmer.dart';

import '../../support/fake_ads.dart';

const String slotId = 'ad-after-3';

Future<FakeAdPreloader> pumpAdPage(
  WidgetTester tester,
  AdSlotStatus status,
) async {
  final preloader = FakeAdPreloader({slotId: status});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adPreloaderProvider.overrideWith(() => preloader)],
      child: MaterialApp(
        home: ShimmerScope(child: AdPage(slot: AdSlotItem.after(3))),
      ),
    ),
  );
  return preloader;
}

void main() {
  testWidgets('shows the branded skeleton while the ad loads', (tester) async {
    await pumpAdPage(tester, const AdSlotStatus(AdSlotState.loading));

    expect(find.byType(BrandedSkeleton), findsOneWidget);
    expect(find.text('Sponsored'), findsOneWidget);
  });

  testWidgets('swaps the skeleton for the ad once it has loaded', (
    tester,
  ) async {
    final preloader = await pumpAdPage(
      tester,
      const AdSlotStatus(AdSlotState.loading),
    );

    preloader.emit({
      slotId: AdSlotStatus(AdSlotState.loaded, FakeNativeAdHandle(1)),
    });
    await tester.pump();
    await tester.pump(
      MotionDurations.adNoFillFade + const Duration(milliseconds: 16),
    );

    expect(find.byKey(const ValueKey('fake-ad-1')), findsOneWidget);
    expect(find.byType(BrandedSkeleton), findsNothing);
  });

  testWidgets('fades the skeleton out when the slot fails', (tester) async {
    final preloader = await pumpAdPage(
      tester,
      const AdSlotStatus(AdSlotState.loading),
    );

    preloader.emit({slotId: const AdSlotStatus(AdSlotState.failed)});
    await tester.pump();
    await tester.pump(MotionDurations.adNoFillFade ~/ 2);
    expect(find.byType(BrandedSkeleton), findsOneWidget, reason: 'fading');

    await tester.pump(MotionDurations.adNoFillFade);
    expect(find.byType(BrandedSkeleton), findsNothing);
  });

  testWidgets('has no gesture layer of its own', (tester) async {
    await pumpAdPage(
      tester,
      AdSlotStatus(AdSlotState.shown, FakeNativeAdHandle(1)),
    );

    expect(
      find.descendant(
        of: find.byType(AdPage),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });
}
