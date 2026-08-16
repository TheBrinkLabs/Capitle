import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../data/models/country_flag_data.dart';
import '../providers/league_provider.dart';
import 'league_tier_badge.dart' show kTopTier;

class LeagueLeaderboard extends StatelessWidget {
  final List<LeagueMemberEntry> members;
  final String currentUid;
  final String tier;
  final bool isDark;

  const LeagueLeaderboard({
    super.key,
    required this.members,
    required this.currentUid,
    required this.tier,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final canPromote = tier != kTopTier;
    final canRelegate = tier != 'bronze';
    final promotionZone = canPromote ? 3 : 0;
    final relegationZone = canRelegate ? 3 : 0;

    return Column(
      children: [
        for (int i = 0; i < members.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _LeaderboardRow(
            rank: i + 1,
            entry: members[i],
            isMe: members[i].uid == currentUid,
            isDark: isDark,
            isPromotionZone: i < promotionZone,
            isRelegationZone: i >= members.length - relegationZone,
          ),
        ],
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeagueMemberEntry entry;
  final bool isMe;
  final bool isDark;
  final bool isPromotionZone;
  final bool isRelegationZone;

  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.isDark,
    required this.isPromotionZone,
    required this.isRelegationZone,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final sheen = isPromotionZone
        ? MatteSheen.gold
        : isRelegationZone
            ? MatteSheen.red
            : (isMe ? MatteSheen.blue : MatteSheen.none);
    final flag = findCountryByCode(entry.countryCode)?.flagEmoji ?? '🏳️';

    return MatteCard(
      isDark: isDark,
      sheen: sheen,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('$rank', textAlign: TextAlign.center, style: TextStyle(
              fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700, color: textMuted)),
        ),
        const SizedBox(width: 8),
        Text(flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(entry.nickname, overflow: TextOverflow.ellipsis, style: TextStyle(
              fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700,
              color: isMe ? AppColors.blue : textColor)),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          TabularNumber('${entry.streak}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
        ]),
        const SizedBox(width: 14),
        TabularNumber('${entry.score}', style: TextStyle(
            fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
        if (isPromotionZone) ...[
          const SizedBox(width: 6),
          const Icon(Icons.arrow_upward_rounded, size: 15, color: AppColors.yellow),
        ] else if (isRelegationZone) ...[
          const SizedBox(width: 6),
          const Icon(Icons.arrow_downward_rounded, size: 15, color: AppColors.red),
        ],
      ]),
    );
  }
}
