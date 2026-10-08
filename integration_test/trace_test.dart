import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'scenarios.dart';

/// Records a timeline per interaction, for finding what a slow frame
/// spends its time on.
///
/// Run in profile mode on a device:
///   flutter drive --profile --no-dds \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/trace_test.dart -d DEVICE_ID
/// Each timeline lands in build/integration_response_data.json.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('timelines', (tester) async {
    final app = Scenarios(tester);
    await app.launch();

    await binding.traceAction(app.scrub, reportKey: 'scrub');
    await binding.traceAction(app.doubleTapCombo, reportKey: 'double_tap');
    await app.goTo(app.itemBefore('ep-07'));
    await binding.traceAction(app.openPaywall, reportKey: 'paywall');
  });
}
