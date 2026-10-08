import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';

// Debug panel: developer view of the feed, the paywall and the player pool.
// It is a real route, so opening it also exercises pausing when the feed is
// covered.
//
// TODO: Add a control to force an ad failure.

/// Small "DEV" pill that opens the [DebugPanel].
class DebugPanelButton extends StatelessWidget {
  const DebugPanelButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: ActionChip(
      label: const Text('DEV'),
      visualDensity: VisualDensity.compact,
      onPressed: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const DebugPanel(),
          ),
        ),
      ),
    ),
  );
}

/// Lists every feed page with its player state.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider).value;
    final pool = ref.watch(playerPoolProvider);
    final paywall = ref.watch(paywallControllerProvider);
    final playback = pool.suspended
        ? 'On hold (app inactive or covered)'
        : pool.userPaused
        ? 'Paused by user'
        : 'Normal';
    final lockedItemId = paywall.lockedItemId;
    final paywallActions = ref.read(paywallControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Live players'),
            trailing: Text('${pool.slots.length} / ${PlayerPool.maxPlayers}'),
          ),
          ListTile(title: const Text('Playback'), trailing: Text(playback)),
          ListTile(
            title: const Text('Paywall'),
            subtitle: Text(
              lockedItemId == null
                  ? 'Nothing locked'
                  : 'Feed stops at $lockedItemId',
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: lockedItemId == null
                      ? null
                      : () => unawaited(paywallActions.unlock(lockedItemId)),
                  child: const Text('Unlock'),
                ),
                OutlinedButton(
                  onPressed: () => unawaited(paywallActions.reset()),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          const Divider(),
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

  static String _describe(PlayerSlot? slot) => switch (slot) {
    null => 'No player (outside the window)',
    PlayerLoading() => 'Loading',
    PlayerReady(:final controller) =>
      controller.value.isPlaying ? 'Playing' : 'Ready, paused',
    PlayerFailed(:final message) => 'Failed: $message',
  };
}
