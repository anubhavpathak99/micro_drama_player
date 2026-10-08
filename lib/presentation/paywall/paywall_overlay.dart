import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_drama_interactive_player/application/feed_controller.dart';
import 'package:micro_drama_interactive_player/application/paywall_controller.dart';
import 'package:micro_drama_interactive_player/core/haptics/haptics.dart';
import 'package:micro_drama_interactive_player/core/motion/motion_tokens.dart';
import 'package:micro_drama_interactive_player/core/motion/reduced_motion.dart';
import 'package:micro_drama_interactive_player/core/theme/app_theme.dart';
import 'package:micro_drama_interactive_player/domain/episode.dart';
import 'package:micro_drama_interactive_player/domain/unlock_state.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/paywall_motion.dart';
import 'package:micro_drama_interactive_player/presentation/paywall/shimmer_cta.dart';

/// Card content that enters one group after another: heading, perks, price
/// and actions.
const int _contentGroups = 4;

/// Card kept below the screen edge, so the entrance spring's overshoot never
/// opens a gap beneath the card.
const double _overshootRoom = 80;

/// Visibility at which a page counts as settled in view.
const double _inView = 0.999;

/// The paywall over a premium episode: the page's bundled poster blurred
/// behind a card offering the unlock.
///
/// The card peeks in with its page and springs up once the page settles.
/// Leaving the page resets it, so every visit replays the entrance. After a
/// purchase the button turns into a checkmark, the card drops away and the
/// blur clears; only then does the episode unlock and start playing.
class PaywallOverlay extends ConsumerStatefulWidget {
  const PaywallOverlay({super.key, required this.episode});

  final Episode episode;

  @override
  ConsumerState<PaywallOverlay> createState() => _PaywallOverlayState();
}

