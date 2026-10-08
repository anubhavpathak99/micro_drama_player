import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys the app keeps in shared preferences. The preferences cache loads only
/// these, so every new key must be listed here.
abstract final class PreferenceKeys {
  static const String unlockedEpisodes = 'unlocked_episode_ids';

  static const Set<String> all = {unlockedEpisodes};
}

/// Preferences loaded before the first frame, so reads are synchronous.
///
/// `main()` overrides this with the instance it created.
final Provider<SharedPreferencesWithCache> sharedPreferencesProvider = Provider(
  (ref) => throw StateError(
    'sharedPreferencesProvider must be overridden with the instance '
    'created in main().',
  ),
);
