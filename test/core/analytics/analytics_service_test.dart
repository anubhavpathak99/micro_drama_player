import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';

void main() {
  test('console analytics prints each event with its parameters', () {
    final printed = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    addTearDown(() => debugPrint = original);

    const ConsoleAnalytics()
      ..log(AnalyticsEvents.adRequest, {'slot': 'ad-after-3'})
      ..log(AnalyticsEvents.adImpression);

    expect(printed, [
      '[analytics] ad_request {slot: ad-after-3}',
      '[analytics] ad_impression',
    ]);
  });
}
