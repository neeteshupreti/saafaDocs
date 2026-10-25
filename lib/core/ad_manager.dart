import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Conditional import (for use within this file) + conditional export
// (for other files that import this library).
import 'ad_manager_mobile.dart' if (dart.library.html) 'ad_manager_web.dart';
export 'ad_manager_mobile.dart' if (dart.library.html) 'ad_manager_web.dart';

/// Rewarded-ad controller.
///
/// On mobile this wraps Google AdMob; on web it is a no-op stub (ads are not
/// available in the browser).  The web stub auto-grants the reward so that
/// the watermark-removal UX still works on the web build.
abstract class AdManager {
  /// Initialise the ad SDK. No-op on web.
  Future<void> init();

  /// Pre-load a rewarded ad so that [showRewarded] is instant.
  Future<void> preload();

  /// Show the rewarded ad. Returns true only if the user earned the reward.
  /// On web this always returns true (no real ads available).
  Future<bool> showRewarded();
}

/// The provider — concrete [AdManager] is selected at compile time via the
/// conditional export below.
final adProvider = Provider<AdManager>((ref) => createAdManager());

// Each platform file defines:
//   AdManager createAdManager();
