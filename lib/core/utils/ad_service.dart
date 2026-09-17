import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

/// Rewarded ad "slot" — currently just streak repair (fires at most once
/// a day). The clue-reveal ad uses an embedded banner instead (see
/// clue_ad_screen.dart) rather than a rewarded video, specifically
/// because a rewarded ad's watch length/skip behaviour is controlled by
/// the SDK and the ad creative, not by us — clue needed a short,
/// predictable unlock time a rewarded video can't guarantee.
enum RewardedAdSlot { streakRepair }

/// Unity LevelPlay mediates everything now: Unity Ads, Vungle/Liftoff
/// Monetize, and Meta Audience Network all bid against each other for
/// the same ad units — the nav banner (see banner_ad_widget.dart), the
/// clue-reveal MREC, streak-repair's rewarded video, and its fallback
/// interstitial if the rewarded ad has nothing. Unity used to be called
/// directly via `unity_ads_plugin`; folded into LevelPlay so it competes
/// in the same real-time auction as everything else instead of always
/// getting first refusal in a fixed waterfall slot regardless of who'd
/// actually pay more for this request.
class AdService implements LevelPlayInitListener {
  // Unity LevelPlay — app-level key from the LevelPlay dashboard, plus
  // one ad-unit id per format. Unity Ads, Vungle, and Meta are each
  // configured as mediated networks behind these ad units in the
  // dashboard, mapped to their existing accounts (Unity Game ID
  // 800112186, Vungle App ID 6a8b5a2fa58d1846183b4aae, Meta App ID
  // 27937713359198663).
  static const _levelPlayAppKey = '27e98373d';
  static const _levelPlayBannerAdUnitId = 'ys76fqapff8aa0fn';
  static const _levelPlayMrecAdUnitId = '1t5uxyd1n2o74xik';
  static const _levelPlayInterstitialAdUnitId = 'y0s8vsk7x3cv5icb';
  static const _levelPlayRewardedAdUnitId = '2tdknaw4onigonjx';

  bool _isLevelPlayInitialized = false;

  late final LevelPlayInterstitialAd _levelPlayInterstitialAd;
  bool _levelPlayInterstitialReady = false;
  bool _levelPlayInterstitialLoading = false;
  VoidCallback? _pendingLevelPlayInterstitialDismiss;

  late final LevelPlayRewardedAd _levelPlayRewardedAd;
  bool _rewardedReady = false;
  bool _rewardedLoading = false;
  bool _rewardEarned = false; // set in onAdRewarded, read in onAdClosed
  VoidCallback? _pendingRewardOnReward;
  VoidCallback? _pendingRewardOnDismissedWithoutReward;

  AdService() {
    _levelPlayInterstitialAd = LevelPlayInterstitialAd(adUnitId: _levelPlayInterstitialAdUnitId);
    _levelPlayInterstitialAd.setListener(_InterstitialListener(this));
    _levelPlayRewardedAd = LevelPlayRewardedAd(adUnitId: _levelPlayRewardedAdUnitId);
    _levelPlayRewardedAd.setListener(_RewardedListener(this));
  }

  // GDPR/CCPA consent — see ad_consent.dart, which owns *when* this is
  // called (first-launch/existing-user gate, or re-opened from Settings).
  // [consentGranted] must be applied before LevelPlay.init() the first
  // time; on a later call (consent changed from Settings mid-session)
  // LevelPlay is already initialized so this just re-applies the flags —
  // that only affects *future* ad requests, not ones already in flight,
  // which is an accepted limitation rather than something worth an app
  // restart to fix properly.
  Future<void> initialize({required bool consentGranted}) async {
    await _applyConsent(consentGranted);
    if (_isLevelPlayInitialized) return;
    await _initLevelPlay();
  }

  Future<void> _applyConsent(bool granted) async {
    try {
      // Exact network key strings LevelPlay expects — confirmed against
      // Unity's own docs, not guessed: case-sensitive, "UnityAds" not
      // "Unity". Mintegral is included even though its account isn't live
      // yet — an inert entry for a network with no active instance is
      // harmless, and it's one less thing to remember to add later.
      await LevelPlayPrivacySettings.setGDPRConsents({
        'Facebook': granted,
        'Vungle': granted,
        'UnityAds': granted,
        'Mintegral': granted,
      });
      await LevelPlayPrivacySettings.setCCPA(!granted); // CCPA flag = "opted out of sale"
    } catch (e, st) {
      debugPrint('Failed to apply ad consent: $e\n$st');
    }
  }

