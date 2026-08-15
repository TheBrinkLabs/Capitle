import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/outline_assets.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../core/utils/providers.dart';
import '../../game/screens/game_screen.dart';
import '../../game/screens/neighbours_screen.dart';
import '../../game/screens/population_screen.dart';
import '../../game/screens/practice_screen.dart';
import '../../stats/providers/stats_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/widgets/app_transitions.dart';
import '../widgets/app_logo.dart';
import '../../worldcup/screens/worldcup_screen.dart';
import '../../../core/widgets/streak_break_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _checkedStreakBreak = false;

  void _maybeShowStreakBreak() {
    if (_checkedStreakBreak) return;
    _checkedStreakBreak = true;

    final repo = ref.read(gameRepositoryProvider);
    final settings = ref.read(settingsProvider);
    final stats = ref.read(statsProvider);
    final repairableModes = repo.modesWithRepairableStreak(settings.activeModes);
    if (repairableModes.isEmpty) return;

    // The overall streak (the big hero number) is the MAX across all
    // modes — so losing one mode's streak only actually drops that
    // overall figure if no OTHER, unaffected mode is already holding an
    // equal-or-higher streak. If some other mode's streak already
    // matches or exceeds it, the overall number survives untouched even
    // without repairing anything, so there's nothing worth prompting an
    // ad for — this was the bug: it used to fire for any single mode's
    // break regardless of whether the overall streak was actually at risk.
    final repairableSet = repairableModes.toSet();
    final bestUnaffectedStreak = GameMode.values
        .where((m) => !repairableSet.contains(m))
        .map((m) => stats.streakForMode(m).current)
        .fold(0, (a, b) => a > b ? a : b);
    if (bestUnaffectedStreak >= stats.currentStreak) return;

    final broken = repairableModes
        .map((m) => BrokenStreakInfo(
              modeLabel: m.label,
              modeEmoji: m.emoji,
              // Streak shown pre-break: current cached streak (computeStreakForMode
              // hasn't dropped it yet since a skipped day doesn't auto-reset it).
              preBreakStreak: stats.streakForMode(m).current,
            ))
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showStreakBreakDialog(
        context,
        broken: broken,
        onWatchAd: () async {
          for (final mode in repairableModes) {
            await ref.read(statsProvider.notifier).repairStreak(mode);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Streak saved! ${repairableModes.map((m) => m.label).join(', ')} back on track. 🔥')),
            );
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final repo = ref.watch(gameRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;

    final dayRecord = repo.loadDayRecord(repo.todayKey);
    final activeModes = settings.activeModes;
    final allDone = dayRecord.allComplete(activeModes);

    _maybeShowStreakBreak();

    // The 5 streak modes in order (2 placeholders for now)
    final allStreakModes = [
      GameMode.guessCountry,
      GameMode.guessCapital,
      GameMode.guessFlag,
      GameMode.guessNeighbours,
      GameMode.guessPopulation,
      GameMode.guessOutline,
    ];
    final placeholders = <String>[]; // All 5 modes are now real

    return Scaffold(
      backgroundColor: bg,
      // The persistent banner ad (see PersistentBannerAd) is positioned
      // here by MainScaffold based on the active tab — this screen just
      // reserves the same visual space it always has.
      bottomNavigationBar:
          const SafeArea(top: false, bottom: true, child: SizedBox(height: 50)),
      body: BlackGlowBackground(
        isDark: isDark,
        child: Stack(
          children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: logo+stats (left) / big streak (right) ──
                  IntrinsicHeight(
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              // Split 2:1 with a matching 8px gutter, same
                              // as the 3-way WIN RATE/PLAYED/BEST row below
                              // — keeps the SCORE card here essentially the
                              // same size as BEST, sitting right above it.
                              Expanded(
                                flex: 2,
                                child: Row(children: [
                                  const AppLogoMark(size: 44, borderRadius: 13),
                                  const SizedBox(width: 12),
                                  const AppWordmark(fontSize: 26),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: _MiniStat(
                                  value: '${stats.totalScore}',
                                  icon: '⭐',
                                  label: 'SCORE',
                                  color: AppColors.blue,
                                  isDark: isDark,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: _MiniStat(
                                value: '${stats.winRatePct.toStringAsFixed(0)}%',
                                label: 'WIN RATE',
                                color: AppColors.teal,
                                isDark: isDark,
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: _MiniStat(
                                value: '${stats.totalPlayed}',
                                label: 'PLAYED',
                                isDark: isDark,
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: _MiniStat(
                                value: '${stats.bestStreak}',
                                icon: '🔥',
                                label: 'BEST',
                                color: AppColors.yellow,
                                isDark: isDark,
                              )),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 104, child: _BigStreakCard(streak: stats.currentStreak, isDark: isDark)),
                    ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Row 3: All streak cards ───────────────────────
                  Text('YOUR STREAKS', style: TextStyle(
                      fontSize: 10, letterSpacing: 3,
                      fontWeight: FontWeight.w600, color: textMuted)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      ...allStreakModes.map((mode) {
                        final active = settings.activeModes.contains(mode);
                        return Expanded(child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _StreakCard(
                            emoji: mode.emoji,
                            label: _shortLabel(mode),
                            streak: stats.streakForMode(mode).current,
                            completed: dayRecord.completedMode(mode),
                            won: dayRecord.wonMode(mode),
                            active: active,
                            isDark: isDark,
                            onTap: active && !dayRecord.completedMode(mode)
                                ? () => _openGame(context, mode)
                                : null,
                          ),
                        ));
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── All done / come back banner ──────────────────
                  if (allDone)
                    MatteCard(
                      isDark: isDark,
                      sheen: MatteSheen.teal,
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Text('✦', style: TextStyle(color: AppColors.teal, fontSize: 16)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text(
                          'All done for today! Come back tomorrow.',
                          style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500),
                        )),
                      ]),
                    )
                  else
                    Center(child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 5, height: 5,
                            decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('Puzzles reset at midnight',
                            style: TextStyle(fontSize: 11, color: textMuted)),
                      ],
                    )),

                  const SizedBox(height: 24),

                  // ── Row 4+: Today's puzzles ───────────────────────
                  Text("TODAY'S PUZZLES", style: TextStyle(
                      fontSize: 10, letterSpacing: 3,
                      fontWeight: FontWeight.w600, color: textMuted)),
                  const SizedBox(height: 12),

                  ...activeModes.map((mode) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PuzzleCard(
                      mode: mode,
                      repo: repo,
                      completed: dayRecord.completedMode(mode),
                      won: dayRecord.wonMode(mode),
                      isDark: isDark,
                      showContinent: settings.showContinentHint,
                      onTap: () => _openGame(context, mode),
                    ),
                  )),

                  const SizedBox(height: 18),

                  // ── Other modes (Practice) ──────────────────────────
                  Text('OTHER MODES', style: TextStyle(
                      fontSize: 10, letterSpacing: 3,
                      fontWeight: FontWeight.w600, color: textMuted)),
                  const SizedBox(height: 12),

                  // ── Practice ──────────────────────────────────────
                  MatteCard(
                    isDark: isDark,
                    sheen: MatteSheen.blue,
                    borderRadius: 18,
                    padding: const EdgeInsets.all(16),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PracticeMenuScreen())),
                    child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0099FF), Color(0xFF7B61FF)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Center(child: Text('🎯', style: TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Practice Mode', style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                              color: textColor, letterSpacing: -0.3)),
                            Text('Unlimited rounds · no stats · just practice',
                                style: TextStyle(fontSize: 11, color: textMuted)),
                          ],
                        )),
                        Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 14),
                    ]),
                  ),

                  const SizedBox(height: 18),

                  // ── Special editions (World Cup) ────────────────────
                  Text('SPECIAL EDITIONS', style: TextStyle(
                      fontSize: 10, letterSpacing: 3,
                      fontWeight: FontWeight.w600, color: textMuted)),
                  const SizedBox(height: 12),
                  MatteCard(
                    isDark: isDark,
                    sheen: MatteSheen.gold,
                    borderRadius: 18,
                    padding: const EdgeInsets.all(16),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WorldCupMenuScreen())),
                    child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Center(child: Text('⚽', style: TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Football World Cup 2026', style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                              color: textColor, letterSpacing: -0.3)),
                            Text('48 nations · by round · share your score',
                                style: TextStyle(fontSize: 11, color: textMuted)),
                          ],
                        )),
                        Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 14),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _shortLabel(GameMode mode) => switch (mode) {
        GameMode.guessCountry => 'Country',
        GameMode.guessCapital => 'Capital',
        GameMode.guessFlag => 'Flag',
        GameMode.guessNeighbours => 'Neighbours',
        GameMode.guessPopulation => 'Population',
        GameMode.guessOutline => 'Outline',
      };

  void _openGame(BuildContext context, GameMode mode) {
    Widget screen = switch (mode) {
      GameMode.guessNeighbours => const NeighboursScreen(),
      GameMode.guessPopulation => const PopulationScreen(),
      _ => GameScreen(mode: mode),
    };
    Navigator.of(context).pushCinematic(screen);
  }
}

