import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/ad_preloader.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/application/view_tracker.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/presentation/ads/ad_page.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_logo.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_scroll_behavior.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_scroll_physics.dart';
import 'package:micro_drama_interactive_player/presentation/feed/paywall_lock_physics.dart';
import 'package:micro_drama_interactive_player/presentation/player/episode_page.dart';
import 'package:micro_drama_interactive_player/presentation/shared/app_route_observer.dart';
import 'package:micro_drama_interactive_player/presentation/shared/branded_skeleton.dart';
import 'package:micro_drama_interactive_player/presentation/shared/delayed_flag.dart';
import 'package:micro_drama_interactive_player/presentation/shared/shimmer.dart';

/// The vertical feed of episodes and ads.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only a new item list rebuilds the pager; page changes don't.
    final items = ref.watch(
      feedControllerProvider.select((feed) => feed.whenData((f) => f.items)),
    );
    return Scaffold(
      body: ShimmerScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            switch (items) {
              AsyncData(:final value) => _FeedPager(items: value),
              AsyncError() => _FeedError(
                onRetry: () => ref.invalidate(feedControllerProvider),
              ),
              AsyncLoading() => const DelayedReveal(child: BrandedSkeleton()),
            },
            const SafeArea(
              child: Align(alignment: Alignment.topCenter, child: FeedLogo()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pages through [items] and keeps the player pool in step with the page on
/// screen, the app lifecycle and covering routes.
class _FeedPager extends ConsumerStatefulWidget {
  const _FeedPager({required this.items});

  final List<FeedItem> items;

  @override
  ConsumerState<_FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends ConsumerState<_FeedPager> with RouteAware {
  late final PageController _pages;
  late final AppLifecycleListener _lifecycle;
  late Map<String, int> _indexById = _indexItems();
  // Rebuilt only for a new item list: a rebuild that just swaps the physics
  // (a scrub, a moved lock) then leaves every page alone.
  late SliverChildBuilderDelegate _pagesDelegate = _delegateFor(widget.items);
  ModalRoute<void>? _route;

  // The physics in use and what they were built from. New instances are made
  // only when the locked page (or the platform physics) changes.
  ScrollPhysics? _physics;
  ScrollPhysics? _physicsBase;
  int? _physicsLockedPage;

  // Lift times for the fling tracker; see FeedScrollBehavior.
  final PointerLifts _lifts = PointerLifts();

  late final FeedController _feed;
  late final FeedPager _pager;

  PlayerPool get _pool => ref.read(playerPoolProvider.notifier);

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      initialPage: ref.read(feedControllerProvider).requireValue.currentIndex,
    );
    _pager = _PageControllerPager(
      _pages,
      reduceMotion: () => mounted && context.reduceMotion,
    );
    _feed = ref.read(feedControllerProvider.notifier)..attachPager(_pager);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    ref
      ..listenManual(
        paywallControllerProvider.select((paywall) => paywall.lockedItemId),
        (_, lockedItemId) => _returnToLock(lockedItemId),
      )
      // Keeps the ad preloader running from the start, so the first slot
      // loads before the user gets near it.
      ..listenManual(adPreloaderProvider, (_, _) {})
      ..listenManual(viewTrackerProvider, (_, _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
    _precacheAround(_pages.initialPage);
  }

  @override
  void didUpdateWidget(_FeedPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.items, oldWidget.items)) {
      _indexById = _indexItems();
      _pagesDelegate = _delegateFor(widget.items);
    }
  }

  @override
  void dispose() {
    _feed.detachPager(_pager);
    appRouteObserver.unsubscribe(this);
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

  SliverChildBuilderDelegate _delegateFor(List<FeedItem> items) =>
      SliverChildBuilderDelegate(
        (context, index) =>
            FeedPage(key: ValueKey(items[index].id), item: items[index]),
        childCount: items.length,
        findChildIndexCallback: (key) =>
            _indexById[(key as ValueKey<String>).value],
        // Pages hold no state worth keeping alive (the pool owns players),
        // and FeedPage adds its own repaint boundary.
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
      );

  Map<String, int> _indexItems() => {
    for (final (index, item) in widget.items.indexed) item.id: index,
  };

  void _onLifecycleChanged(AppLifecycleState state) =>
      state == AppLifecycleState.resumed
      ? _pool.resume(SuspendReason.appInactive)
      : _pool.suspend(SuspendReason.appInactive);

  @override
  void didPushNext() => _pool.suspend(SuspendReason.routeCovered);

  @override
  void didPopNext() => _pool.resume(SuspendReason.routeCovered);

  // Reads the feed's latest items: when an ad slot is removed, the pager
  // jumps in the same frame, before this widget has rebuilt with them.
  List<FeedItem> get _items =>
      ref.read(feedControllerProvider).value?.items ?? widget.items;

  void _onPageChanged(int index) {
    final items = _items;
    if (index >= items.length) return;
    _feed.setCurrent(items[index].id);
    _precacheAround(index);
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.depth == 0) {
      _pool.rewindInactive();
      _feed.onSettled();
    }
    return false;
  }

  /// A lock that comes back (the debug reset) while the user is already past
  /// it would leave them on unreachable pages, so jump back to it.
  void _returnToLock(String? lockedItemId) {
    final lockedPage = _indexById[lockedItemId];
    final current = ref.read(feedControllerProvider).value?.currentIndex;
    if (lockedPage == null || current == null || current <= lockedPage) return;
    if (_pages.hasClients) _pages.jumpToPage(lockedPage);
  }

  /// Page physics for the current lock: paging with the feed's snap spring,
  /// plus a barrier at [lockedPage] while there is one.
  ScrollPhysics _physicsFor(int? lockedPage) {
    final base = ScrollConfiguration.of(context).getScrollPhysics(context);
    if (_physics == null ||
        lockedPage != _physicsLockedPage ||
        !identical(base, _physicsBase)) {
      final paging = const FeedPageScrollPhysics().applyTo(base);
      _physics = lockedPage == null
          ? paging
          : PaywallLockPhysics(lockedPage: lockedPage).applyTo(paging);
      _physicsBase = base;
      _physicsLockedPage = lockedPage;
    }
    return _physics!;
  }

  /// Decodes posters two pages ahead and behind, so a page never shows up
  /// before its poster does.
  void _precacheAround(int index) {
    final items = _items;
    for (var i = index - 2; i <= index + 2; i++) {
      if (i < 0 || i >= items.length) continue;
      if (items[i] case EpisodeItem(:final episode)) {
        unawaited(precacheImage(AssetImage(episode.posterAsset), context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recomputed every build: removing an ad shifts the locked page's index.
    final lockedItemId = ref.watch(
      paywallControllerProvider.select((paywall) => paywall.lockedItemId),
    );
    // A scrub owns the drag on its page: the feed holds still until it ends.
    final scrubbing = ref.watch(
      playerPoolProvider.select((pool) => pool.scrubbing),
    );
    final physics = scrubbing
        ? const NeverScrollableScrollPhysics()
        : _physicsFor(_indexById[lockedItemId]);
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: Listener(
        onPointerUp: _lifts.record,
        child: PageView.custom(
          controller: _pages,
          scrollDirection: Axis.vertical,
          allowImplicitScrolling: true,
          // The feed physics snap pages themselves. PageView's own snapping
          // would wrap them and bypass the paywall's fling handling.
          pageSnapping: false,
          physics: physics,
          // Scrollable keeps its position, and with it the old physics, when
          // only the physics' configuration changes. The behaviour compares
          // physics instances, so a moved lock does take effect.
          scrollBehavior: FeedScrollBehavior(_lifts)
              .copyWith(scrollbars: false, physics: physics),
          onPageChanged: _onPageChanged,
          childrenDelegate: _pagesDelegate,
        ),
      ),
    );
  }
}

/// [FeedPager] over the feed's PageController.
final class _PageControllerPager implements FeedPager {
  _PageControllerPager(this._pages, {required this.reduceMotion});

  final PageController _pages;

  /// Whether the OS asks for reduced motion right now.
  final bool Function() reduceMotion;

  @override
  bool get isScrolling =>
      _pages.hasClients && _pages.position.isScrollingNotifier.value;

  @override
  Future<void> animateToPage(int index) async {
    // The page being left fades its skeleton out first.
    await Future<void>.delayed(MotionDurations.adNoFillFade);
    if (!_pages.hasClients) return;
    // Under reduced motion the next page replaces the faded one in place.
    if (reduceMotion()) return _pages.jumpToPage(index);
    await _pages.animateToPage(
      index,
      duration: MotionDurations.adNoFillSkip,
      curve: MotionCurves.standard,
    );
  }

  @override
  void jumpToPage(int index) {
    if (_pages.hasClients) _pages.jumpToPage(index);
  }
}

/// One feed page, isolated in its own repaint boundary.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key, required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: switch (item) {
      EpisodeItem(:final episode) => EpisodePage(episode: episode),
      final AdSlotItem slot => AdPage(slot: slot),
    },
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 40,
          color: AppColors.onMediaMuted,
        ),
        const SizedBox(height: 12),
        Text(
          "Couldn't load episodes",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
