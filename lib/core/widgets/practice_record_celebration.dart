import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';

/// Full-screen celebratory overlay for beating your personal best on a
/// scored practice session. Unlike streak celebrations there's no
/// milestone check here — call this only when the caller already knows
/// (via PracticeSessionState.isNewRecord) that this run set a new record.
Future<void> showPracticeRecordCelebration(
  BuildContext context, {
  required int correct,
  required int total,
  required String modeLabel,
  required String modeEmoji,
  String? region,
}) async {
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'New record',
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) => _PracticeRecordDialog(
      correct: correct, total: total, modeLabel: modeLabel, modeEmoji: modeEmoji, region: region,
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

class _PracticeRecordDialog extends StatefulWidget {
  final int correct;
  final int total;
  final String modeLabel;
  final String modeEmoji;
  final String? region;
  const _PracticeRecordDialog({
    required this.correct,
    required this.total,
    required this.modeLabel,
    required this.modeEmoji,
    this.region,
  });

  @override
  State<_PracticeRecordDialog> createState() => _PracticeRecordDialogState();
}

class _PracticeRecordDialogState extends State<_PracticeRecordDialog>
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = widget.total == 0 ? 0 : (widget.correct / widget.total * 100).round();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) => CustomPaint(
              size: const Size(320, 320),
              painter: _ConfettiPainter(progress: _confettiController.value),
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
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: const Text('🏆', style: TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 8),
                TabularNumber(
                  '${widget.correct}/${widget.total}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.yellow,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                Text(
                  '$percent% CORRECT',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Personal Best!',
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
                  '${widget.modeEmoji} ${widget.modeLabel} · ${widget.region ?? 'All Regions'}',
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
                        'Nice!',
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
  _ConfettiPainter({required this.progress});

  List<_ConfettiPiece> get _pieces => List.generate(24, (i) {
    final angle = (i / 24) * 2 * 3.14159;
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
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _ConfettiPiece {
  final double angle;
  final double speed;
  final Color color;
  final double size;
  _ConfettiPiece({required this.angle, required this.speed, required this.color, required this.size});
}
