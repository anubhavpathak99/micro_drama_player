import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/debug_settings.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';
import 'package:micro_drama_interactive_player/presentation/shared/app_route_observer.dart';

/// Light status and navigation bar icons over transparent bars, so video
/// shows through.
final SystemUiOverlayStyle _immersiveChrome = SystemUiOverlayStyle.light
    .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    );

class MicroDramaApp extends ConsumerWidget {
  const MicroDramaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Micro Drama',
    debugShowCheckedModeBanner: false,
    showPerformanceOverlay: ref.watch(
      debugSettingsProvider.select((settings) => settings.performanceOverlay),
    ),
    theme: AppTheme.dark(),
    navigatorObservers: [appRouteObserver],
    builder: (context, child) => ReducedMotionScope(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _immersiveChrome,
        child: child!,
      ),
    ),
    home: const FeedScreen(),
  );
}
