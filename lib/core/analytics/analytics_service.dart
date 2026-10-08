import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Event names the app logs.
abstract final class AnalyticsEvents {
  static const String adRequest = 'ad_request';
  static const String adLoaded = 'ad_loaded';
  static const String adNoFill = 'ad_no_fill';
  static const String adImpression = 'ad_impression';

  /// An episode became the page on screen: `episode`, `position`, `locked`.
  static const String episodeView = 'episode_view';

  /// A like went on or off: `episode`, `liked`, `source` (`button` or
  /// `double_tap`).
  static const String like = 'like';

  /// A scrub ended: `episode`, `from_ms`, `to_ms`.
  static const String scrub = 'scrub';

  /// A locked episode's paywall came on screen: `episode`.
  static const String paywallShown = 'paywall_shown';

  /// The user asked to unlock: `episode`.
  static const String unlockTap = 'unlock_tap';

  /// The unlock went through: `episode`.
  static const String unlockSuccess = 'unlock_success';
}

/// Records product events. Swap the implementation for a real backend.
abstract interface class AnalyticsService {
  void log(String event, [Map<String, Object?> parameters = const {}]);
}

/// Prints events to the console, for development.
final class ConsoleAnalytics implements AnalyticsService {
  const ConsoleAnalytics();

  @override
  void log(String event, [Map<String, Object?> parameters = const {}]) =>
      debugPrint(
        parameters.isEmpty
            ? '[analytics] $event'
            : '[analytics] $event $parameters',
      );
}

final Provider<AnalyticsService> analyticsProvider = Provider(
  (ref) => const ConsoleAnalytics(),
);
