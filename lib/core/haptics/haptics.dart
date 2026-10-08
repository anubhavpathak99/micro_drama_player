import 'package:flutter/services.dart';

/// The app's haptic vocabulary, in one place so feedback stays consistent.
abstract final class Haptics {
  /// A toggle, such as like or save, changed state.
  static Future<void> toggle() => HapticFeedback.lightImpact();

  /// Something the user paid for or waited on went through.
  static Future<void> success() => HapticFeedback.mediumImpact();
}