  Future<void> _initLevelPlay() async {
    try {
      // Registered before init, per LevelPlay's own guidance — attaching
      // the listener afterward risks losing early impression events.
      LevelPlay.addImpressionDataListener(_ImpressionDataListener());
      final initRequest = LevelPlayInitRequest.builder(_levelPlayAppKey).build();
      await LevelPlay.init(initRequest: initRequest, initListener: this);
    } catch (e, st) {
      debugPrint('LevelPlay failed to initialize: $e\n$st');
    }
  }

  // ── LevelPlayInitListener ────────────────────────────────────────────

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    debugPrint('LevelPlay initialized');
    _isLevelPlayInitialized = true;
    loadLevelPlayInterstitial();
    loadRewardedAd(RewardedAdSlot.streakRepair);
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    debugPrint('LevelPlay failed to initialize: $error');
  }

  // ── Banner + MREC (LevelPlay) ────────────────────────────────────────

  String get levelPlayBannerAdUnitId => _levelPlayBannerAdUnitId;
  String get levelPlayMrecAdUnitId => _levelPlayMrecAdUnitId;
  bool get isLevelPlayInitialized => _isLevelPlayInitialized;

  // ── Interstitial, streak-repair fallback (LevelPlay) ─────────────────

  bool get isLevelPlayInterstitialReady => _levelPlayInterstitialReady;

  void loadLevelPlayInterstitial() {
    if (_levelPlayInterstitialReady || _levelPlayInterstitialLoading) return;
    _levelPlayInterstitialLoading = true;
    _levelPlayInterstitialAd.loadAd();
  }

  /// Shows the streak-repair interstitial — falls back to this when the
  /// rewarded video (see below) has nothing (see streak_break_dialog.dart).
  /// Unlike a rewarded ad, an interstitial has no "reward earned" signal
  /// of its own: [onDismissed] fires once the user closes it, full stop,
  /// so callers treat "watched" and "dismissed" as the same outcome —
  /// there's no equivalent of a rewarded ad's skip-without-reward case.
  Future<void> showLevelPlayInterstitial({
    required VoidCallback onDismissed,
    VoidCallback? onNotReady,
  }) async {
    final ready = await _levelPlayInterstitialAd.isAdReady();
    if (!ready) {
      onNotReady?.call();
      loadLevelPlayInterstitial();
      return;
    }
    _pendingLevelPlayInterstitialDismiss = onDismissed;
    // 'Default' — LevelPlay's placement name is a reporting tag, not a
    // functional identifier; there's only one placement for this slot.
    _levelPlayInterstitialAd.showAd(placementName: 'Default');
  }

  void _onInterstitialLoaded() {
    debugPrint('LevelPlay interstitial loaded');
    _levelPlayInterstitialReady = true;
    _levelPlayInterstitialLoading = false;
  }

  void _onInterstitialLoadFailed(LevelPlayAdError error) {
    debugPrint('LevelPlay interstitial failed to load: $error');
    _levelPlayInterstitialReady = false;
    _levelPlayInterstitialLoading = false;
  }

  void _onInterstitialDisplayFailed(LevelPlayAdError error) {
    debugPrint('LevelPlay interstitial failed to display: $error');
    _levelPlayInterstitialReady = false;
    _pendingLevelPlayInterstitialDismiss?.call();
    _pendingLevelPlayInterstitialDismiss = null;
    loadLevelPlayInterstitial();
  }

  void _onInterstitialClosed() {
    _levelPlayInterstitialReady = false; // consumed — reload below for next time
    _pendingLevelPlayInterstitialDismiss?.call();
    _pendingLevelPlayInterstitialDismiss = null;
    loadLevelPlayInterstitial();
  }

  // ── Rewarded, streak-repair primary (LevelPlay) ──────────────────────
  //
  // `slot` is accepted on every method below purely so call sites keep
  // expressing which feature is asking, even though there's currently
  // only the one rewarded slot.

  bool isRewardedAdReady(RewardedAdSlot slot) => _rewardedReady;

  void loadRewardedAd(RewardedAdSlot slot) {
    if (_rewardedReady || _rewardedLoading) return;
    _rewardedLoading = true;
    _levelPlayRewardedAd.loadAd();
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
    _rewardEarned = false;
    _pendingRewardOnReward = onReward;
    _pendingRewardOnDismissedWithoutReward = onDismissedWithoutReward;
    _levelPlayRewardedAd.showAd(placementName: 'Default');
  }

  void _onRewardedLoaded() {
    debugPrint('LevelPlay rewarded ad loaded');
    _rewardedReady = true;
    _rewardedLoading = false;
  }

  void _onRewardedLoadFailed(LevelPlayAdError error) {
    debugPrint('LevelPlay rewarded ad failed to load: $error');
    _rewardedReady = false;
    _rewardedLoading = false;
  }

  void _onRewardedDisplayFailed(LevelPlayAdError error) {
    debugPrint('LevelPlay rewarded ad failed to display: $error');
    _rewardedReady = false;
    _pendingRewardOnDismissedWithoutReward?.call();
    _pendingRewardOnReward = null;
    _pendingRewardOnDismissedWithoutReward = null;
    loadRewardedAd(RewardedAdSlot.streakRepair);
  }

  void _onRewardedEarned() {
    _rewardEarned = true;
  }

  void _onRewardedClosed() {
    if (_rewardEarned) {
      _pendingRewardOnReward?.call();
    } else {
      _pendingRewardOnDismissedWithoutReward?.call();
    }
    _pendingRewardOnReward = null;
    _pendingRewardOnDismissedWithoutReward = null;
    loadRewardedAd(RewardedAdSlot.streakRepair);
  }

  void dispose() {
    // Both SDKs manage their own ad lifecycle internally; nothing to
    // explicitly dispose here.
  }
}

