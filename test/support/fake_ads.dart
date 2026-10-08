import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';

/// What a [FakeAdRepository] does with each request.
enum FakeAdBehavior {
  /// Fill at once.
  fill,

  /// Fail at once with a no-fill error.
  noFill,

  /// Never answer on its own; complete [FakeAdRepository.pending] by hand.
  hang,
}

/// Serves [FakeNativeAdHandle]s, or fails, as [behavior] says.
class FakeAdRepository implements AdRepository {
  FakeAdRepository([this.behavior = FakeAdBehavior.fill]);

  FakeAdBehavior behavior;

  /// When set, the SDK start-up waits for it.
  Completer<void>? initialization;
  final List<FakeNativeAdHandle> served = [];
  final List<Completer<NativeAdHandle>> pending = [];
  final List<VoidCallback> impressionCallbacks = [];
  int requests = 0;

  @override
  Future<void> initialize() => initialization?.future ?? Future.value();

  @override
  Future<NativeAdHandle> loadNative({required VoidCallback onImpression}) {
    requests++;
    impressionCallbacks.add(onImpression);
    switch (behavior) {
      case FakeAdBehavior.fill:
        final ad = FakeNativeAdHandle(requests);
        served.add(ad);
        return Future.value(ad);
      case FakeAdBehavior.noFill:
        return Future.error(
          const AdLoadFailure(code: 3, message: 'No fill', noFill: true),
        );
      case FakeAdBehavior.hang:
        final request = Completer<NativeAdHandle>();
        pending.add(request);
        return request.future;
    }
  }
}

/// A served ad whose view is a plain box, keyed by its serial number.
class FakeNativeAdHandle implements NativeAdHandle {
  FakeNativeAdHandle(this.serial);

  final int serial;
  bool isDisposed = false;

  @override
  Widget buildView() => ColoredBox(
    key: ValueKey('fake-ad-$serial'),
    color: const Color(0xFF203040),
  );

  @override
  void dispose() => isDisposed = true;
}

/// Records every event instead of printing it.
class FakeAnalytics implements AnalyticsService {
  final List<(String, Map<String, Object?>)> events = [];

  List<String> get names => [for (final (name, _) in events) name];

  /// Parameters of every [name] event, in order.
  List<Map<String, Object?>> parametersOf(String name) => [
    for (final (event, parameters) in events)
      if (event == name) parameters,
  ];

  @override
  void log(String event, [Map<String, Object?> parameters = const {}]) =>
      events.add((event, parameters));
}

/// A preloader with a fixed set of slots, for testing the ad page alone.
class FakeAdPreloader extends AdPreloader {
  FakeAdPreloader(this.initial);

  final Map<String, AdSlotStatus> initial;

  @override
  Map<String, AdSlotStatus> build() => initial;

  void emit(Map<String, AdSlotStatus> next) => state = next;
}
