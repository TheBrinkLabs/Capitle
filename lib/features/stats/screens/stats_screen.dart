import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../providers/stats_provider.dart';
import '../../home/widgets/banner_ad_widget.dart';
import '../../../core/widgets/app_effects.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Statistics', style: TextStyle(
                fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: -1,
              )),

              const SizedBox(height: 20),

              // ── Per-mode streak cards ─────────────────────────────
              Text('STREAKS', style: TextStyle(
                  fontSize: 10, letterSpacing: 3,
                  fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 10),

              Row(children: [
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _ModeStreakCard(mode: GameMode.guessCountry, streak: stats.countryStreak, isDark: isDark))),
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _ModeStreakCard(mode: GameMode.guessCapital, streak: stats.capitalStreak, isDark: isDark))),
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _ModeStreakCard(mode: GameMode.guessFlag, streak: stats.flagStreak, isDark: isDark))),
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _ModeStreakCard(mode: GameMode.guessNeighbours, streak: stats.neighboursStreak, isDark: isDark))),
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _ModeStreakCard(mode: GameMode.guessPopulation, streak: stats.populationStreak, isDark: isDark))),
                Expanded(child: _ModeStreakCard(mode: GameMode.guessOutline, streak: stats.outlineStreak, isDark: isDark)),
              ]),

              const SizedBox(height: 16),

              // ── Overall best streak hero ──────────────────────────
              MatteCard(
                isDark: isDark,
                sheen: MatteSheen.teal,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(children: [
                      TabularNumber('${stats.bestStreak}', style: const TextStyle(
                        fontFamily: 'Outfit', fontSize: 48,
                        fontWeight: FontWeight.w800, color: AppColors.yellow,
                        letterSpacing: -2, height: 1,
                      )),
                      Text('BEST STREAK 🔥', style: TextStyle(
                        fontSize: 9, letterSpacing: 2.5,
                        color: textMuted, fontWeight: FontWeight.w500,
                      )),
                    ]),
                    Container(width: 1, height: 50,
                        color: Colors.white.withOpacity(0.08)),
                    Column(children: [
                      TabularNumber('${stats.totalPlayed}', style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 48,
                        fontWeight: FontWeight.w800, color: textColor,
                        letterSpacing: -2, height: 1,
                      )),
                      Text('GAMES PLAYED', style: TextStyle(
                        fontSize: 9, letterSpacing: 2.5,
                        color: textMuted, fontWeight: FontWeight.w500,
                      )),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 4-stat grid ───────────────────────────────────────
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _StatBox(value: '${stats.winRatePct.toStringAsFixed(0)}%',
                      label: 'Win Rate', color: AppColors.teal, surface: surface),
                  _StatBox(
                      value: stats.avgGuesses > 0
                          ? stats.avgGuesses.toStringAsFixed(1) : '—',
                      label: 'Avg Guesses', surface: surface),
                  _StatBox(value: '${stats.totalWon}',
                      label: 'Games Won', color: AppColors.teal, surface: surface),
                  _StatBox(
                      value: stats.totalPlayed > 0
                          ? '${stats.totalPlayed - stats.totalWon}' : '—',
                      label: 'Games Lost', surface: surface),
                ],
              ),

              const SizedBox(height: 24),

              // ── Guess distributions ───────────────────────────────
              _DistributionSection(
                title: '🌍 Country Mode',
                distribution: stats.guessDistributionCountry,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _DistributionSection(
                title: '🗺️ Capital Mode',
                distribution: stats.guessDistributionCapital,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _DistributionSection(
                title: '🚩 Flag Mode',
                distribution: stats.guessDistributionFlag,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _DistributionSection(
                title: '🤝 Neighbours Mode',
                distribution: stats.guessDistributionNeighbours,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _DistributionSection(
                title: '📊 Population Mode',
                distribution: stats.guessDistributionPopulation,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _DistributionSection(
                title: '🧩 Outline Mode',
                distribution: stats.guessDistributionOutline,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode Streak Card ───────────────────────────────────────────────────────

class _ModeStreakCard extends StatelessWidget {
  final GameMode mode;
  final ModeStreak streak;
  final bool isDark;

  const _ModeStreakCard({
    required this.mode, required this.streak, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return MatteCard(
      isDark: isDark,
      sheen: streak.current > 0 ? MatteSheen.teal : MatteSheen.none,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mode.emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 3),
          TabularNumber('${streak.current}', style: TextStyle(
            fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w800,
            color: streak.current > 0 ? AppColors.yellow : textMuted,
            letterSpacing: -0.5,
          )),
          const SizedBox(height: 1),
          Text('🔥${streak.best}', style: TextStyle(
            fontSize: 9, color: textMuted,
          ), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Stat Box ───────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final Color surface;

  const _StatBox({
    required this.value, required this.label,
    this.color, required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MatteCard(
      isDark: isDark,
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TabularNumber(value, style: TextStyle(
            fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w800,
            color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
            letterSpacing: -0.5, height: 1,
          )),
          const SizedBox(height: 5),
          Text(label.toUpperCase(), style: TextStyle(
            fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Distribution Section ───────────────────────────────────────────────────

class _DistributionSection extends StatelessWidget {
  final String title;
  final Map<int, int> distribution;
  final bool isDark;

  const _DistributionSection({
    required this.title, required this.distribution, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final maxVal = distribution.values.isEmpty
        ? 1 : distribution.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: textColor, letterSpacing: 0.3,
        )),
        const SizedBox(height: 4),
        Text('GUESS DISTRIBUTION', style: TextStyle(
          fontSize: 9, letterSpacing: 2.5,
          color: textMuted, fontWeight: FontWeight.w500,
        )),
        const SizedBox(height: 12),
        if (distribution.isEmpty)
          Text('No games played yet', style: TextStyle(fontSize: 12, color: textMuted))
        else
          ...List.generate(GameState.maxGuesses, (i) {
            final guessNum = i + 1;
            final count = distribution[guessNum] ?? 0;
            final frac = maxVal == 0 ? 0.0 : count / maxVal;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                SizedBox(
                  width: 14,
                  child: Text('$guessNum', style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 13,
                    fontWeight: FontWeight.w700, color: textMuted,
                  ), textAlign: TextAlign.center),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(children: [
                    Container(height: 26,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface2 : AppColors.surface2Light,
                          borderRadius: BorderRadius.circular(6),
                        )),
                    FractionallySizedBox(
                      widthFactor: frac.clamp(0.05, 1.0),
                      child: Container(
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientTealBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(count > 0 ? '$count' : '',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.black,
                            )),
                      ),
                    ),
                  ]),
                ),
              ]),
            );
          }),
      ],
    );
  }
}
