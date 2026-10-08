/// Paywall state of a premium episode.
enum UnlockState {
  /// Behind the paywall: the overlay is up and no player may exist.
  locked,

  /// The user committed to the unlock: the purchase is in flight, or done
  /// while the paywall plays its exit. The player may warm up, but the
  /// episode doesn't play and the feed still stops here.
  unlocking,

  /// Purchased: plays like any other episode.
  unlocked;

  /// Whether a video player may be created for the episode.
  bool get canPrepare => this != UnlockState.locked;

  /// Whether the episode may play.
  bool get canPlay => this == UnlockState.unlocked;
}
