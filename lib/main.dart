import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/app.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/data/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A vertical feed only makes sense upright.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  // Video runs edge to edge, under the status and navigation bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Loaded before the first frame, so saved unlocks are known synchronously
  // and a purchased episode never flashes as locked.
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: PreferenceKeys.all,
    ),
  );
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  // Start the ads SDK right away; ad loads wait for it.
  unawaited(container.read(adRepositoryProvider).initialize());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MicroDramaApp(),
    ),
  );
}
