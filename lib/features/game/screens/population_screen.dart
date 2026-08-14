import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/capital_entry.dart';
import '../providers/game_provider.dart';
import 'result_screen.dart';
import '../../home/widgets/banner_ad_widget.dart';

class PopulationScreen extends ConsumerWidget {
  const PopulationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(guessPopulationGameProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.isOver && gameState.guesses.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ResultScreen(mode: GameMode.guessPopulation)));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final puzzle = gameState.puzzle;
    final popPuzzle = puzzle.populationPuzzle!;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    void choose(CapitalEntry chosen) {
      if (gameState.isOver) return;
      HapticFeedback.mediumImpact();
      ref.read(guessPopulationGameProvider.notifier).submitGuess(chosen.capital);

      final updated = ref.read(guessPopulationGameProvider);
      if (updated?.isOver == true) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ResultScreen(mode: GameMode.guessPopulation)));
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: surface2, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16,
                        color: isDark ? AppColors.textDimDark : AppColors.textDimLight),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    border: Border.all(color: borderTeal),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('📊 Population',
                      style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                // Single pip — 1 guess
                Row(children: List.generate(1, (i) {
                  final realGuesses = gameState.guesses.where((g) => !g.isClue).toList();
                  Color pipColor = realGuesses.isNotEmpty
                      ? (realGuesses[0].isCorrect ? AppColors.teal : AppColors.red)
                      : borderTeal;
                  return Container(
                    width: 8, height: 8, margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: realGuesses.isNotEmpty ? pipColor : Colors.transparent,
                      border: Border.all(color: pipColor, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  );
                })),
              ]),
            ),

            const SizedBox(height: 20),

            // Question prompt
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: borderTeal),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  const Text('POPULATION', style: TextStyle(
                    fontSize: 10, letterSpacing: 3, color: AppColors.teal, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Which capital city has the\nlarger population?',
                      style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700,
                        color: textColor, letterSpacing: -0.5, height: 1.3,
                      ), textAlign: TextAlign.center),
                ]),
              ),
            ),

            const SizedBox(height: 20),

            // Two choice cards
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  Expanded(child: _PopChoiceCard(
                    entry: popPuzzle.entryA,
                    isDark: isDark,
                    isOver: gameState.isOver,
                    isCorrect: gameState.isOver ? popPuzzle.entryA.capital == popPuzzle.correctAnswer : null,
                    wasChosen: gameState.guesses.isNotEmpty &&
                        gameState.guesses.last.input == popPuzzle.entryA.capital,
                    onTap: gameState.isOver ? null : () => choose(popPuzzle.entryA),
                  )),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('VS', style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w800,
                      color: textMuted, letterSpacing: 2,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: _PopChoiceCard(
                    entry: popPuzzle.entryB,
                    isDark: isDark,
                    isOver: gameState.isOver,
                    isCorrect: gameState.isOver ? popPuzzle.entryB.capital == popPuzzle.correctAnswer : null,
                    wasChosen: gameState.guesses.isNotEmpty &&
                        gameState.guesses.last.input == popPuzzle.entryB.capital,
                    onTap: gameState.isOver ? null : () => choose(popPuzzle.entryB),
                  )),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopChoiceCard extends StatelessWidget {
  final CapitalEntry entry;
  final bool isDark;
  final bool isOver;
  final bool? isCorrect;
  final bool wasChosen;
  final VoidCallback? onTap;

  const _PopChoiceCard({
    required this.entry, required this.isDark, required this.isOver,
    this.isCorrect, required this.wasChosen, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final borderTeal = isDark ? AppColors.borderTealDark : AppColors.borderTealLight;

    Color borderColor = borderTeal;
    Color bgColor = surface;

    if (isOver && isCorrect != null) {
      if (isCorrect!) {
        borderColor = AppColors.teal.withOpacity(0.5);
        bgColor = AppColors.teal.withOpacity(0.05);
      } else if (wasChosen) {
        borderColor = AppColors.red.withOpacity(0.4);
        bgColor = AppColors.red.withOpacity(0.04);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isOver && isCorrect == true ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: onTap != null
              ? [BoxShadow(color: AppColors.teal.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(entry.flagEmoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              Text(entry.capital, style: TextStyle(
                fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: -0.8,
              )),
              const SizedBox(height: 4),
              Text(entry.country, style: TextStyle(fontSize: 13, color: textMuted)),
              if (isOver) ...[
                const SizedBox(height: 8),
                Text('${entry.populationLabel} people',
                    style: TextStyle(
                      fontSize: 12, color: isCorrect == true ? AppColors.teal : textMuted,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ]),
          ),
          if (isOver && isCorrect != null)
            Positioned(top: 12, right: 12,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isCorrect! ? AppColors.teal : AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(
                  isCorrect! ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white, size: 16,
                )),
              ),
            ),
        ]),
      ),
    );
  }
}
