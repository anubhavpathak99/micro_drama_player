import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Developer switches, flipped from the debug panel. All off at launch, and
/// the panel only exists in debug and profile builds.
@immutable
final class DebugSettings {
  const DebugSettings({
    this.forceAdNoFill = false,
    this.slowNetwork = false,
    this.performanceOverlay = false,
  });

  /// How long a slow network holds up each player's initialization.
  static const Duration slowNetworkDelay = Duration(seconds: 2);

  /// Every ad request from now on comes back empty.
  final bool forceAdNoFill;

  /// Players wait [slowNetworkDelay] before initializing.
  final bool slowNetwork;

  /// Flutter's frame timing overlay is drawn over the app.
  final bool performanceOverlay;

  DebugSettings copyWith({
    bool? forceAdNoFill,
    bool? slowNetwork,
    bool? performanceOverlay,
  }) => DebugSettings(
    forceAdNoFill: forceAdNoFill ?? this.forceAdNoFill,
    slowNetwork: slowNetwork ?? this.slowNetwork,
    performanceOverlay: performanceOverlay ?? this.performanceOverlay,
  );

  @override
  bool operator ==(Object other) =>
      other is DebugSettings &&
      other.forceAdNoFill == forceAdNoFill &&
      other.slowNetwork == slowNetwork &&
      other.performanceOverlay == performanceOverlay;

  @override
  int get hashCode =>
      Object.hash(forceAdNoFill, slowNetwork, performanceOverlay);
}

class DebugSettingsController extends Notifier<DebugSettings> {
  @override
  DebugSettings build() => const DebugSettings();

  void setForceAdNoFill(bool on) => state = state.copyWith(forceAdNoFill: on);

  void setSlowNetwork(bool on) => state = state.copyWith(slowNetwork: on);

  void setPerformanceOverlay(bool on) =>
      state = state.copyWith(performanceOverlay: on);
}

final NotifierProvider<DebugSettingsController, DebugSettings>
debugSettingsProvider = NotifierProvider(DebugSettingsController.new);
