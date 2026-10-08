import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

// Paywall controller: lock state of premium episodes.
//
// TODO: Add the unlock flow (simulated purchase, persistence via the unlock
// repository) and the forward-scroll barrier.

/// Unlock state of premium episodes, keyed by episode id.
@immutable
final class PaywallState {
  const PaywallState({this.unlocks = const {}});

  final Map<String, UnlockState> unlocks;

  /// Whether [episode] is behind the paywall right now. Premium episodes
  /// stay locked until they are fully unlocked.
  bool isLocked(Episode episode) =>
      episode.isPremium && !(unlocks[episode.id]?.canPlay ?? false);
}

/// Decides which episodes are locked. For now only the catalog's premium
/// flag counts, and nothing can be unlocked yet.
class PaywallController extends Notifier<PaywallState> {
  @override
  PaywallState build() => const PaywallState();
}

final NotifierProvider<PaywallController, PaywallState>
paywallControllerProvider = NotifierProvider(PaywallController.new);
