import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';

/// Full-screen celebratory overlay shown when the app notices the player's
/// World Champion count went up since it last checked (comparing the
/// previous locally-cached count against the count now returned from
/// players/{uid} — see PlayerProfileNotifier.noteWorldChampionCountAndCheckNewWin).
/// The title itself is decided server-side during the weekly rollover
/// (rollover.js) — this widget is purely the client-side "hey, you won"
/// moment, not the source of truth. The biggest of the app's celebration
/// dialogs (streak milestones, league promotion) since becoming World
/// Champion is the top of the whole league.
Future<void> showWorldChampionCelebration(BuildContext context) async {
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'World Champion',
    barrierColor: Colors.black.withOpacity(0.8),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, anim1, anim2) => const _WorldChampionDialog(),
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + (curved.value * 0.3), child: child),
      );
    },
  );
}

class _WorldChampionDialog extends StatefulWidget {
  const _WorldChampionDialog();

  @override
  State<_WorldChampionDialog> createState() => _WorldChampionDialogState();
}

class _WorldChampionDialogState extends State<_WorldChampionDialog>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _glowController.dispose();
    super.dispose();
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
          // Pulsing gold glow behind everything — bigger occasion than a
          // streak milestone or a tier promotion gets a bit more presence.
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glow = 0.5 + (_glowController.value * 0.5);
              return Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.yellow.withOpacity(0.32 * glow),
                    Colors.transparent,
                  ]),
                ),
              );
            },
          ),
          // Confetti bursts — the biggest of the three celebration dialogs.
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) => CustomPaint(
              size: const Size(380, 380),
              painter: _ConfettiPainter(progress: _confettiController.value, pieceCount: 56),
            ),
          ),
          MatteCard(
            isDark: isDark,
            sheen: MatteSheen.gold,
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: const Text('👑', style: TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 10),
                Text(
                  'WORLD CHAMPION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.yellow,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You're the Capitle World Champion!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Top of the whole league this week — the best of the best.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientTealBlue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Amazing!',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
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
      speed: 100 + (i % 5) * 26.0,
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
      final dy = center.dy + direction.dy - (progress * progress * 70);
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
