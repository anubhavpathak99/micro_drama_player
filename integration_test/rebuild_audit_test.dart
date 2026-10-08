import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'scenarios.dart';

/// Counts widget rebuilds, by widget type, during each interaction.
///
/// Rebuild tracking is a debug-mode feature, so run it in debug mode:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/rebuild_audit_test.dart -d DEVICE_ID
/// Results land in build/integration_response_data.json.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('rebuilds per interaction', (tester) async {
    final app = Scenarios(tester);
    await app.launch();
    final report = <String, Object>{};

    Future<void> count(String key, Future<void> Function() action) async {
      final counts = <String, int>{};
      debugOnRebuildDirtyWidget = (element, _) => counts.update(
        element.widget.runtimeType.toString(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      await action();
      debugOnRebuildDirtyWidget = null;
      final ranked = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      report[key] = {
        'total': counts.values.fold(0, (sum, count) => sum + count),
        'top': {for (final entry in ranked.take(30)) entry.key: entry.value},
      };
    }

    await count('idle_playback', () => app.wait(const Duration(seconds: 5)));
    await count('swipe', app.swipes);
    await count('scrub', app.scrub);
    await count('double_tap', app.doubleTapCombo);
    await app.goTo(app.itemBefore('ep-07'));
    await count('paywall', app.openPaywall);

    binding.reportData = report;
  });
}
