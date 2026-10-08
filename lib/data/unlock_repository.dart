import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/data/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which premium episodes the user has unlocked.
abstract interface class UnlockRepository {
  /// Ids of the episodes unlocked on this device.
  Set<String> unlockedIds();

  /// Buys [episodeId] (simulated) and records the unlock.
  Future<void> unlock(String episodeId);

  /// Forgets every unlock. Used by the debug panel.
  Future<void> reset();
}

/// [UnlockRepository] backed by shared preferences. The purchase is a
/// stand-in: it waits [purchaseLatency], as a store round-trip would, then
/// always succeeds.
final class PrefsUnlockRepository implements UnlockRepository {
  PrefsUnlockRepository(
    this._preferences, {
    this.purchaseLatency = defaultPurchaseLatency,
  });

  static const Duration defaultPurchaseLatency = Duration(milliseconds: 900);

  final SharedPreferencesWithCache _preferences;
  final Duration purchaseLatency;

  @override
  Set<String> unlockedIds() => {
    ...?_preferences.getStringList(PreferenceKeys.unlockedEpisodes),
  };

  @override
  Future<void> unlock(String episodeId) async {
    await Future<void>.delayed(purchaseLatency);
    final ids = unlockedIds()..add(episodeId);
    await _preferences.setStringList(
      PreferenceKeys.unlockedEpisodes,
      ids.toList(),
    );
  }

  @override
  Future<void> reset() => _preferences.remove(PreferenceKeys.unlockedEpisodes);
}

final Provider<UnlockRepository> unlockRepositoryProvider = Provider(
  (ref) => PrefsUnlockRepository(ref.watch(sharedPreferencesProvider)),
);
