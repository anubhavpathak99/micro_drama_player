import 'package:flutter/foundation.dart';

/// The expensive native objects worth watching for leaks.
enum LifecycleKind { player, ad }

/// Logs every video player and ad as it is created and disposed, with a
/// running count, so a leak shows up as a live count that keeps climbing.
///
/// Debug and profile builds only: in release it does nothing.
abstract final class LifecycleLog {
  static final Map<LifecycleKind, int> _live = {};
  static final Map<LifecycleKind, int> _created = {};

  /// How many objects of [kind] exist right now.
  static int live(LifecycleKind kind) => _live[kind] ?? 0;

  /// How many objects of [kind] were created in all.
  static int created(LifecycleKind kind) => _created[kind] ?? 0;

  /// A [kind] object called [id] was created.
  static void opened(LifecycleKind kind, String id) {
    if (kReleaseMode) return;
    _created.update(kind, (count) => count + 1, ifAbsent: () => 1);
    _live.update(kind, (count) => count + 1, ifAbsent: () => 1);
    _log('${kind.name}+ $id', kind);
  }

  /// The [kind] object called [id] was disposed.
  static void closed(LifecycleKind kind, String id) {
    if (kReleaseMode) return;
    _live.update(kind, (count) => count - 1, ifAbsent: () => -1);
    _log('${kind.name}- $id', kind);
  }

  @visibleForTesting
  static void reset() {
    _live.clear();
    _created.clear();
  }

  static void _log(String event, LifecycleKind kind) => debugPrint(
    '[lifecycle] $event (live ${live(kind)}, created ${created(kind)})',
  );
}
