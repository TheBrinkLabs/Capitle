import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/widgets/app_transitions.dart';
import '../../../core/widgets/streak_celebration.dart';
import '../../../core/widgets/location_reveal_map.dart';
import '../../../core/widgets/daily_complete_screen.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/capital_entry.dart';
import '../../../core/utils/providers.dart';
import '../providers/game_provider.dart';
import '../../stats/providers/stats_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../home/widgets/banner_ad_widget.dart';
import 'game_screen.dart';
import 'neighbours_screen.dart';
import 'population_screen.dart';

/// The globe reveal's label — usually just the country name, but for
/// modes asking about something other than the country itself
/// (Neighbours, Capital), showing the country alone would be redundant
/// or just wrong — it wouldn't confirm the actual thing being guessed.
/// Shows the specific answer detail instead in those cases.
String _globeLabelFor(GameMode mode, CapitalEntry entry) {
  switch (mode) {
    case GameMode.guessNeighbours:
      final n = entry.neighbours;
      return '${entry.country} · $n border${n == 1 ? '' : 's'}';
    case GameMode.guessCapital:
      return entry.capital;
    default:
      return entry.country;
  }
}

class ResultScreen extends ConsumerStatefulWidget {
  final GameMode mode;
  const ResultScreen({super.key, required this.mode});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _celebrationChecked = false;

