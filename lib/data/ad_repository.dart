import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:micro_drama_interactive_player/core/diagnostics/lifecycle_log.dart';
import 'package:micro_drama_interactive_player/core/env/ad_config.dart';

/// A native ad, loaded and ready to render. Callers never see SDK types.
abstract interface class NativeAdHandle {
  /// The ad's platform view. Build it in one place at a time.
  Widget buildView();

  /// Releases the ad. Its native view goes away after the current frame, so
  /// a view that is still on screen never points at a released ad.
  void dispose();
}

/// Why an ad didn't arrive.
final class AdLoadFailure implements Exception {
  const AdLoadFailure({
    required this.code,
    required this.message,
    required this.noFill,
  });

  final int code;
  final String message;

  /// The server had no ad to give, as opposed to an error.
  final bool noFill;

  @override
  String toString() => 'AdLoadFailure($code: $message)';
}

abstract interface class AdRepository {
  /// Starts the ads SDK. Loads wait for it.
  Future<void> initialize();

  /// Loads a full-screen native ad. Fails with [AdLoadFailure].
  /// [onImpression] runs when the SDK records an impression.
  Future<NativeAdHandle> loadNative({required VoidCallback onImpression});
}

/// [AdRepository] backed by Google Mobile Ads, using Ad Manager requests.
final class GoogleAdRepository implements AdRepository {
  Future<void>? _initialized;
  int _serial = 0;

  @override
  Future<void> initialize() => _initialized ??= MobileAds.instance.initialize();

  @override
  Future<NativeAdHandle> loadNative({
    required VoidCallback onImpression,
  }) async {
    await initialize();
    final loaded = Completer<NativeAdHandle>();
    final id = 'ad#${++_serial}';
    late final NativeAd ad;
    ad = NativeAd.fromAdManagerRequest(
      adUnitId: AdConfig.nativeUnitId,
      factoryId: AdConfig.nativeFactoryId,
      adManagerRequest: const AdManagerAdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => loaded.complete(_GoogleNativeAd(ad, id)),
        onAdFailedToLoad: (_, error) {
          unawaited(ad.dispose());
          LifecycleLog.closed(LifecycleKind.ad, id);
          loaded.completeError(
            AdLoadFailure(
              code: error.code,
              message: error.message,
              noFill: _isNoFill(error),
            ),
          );
        },
        onAdImpression: (_) => onImpression(),
      ),
    );
    LifecycleLog.opened(LifecycleKind.ad, id);
    await ad.load();
    return loaded.future;
  }

  // The two SDKs number "no fill" differently.
  static bool _isNoFill(LoadAdError error) => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => error.code == 1,
    _ => error.code == 3,
  };
}

final class _GoogleNativeAd implements NativeAdHandle {
  _GoogleNativeAd(this._ad, this._id);

  final NativeAd _ad;
  final String _id;
  // One widget for the ad's life, so rebuilds around it skip the view.
  late final Widget _view = AdWidget(ad: _ad);

  @override
  Widget buildView() => _view;

  @override
  void dispose() {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        unawaited(_ad.dispose());
        LifecycleLog.closed(LifecycleKind.ad, _id);
      })
      ..scheduleFrame();
  }
}

final Provider<AdRepository> adRepositoryProvider = Provider(
  (ref) => GoogleAdRepository(),
);
