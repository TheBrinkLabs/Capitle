import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Rewarded ad "slot" — currently just streak repair (fires at most once
/// a day). The clue-reveal ad uses an embedded banner instead (see
/// clue_ad_screen.dart) rather than a rewarded video, specifically
/// because a rewarded ad's watch length/skip behaviour is controlled by
/// the SDK and the ad creative, not by us — clue needed a short,
/// predictable unlock time a rewarded video can't guarantee.
enum RewardedAdSlot { streakRepair }

/// Unity handles rewarded ads (streak repair) and is the primary banner
/// provider (both the persistent nav banner and the clue-reveal embed).
/// Its interstitial format was dropped (felt indistinguishable from a
/// rewarded ad with no reliable way to keep it short) — that one still
/// goes nowhere. Meta Audience Network (see meta_banner_ad.dart, wired up
/// via a native platform channel since it has no standalone Flutter
/// plugin) is the nav banner's second provider in the waterfall — see
/// banner_ad_widget.dart.
class AdService {
  static const _unityGameId = '800112186';
  static const _rewardedPlacementId = 'Rewarded_Android';
  static const _bannerPlacementId = 'Banner_Android';

  // Meta Audience Network — App ID 27937713359198663.
  static const _metaBannerPlacementId = '27937713359198663_27937721435864522';

  static const _metaAdsInitChannel = MethodChannel('meta_ads_init');

  // Was hardcoded true, which meant Unity was serving test ad creatives
  // in every build, release included — no real Unity revenue was ever
  // possible while that stood. kDebugMode ties it to the actual build
  // type instead: real ads in release, test creatives while developing.
  static const bool _testMode = kDebugMode;

  bool _isUnityInitialized = false;
  bool _isMetaInitialized = false;
  bool _rewardedReady = false;
  bool _rewardedLoading = false;

  Future<void> initialize() async {
    await Future.wait([_initUnity(), _initMeta()]);
  }

  Future<void> _initUnity() async {
    await UnityAds.init(
      gameId: _unityGameId,
      testMode: _testMode,
      onComplete: () {
        debugPrint('Unity Ads initialized');
        _isUnityInitialized = true;
        loadRewardedAd(RewardedAdSlot.streakRepair);
      },
      onFailed: (error, message) {
        debugPrint('Unity Ads failed to initialize: $error $message');
      },
    );
  }

  Future<void> _initMeta() async {
    try {
      final result = await _metaAdsInitChannel.invokeMethod<Map<Object?, Object?>>('initialize');
      final success = result?['success'] as bool? ?? false;
      debugPrint('Meta Audience Network initialized: $success (${result?['message']})');
      _isMetaInitialized = success;
    } catch (e, st) {
      debugPrint('Meta Audience Network failed to initialize: $e\n$st');
    }
  }

  // ── Banner, second provider (Meta) ──────────────────────────────────

  String get metaBannerPlacementId => _metaBannerPlacementId;
  bool get isMetaInitialized => _isMetaInitialized;

  // ── Banner + Rewarded (Unity) ────────────────────────────────────────
  //
  // Rewarded's two slots share _rewardedPlacementId, so ready/loading
  // state is tracked once rather than per-slot — there's only one
  // underlying ad to be ready or not. `slot` is still accepted on every
  // method below purely so call sites keep expressing which feature is
  // asking.

  String get unityBannerPlacementId => _bannerPlacementId;
  bool get isUnityInitialized => _isUnityInitialized;

  bool isRewardedAdReady(RewardedAdSlot slot) => _rewardedReady;

  void loadRewardedAd(RewardedAdSlot slot) {
    if (_rewardedReady || _rewardedLoading) return;
    _rewardedLoading = true;
    UnityAds.load(
      placementId: _rewardedPlacementId,
      onComplete: (placementId) {
        debugPrint('RewardedAd loaded');
        _rewardedReady = true;
        _rewardedLoading = false;
      },
      onFailed: (placementId, error, message) {
        debugPrint('RewardedAd failed to load: $error $message');
        _rewardedReady = false;
        _rewardedLoading = false;
      },
    );
  }

  void showRewardedAd(
    RewardedAdSlot slot, {
    required VoidCallback onReward,
    VoidCallback? onDismissedWithoutReward,
    VoidCallback? onNotReady,
  }) {
    if (!_rewardedReady) {
      onNotReady?.call();
      loadRewardedAd(slot);
      return;
    }
    _rewardedReady = false; // consumed — reload below for next time
    UnityAds.showVideoAd(
      placementId: _rewardedPlacementId,
      onComplete: (placementId) {
        onReward();
        loadRewardedAd(slot);
      },
      onSkipped: (placementId) {
        onDismissedWithoutReward?.call();
        loadRewardedAd(slot);
      },
      onFailed: (placementId, error, message) {
        debugPrint('RewardedAd failed to display: $error $message');
        onDismissedWithoutReward?.call();
        loadRewardedAd(slot);
      },
    );
  }

  void dispose() {
    // Both SDKs manage their own ad lifecycle internally; nothing to
    // explicitly dispose here.
  }
}

final adService = AdService();
