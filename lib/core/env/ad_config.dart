/// Google Ad Manager settings.
///
/// Every unit id here is one of Google's demo units, which only ever serve
/// test ads. Checked against the Ad Manager test-ads pages for Android and
/// iOS (October 2026): both platforms use the same ids. Production ids never
/// belong in this file.
abstract final class AdConfig {
  /// Demo native ad unit.
  static const String nativeUnitId = '/21775744923/example/native';

  /// Demo rewarded ad unit, for "Watch an ad to unlock".
  static const String rewardedUnitId = '/21775744923/example/rewarded';

  /// Native ad factory registered by MainActivity.kt and AppDelegate.swift.
  static const String nativeFactoryId = 'fullScreenNative';

  /// A load that hasn't finished by then counts as a failure.
  static const Duration loadTimeout = Duration(seconds: 8);

  /// An ad starts loading once at most two items separate its slot from the
  /// current page (three pages ahead), so it is ready when the user arrives.
  static const int preloadDistance = 3;

  /// A shown ad is released once the user is this many pages away from it.
  static const int disposeDistance = 2;
}
