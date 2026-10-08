/// Paywall state of a premium episode.
enum UnlockState {
  /// Behind the paywall: the overlay is up and no player may exist.
  locked,

  /// Simulated purchase in flight. Still no playback.
  unlocking,

  /// Purchased: plays like any other episode.
  unlocked;

  /// Whether a video player may be created for the episode.
  bool get canPlay => this == UnlockState.unlocked;
}
