import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/ad_service.dart';
import '../utils/meta_banner_ad.dart';
import 'aluna_mrec_ad.dart';

/// A "watch an ad for a clue" screen modelled on Wordle's own — an ad
/// embedded directly in a page WE control, with our own always-visible
/// "Get Clue" button, rather than a network's native full-screen
/// interstitial. A native interstitial view is owned entirely by the ad
/// SDK: we can't put our own button on top of it or control how long it
/// runs. Embedding a fixed-size (MREC) ad in our own screen sidesteps
/// that entirely — the user decides when to move on, always.
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

class _ClueAdScreenState extends State<_ClueAdScreen> {
  // Minimum time the ad must be visible before "Get Clue" is tappable —
  // MREC ads have no SDK-level "reward earned" signal the way a
  // rewarded video does, so this is a product-level stand-in: give the
  // ad a real chance to actually be seen rather than letting the button
  // be tapped the instant the screen opens.
  static const _minWatchSeconds = 7;

  bool _adFailed = false;
  bool _canContinue = false;
  int _secondsRemaining = _minWatchSeconds;
  Timer? _countdownTimer;
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    // If the ad never calls back at all (success or failure) within
    // this window, don't leave the user stuck waiting on nothing —
    // fall back to the house ad and start its own watch countdown.
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_adFailed && _countdownTimer == null) {
        setState(() => _adFailed = true);
        _startCountdown();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    super.dispose();
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
                child: _adFailed
                    ? const AlunaMrecAd()
                    : MetaBannerAd(
                        placementId: adService.metaMrecPlacementId,
                        size: MetaBannerSize.mrec,
                        onLoad: _startCountdown,
                        onFailed: (errorCode, errorMessage) {
                          debugPrint('Clue MREC ad failed to load: $errorCode $errorMessage');
                          if (mounted) {
                            setState(() => _adFailed = true);
                            // Falls back to a real house ad now, not a
                            // blank box — it still deserves the same
                            // minimum watch time as a real ad.
                            _startCountdown();
                          }
                        },
                      ),
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
