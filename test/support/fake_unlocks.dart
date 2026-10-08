import 'dart:async';

import 'package:micro_drama_interactive_player/data/unlock_repository.dart';

/// Unlocks kept in memory. Set [purchase] to hold an unlock open, so a test
/// can watch the unlocking state.
class FakeUnlockRepository implements UnlockRepository {
  FakeUnlockRepository([Set<String> unlocked = const {}])
    : _unlocked = {...unlocked};

  final Set<String> _unlocked;
  Completer<void>? purchase;
  int resets = 0;

  @override
  Set<String> unlockedIds() => {..._unlocked};

  @override
  Future<void> unlock(String episodeId) async {
    await purchase?.future;
    _unlocked.add(episodeId);
  }

  @override
  Future<void> reset() async {
    _unlocked.clear();
    resets++;
  }
}
