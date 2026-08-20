import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';
import 'league_reveal_screen.dart';
import '../../data/models/game_models.dart';
import '../../features/home/widgets/banner_ad_widget.dart' show BannerPosition;
import '../utils/banner_position_route.dart';

/// Shown right after finishing the LAST active daily puzzle — a
/// screenshot-style recap led by the overall streak (the headline number),
/// with the per-mode breakdown as supporting detail below. On a milestone
/// day, callers should show [showStreakCelebration] instead of this (see
/// streak_celebration.dart) rather than both back to back. Tapping "Next"
/// continues on to LeagueRevealScreen — the animated before/after league
/// standing — rather than ending the flow here.
class DailyCompleteScreen extends ConsumerStatefulWidget {
  final List<GameMode> activeModes;
  final PlayerStats stats;
  final int todayScore;
  const DailyCompleteScreen({
    super.key,
    required this.activeModes,
    required this.stats,
    required this.todayScore,
  });

  @override
  ConsumerState<DailyCompleteScreen> createState() => _DailyCompleteScreenState();
}

class _DailyCompleteScreenState extends ConsumerState<DailyCompleteScreen>
    with TickerProviderStateMixin, BannerPositionRoute<DailyCompleteScreen> {
  // The banner ad sits on top of everything else via a screen-wide
  // overlay (see PersistentBannerAd) — this screen's own bottom CTA
  // ("Next") was ending up partially covered by it, since nothing here
  // reserved space the way ResultScreen's bottomNavigationBar spacer
  // does. Simplest fix: no banner on this celebratory recap screen at
  // all, same as League/Settings never show one either.
  @override
  BannerPosition get bannerPosition => BannerPosition.hidden;

  late final AnimationController _glowController;
  late final AnimationController _popController;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // One-shot pop: 0.5x -> 1.5x (overshoot) -> 1.0x (settle)
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.5).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
    ]).animate(_popController);
    _popController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overallStreak = widget.stats.currentStreak;

    return Scaffold(
      body: BlackGlowBackground(
        isDark: isDark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: const Text('✅', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 10),
                Text(
                  "Today's puzzles complete!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 19, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 26),

                // ── Hero: overall streak — pop entrance + pulsing glow ──
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    final glow = 0.5 + (_glowController.value * 0.5); // 0.5 -> 1.0 -> 0.5
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220, height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              AppColors.yellow.withOpacity(0.28 * glow),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                        child!,
                      ],
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _popScale,
                    builder: (context, child) => Transform.scale(scale: _popScale.value, child: child),
                    child: MatteCard(
                    isDark: isDark,
                    sheen: overallStreak > 0 ? MatteSheen.gold : MatteSheen.none,
                    borderRadius: 28,
                    padding: const EdgeInsets.fromLTRB(36, 22, 36, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 4),
                        TabularNumber(
                          '$overallStreak',
                          style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 64, fontWeight: FontWeight.w800,
                            color: AppColors.yellow, letterSpacing: -3, height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('DAY STREAK', style: TextStyle(
                          fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        )),
                      ],
                    ),
                  ),
                  ),
                ),

                const SizedBox(height: 16),
                MatteCard(
                  isDark: isDark,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      TabularNumber(
                        '${widget.todayScore}',
                        style: const TextStyle(
                          fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w800,
                          color: AppColors.blue, letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("TODAY'S SCORE", style: TextStyle(
                        fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      )),
                    ],
                  ),
                ),

                const SizedBox(height: 26),
                Text(
                  'Streaks by mode',
                  style: TextStyle(
                    fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 10),

                MatteCard(
                  isDark: isDark,
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (int i = 0; i < widget.activeModes.length; i++) ...[
                        if (i > 0) Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                        _StreakLine(
                          mode: widget.activeModes[i],
                          streak: widget.stats.streakForMode(widget.activeModes[i]),
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LeagueRevealScreen(todayScore: widget.todayScore),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientTealBlue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.teal.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Next',
                            style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.black,
                            )),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakLine extends StatelessWidget {
  final GameMode mode;
  final ModeStreak streak;
  final bool isDark;
  const _StreakLine({required this.mode, required this.streak, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return Row(
      children: [
        Text(mode.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(mode.label,
              style: TextStyle(
                fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600,
                color: textColor,
              )),
        ),
        TabularNumber('${streak.current}',
            style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.w800,
              color: AppColors.yellow, letterSpacing: -0.5,
            )),
        const SizedBox(width: 4),
        Text('🔥', style: TextStyle(fontSize: 12, color: streak.current > 0 ? null : textMuted.withOpacity(0.3))),
      ],
    );
  }
}
