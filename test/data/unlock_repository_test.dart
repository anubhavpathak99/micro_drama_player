import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/data/preferences.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A fresh cache over the in-memory store, as a new app launch would load.
Future<SharedPreferencesWithCache> launchPreferences() =>
    SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PreferenceKeys.all,
      ),
    );

Future<PrefsUnlockRepository> instantRepository() async =>
    PrefsUnlockRepository(
      await launchPreferences(),
      purchaseLatency: Duration.zero,
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('PrefsUnlockRepository', () {
    test('starts with nothing unlocked', () async {
      final repository = await instantRepository();

      expect(repository.unlockedIds(), isEmpty);
    });

    test('keeps an unlock across launches', () async {
      await (await instantRepository()).unlock('ep-07');

      final relaunched = await instantRepository();

      expect(relaunched.unlockedIds(), {'ep-07'});
    });

    test('adds to earlier unlocks', () async {
      final repository = await instantRepository();

      await repository.unlock('ep-07');
      await repository.unlock('ep-09');

      expect(repository.unlockedIds(), {'ep-07', 'ep-09'});
    });

    test('reset forgets every unlock, also on the next launch', () async {
      final repository = await instantRepository();
      await repository.unlock('ep-07');

      await repository.reset();

      expect(repository.unlockedIds(), isEmpty);
      expect((await instantRepository()).unlockedIds(), isEmpty);
    });

    testWidgets('the purchase takes the simulated store latency', (
      tester,
    ) async {
      final repository = PrefsUnlockRepository(await launchPreferences());
      var done = false;

      unawaited(repository.unlock('ep-07').then((_) => done = true));
      await tester.pump(
        PrefsUnlockRepository.defaultPurchaseLatency -
            const Duration(milliseconds: 1),
      );
      expect(done, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      expect(done, isTrue);
    });
  });
}
