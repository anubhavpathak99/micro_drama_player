/// Lifecycle of one ad slot, driven by the ad preloader.
///
/// ```text
/// idle ─► loading ─► loaded ─► shown ─► disposed
///            │
///            └─► failed   (no fill, error or timeout: the slot leaves the feed)
/// ```
enum AdSlotState {
  /// In the feed; no request has been made yet.
  idle,

  /// Request in flight. The page shows the branded skeleton.
  loading,

  /// Creative is ready to render.
  loaded,

  /// Rendered on screen at least once.
  shown,

  /// No fill, load error or timeout. The feed drops the slot.
  failed,

  /// Native ad resources were released.
  disposed,
}
