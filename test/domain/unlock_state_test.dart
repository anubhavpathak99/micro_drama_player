import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

void main() {
  test('only an unlocked episode may play', () {
    expect(
      {for (final state in UnlockState.values) state: state.canPlay},
      {
        UnlockState.locked: false,
        UnlockState.unlocking: false,
        UnlockState.unlocked: true,
      },
    );
  });
}
