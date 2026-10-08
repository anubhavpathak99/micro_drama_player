import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/application/feed_composer.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/data/episode_repository.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

import '../support/episode_fixtures.dart';
import '../support/fake_unlocks.dart';
import '../support/fake_video.dart';

/// A container with the feed loaded and the paywall running on [unlocks].
Future<ProviderContainer> paywallOn(FakeUnlockRepository unlocks) async {
  final container = ProviderContainer.test(
    overrides: [
      episodeRepositoryProvider.overrideWithValue(
        FakeEpisodeRepository(fakeEpisodes()),
      ),
      unlockRepositoryProvider.overrideWithValue(unlocks),
    ],
  );
  container.listen(paywallControllerProvider, (_, _) {});
  await container.read(feedControllerProvider.future);
  return container;
}

void main() {
  final premium = fakeEpisode(7, isPremium: true);

  group('PaywallState', () {
    test('locks premium episodes by default', () {
      const paywall = PaywallState();

      expect(paywall.stateOf(premium), UnlockState.locked);
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

  group('firstLockedItemId', () {
    final feed = composeFeed(fakeEpisodes());

    test('is the locked premium episode', () {
      expect(firstLockedItemId(feed, const {}), 'ep-07');
    });

    test('counts an unlock in flight as locked', () {
      expect(
        firstLockedItemId(feed, {'ep-07': UnlockState.unlocking}),
        'ep-07',
      );
    });

    test('is null once nothing is locked', () {
      expect(firstLockedItemId(feed, {'ep-07': UnlockState.unlocked}), isNull);
    });

    test('moves to the next locked episode', () {
      final twoLocks = composeFeed([
        for (var n = 1; n <= 10; n++)
          fakeEpisode(n, isPremium: n == 7 || n == 9),
      ]);

      expect(firstLockedItemId(twoLocks, const {}), 'ep-07');
      expect(
        firstLockedItemId(twoLocks, {'ep-07': UnlockState.unlocked}),
        'ep-09',
      );
    });
  });

  group('PaywallController', () {
    test('starts with the premium episode locked', () async {
      final container = await paywallOn(FakeUnlockRepository());

      final paywall = container.read(paywallControllerProvider);
      expect(paywall.lockedItemId, 'ep-07');
      expect(paywall.stateOf(premium), UnlockState.locked);
    });

    test('restores a saved unlock', () async {
      final container = await paywallOn(FakeUnlockRepository({'ep-07'}));

      final paywall = container.read(paywallControllerProvider);
      expect(paywall.lockedItemId, isNull);
      expect(paywall.stateOf(premium), UnlockState.unlocked);
    });

    test('goes locked, unlocking, unlocked, and saves the unlock', () async {
      final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
      final container = await paywallOn(unlocks);
      PaywallState paywall() => container.read(paywallControllerProvider);

      final unlocking = container
          .read(paywallControllerProvider.notifier)
          .unlock('ep-07');
      expect(paywall().stateOf(premium), UnlockState.unlocking);
      expect(paywall().lockedItemId, 'ep-07');

      unlocks.purchase!.complete();
      await unlocking;
      expect(paywall().stateOf(premium), UnlockState.unlocked);
      expect(paywall().lockedItemId, isNull);
      expect(unlocks.unlockedIds(), {'ep-07'});
    });

    test('locks the episode again when the purchase fails', () async {
      final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
      final container = await paywallOn(unlocks);

      final unlocking = container
          .read(paywallControllerProvider.notifier)
          .unlock('ep-07');
      unlocks.purchase!.completeError(StateError('Store unavailable'));

      await expectLater(unlocking, throwsStateError);
      expect(
        container.read(paywallControllerProvider).stateOf(premium),
        UnlockState.locked,
      );
    });

    test('ignores free episodes and unlocks already in flight', () async {
      final unlocks = FakeUnlockRepository()..purchase = Completer<void>();
      final container = await paywallOn(unlocks);
      final paywall = container.read(paywallControllerProvider.notifier);

      await paywall.unlock('ep-01');
      expect(container.read(paywallControllerProvider).unlocks, isEmpty);

      final first = paywall.unlock('ep-07');
      await paywall.unlock('ep-07');
      unlocks.purchase!.complete();
      await first;
      expect(
        container.read(paywallControllerProvider).stateOf(premium),
        UnlockState.unlocked,
      );
    });

    test('reset locks everything again and forgets saved unlocks', () async {
      final unlocks = FakeUnlockRepository({'ep-07'});
      final container = await paywallOn(unlocks);

      await container.read(paywallControllerProvider.notifier).reset();

      expect(container.read(paywallControllerProvider).lockedItemId, 'ep-07');
      expect(unlocks.unlockedIds(), isEmpty);
    });
  });
}