  @override
  Widget build(BuildContext context) {
    final provider = gameProviderForMode(widget.mode);
    final gameState = ref.watch(provider);
    final stats = ref.watch(statsProvider);
    final repo = ref.watch(gameRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final won = gameState.status == GameStatus.won;
    final puzzle = gameState.puzzle;
    final guesses = gameState.guesses;

    // ── Find the next uncompleted active daily mode, if any ────────────
    final dayRecord = repo.loadDayRecord(repo.todayKey);
    GameMode? nextMode;
    for (final m in settings.activeModes) {
      if (m == widget.mode) continue;
      if (!dayRecord.completedMode(m)) {
        nextMode = m;
        break;
      }
    }

    // ── Post-game popup — checked once per screen visit ─────────────────
    // On a WIN: milestone celebration takes priority; otherwise, if this
    // was the LAST active puzzle for today, show the daily recap. The
    // location reveal is NOT automatic here — a "(?)" button in the win
    // panel below lets the user pull it up on demand instead.
    // On a LOSS: show the location reveal automatically instead (helps
    // the player see where the actual answer was, since they didn't
    // guess it) — nothing else applies on a loss.
    if (!_celebrationChecked) {
      _celebrationChecked = true;

      if (won) {
        final streak = stats.streakForMode(widget.mode).current;
        final isMilestone = isStreakMilestone(streak);
        final wasLastGameToday = nextMode == null;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isMilestone) {
            showStreakCelebration(
              context,
              streak: streak,
              modeLabel: widget.mode.label,
              modeEmoji: widget.mode.emoji,
            );
          } else if (wasLastGameToday) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DailyCompleteScreen(
                  activeModes: settings.activeModes,
                  stats: stats,
                ),
                fullscreenDialog: true,
              ),
            );
          }
        });
      } else if (settings.locationRevealEnabled && widget.mode != GameMode.guessPopulation) {
        final entry = puzzle.entry;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showLocationReveal(
            context,
            targetLat: entry.lat,
            targetLng: entry.lng,
            countryName: _globeLabelFor(widget.mode, entry),
            countryEmoji: entry.flagEmoji,
          );
        });
      }
    }

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    void openNextPuzzle() {
      if (nextMode == null) return;
      final Widget screen = switch (nextMode!) {
        GameMode.guessNeighbours => const NeighboursScreen(),
        GameMode.guessPopulation => const PopulationScreen(),
        _ => GameScreen(mode: nextMode!),
      };
      Navigator.of(context).pushCinematic(screen);
    }

    void shareResult() {
      final allDoneToday = nextMode == null;
      String text;
      if (allDoneToday) {
        final activeModes = settings.activeModes;
        final total = activeModes.length;
        final keptStreak = activeModes.where((m) => dayRecord.wonMode(m)).length;
        final modeGrid = activeModes.map((m) => dayRecord.wonMode(m) ? '🟩' : '🟥').join('');
        text = 'I played all $total daily Capitle games today and kept my '
            'streak on $keptStreak of them! 🌍🔥\n$modeGrid\n\n'
            'https://play.google.com/store/apps/details?id=com.brinklabs.capitle';
      } else {
        text = repo.buildShareText(puzzle: puzzle, guesses: guesses, won: won);
      }
      Share.share(text);
    }

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const BannerAdWidget(),
      body: BlackGlowBackground(
        isDark: isDark,
        child: Stack(
          children: [
            if (won)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.teal.withOpacity(0.15),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    // Top bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MatteCard(
                          isDark: isDark,
                          sheen: won ? MatteSheen.teal : MatteSheen.red,
                          borderRadius: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(won ? '✦' : '✕',
                                  style: TextStyle(
                                    color: won ? AppColors.teal : AppColors.red,
                                    fontSize: 12,
                                  )),
                              const SizedBox(width: 6),
                              Text(
                                won ? 'Solved' : 'Better luck tomorrow',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: won ? AppColors.teal : AppColors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (won && settings.locationRevealEnabled && widget.mode != GameMode.guessPopulation) ...[
                              GestureDetector(
                                onTap: () => showLocationReveal(
                                  context,
                                  targetLat: puzzle.entry.lat,
                                  targetLng: puzzle.entry.lng,
                                  countryName: _globeLabelFor(widget.mode, puzzle.entry),
                                  countryEmoji: puzzle.entry.flagEmoji,
                                ),
                                child: MatteCard(
                                  isDark: isDark,
                                  borderRadius: 10,
                                  padding: EdgeInsets.zero,
                                  child: const SizedBox(
                                    width: 38, height: 38,
                                    child: Center(
                                      child: Text('?', style: TextStyle(
                                          fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.w800,
                                          color: AppColors.teal)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            GestureDetector(
                              onTap: shareResult,
                              child: MatteCard(
                                isDark: isDark,
                                borderRadius: 10,
                                padding: EdgeInsets.zero,
                                child: const SizedBox(
                                  width: 38, height: 38,
                                  child: Icon(Icons.ios_share_rounded, size: 18, color: AppColors.teal),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Hero
                    Text(won ? '🌏' : '🗺️', style: const TextStyle(fontSize: 60)),
                    const SizedBox(height: 14),
                    Text(
                      won ? 'Nailed it!' : 'So close!',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      won ? "You got today's ${widget.mode.label}" : 'The answer was...',
                      style: TextStyle(fontSize: 14, color: textMuted),
                    ),

                    const SizedBox(height: 24),

                    // Answer card
                    MatteCard(
                      isDark: isDark,
                      borderRadius: 20,
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Text(puzzle.entry.flagEmoji, style: const TextStyle(fontSize: 38)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ANSWER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.teal,
                                      letterSpacing: 2.5,
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 3),
                                Text(
                                  puzzle.correctAnswer,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  switch (widget.mode) {
                                    GameMode.guessCountry => 'Capital: ${puzzle.entry.capital}',
                                    GameMode.guessCapital => 'Country: ${puzzle.entry.country}',
                                    GameMode.guessFlag => '${puzzle.entry.flagEmoji} ${puzzle.entry.country}',
                                    GameMode.guessNeighbours => 'Land borders: ${puzzle.entry.neighbours}',
                                    GameMode.guessPopulation =>
                                      'Larger city: ${puzzle.populationPuzzle?.correctAnswer ?? ''}',
                                    GameMode.guessOutline => 'Capital: ${puzzle.entry.capital}',
                                  },
                                  style: TextStyle(fontSize: 12, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats row — streak for THIS mode specifically
                    Row(
                      children: [
                        _ResultStat(
                          value: '${stats.streakForMode(widget.mode).current}',
                          label: '${widget.mode.label} Streak',
                          suffix: stats.streakForMode(widget.mode).current > 0 ? ' 🔥' : '',
                          color: AppColors.yellow,
                        ),
                        const SizedBox(width: 10),
                        _ResultStat(
                          value: '${stats.winRatePct.toStringAsFixed(0)}%',
                          label: 'Win Rate',
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 10),
                        _ResultStat(
                          value: '${stats.totalPlayed}',
                          label: 'Played',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Guess trail dots — real guesses only, clue reveals
                    // don't count toward the 3-guess trail (same rule as
                    // everywhere else guesses are counted in the app).
                    Builder(builder: (context) {
                      final realGuesses = guesses.where((g) => !g.isClue).toList();
                      if (realGuesses.isEmpty) return const SizedBox.shrink();
                      final emptySlots = (GameState.maxGuesses - realGuesses.length).clamp(0, GameState.maxGuesses);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(realGuesses.length, (i) => Container(
                            width: 12, height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: realGuesses[i].isCorrect ? AppColors.teal : AppColors.red,
                              shape: BoxShape.circle,
                              boxShadow: realGuesses[i].isCorrect
                                  ? [BoxShadow(color: AppColors.teal.withOpacity(0.5), blurRadius: 8)]
                                  : null,
                            ),
                          )),
                          ...List.generate(
                            emptySlots,
                            (i) => Container(
                              width: 12, height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 28),

                    // ── CTAs ──────────────────────────────────────────
                    if (nextMode != null) ...[
                      // A puzzle remains today — make it the hero CTA
                      GestureDetector(
                        onTap: openNextPuzzle,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientTealBlue,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.teal.withOpacity(0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(nextMode!.emoji, style: const TextStyle(fontSize: 17)),
                              const SizedBox(width: 8),
                              Text('Next: ${nextMode!.label}',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  )),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: shareResult,
                              child: MatteCard(
                                isDark: isDark,
                                borderRadius: 16,
                                padding: EdgeInsets.zero,
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Text('Share Result',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                              child: MatteCard(
                                isDark: isDark,
                                borderRadius: 16,
                                padding: EdgeInsets.zero,
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Text('Home',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // All done for today — share is the hero CTA
                      GestureDetector(
                        onTap: shareResult,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientTealBlue,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.teal.withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.ios_share_rounded, color: Colors.black, size: 18),
                              SizedBox(width: 8),
                              Text('Share Result',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        child: MatteCard(
                          isDark: isDark,
                          borderRadius: 16,
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Center(
                              child: Text('All done for today · Back to Home',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String value;
  final String label;
  final String suffix;
  final Color? color;

  const _ResultStat({
    required this.value,
    required this.label,
    this.suffix = '',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: MatteCard(
        isDark: isDark,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            TabularNumber(
              '$value$suffix',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
