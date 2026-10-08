import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lays the test out on a 360×800 phone (1080×2400 at 3×) instead of the
/// default 800×600 landscape window.
void usePhoneSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
