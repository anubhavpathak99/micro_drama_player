import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'scenarios.dart';

/// Six scrubs, each timed on its own, to compare how scrubs start.
///
///   flutter drive --profile --no-dds \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/scrub_probe_test.dart -d DEVICE_ID
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('scrub starts', (tester) async {
    final app = Scenarios(tester);
    await app.launch();
    for (var scrub = 1; scrub <= 6; scrub++) {
      await binding.watchPerformance(() async {
        await tester.timedDrag(
          find.byType(PageView),
          Offset(scrub.isOdd ? 220 : -220, 0),
          const Duration(milliseconds: 600),
        );
        await app.wait(const Duration(milliseconds: 900));
      }, reportKey: 'scrub_$scrub');
    }
  });
}
