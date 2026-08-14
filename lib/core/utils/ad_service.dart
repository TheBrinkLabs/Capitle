import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Two rewarded ad "slots" the app asks for by purpose:
/// - clue: fast/short — this can be tapped often in a normal day.
/// - streakRepair: fires at most once a day.
///
/// Both currently point at the SAME Unity placement (see
/// _rewardedPlacementId) — there's only one rewarded placement configured
/// in the Unity dashboard so far, shared between the two.
enum RewardedAdSlot { clue, streakRepair }

/// Unity handles rewarded ads only — its interstitial and banner formats
/// were dropped (interstitial felt indistinguishable from a rewarded ad
/// with no reliable way to keep it short; its Flutter banner plugin has
/// a longstanding unresolved no-fill bug). Banner and the clue-reveal
/// placement now go through Meta Audience Network instead, via a native
/// platform channel (see meta_banner_ad.dart) since Meta has no
/// actively-maintained standalone Flutter plugin.
class AdService {
  static const _unityGameId = '800112186';
  static const _rewardedPlacementId = 'Rewarded_Android';

  // Meta Audience Network — App ID 27937713359198663.
  static const _metaBannerPlacementId = '27937713359198663_27937721435864522';
  static const _metaMrecPlacementId = '27937713359198663_27937721432531189';

  static const _metaAdsInitChannel = MethodChannel('meta_ads_init');

  // TODO: flip to false before shipping a real release — testMode serves
  // Unity's test ad creatives instead of live ones, so no real ads (or
  // real revenue) show while this is true.
  static const _testMode = true;

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
        loadRewardedAd(RewardedAdSlot.clue);
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

  // ── Banner (Meta) ────────────────────────────────────────────────────

  String get metaBannerPlacementId => _metaBannerPlacementId;
  String get metaMrecPlacementId => _metaMrecPlacementId;
  bool get isMetaInitialized => _isMetaInitialized;

  // ── Rewarded (Unity) ─────────────────────────────────────────────────
  //
  // Both slots share _rewardedPlacementId, so ready/loading state is
  // tracked once rather than per-slot — there's only one underlying ad
  // to be ready or not. `slot` is still accepted on every method below
  // purely so call sites keep expressing which feature is asking.

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
