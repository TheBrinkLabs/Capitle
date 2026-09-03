import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import 'league_tier_badge.dart';

/// How the player's week just went, relative to the room they played in —
/// mirrors the 'outcome' field rollover.js writes to
/// players/{uid}/weekHistory/{weekId}.
enum WeekOutcome { promoted, relegated, stayed }

WeekOutcome weekOutcomeFromString(String value) => switch (value) {
      'promoted' => WeekOutcome.promoted,
      'relegated' => WeekOutcome.relegated,
      _ => WeekOutcome.stayed,
    };

/// Shown once per week, the first time the app notices an unrevealed
/// players/{uid}/weekHistory entry (see LeagueRepository.latestWeekHistory
/// and PlayerProfileNotifier.shouldShowWeekResult). Covers all three
/// possible outcomes — promoted gets the big confetti moment, relegated
/// and stayed still get a clear "here's where you finished, here's your
/// league this week" instead of the tier badge just silently changing (or
/// not) with no explanation.
Future<void> showLeagueWeekResultReveal(
  BuildContext context, {
  required WeekOutcome outcome,
  required String oldTier,
  required String newTier,
  required int rank,
  required int roomSize,
  required int score,
}) async {
  switch (outcome) {
    case WeekOutcome.promoted:
      HapticFeedback.heavyImpact();
    case WeekOutcome.relegated:
      HapticFeedback.mediumImpact();
    case WeekOutcome.stayed:
      HapticFeedback.selectionClick();
  }
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Week result',
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) => _WeekResultDialog(
      outcome: outcome,
      oldTier: oldTier,
      newTier: newTier,
      rank: rank,
      roomSize: roomSize,
      score: score,
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

class _WeekResultDialog extends StatefulWidget {
  final WeekOutcome outcome;
  final String oldTier;
  final String newTier;
  final int rank;
  final int roomSize;
  final int score;

  const _WeekResultDialog({
    required this.outcome,
    required this.oldTier,
    required this.newTier,
    required this.rank,
    required this.roomSize,
    required this.score,
  });

  @override
  State<_WeekResultDialog> createState() => _WeekResultDialogState();
}

class _WeekResultDialogState extends State<_WeekResultDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;

  bool get _isPromoted => widget.outcome == WeekOutcome.promoted;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (_isPromoted) _confettiController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _headline => switch (widget.outcome) {
        WeekOutcome.promoted => 'Promoted!',
        _ => '${tierLabel(widget.newTier)} League',
      };

  // A 0-point week never results in promotion (the server won't promote
  // anyone who didn't score — see rollover.js), so this only ever needs
  // to cover relegated/stayed. Rank doesn't mean much to call out when it
  // was earned by not playing, so this replaces the rank-based framing
  // entirely rather than just tacking "(0 points)" onto it.
  String get _subtitle {
    if (widget.score == 0) {
      return "You scored 0 points last week — you're in ${tierLabel(widget.newTier)} League this week.";
    }
    return switch (widget.outcome) {
      WeekOutcome.promoted =>
        'Finished #${widget.rank} of ${widget.roomSize} in ${tierLabel(widget.oldTier)} — welcome to ${tierLabel(widget.newTier)} League!',
      WeekOutcome.relegated =>
        "You finished #${widget.rank} of ${widget.roomSize} in ${tierLabel(widget.oldTier)} last week.",
      WeekOutcome.stayed =>
        'You finished #${widget.rank} of ${widget.roomSize} last week — go again this week!',
    };
  }

  MatteSheen get _sheen => switch (widget.outcome) {
        WeekOutcome.promoted => MatteSheen.gold,
        WeekOutcome.relegated => MatteSheen.red,
        WeekOutcome.stayed => MatteSheen.blue,
      };

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
          if (_isPromoted)
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) => CustomPaint(
                size: const Size(340, 340),
                painter: _ConfettiPainter(progress: _confettiController.value),
              ),
            ),
          MatteCard(
            isDark: isDark,
            sheen: _sheen,
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: _isPromoted ? 0.4 : 0.7, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: _isPromoted ? Curves.elasticOut : Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Text(tierEmoji(widget.newTier), style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 12),
              Text(_headline, textAlign: TextAlign.center, style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDark : AppColors.textLight)),
              const SizedBox(height: 8),
              Text(_subtitle, textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 13, color: isDark ? AppColors.textDimDark : AppColors.textDimLight)),
              const SizedBox(height: 14),
              LeagueTierBadge(tier: widget.newTier, fontSize: 15),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(gradient: AppColors.gradientTealBlue, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(_isPromoted ? 'Nice!' : 'Got it', style: const TextStyle(
                      fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static const _pieceCount = 40;
  _ConfettiPainter({required this.progress});

  List<_ConfettiPiece> get _pieces => List.generate(_pieceCount, (i) {
    final angle = (i / _pieceCount) * 2 * 3.14159;
    return _ConfettiPiece(
      angle: angle,
      speed: 90 + (i % 5) * 24.0,
      color: [AppColors.teal, AppColors.yellow, AppColors.blue, AppColors.red][i % 4],
      size: 5.0 + (i % 3) * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final fade = progress < 0.55 ? 1.0 : (1 - (progress - 0.55) / 0.45).clamp(0.0, 1.0);
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
