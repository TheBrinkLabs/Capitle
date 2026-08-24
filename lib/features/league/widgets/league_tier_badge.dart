import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Tiers currently live in the league. Platinum is deliberately not in
/// this list yet — the room-assignment fallback (a single, possibly
/// tiny room when a tier can't fill 12-19 members) means a brand-new
/// top tier would likely sit near-empty for weeks with low player
/// counts. Bronze/Silver/Gold gives Gold real headroom to fill up
/// first. To bring Platinum back: add it here, add it back to `TIERS`
/// in tools/league-rollover/rollover.js, and restore the "Bronze to
/// Platinum" copy in onboarding_screen.dart and
/// league_announcement_screen.dart.
const kActiveTiers = ['bronze', 'silver', 'gold'];
const kTopTier = 'gold';

const _tierColors = {
  'bronze': Color(0xFFCD7F32),
  'silver': Color(0xFFC0C0C0),
  'gold': Color(0xFFFFD700),
  'platinum': Color(0xFF8FE3D3),
};

const _tierEmoji = {
  'bronze': '🥉',
  'silver': '🥈',
  'gold': '🥇',
  'platinum': '💎',
};

Color tierColor(String tier) => _tierColors[tier] ?? _tierColors['bronze']!;

String tierEmoji(String tier) => _tierEmoji[tier] ?? '🥉';

String tierLabel(String tier) =>
    tier.isEmpty ? 'Bronze' : '${tier[0].toUpperCase()}${tier.substring(1)}';

class LeagueTierBadge extends StatelessWidget {
  final String tier;
  final double fontSize;

  const LeagueTierBadge({super.key, required this.tier, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final color = tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(tierEmoji(tier), style: TextStyle(fontSize: fontSize + 2)),
        const SizedBox(width: 6),
        Text(tierLabel(tier), style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Prominent tier display — the medal and the tier name ("Bronze
/// League") sitting directly on the page, no card/border around it.
/// Used both at the top of the active League tab and on the post-game
/// league reveal, so a player sees the exact same "you're in Bronze
/// League" framing in both places.
class LeagueTierHero extends StatelessWidget {
  final String tier;
  final bool isDark;
  const LeagueTierHero({super.key, required this.tier, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = tierColor(tier);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 56,
        height: 56,
        child: Stack(alignment: Alignment.center, children: [
          // Soft outer glow.
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withOpacity(0.3), Colors.transparent]),
            ),
          ),
          // The medal itself — gradient-filled circle matching the
          // tier's own colour rather than a fixed preset.
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.65)],
              ),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Center(child: Text(tierEmoji(tier), style: const TextStyle(fontSize: 21))),
          ),
        ]),
      ),
      const SizedBox(width: 14),
      Text(
        '${tierLabel(tier)} League',
        style: TextStyle(
          fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
          color: textColor, letterSpacing: -0.3,
        ),
      ),
    ]);
  }
}
