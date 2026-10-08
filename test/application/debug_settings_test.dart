import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/debug_settings.dart';

void main() {
  test('every switch starts off', () {
    final settings = ProviderContainer.test().read(debugSettingsProvider);

    expect(settings, const DebugSettings());
    expect(settings.forceAdNoFill, isFalse);
    expect(settings.slowNetwork, isFalse);
    expect(settings.performanceOverlay, isFalse);
  });

  test('each switch flips on its own', () {
    final container = ProviderContainer.test();
    final switches = container.read(debugSettingsProvider.notifier)
      ..setSlowNetwork(true);
    expect(
      container.read(debugSettingsProvider),
      const DebugSettings(slowNetwork: true),
    );

    switches
      ..setForceAdNoFill(true)
      ..setPerformanceOverlay(true)
      ..setSlowNetwork(false);
    expect(
      container.read(debugSettingsProvider),
      const DebugSettings(forceAdNoFill: true, performanceOverlay: true),
    );
  });

  test('settings compare by value', () {
    final copy = const DebugSettings().copyWith(slowNetwork: true);

    expect(copy, const DebugSettings(slowNetwork: true));
    expect(copy.hashCode, const DebugSettings(slowNetwork: true).hashCode);
    expect(copy, isNot(const DebugSettings(forceAdNoFill: true)));
  });
}
