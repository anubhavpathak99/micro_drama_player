import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/core/analytics/analytics_service.dart';
import 'package:micro_drama_interactive_player/core/env/ad_config.dart';
import 'package:micro_drama_interactive_player/data/ad_repository.dart';
import 'package:micro_drama_interactive_player/domain/ad_slot_state.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';

/// One ad slot, as its page sees it.
@immutable
final class AdSlotStatus {
  const AdSlotStatus(this.state, [this.ad]);

  final AdSlotState state;

  /// The ad, while [state] is loaded or shown.
  final NativeAdHandle? ad;

  @override
  bool operator ==(Object other) =>
      other is AdSlotStatus && other.state == state && identical(other.ad, ad);

  @override
  int get hashCode => Object.hash(state, identityHashCode(ad));
}

/// Loads the feed's ads ahead of the user and retires them behind.
///
/// Each slot moves through idle → loading → loaded → shown → disposed, or
/// ends at failed:
///
/// * A slot starts loading once it is at most [AdConfig.preloadDistance]
///   pages ahead (or the page just behind the user). A request that fails,
///   or takes longer than [AdConfig.loadTimeout] once the SDK has started,
///   fails the slot and the feed removes it.
/// * A loaded ad counts as shown once its page is on screen.
/// * A shown ad is released once the user is [AdConfig.disposeDistance]
///   pages away, and is never shown again: coming back loads a fresh one.
class AdPreloader extends Notifier<Map<String, AdSlotStatus>> {
  final Map<String, _Slot> _slots = {};
  late AdRepository _ads;
  late AnalyticsService _analytics;
  FeedState? _feed;

  @override
  Map<String, AdSlotStatus> build() {
    _ads = ref.watch(adRepositoryProvider);
    _analytics = ref.watch(analyticsProvider);
    ref.onDispose(_disposeAll);
    ref.listen(feedControllerProvider, (_, next) {
      _feed = next.value;
      _sync();
      _publish();
    });
    _feed = ref.read(feedControllerProvider).value;
    _sync();
    return _snapshot();
  }

  /// Fails [slotId] as if the network had no ad for it. A debug hook: test
  /// ads always fill, so this is the only way to see the no-fill paths.
  void simulateNoFill(String slotId) {
    final slot = _slots[slotId];
    if (slot == null || slot.state == AdSlotState.failed) return;
    slot.attempt++;
    _fail(slot, reason: 'simulated');
  }

  void _sync() {
    final feed = _feed;
    if (feed == null) return;
    for (final (index, item) in feed.items.indexed) {
      if (item is! AdSlotItem) continue;
      final slot = _slots.putIfAbsent(item.slotId, () => _Slot(item.slotId));
      final distance = index - feed.currentIndex;
      switch (slot.state) {
        case AdSlotState.idle || AdSlotState.disposed
            when distance >= -1 && distance <= AdConfig.preloadDistance:
          _load(slot);
        case AdSlotState.loaded when distance == 0:
          slot.state = AdSlotState.shown;
        case AdSlotState.shown when distance.abs() >= AdConfig.disposeDistance:
          slot
            ..release()
            ..state = AdSlotState.disposed;
        default:
          break;
      }
    }
  }

  void _load(_Slot slot) {
    final attempt = ++slot.attempt;
    slot.state = AdSlotState.loading;
    unawaited(_request(slot, attempt));
  }

  Future<void> _request(_Slot slot, int attempt) async {
    // Starting the SDK is a one-time cost (seconds on a cold start), not part
    // of an ad's time budget: the timeout covers the ad request alone.
    await _ads.initialize();
    if (!ref.mounted || slot.attempt != attempt) return;

    _analytics.log(AnalyticsEvents.adRequest, {'slot': slot.id});
    final stopwatch = Stopwatch()..start();
    final pending = _ads.loadNative(
      onImpression: () =>
          _analytics.log(AnalyticsEvents.adImpression, {'slot': slot.id}),
    );
    final NativeAdHandle ad;
    try {
      ad = await pending.timeout(AdConfig.loadTimeout);
    } on Object catch (error) {
      // An ad that turns up after the timeout is released unseen.
      if (error is TimeoutException) {
        unawaited(
          pending.then((lateAd) => lateAd.dispose(), onError: (Object _) {}),
        );
      }
      if (ref.mounted && slot.attempt == attempt) {
        _fail(slot, reason: _reason(error));
      }
      return;
    }
    if (!ref.mounted || slot.attempt != attempt) {
      ad.dispose();
      return;
    }
    slot
      ..ad = ad
      ..state = AdSlotState.loaded;
    _analytics.log(AnalyticsEvents.adLoaded, {
      'slot': slot.id,
      'latency_ms': stopwatch.elapsedMilliseconds,
    });
    _sync();
    _publish();
  }

  void _fail(_Slot slot, {required String reason}) {
    slot
      ..release()
      ..state = AdSlotState.failed;
    _analytics.log(AnalyticsEvents.adNoFill, {
      'slot': slot.id,
      'reason': reason,
    });
    _publish();
    ref.read(feedControllerProvider.notifier).onAdSlotFailed(slot.id);
  }

  static String _reason(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    AdLoadFailure(noFill: true) => 'no_fill',
    AdLoadFailure(:final code) => 'error_$code',
    _ => 'error',
  };

  void _publish() {
    if (ref.mounted) state = _snapshot();
  }

  Map<String, AdSlotStatus> _snapshot() => Map.unmodifiable({
    for (final slot in _slots.values)
      slot.id: AdSlotStatus(slot.state, slot.ad),
  });

  void _disposeAll() {
    for (final slot in _slots.values) {
      slot
        ..attempt += 1
        ..release();
    }
    _slots.clear();
  }
}

final NotifierProvider<AdPreloader, Map<String, AdSlotStatus>>
adPreloaderProvider = NotifierProvider(AdPreloader.new);

final class _Slot {
  _Slot(this.id);

  final String id;
  AdSlotState state = AdSlotState.idle;
  NativeAdHandle? ad;

  /// Bumped on every load; results of a superseded load are discarded.
  int attempt = 0;

  void release() {
    ad?.dispose();
    ad = null;
  }
}