// ── Streak Card ────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final String emoji;
  final String label;
  final int streak;
  final bool completed;
  final bool won;
  final bool active;
  final bool isDark;
  final VoidCallback? onTap;

  const _StreakCard({
    required this.emoji,
    required this.label,
    required this.streak,
    required this.completed,
    required this.won,
    required this.active,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final sheen = !active
        ? MatteSheen.none
        : completed
            ? (won ? MatteSheen.teal : MatteSheen.red)
            : MatteSheen.none;

    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.32,
      duration: const Duration(milliseconds: 200),
      child: MatteCard(
        isDark: isDark,
        sheen: sheen,
        borderRadius: 16,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: SizedBox(
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              TabularNumber('$streak',
                  style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 19, fontWeight: FontWeight.w800,
                    color: active && streak > 0 ? AppColors.yellow : textMuted,
                    letterSpacing: -0.5,
                  )),
              if (active && completed)
                Icon(
                  won ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: won ? AppColors.teal : AppColors.red,
                  size: 14,
                )
              else if (active)
                Icon(Icons.play_arrow_rounded, color: AppColors.teal, size: 14)
              else
                Icon(Icons.lock_outline_rounded, color: textMuted, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Placeholder Streak Card ────────────────────────────────────────────────

class _StreakCardPlaceholder extends StatelessWidget {
  final String emoji;
  final bool isDark;

  const _StreakCardPlaceholder({required this.emoji, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.3);
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return AnimatedOpacity(
      opacity: 0.25,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: surface.withOpacity(0.3),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Text('—', style: TextStyle(
              fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w800,
              color: textMuted,
            )),
            Icon(Icons.lock_outline_rounded, color: textMuted, size: 12),
          ],
        ),
      ),
    );
  }
}

// ── Big Streak Card (prominent header callout) ──────────────────────────────

class _BigStreakCard extends StatelessWidget {
  final int streak;
  final bool isDark;
  const _BigStreakCard({required this.streak, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return MatteCard(
      isDark: isDark,
      sheen: streak > 0 ? MatteSheen.gold : MatteSheen.none,
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔥', style: TextStyle(fontSize: 24, color: streak > 0 ? null : textMuted.withOpacity(0.35))),
          const SizedBox(height: 2),
          TabularNumber('$streak', style: TextStyle(
            fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w800,
            color: streak > 0 ? AppColors.yellow : textMuted,
            letterSpacing: -1, height: 1.1,
          )),
          const SizedBox(height: 2),
          Text('STREAK', style: TextStyle(
            fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: textMuted,
          )),
        ],
      ),
    );
  }
}

