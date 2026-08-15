import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import 'league_tier_badge.dart';

/// Shown when the app notices the player's tier moved up since it last
/// checked (comparing the previous locally-cached tier against the tier
/// now returned from players/{uid}). The promotion itself already
/// happened server-side during the weekly rollover — this widget is purely
/// a client-side "hey, congrats" moment, not the source of truth.
Future<void> showLeaguePromotionCelebration(BuildContext context, {required String newTier}) async {
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Promoted',
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) => _PromotionDialog(newTier: newTier),
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + (curved.value * 0.3), child: child),
      );
    },
  );
}

class _PromotionDialog extends StatelessWidget {
  final String newTier;
  const _PromotionDialog({required this.newTier});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: MatteCard(
        isDark: isDark,
        sheen: MatteSheen.gold,
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Text(tierEmoji(newTier), style: const TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 12),
          Text('Promoted!', style: TextStyle(
              fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textDark : AppColors.textLight)),
          const SizedBox(height: 8),
          LeagueTierBadge(tier: newTier, fontSize: 15),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(gradient: AppColors.gradientTealBlue, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Nice!', style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
            ),
          ),
        ]),
      ),
    );
  }
}
