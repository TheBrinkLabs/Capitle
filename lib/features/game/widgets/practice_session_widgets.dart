import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_models.dart';
import '../providers/practice_provider.dart';

/// Slim "N/total · X%" progress bar shown at the top of a scored practice
/// session (Country/Capital/Flag/Outline/Neighbours). Not shown in
/// Population mode, which has no session.
class PracticeProgressBar extends StatelessWidget {
  final PracticeSessionState session;
  final bool isDark;
  const PracticeProgressBar({super.key, required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: session.total == 0 ? 0 : session.askedCount / session.total,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${session.askedCount}/${session.total}', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
        if (session.askedCount > 0) ...[
          const SizedBox(width: 6),
          Text('· ${session.percent.round()}%', style: TextStyle(fontSize: 12, color: textMuted)),
        ],
      ]),
    );
  }
}

/// Final results panel shown when a scored practice session runs out of
/// countries. Shows the final score, percent, and — if this run beat the
/// saved best for this mode+region — a "New Best!" badge (the confetti
/// celebration itself is triggered separately by the caller).
class PracticeSessionCompletePanel extends StatelessWidget {
  final GameMode mode;
  final PracticeSessionState session;
  final bool isDark;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToMenu;

  const PracticeSessionCompletePanel({
    super.key,
    required this.mode,
    required this.session,
    required this.isDark,
    required this.onPlayAgain,
    required this.onBackToMenu,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final percent = session.total == 0 ? 0 : (session.correct / session.total * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(
              color: session.isNewRecord ? AppColors.yellow.withOpacity(0.5) : AppColors.blue.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(session.isNewRecord ? '🏆' : '🎯', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text('Session Complete!', style: TextStyle(
                fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 4),
            Text('${mode.emoji} ${mode.label} · ${practiceRegionLabel(session.region)}',
                style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(height: 20),
            Text('${session.correct} / ${session.total}', style: TextStyle(
                fontFamily: 'Outfit', fontSize: 44, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: -1)),
            Text('$percent% correct', style: TextStyle(fontSize: 14, color: textMuted)),
            const SizedBox(height: 14),
            if (session.isNewRecord)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withOpacity(0.12),
                  border: Border.all(color: AppColors.yellow.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🏆 New Best!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.yellow)),
              )
            else
              Text('Best: ${session.bestScore} / ${session.total}', style: TextStyle(fontSize: 13, color: textMuted)),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onPlayAgain,
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(gradient: AppColors.gradientTealBlue, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Play Again', style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onBackToMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Back to Menu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
