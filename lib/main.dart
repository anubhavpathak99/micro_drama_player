import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A vertical feed only makes sense upright.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  // Video runs edge to edge, under the status and navigation bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: MicroDramaApp()));
}
