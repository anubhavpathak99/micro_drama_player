import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';

import 'scenarios.dart';

/// Frame timings per interaction, then memory over three full feed passes.
///
/// Run in profile mode on a device:
///   flutter drive --profile --driver=test_driver/integration_test.dart \
///     --target=integration_test/perf_test.dart -d DEVICE_ID
/// Results land in build/integration_response_data.json.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame timings and memory', (tester) async {
    final app = Scenarios(tester);
    await app.launch();

    await binding.watchPerformance(
      () => app.wait(const Duration(seconds: 5)),
      reportKey: 'idle_playback',
    );
    await binding.watchPerformance(app.swipes, reportKey: 'swipe');
    await binding.watchPerformance(app.scrub, reportKey: 'scrub');
    await binding.watchPerformance(app.doubleTapCombo, reportKey: 'double_tap');
    await app.goTo(app.itemBefore('ep-07'));
    await binding.watchPerformance(app.openPaywall, reportKey: 'paywall');

    // Three passes over the whole feed, the locked episode opened up.
    final paywall = app.container.read(paywallControllerProvider.notifier);
    await paywall.unlock('ep-07');
    await app.wait(const Duration(seconds: 3));
    final samples = [app.memorySample('before passes')];
    for (var pass = 1; pass <= 3; pass++) {
      await app.goTo(app.feed.items.last.id);
      await app.goTo(app.feed.items.first.id);
      await app.wait(const Duration(seconds: 3));
      samples.add(app.memorySample('after pass $pass'));
    }
    (binding.reportData ??= {})['memory'] = samples;

    await paywall.reset();
  });
}
