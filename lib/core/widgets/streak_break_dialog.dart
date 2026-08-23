import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';
import '../utils/ad_service.dart';

/// Auto-shown on app load (not a tappable banner) when one or more active
/// streaks broke yesterday and are still within their one-day repair
/// window. Plays a short "crack" sequence — the intact streak, then a
/// shatter — before revealing the save-or-lose choice.
Future<void> showStreakBreakDialog(
  BuildContext context, {
  required List<_BrokenStreak> broken,
  required Future<void> Function() onWatchAd,
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Streak broken',
    barrierColor: Colors.black.withOpacity(0.82),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, anim1, anim2) => _StreakBreakDialog(broken: broken, onWatchAd: onWatchAd),
    transitionBuilder: (context, anim, secondaryAnim, child) {
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + (anim.value * 0.15), child: child),
      );
    },
  );
}

class BrokenStreakInfo {
  final String modeLabel;
  final String modeEmoji;
  final int preBreakStreak;
  const BrokenStreakInfo({required this.modeLabel, required this.modeEmoji, required this.preBreakStreak});
}
typedef _BrokenStreak = BrokenStreakInfo;

class _StreakBreakDialog extends StatefulWidget {
  final List<_BrokenStreak> broken;
  final Future<void> Function() onWatchAd;
  const _StreakBreakDialog({required this.broken, required this.onWatchAd});

  @override
  State<_StreakBreakDialog> createState() => _StreakBreakDialogState();
}

enum _Phase { intact, cracking, broken }

class _StreakBreakDialogState extends State<_StreakBreakDialog> with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.intact;
  late AnimationController _shakeController;
  bool _watching = false;
  bool _resolved = false;

  int get _highestStreak => widget.broken.map((b) => b.preBreakStreak).reduce(max);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    // Brief beat showing the streak intact, then crack.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.cracking);
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() => _phase = _Phase.broken);
      });
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // Trialling Vungle's interstitial here in place of Unity's rewarded
  // video, to see how it performs for this slot. Unlike rewarded, an
  // interstitial has no "watched to completion" signal of its own — the
  // streak saves as soon as the ad is dismissed, full stop. That's a
  // slightly weaker commitment than rewarded's guarantee, which is the
  // actual trade-off being tested here alongside fill/revenue.
  void _watchAd() {
    if (_watching || _resolved) return;
    setState(() => _watching = true);

    adService.showVungleInterstitial(
      onDismissed: () async {
        await widget.onWatchAd();
        _resolved = true;
        if (mounted) Navigator.of(context).pop();
      },
      onNotReady: () {
        if (mounted) {
          setState(() => _watching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ad isn't ready yet — try again in a moment.")),
          );
        }
      },
    );
  }

  void _letItGo() {
    _resolved = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cracked = _phase != _Phase.intact;
    final modeEmojis = widget.broken.map((b) => b.modeEmoji).join(' ');
    final plural = widget.broken.length > 1 ? 'streaks' : 'streak';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          if (_phase != _Phase.cracking) return child!;
          final t = _shakeController.value;
          final offset = sin(t * pi * 8) * (1 - t) * 6;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: MatteCard(
          isDark: isDark,
          sheen: cracked ? MatteSheen.red : MatteSheen.gold,
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fire + crack overlay
              SizedBox(
                width: 100, height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: cracked ? 0.35 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: const Text('🔥', style: TextStyle(fontSize: 64)),
                    ),
                    if (cracked)
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: CustomPaint(
                          size: const Size(100, 100),
                          painter: _CrackPainter(),
                        ),
                      ),
                    if (cracked)
                      const Text('💔', style: TextStyle(fontSize: 40)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TabularNumber(
                '$_highestStreak',
                style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 44, fontWeight: FontWeight.w800,
                  color: cracked ? AppColors.red : AppColors.yellow,
                  letterSpacing: -2, height: 1,
                  decoration: cracked ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.red,
                  decorationThickness: 2.5,
                ),
              ),
              Text(
                cracked ? 'STREAK AT RISK' : 'DAY STREAK',
                style: TextStyle(
                  fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: cracked
                    ? Column(
                        key: const ValueKey('broken'),
                        children: [
                          Text('You missed yesterday',
                              style: TextStyle(
                                fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              )),
                          const SizedBox(height: 6),
                          Text(
                            '$modeEmojis Your $plural will reset unless you save it now',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDimDark : AppColors.textDimLight),
                          ),
                        ],
                      )
                    : Text(
                        "Still going strong...",
                        key: const ValueKey('intact'),
                        style: TextStyle(fontSize: 14, color: isDark ? AppColors.textDimDark : AppColors.textDimLight),
                      ),
              ),
              const SizedBox(height: 22),
              AnimatedOpacity(
                opacity: cracked ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !cracked,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _watchAd,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.teal, AppColors.blue],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Center(
                            child: _watching
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 20),
                                      SizedBox(width: 8),
                                      Text('Watch ad to save it',
                                          style: TextStyle(
                                            fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          )),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _watching ? null : _letItGo,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text('Let it go',
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple jagged crack lines drawn across the fire icon.
class _CrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path1 = Path()
      ..moveTo(cx - 6, cy - 30)
      ..lineTo(cx - 2, cy - 10)
      ..lineTo(cx + 8, cy - 2)
      ..lineTo(cx - 4, cy + 14)
      ..lineTo(cx + 4, cy + 30);
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(cx + 14, cy - 20)
      ..lineTo(cx + 4, cy - 4)
      ..lineTo(cx + 16, cy + 8);
    canvas.drawPath(path2, paint..color = Colors.white.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
