import 'package:flutter/material.dart';

/// Brand palette. Video is the hero, so chrome stays near-black, one warm
/// accent carries likes and progress, and gold is reserved for premium.
abstract final class AppColors {
  static const Color background = Color(0xFF09090D);
  static const Color surface = Color(0xFF15151C);
  static const Color accent = Color(0xFFFF3D6E);
  static const Color premium = Color(0xFFFFC24D);

  /// Text and icons drawn over video.
  static const Color onMedia = Color(0xFFFFFFFF);
  static const Color onMediaMuted = Color(0xB3FFFFFF);

  /// Skeleton shapes, and the highlight that sweeps across them.
  static const Color skeleton = Color(0x24FFFFFF);
  static const Color skeletonHighlight = Color(0x5CFFFFFF);

  /// Dims a poster behind a skeleton or an error message.
  static const Color scrim = Color(0x80000000);
}

abstract final class AppTheme {
  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      secondary: AppColors.premium,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
}
