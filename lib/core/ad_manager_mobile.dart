import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_manager.dart';

/// Rewarded-ad controller for Android / iOS via Google AdMob.
class MobileAdManager implements AdManager {
  static const _unitId = 'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _ad;
  Completer<void>? _loading;
  bool _initialised = false;

  @override
  Future<void> init() {
    if (_initialised) return Future.value();
    _initialised = true;
    return MobileAds.instance.initialize();
  }

  @override
  Future<void> preload() {
    if (_ad != null) return Future.value();
    if (_loading != null) return _loading!.future;
    final c = Completer<void>();
    _loading = c;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (a) {
          _ad = a;
          _loading = null;
          c.complete();
        },
        onAdFailedToLoad: (_) {
          _loading = null;
          c.complete();
        },
      ),
    );
    return c.future;
  }

  @override
  Future<bool> showRewarded() async {
    await preload().timeout(const Duration(seconds: 8), onTimeout: () {});
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preload();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return done.future;
  }
}

AdManager createAdManager() => MobileAdManager();
