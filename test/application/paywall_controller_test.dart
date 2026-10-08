import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

import '../support/episode_fixtures.dart';

void main() {
  final premium = fakeEpisode(7, isPremium: true);

  group('PaywallState', () {
    test('locks premium episodes by default', () {
      const paywall = PaywallState();

      expect(paywall.isLocked(premium), isTrue);
      expect(paywall.isLocked(fakeEpisode(6)), isFalse);
    });

    test('keeps the lock while the unlock is in flight', () {
      final paywall = PaywallState(
        unlocks: {premium.id: UnlockState.unlocking},
      );

      expect(paywall.isLocked(premium), isTrue);
    });

    test('lifts the lock once unlocked', () {
      final paywall = PaywallState(unlocks: {premium.id: UnlockState.unlocked});

      expect(paywall.isLocked(premium), isFalse);
    });
  });
}
