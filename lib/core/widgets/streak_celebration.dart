import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';

/// Three tiers of milestone: early habit-builders, then every 100, with
/// a bigger celebration every 1000.
enum StreakMilestoneTier { small, hundred, thousand }

const List<int> _smallMilestones = [10, 20, 50];

StreakMilestoneTier? streakMilestoneTier(int streak) {
  if (streak >= 1000 && streak % 1000 == 0) return StreakMilestoneTier.thousand;
  if (streak >= 100 && streak % 100 == 0) return StreakMilestoneTier.hundred;
  if (_smallMilestones.contains(streak)) return StreakMilestoneTier.small;
  return null;
}

bool isStreakMilestone(int streak) => streakMilestoneTier(streak) != null;

/// Full-screen celebratory overlay shown when a streak hits a milestone.
/// Call `showStreakCelebration` right after a win is recorded — it checks
/// the milestone itself, so callers can always call it and it'll no-op if
/// the new streak isn't a milestone number.
Future<void> showStreakCelebration(
  BuildContext context, {
  required int streak,
  required String modeLabel,
  required String modeEmoji,
}) async {
  if (!isStreakMilestone(streak)) return;
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Streak celebration',
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) => _StreakCelebrationDialog(
      streak: streak,
      modeLabel: modeLabel,
      modeEmoji: modeEmoji,
    ),
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + (curved.value * 0.3), child: child),
      );
    },
  );
}

class _StreakCelebrationDialog extends StatefulWidget {
  final int streak;
  final String modeLabel;
  final String modeEmoji;
  const _StreakCelebrationDialog({
    required this.streak,
    required this.modeLabel,
    required this.modeEmoji,
  });

  @override
  State<_StreakCelebrationDialog> createState() => _StreakCelebrationDialogState();
}

class _StreakCelebrationDialogState extends State<_StreakCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  StreakMilestoneTier get _tier => streakMilestoneTier(widget.streak) ?? StreakMilestoneTier.small;

  String get _title {
    final s = widget.streak;
    if (s == 365) return 'A whole year!';
    return switch (s) {
      10 => 'Ten in a row!',
      20 => 'Twenty strong!',
      50 => 'Halfway to a hundred!',
      100 => 'Triple digits!',
      _ when _tier == StreakMilestoneTier.thousand =>
        s == 1000 ? 'ONE THOUSAND DAYS!!' : '${s ~/ 1000}K DAYS — LEGENDARY!',
      _ when _tier == StreakMilestoneTier.hundred => '$s days strong!',
      _ => 'Milestone reached!',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Confetti bursts
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) => CustomPaint(
              size: Size(320, 320) * (_tier == StreakMilestoneTier.thousand ? 1.25 : 1.0),
              painter: _ConfettiPainter(
                progress: _confettiController.value,
                pieceCount: _tier == StreakMilestoneTier.thousand ? 40 : 24,
              ),
            ),
          ),
          MatteCard(
            isDark: isDark,
            sheen: MatteSheen.gold,
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Text(
                    _tier == StreakMilestoneTier.thousand ? '🔥👑🔥' : '🔥',
                    style: TextStyle(fontSize: _tier == StreakMilestoneTier.thousand ? 56 : 64),
                  ),
                ),
                const SizedBox(height: 8),
                TabularNumber(
                  '${widget.streak}',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: _tier == StreakMilestoneTier.thousand ? 68 : 56,
                    fontWeight: FontWeight.w800,
                    color: AppColors.yellow,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                Text(
                  'DAY STREAK',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.modeEmoji} ${widget.modeLabel} · ${widget.streak} days and counting',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientTealBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Keep it going',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int pieceCount;
  _ConfettiPainter({required this.progress, this.pieceCount = 24});

  List<_ConfettiPiece> get _pieces => List.generate(pieceCount, (i) {
    final angle = (i / pieceCount) * 2 * 3.14159;
    return _ConfettiPiece(
      angle: angle,
      speed: 90 + (i % 5) * 22.0,
      color: [AppColors.teal, AppColors.yellow, AppColors.blue, AppColors.red][i % 4],
      size: 5.0 + (i % 3) * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (final p in _pieces) {
      final dist = p.speed * progress;
      final direction = Offset.fromDirection(p.angle, dist);
      final dx = center.dx + direction.dx;
      final dy = center.dy + direction.dy - (progress * progress * 60);
      final paint = Paint()..color = p.color.withOpacity(fade);
      canvas.drawCircle(Offset(dx, dy), p.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiPiece {
  final double angle;
  final double speed;
  final Color color;
  final double size;
  _ConfettiPiece({required this.angle, required this.speed, required this.color, required this.size});
}
