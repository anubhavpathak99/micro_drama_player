import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Event names the app logs.
abstract final class AnalyticsEvents {
  static const String adRequest = 'ad_request';
  static const String adLoaded = 'ad_loaded';
  static const String adNoFill = 'ad_no_fill';
  static const String adImpression = 'ad_impression';
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
