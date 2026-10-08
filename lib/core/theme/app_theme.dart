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
