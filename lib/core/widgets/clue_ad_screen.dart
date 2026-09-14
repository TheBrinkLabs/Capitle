import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import '../theme/app_theme.dart';
import '../utils/ad_service.dart';
import 'aluna_mrec_ad.dart';

/// A "watch an ad for a clue" screen modelled on Wordle's own — an ad
/// embedded directly in a page WE control, with our own always-visible
/// "Get Clue" button, rather than a network's native full-screen
/// interstitial or rewarded ad. A rewarded video's watch length/skip
/// behaviour is controlled by the SDK and the ad creative being served,
/// not by us — there's no way to guarantee a short, predictable unlock
/// time with one. Embedding a fixed-size ad in our own screen keeps that
/// fully in our control instead: LevelPlay's (Vungle-mediated) MREC —
/// a bigger, higher-value format than a plain banner — and, since
/// display ads have no minimum-watch guarantee either way, the internal
/// Aluna house ad as a real final fallback instead of a blank placeholder,
/// so there's always something worth looking at during the watch timer
/// even when the real network doesn't fill. Plus a short minimum watch
/// timer we own throughout, independent of whichever slot ends up showing.
Future<void> showClueAdScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _ClueAdScreen(),
    ),
  );
}

class _ClueAdScreen extends StatefulWidget {
  const _ClueAdScreen();

  @override
  State<_ClueAdScreen> createState() => _ClueAdScreenState();
}

class _ClueAdScreenState extends State<_ClueAdScreen> implements LevelPlayBannerAdViewListener {
  // Minimum time the ad must be visible before "Get Clue" is tappable —
  // display ads have no SDK-level "reward earned" signal the way a
  // rewarded video does, so this is a product-level stand-in: give the
  // ad a real chance to actually be seen rather than letting the button
  // be tapped the instant the screen opens.
  static const _minWatchSeconds = 8;
  static const _providerTimeout = Duration(seconds: 6);

  final _mrecKey = GlobalKey<LevelPlayBannerAdViewState>();

  bool _adFailed = false;
  bool _canContinue = false;
  int _secondsRemaining = _minWatchSeconds;
  Timer? _countdownTimer;
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _startProviderTimeout();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startProviderTimeout() {
    _loadTimeoutTimer?.cancel();
    // If the ad never calls back at all (success or failure) within
    // this window, don't leave the user stuck waiting on nothing —
    // treat it the same as a failed load.
    _loadTimeoutTimer = Timer(_providerTimeout, _onProviderFailed);
  }

  void _onProviderFailed() {
    if (!mounted || _countdownTimer != null) return;
    // The real network struck out — the internal Aluna house ad is a
    // real fallback, not a blank placeholder, so it still gets the same
    // minimum-watch countdown as a real ad rather than letting the user
    // through instantly.
    setState(() => _adFailed = true);
    _startCountdown();
  }

  void _startCountdown() {
    _loadTimeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _canContinue = true;
        });
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Widget _buildProviderAd() {
    return LevelPlayBannerAdView(
      key: _mrecKey,
      adUnitId: adService.levelPlayMrecAdUnitId,
      adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
      listener: this,
      onPlatformViewCreated: () => _mrecKey.currentState?.loadAd(),
    );
  }

  // ── LevelPlayBannerAdViewListener ────────────────────────────────────

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _startCountdown();

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('Clue ad (LevelPlay MREC) failed to load: $error');
    _onProviderFailed();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    debugPrint('Clue ad (LevelPlay MREC) failed to display: $error');
    _onProviderFailed();
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'ADVERTISEMENT',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                  color: textMuted,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _adFailed ? const AlunaMrecAd() : _buildProviderAd(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: _canContinue ? () => Navigator.of(context).pop() : null,
                child: AnimatedOpacity(
                  opacity: _canContinue ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _canContinue ? AppColors.gradientTealBlue : null,
                      color: _canContinue ? null : surface2,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _canContinue
                          ? [BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 5))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _canContinue ? 'Get Clue' : 'Get Clue in ${_secondsRemaining}s',
                          style: TextStyle(
                            fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                            color: _canContinue ? Colors.black : textMuted,
                          ),
                        ),
                        if (_canContinue) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                        ],
                      ],
                    ),
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
