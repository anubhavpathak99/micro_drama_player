import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/presentation/shared/blurred_poster.dart';

// Decoding and blurring run for real, so they must start inside runAsync:
// work started on the test's fake clock would never finish.

const String poster = 'assets/posters/ep-01.jpg';

/// Blurs [poster] for real, holding it with the returned subscription.
Future<(ProviderSubscription<AsyncValue<ui.Image>>, ui.Image)> blurPoster(
  WidgetTester tester,
  ProviderContainer container,
) async => (await tester.runAsync(() async {
  final subscription = container.listen(
    blurredPosterProvider(poster),
    (_, _) {},
  );
  return (
    subscription,
    await container.read(blurredPosterProvider(poster).future),
  );
}))!;

void main() {
  testWidgets('blurs a poster down to a small image', (tester) async {
    final (_, image) = await blurPoster(tester, ProviderContainer.test());

    // The 720×1280 poster at 64 px wide.
    expect(image.width, 64);
    expect(image.height, 113);
  });

  testWidgets('draws the blur, and frees it once nothing shows it', (
    tester,
  ) async {
    final container = ProviderContainer.test();
    final (subscription, image) = await blurPoster(tester, container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BlurredPoster(asset: poster),
      ),
    );
    subscription.close();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(image));

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SizedBox()),
    );
    await tester.pump();
    expect(image.debugDisposed, isTrue);
  });

  testWidgets('draws nothing while the blur is on its way', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blurredPosterProvider.overrideWith(
            (ref, asset) => Completer<ui.Image>().future,
          ),
        ],
        child: const BlurredPoster(asset: poster),
      ),
    );

    expect(find.byType(RawImage), findsNothing);
  });
}