class _PaywallOverlayState extends ConsumerState<PaywallOverlay>
    with TickerProviderStateMixin {
  // Card position: 0 hidden below the page, 1 at rest. Unbounded so the
  // entrance spring can overshoot. The backdrop blur follows it too.
  late final AnimationController _card = AnimationController.unbounded(
    vsync: this,
  );

  // Staggered entrance of the card's content groups.
  late final AnimationController _content = AnimationController(
    vsync: this,
    duration: staggerDuration(_contentGroups),
  );

  // Whether the card has made its entrance. The button sweeps only then.
  final ValueNotifier<bool> _entered = ValueNotifier(false);

  ScrollPosition? _position;
  bool _exiting = false;
  bool _purchased = false;
  String? _message;

  Episode get _episode => widget.episode;

  bool get _gated =>
      ref.read(paywallControllerProvider).stateOf(_episode) !=
      UnlockState.unlocked;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      paywallControllerProvider.select((paywall) => paywall.stateOf(_episode)),
      _onGateChanged,
    );
    // Already settled on this page (or not in a feed at all): enter now.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The feed swaps its scroll position when the paywall physics change.
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;
    _unsubscribe();
    _position = position
      ?..addListener(_onScroll)
      ..isScrollingNotifier.addListener(_onScroll);
  }

  @override
  void dispose() {
    _unsubscribe();
    _card.dispose();
    _content.dispose();
    _entered.dispose();
    super.dispose();
  }

  void _unsubscribe() => _position
    ?..removeListener(_onScroll)
    ..isScrollingNotifier.removeListener(_onScroll);

  /// How much of this page is on screen. A paywall outside a feed is always
  /// fully in view.
  double get _visibility {
    final position = _position;
    if (position == null) return 1;
    final index =
        ref.read(feedControllerProvider).value?.indexOf(_episode.id) ?? -1;
    if (index < 0 ||
        !position.hasPixels ||
        !position.hasViewportDimension ||
        position.viewportDimension <= 0) {
      return 0;
    }
    return pageVisibility(
      page: position.pixels / position.viewportDimension,
      index: index,
    );
  }

  bool get _scrolling => _position?.isScrollingNotifier.value ?? false;

  // Peek while the page scrolls in, spring up once it settles, and reset
  // once it has fully left.
  void _onScroll() {
    if (!_gated || _exiting) return;
    final visibility = _visibility;
    if (visibility == 0) {
      _resetEntrance();
    } else if (!_entered.value) {
      if (!_scrolling && visibility >= _inView) {
        _enter();
      } else if (!context.reduceMotion) {
        _card.value = peekProgress(visibility);
      }
    }
  }

  void _enter() {
    _entered.value = true;
    if (context.reduceMotion) {
      unawaited(
        _card.animateTo(1, duration: MotionDurations.reducedMotionFade),
      );
      _content.value = 1;
    } else {
      // Hand-off: the spring starts wherever the peek left the card.
      unawaited(
        _card.animateWith(
          SpringSimulation(
            MotionSprings.bouncy,
            _card.value,
            1,
            0,
            snapToEnd: true,
          ),
        ),
      );
      unawaited(_content.forward(from: 0));
    }
  }

  void _resetEntrance() {
    if (!_entered.value && _card.value == 0) return;
    _card.value = 0;
    _content.value = 0;
    _entered.value = false;
  }

  void _onGateChanged(UnlockState? previous, UnlockState next) {
    switch (next) {
      case UnlockState.locked:
        // A failed purchase or a reset: the paywall stands again.
        _purchased = false;
        _onScroll();
      case UnlockState.unlocking:
        break;
      case UnlockState.unlocked:
        // Unlocked from elsewhere (the debug panel) while the card is up.
        if (_card.value > 0 && !_exiting) unawaited(_dismiss());
    }
  }

  Future<void> _unlock() async {
    final paywall = ref.read(paywallControllerProvider.notifier);
    setState(() => _message = null);
    try {
      await paywall.unlock(_episode.id, onPurchased: _celebrate);
    } on Object {
      if (mounted) {
        setState(() => _message = "Couldn't unlock this episode. Try again.");
      }
    }
  }

  // Runs between the purchase going through and the episode opening up.
  Future<void> _celebrate() async {
    if (!mounted) return;
    setState(() => _purchased = true);
    unawaited(Haptics.success());
    await Future<void>.delayed(MotionDurations.unlockCelebration);
    if (mounted) await _dismiss();
  }

  Future<void> _dismiss() async {
    setState(() => _exiting = true);
    final leaving = context.reduceMotion
        ? _card.animateTo(0, duration: MotionDurations.reducedMotionFade)
        : _card.animateTo(
            0,
            duration: MotionDurations.paywallDismiss,
            curve: MotionCurves.exit,
          );
    try {
      await leaving.orCancel;
    } on TickerCanceled {
      return; // Disposed while leaving. The unlock completes regardless.
    }
    if (!mounted) return;
    _content.value = 0;
    _entered.value = false;
    setState(() {
      _exiting = false;
      _purchased = false;
    });
  }

  void _watchAd() {
    // TODO: Unlock through the GAM rewarded test unit once ads are in place.
    setState(() => _message = 'Rewarded unlocks are not available yet.');
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(
      paywallControllerProvider.select((paywall) => paywall.stateOf(_episode)),
    );
    if (gate == UnlockState.unlocked && !_exiting) {
      return const SizedBox.shrink();
    }
    final reduceMotion = context.reduceMotion;
    final phase = _purchased
        ? CtaPhase.done
        : gate == UnlockState.unlocking
        ? CtaPhase.busy
        : CtaPhase.idle;

    return Semantics(
      container: true,
      label: 'Episode ${_episode.number} is locked',
      child: GestureDetector(
        // Taps on the backdrop must not reach the page beneath.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Backdrop(strength: _card),
            Positioned(
              left: 0,
              right: 0,
              bottom: -_overshootRoom,
              child: AnimatedBuilder(
                animation: _card,
                builder: (context, card) => reduceMotion
                    ? Opacity(opacity: _card.value.clamp(0.0, 1.0), child: card)
                    : FractionalTranslation(
                        translation: Offset(0, 1 - _card.value),
                        child: card,
                      ),
                child: RepaintBoundary(
                  child: _PaywallCard(
                    episode: _episode,
                    content: _content,
                    rise: reduceMotion ? 0 : MotionValues.staggerRise,
                    phase: phase,
                    entered: _entered,
                    message: _message,
                    onUnlock: phase == CtaPhase.idle ? _unlock : null,
                    onWatchAd: phase == CtaPhase.idle ? _watchAd : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page beneath, blurred and darkened in step with the card.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.strength});

  /// Card position; values past 1 (overshoot) count as full strength.
  final Animation<double> strength;

  // Darker at the top too, so the status bar stays legible over a bright
  // blurred poster.
  static const List<double> _scrimAlphas = [0.45, 0.5, 0.85];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: strength,
    builder: (context, _) {
      final amount = strength.value.clamp(0.0, 1.0);
      if (amount == 0) return const SizedBox.shrink();
      final sigma = MotionValues.paywallBlurSigma * amount;
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  for (final alpha in _scrimAlphas)
                    Color.fromRGBO(0, 0, 0, alpha * amount),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PaywallCard extends StatelessWidget {
  const _PaywallCard({
    required this.episode,
    required this.content,
    required this.rise,
    required this.phase,
    required this.entered,
    required this.message,
    required this.onUnlock,
    required this.onWatchAd,
  });

  final Episode episode;
  final Animation<double> content;
  final double rise;
  final CtaPhase phase;
  final ValueListenable<bool> entered;
  final String? message;
  final VoidCallback? onUnlock;
  final VoidCallback? onWatchAd;

  @override
  Widget build(BuildContext context) {
    Widget group(int index, Widget child) => _Staggered(
      animation: content.drive(
        CurveTween(curve: staggerInterval(index, count: _contentGroups)),
      ),
      rise: rise,
      child: child,
    );

    return DecoratedBox(
      key: const Key('paywall-card'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          28,
          24,
          20 + MediaQuery.paddingOf(context).bottom + _overshootRoom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            group(0, _Heading(episode: episode)),
            const SizedBox(height: 20),
            group(1, const _Perks()),
            const SizedBox(height: 16),
            group(2, const _Price()),
            const SizedBox(height: 20),
            group(
              3,
              _Actions(
                phase: phase,
                entered: entered,
                message: message,
                onUnlock: onUnlock,
                onWatchAd: onWatchAd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades [child] in with [animation] while it rises [rise] pixels.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.rise,
    required this.child,
  });

  final Animation<double> animation;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: rise == 0
        ? child
        : AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, (1 - animation.value) * rise),
              child: child,
            ),
            child: child,
          ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PremiumTag(),
      const SizedBox(height: 12),
      Text(
        'Unlock Episode ${episode.number}',
        style: const TextStyle(
          color: AppColors.onMedia,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        episode.title,
        style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 15),
      ),
    ],
  );
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.premium.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_rounded, size: 12, color: AppColors.premium),
        SizedBox(width: 4),
        Text(
          'PREMIUM',
          style: TextStyle(
            color: AppColors.premium,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class _Perks extends StatelessWidget {
  const _Perks();

  static const List<String> _perks = [
    'Watch the full episode now',
    'Yours to rewatch anytime',
    'Unlocks instantly on this device',
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final perk in _perks)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.premium,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  perk,
                  style: const TextStyle(
                    color: AppColors.onMedia,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Price extends StatelessWidget {
  const _Price();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        r'$0.99',
        style: TextStyle(
          color: AppColors.onMedia,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(width: 8),
      Text(
        'one-time',
        style: TextStyle(color: AppColors.onMediaMuted, fontSize: 14),
      ),
    ],
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.phase,
    required this.entered,
    required this.message,
    required this.onUnlock,
    required this.onWatchAd,
  });

  final CtaPhase phase;
  final ValueListenable<bool> entered;
  final String? message;
  final VoidCallback? onUnlock;
  final VoidCallback? onWatchAd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (message case final message?)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.onMediaMuted, fontSize: 13),
          ),
        ),
      ValueListenableBuilder<bool>(
        valueListenable: entered,
        builder: (context, entered, _) => ShimmerCta(
          label: 'Unlock Episode',
          phase: phase,
          onPressed: onUnlock,
          shimmer: entered,
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: onWatchAd,
        style: TextButton.styleFrom(foregroundColor: AppColors.onMediaMuted),
        child: const Text('Watch an ad to unlock'),
      ),
    ],
  );
}
