import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class MicroDramaApp extends StatelessWidget {
  const MicroDramaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Micro Drama',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    navigatorObservers: [appRouteObserver],
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: _immersiveChrome,
      child: child!,
    ),
    home: const FeedScreen(),
  );
}