// ── Mini Stat (compact row-2 pill) ──────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final String? icon;
  final Color? color;
  final bool isDark;

  const _MiniStat({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return MatteCard(
      isDark: isDark,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Text(icon!, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                ],
                TabularNumber(value, style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w800,
                    color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
                    letterSpacing: -0.3)),
              ],
            ),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(fontSize: 7.5, letterSpacing: 1.0,
                fontWeight: FontWeight.w600, color: textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Puzzle Card ────────────────────────────────────────────────────────────

class _PuzzleCard extends StatelessWidget {
  final GameMode mode;
  final GameRepository repo;
  final bool completed;
  final bool won;
  final bool isDark;
  final bool showContinent;
  final VoidCallback onTap;

  const _PuzzleCard({
    required this.mode, required this.repo, required this.completed,
    required this.won, required this.isDark, required this.showContinent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final puzzle = repo.getPuzzle(mode);
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final borderColor = completed
        ? (won ? AppColors.teal.withOpacity(0.4) : AppColors.red.withOpacity(0.3))
        : borderTeal;
    final bgColor = completed
        ? (won ? AppColors.teal.withOpacity(0.05) : AppColors.red.withOpacity(0.04))
        : surface;

    final isFlag = mode == GameMode.guessFlag;
    final isOutline = mode == GameMode.guessOutline;
    final sheen = completed
        ? (won ? MatteSheen.teal : MatteSheen.red)
        : MatteSheen.none;

    return MatteCard(
      isDark: isDark,
      sheen: sheen,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      onTap: completed ? null : onTap,
      child: Row(children: [
          MorphHero(
            tag: 'puzzle-icon-${mode.name}',
            child: Container(
              width: 46, height: 46,
              padding: isOutline ? const EdgeInsets.all(7) : EdgeInsets.zero,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A1A), Color(0xFF0E0E0E)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 2)),
                  BoxShadow(color: Colors.white.withOpacity(0.04), blurRadius: 0, offset: const Offset(0, 1)),
                ],
              ),
              child: Center(
                child: isOutline
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
                        child: Image.asset(
                          kOutlineAssetPath[puzzle.entry.country]!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Text(
                        isFlag ? puzzle.entry.flagEmoji : mode.emoji,
                        style: TextStyle(fontSize: isFlag ? 26 : 22),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.label.toUpperCase(), style: const TextStyle(
                  fontSize: 9, letterSpacing: 2,
                  fontWeight: FontWeight.w600, color: AppColors.teal)),
              const SizedBox(height: 2),
              Text(
                // Never reveal the answer in text — flag/outline show a
                // neutral prompt since their icon already is the puzzle.
                isOutline
                    ? 'Guess the shape'
                    : puzzle.heroText,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                    letterSpacing: -0.5),
              ),
              if (showContinent && !isFlag && !isOutline) ...[
                const SizedBox(height: 1),
                Text(puzzle.entry.continent,
                    style: TextStyle(fontSize: 11, color: textMuted)),
              ],
            ],
          )),
          if (completed)
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: won ? AppColors.teal.withOpacity(0.15) : AppColors.red.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(
                  won ? Icons.check_rounded : Icons.close_rounded,
                  color: won ? AppColors.teal : AppColors.red, size: 18)),
            )
          else
            Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 14),
      ]),
    );
  }
}
