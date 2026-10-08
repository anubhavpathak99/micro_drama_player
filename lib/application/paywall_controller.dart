import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/data/unlock_repository.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

/// Paywall state: how far each premium episode is from being unlocked, and
/// which page the feed must stop at.
@immutable
final class PaywallState {
  const PaywallState({this.unlocks = const {}, this.lockedItemId});

  /// Unlock progress of premium episodes, keyed by episode id. A premium
  /// episode with no entry is locked.
  final Map<String, UnlockState> unlocks;

  /// Id of the first premium episode in the feed that is still locked: the
  /// furthest page anyone can scroll to. Null when nothing is locked.
  final String? lockedItemId;

  /// Where [episode] stands. Free episodes are always unlocked.
  UnlockState stateOf(Episode episode) => episode.isPremium
      ? unlocks[episode.id] ?? UnlockState.locked
      : UnlockState.unlocked;

  /// Whether [episode] is behind the paywall: locked, or still unlocking.
  bool isLocked(Episode episode) => !stateOf(episode).canPlay;

  /// Whether a player may be created for [episode]. True once the user has
  /// committed to the unlock, so the episode is ready the moment it opens.
  bool canPrepare(Episode episode) => stateOf(episode).canPrepare;
}

/// Id of the first locked premium episode in [items], or null.
String? firstLockedItemId(
  List<FeedItem> items,
  Map<String, UnlockState> unlocks,
) {
  final paywall = PaywallState(unlocks: unlocks);
  for (final item in items) {
    if (item case EpisodeItem(:final episode) when paywall.isLocked(episode)) {
      return episode.id;
    }
  }
  return null;
}

/// Runs the paywall: loads saved unlocks, runs the simulated purchase
/// (locked → unlocking → unlocked) and tells the feed where to stop.
class PaywallController extends Notifier<PaywallState> {
  late UnlockRepository _repository;
  List<FeedItem> _items = const [];

  // Survives rebuilds (the feed's item list can change); the repository is
  // read once, when the first build runs.
  Map<String, UnlockState>? _unlocks;

  @override
  PaywallState build() {
    _repository = ref.watch(unlockRepositoryProvider);
    _items =
        ref.watch(feedControllerProvider.select((feed) => feed.value?.items)) ??
        const [];
    _unlocks ??= {
      for (final id in _repository.unlockedIds()) id: UnlockState.unlocked,
    };
    return _compose();
  }

  /// Buys [episodeId]. It is unlocking from the tap, so its player can warm
  /// up, and becomes unlocked (playable, no longer stopping the feed) once
  /// the purchase is saved and [onPurchased] has finished. The paywall uses
  /// [onPurchased] to play its exit before the episode opens up.
  ///
  /// If the purchase fails, the episode is locked again and the error is
  /// rethrown. The unlock completes even if [onPurchased] throws.
  /// Ignored for free episodes and for episodes not currently locked.
  Future<void> unlock(
    String episodeId, {
    Future<void> Function()? onPurchased,
  }) async {
    if (!_isLockedPremium(episodeId)) return;
    _set(episodeId, UnlockState.unlocking);
    try {
      await _repository.unlock(episodeId);
    } catch (_) {
      if (ref.mounted) _set(episodeId, UnlockState.locked);
      rethrow;
    }
    try {
      await onPurchased?.call();
    } finally {
      if (ref.mounted) _set(episodeId, UnlockState.unlocked);
    }
  }

  /// Locks every premium episode again and forgets saved unlocks.
  Future<void> reset() async {
    _unlocks = {};
    state = _compose();
    await _repository.reset();
  }

  bool _isLockedPremium(String episodeId) {
    for (final item in _items) {
      if (item case EpisodeItem(:final episode) when episode.id == episodeId) {
        return state.stateOf(episode) == UnlockState.locked;
      }
    }
    return false;
  }

  void _set(String episodeId, UnlockState unlock) {
    _unlocks = {..._unlocks!, episodeId: unlock};
    state = _compose();
  }

  PaywallState _compose() => PaywallState(
    unlocks: Map.unmodifiable(_unlocks!),
    lockedItemId: firstLockedItemId(_items, _unlocks!),
  );
}

final NotifierProvider<PaywallController, PaywallState>
paywallControllerProvider = NotifierProvider(PaywallController.new);
