import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/core/diagnostics/lifecycle_log.dart';

void main() {
  late List<String?> printed;

  setUp(() {
    LifecycleLog.reset();
    printed = [];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    addTearDown(() => debugPrint = original);
  });

  tearDown(LifecycleLog.reset);

  test('counts live and created objects of each kind', () {
    LifecycleLog.opened(LifecycleKind.player, 'ep-01');
    LifecycleLog.opened(LifecycleKind.player, 'ep-02');
    LifecycleLog.opened(LifecycleKind.ad, 'ad-after-3');
    LifecycleLog.closed(LifecycleKind.player, 'ep-01');

    expect(LifecycleLog.live(LifecycleKind.player), 1);
    expect(LifecycleLog.created(LifecycleKind.player), 2);
    expect(LifecycleLog.live(LifecycleKind.ad), 1);
    expect(LifecycleLog.created(LifecycleKind.ad), 1);
  });

  test('logs each change with the running counts', () {
    LifecycleLog.opened(LifecycleKind.player, 'ep-01');
    LifecycleLog.closed(LifecycleKind.player, 'ep-01');

    expect(printed, [
      '[lifecycle] player+ ep-01 (live 1, created 1)',
      '[lifecycle] player- ep-01 (live 0, created 1)',
    ]);
  });

  test('a close without an open shows as a negative live count', () {
    LifecycleLog.closed(LifecycleKind.ad, 'ad-after-6');

    expect(LifecycleLog.live(LifecycleKind.ad), -1);
    expect(LifecycleLog.created(LifecycleKind.ad), 0);
  });
}
