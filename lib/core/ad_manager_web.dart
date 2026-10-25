import 'ad_manager.dart';

/// No-op ad manager for the web build.
///
/// Rewarded ads are not available on the web platform.  To keep the UX
/// functional (e.g. watermark removal) [showRewarded] auto-grants the reward.
class _WebAdManager implements AdManager {
  @override
  Future<void> init() async {}

  @override
  Future<void> preload() async {}

  @override
  Future<bool> showRewarded() async => true;
}

AdManager createAdManager() => _WebAdManager();
