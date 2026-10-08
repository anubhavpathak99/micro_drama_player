import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/application/player_pool.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/feed_item.dart';
import 'package:micro_drama_interactive_player/presentation/ads/ad_page.dart';
import 'package:micro_drama_interactive_player/presentation/debug/debug_panel.dart';
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
            if (kDebugMode || kProfileMode)
              const SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: DebugPanelButton(),
                ),
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
  ModalRoute<void>? _route;

  // The physics in use and what they were built from. New instances are made
  // only when the locked page (or the platform physics) changes.
  ScrollPhysics? _physics;
  ScrollPhysics? _physicsBase;
  int? _physicsLockedPage;

  PlayerPool get _pool => ref.read(playerPoolProvider.notifier);

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      initialPage: ref.read(feedControllerProvider).requireValue.currentIndex,
    );
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    ref.listenManual(
      paywallControllerProvider.select((paywall) => paywall.lockedItemId),
      (_, lockedItemId) => _returnToLock(lockedItemId),
    );
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
    if (!identical(widget.items, oldWidget.items)) _indexById = _indexItems();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

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

  void _onPageChanged(int index) {
    ref
        .read(feedControllerProvider.notifier)
        .setCurrent(widget.items[index].id);
    _precacheAround(index);
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.depth == 0) _pool.rewindInactive();
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
    for (var i = index - 2; i <= index + 2; i++) {
      if (i < 0 || i >= widget.items.length) continue;
      if (widget.items[i] case EpisodeItem(:final episode)) {
        unawaited(precacheImage(AssetImage(episode.posterAsset), context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // Recomputed every build: removing an ad shifts the locked page's index.
    final lockedItemId = ref.watch(
      paywallControllerProvider.select((paywall) => paywall.lockedItemId),
    );
    final physics = _physicsFor(_indexById[lockedItemId]);
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
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
        scrollBehavior: ScrollConfiguration.of(context)
            .copyWith(scrollbars: false, physics: physics),
        onPageChanged: _onPageChanged,
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) =>
              FeedPage(key: ValueKey(items[index].id), item: items[index]),
          childCount: items.length,
          findChildIndexCallback: (key) =>
              _indexById[(key as ValueKey<String>).value],
          // Pages hold no state worth keeping alive (the pool owns players),
          // and FeedPage adds its own repaint boundary.
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
        ),
      ),
    );
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
