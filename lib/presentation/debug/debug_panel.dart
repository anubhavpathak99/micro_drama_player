import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/application/debug_settings.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

// Debug panel: developer switches plus a live view of the feed, the paywall,
// the ads and the player pool. It is a real route, so opening it also
// exercises pausing when the feed is covered. Debug and profile builds open
// it with a long press on the feed's logo.

/// How long an ad shows after the panel closes before it is failed, so the
/// feed's reaction plays on screen rather than under the panel.
const Duration _afterClose = Duration(milliseconds: 700);

/// The episode "Jump to E6" lands on: the last one before the paywall.
const String _jumpTarget = 'ep-06';

/// Opens the [DebugPanel] over the feed.
Future<void> openDebugPanel(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const DebugPanel(),
  ),
);

/// Developer switches and the state of every feed page.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider).value;
    final pool = ref.watch(playerPoolProvider);
    final paywall = ref.watch(paywallControllerProvider);
    final settings = ref.watch(debugSettingsProvider);
    final switches = ref.read(debugSettingsProvider.notifier);
    final playback = pool.scrubbing
        ? 'Scrubbing'
        : pool.suspended
        ? 'On hold (app inactive or covered)'
        : pool.userPaused
        ? 'Paused by user'
        : 'Normal';
    final ads = ref.watch(adPreloaderProvider);
    final lockedItemId = paywall.lockedItemId;
    final paywallActions = ref.read(paywallControllerProvider.notifier);
    final canJump = (feed?.indexOf(_jumpTarget) ?? -1) >= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ListView(
        children: [
          const _Heading('Simulate'),
          SwitchListTile(
            title: const Text('Force ad no-fill'),
            subtitle: const Text(
              'Every ad request from now on comes back empty, and its slot '
              'leaves the feed.',
            ),
            value: settings.forceAdNoFill,
            onChanged: switches.setForceAdNoFill,
          ),
          SwitchListTile(
            title: const Text('Slow network'),
            subtitle: Text(
              'Each player waits '
              '${DebugSettings.slowNetworkDelay.inSeconds} s before it starts.',
            ),
            value: settings.slowNetwork,
            onChanged: switches.setSlowNetwork,
          ),
          SwitchListTile(
            title: const Text('Performance overlay'),
            subtitle: const Text('Frame times of the UI and raster threads.'),
            value: settings.performanceOverlay,
            onChanged: switches.setPerformanceOverlay,
          ),
          ListTile(
            title: const Text('Jump to E6'),
            subtitle: const Text('The last episode before the paywall.'),
            trailing: FilledButton.tonal(
              onPressed: canJump
                  ? () => _jumpTo(context, ref, _jumpTarget)
                  : null,
              child: const Text('Jump'),
            ),
          ),
          const _Heading('Paywall'),
          ListTile(
            title: Text(
              lockedItemId == null
                  ? 'Nothing locked'
                  : 'Feed stops at $lockedItemId',
            ),
            // Below the title rather than trailing, so both buttons fit
            // the narrowest phones.
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: lockedItemId == null
                        ? null
                        : () => unawaited(paywallActions.unlock(lockedItemId)),
                    child: const Text('Unlock'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(paywallActions.reset()),
                    child: const Text('Reset unlock'),
                  ),
                ],
              ),
            ),
          ),
          const _Heading('Ads'),
          const ListTile(
            dense: true,
            subtitle: Text(
              'Test ads always fill. Simulate no-fill closes this panel on '
              'that ad, then fails it: the feed fades it out and moves on.',
            ),
          ),
          for (final MapEntry(key: slotId, value: status) in ads.entries)
            ListTile(
              dense: true,
              title: Text(slotId),
              subtitle: Text(status.state.name),
              trailing: TextButton(
                onPressed: status.state == AdSlotState.failed
                    ? null
                    : () => _simulateNoFill(context, ref, slotId),
                child: const Text('Simulate no-fill'),
              ),
            ),
          const _Heading('Players'),
          ListTile(
            dense: true,
            title: const Text('Live players'),
            trailing: Text('${pool.slots.length} / ${PlayerPool.maxPlayers}'),
          ),
          ListTile(
            dense: true,
            title: const Text('Playback'),
            trailing: Text(playback),
          ),
          const _Heading('Feed'),
          for (final item in feed?.items ?? const <FeedItem>[])
            ListTile(
              dense: true,
              selected: item.id == feed?.currentId,
              leading: Icon(
                item.id == feed?.currentId
                    ? Icons.play_arrow_rounded
                    : Icons.circle_outlined,
              ),
              title: Text(switch (item) {
                EpisodeItem(:final episode) =>
                  'E${episode.number} · ${episode.title}',
                AdSlotItem(:final afterEpisode) => 'Ad after E$afterEpisode',
              }),
              subtitle: Text(switch (item) {
                EpisodeItem(:final episode) when paywall.isLocked(episode) =>
                  paywall.stateOf(episode) == UnlockState.unlocking
                      ? 'Unlocking…'
                      : 'Locked: no player',
                EpisodeItem(:final episode) => _describe(
                  pool.slots[episode.id],
                ),
                AdSlotItem() => 'Ad slot',
              }),
            ),
        ],
      ),
    );
  }

  static void _simulateNoFill(
    BuildContext context,
    WidgetRef ref,
    String slotId,
  ) {
    final preloader = ref.read(adPreloaderProvider.notifier);
    // On the slot itself: the hardest case, where the page on screen goes.
    ref.read(feedControllerProvider.notifier).jumpTo(slotId);
    Navigator.of(context).pop();
    unawaited(
      Future<void>.delayed(_afterClose, () => preloader.simulateNoFill(slotId)),
    );
  }

  static void _jumpTo(BuildContext context, WidgetRef ref, String id) {
    ref.read(feedControllerProvider.notifier).jumpTo(id);
    Navigator.of(context).pop();
  }

  static String _describe(PlayerSlot? slot) => switch (slot) {
    null => 'No player (outside the window)',
    PlayerLoading() => 'Loading',
    PlayerReady(:final controller) =>
      controller.value.isPlaying ? 'Playing' : 'Ready, paused',
    PlayerFailed(:final message) => 'Failed: $message',
  };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