// LevelPlayInterstitialAd and LevelPlayRewardedAd share identically-named
// listener methods (onAdLoaded, onAdClosed, etc.) — if AdService
// implemented both listener interfaces directly, one method body
// couldn't tell which ad type had actually fired it. Each ad object gets
// its own small adapter instead, delegating to AdService's private
// per-ad-type handlers.

class _InterstitialListener implements LevelPlayInterstitialAdListener {
  final AdService _service;
  _InterstitialListener(this._service);

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _service._onInterstitialLoaded();
  @override
  void onAdLoadFailed(LevelPlayAdError error) => _service._onInterstitialLoadFailed(error);
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) =>
      _service._onInterstitialDisplayFailed(error);
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _service._onInterstitialClosed();
  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}

class _RewardedListener implements LevelPlayRewardedAdListener {
  final AdService _service;
  _RewardedListener(this._service);

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _service._onRewardedLoaded();
  @override
  void onAdLoadFailed(LevelPlayAdError error) => _service._onRewardedLoadFailed(error);
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) =>
      _service._onRewardedDisplayFailed(error);
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _service._onRewardedClosed();
  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) => _service._onRewardedEarned();
}

// Forwards LevelPlay's per-impression revenue data (Impression-Level
// Revenue / ILR) to Firebase Analytics as an `ad_impression` event —
// Firebase/GA4's own documented convention for ad-mediation revenue
// events, letting ad revenue show up alongside the rest of the app's
// analytics rather than only in LevelPlay's own dashboard.
class _ImpressionDataListener implements LevelPlayImpressionDataListener {
  @override
  void onImpressionSuccess(LevelPlayImpressionData impressionData) {
    FirebaseAnalytics.instance.logEvent(
      name: 'ad_impression',
      parameters: {
        'ad_platform': 'levelplay',
        if (impressionData.adNetwork != null) 'ad_source': impressionData.adNetwork!,
        if (impressionData.adFormat != null) 'ad_format': impressionData.adFormat!,
        if (impressionData.mediationAdUnitName != null)
          'ad_unit_name': impressionData.mediationAdUnitName!,
        'currency': 'USD',
        if (impressionData.revenue != null) 'value': impressionData.revenue!,
      },
    );
  }
}

final adService = AdService();
