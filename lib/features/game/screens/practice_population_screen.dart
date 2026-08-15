import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/capital_entry.dart';
import '../../home/widgets/banner_ad_widget.dart' show BannerPosition;
import '../../../core/utils/banner_position_route.dart';
import '../providers/practice_provider.dart';

class PracticePopulationScreen extends ConsumerStatefulWidget {
  const PracticePopulationScreen({super.key});

  @override
  ConsumerState<PracticePopulationScreen> createState() => _PracticePopulationScreenState();
}

class _PracticePopulationScreenState extends ConsumerState<PracticePopulationScreen>
    with BannerPositionRoute<PracticePopulationScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.bottom;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(practicePopulationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final puzzle = gameState.puzzle;
    final popPuzzle = puzzle.populationPuzzle!;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final surface2 = isDark ? AppColors.surface2 : AppColors.surface2Light;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    void choose(CapitalEntry chosen) {
      if (gameState.isOver) return;
      HapticFeedback.mediumImpact();
      ref.read(practicePopulationProvider.notifier).submitGuess(chosen.capital);
    }

    void next() {
      ref.read(practicePopulationProvider.notifier).nextPuzzle();
    }

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar:
          const SafeArea(top: false, bottom: true, child: SizedBox(height: 50)),
      body: SafeArea(
        child: Column(
          children: [
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
                    color: AppColors.blue.withOpacity(0.1),
                    border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('🎯 Practice · Population',
                      style: TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                const SizedBox(width: 36),
              ]),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  const Text('POPULATION', style: TextStyle(
                    fontSize: 10, letterSpacing: 3, color: AppColors.blue, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Which capital city has the\nlarger population?',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700,
                          color: textColor, letterSpacing: -0.5, height: 1.3),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  Expanded(child: _PopChoiceCard(
                    entry: popPuzzle.entryA, isDark: isDark, isOver: gameState.isOver,
                    isCorrect: gameState.isOver ? popPuzzle.entryA.capital == popPuzzle.correctAnswer : null,
                    wasChosen: gameState.guesses.isNotEmpty && gameState.guesses.last.input == popPuzzle.entryA.capital,
                    onTap: gameState.isOver ? null : () => choose(popPuzzle.entryA),
                  )),
                  const SizedBox(height: 12),
                  Text('VS', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w800,
                      color: textMuted, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Expanded(child: _PopChoiceCard(
                    entry: popPuzzle.entryB, isDark: isDark, isOver: gameState.isOver,
                    isCorrect: gameState.isOver ? popPuzzle.entryB.capital == popPuzzle.correctAnswer : null,
                    wasChosen: gameState.guesses.isNotEmpty && gameState.guesses.last.input == popPuzzle.entryB.capital,
                    onTap: gameState.isOver ? null : () => choose(popPuzzle.entryB),
                  )),
                  const SizedBox(height: 16),
                  if (gameState.isOver)
                    GestureDetector(
                      onTap: next,
                      child: Container(
                        width: double.infinity, height: 50,
                        decoration: BoxDecoration(gradient: AppColors.gradientTealBlue, borderRadius: BorderRadius.circular(14)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Next Puzzle', style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 17),
                        ]),
                      ),
                    )
                  else
                    const SizedBox(height: 50),
                  const SizedBox(height: 12),
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
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(entry.flagEmoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              Text(entry.capital, style: TextStyle(fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.w800,
                  color: textColor, letterSpacing: -0.8)),
              const SizedBox(height: 4),
              Text(entry.country, style: TextStyle(fontSize: 13, color: textMuted)),
              if (isOver) ...[
                const SizedBox(height: 8),
                Text('${entry.populationLabel} people',
                    style: TextStyle(fontSize: 12, color: isCorrect == true ? AppColors.teal : textMuted, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
          if (isOver && isCorrect != null)
            Positioned(top: 12, right: 12,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: isCorrect! ? AppColors.teal : AppColors.red, shape: BoxShape.circle),
                child: Center(child: Icon(isCorrect! ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 16)),
              ),
            ),
        ]),
      ),
    );
  }
}
