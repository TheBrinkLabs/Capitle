import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';
import '../../data/models/country_flag_data.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/league/providers/league_provider.dart';

/// Shown on DailyCompleteScreen right after finishing today's puzzles —
/// reveals where the player's week-to-date league score ranked BEFORE
/// today's just-submitted score, then animates it counting up to the
/// real current total while the room's rows reorder around it, so
/// climbing the standings is something you watch happen rather than
/// just a static number. Fails quiet (renders nothing) if the player
/// isn't in a league room yet, or the data can't be fetched — this is a
/// bonus flourish on top of the day-complete recap, not essential to it.
class LeagueRankReveal extends StatefulWidget {
  final int todayScore;
  final bool isDark;
  const LeagueRankReveal({super.key, required this.todayScore, required this.isDark});

  @override
  State<LeagueRankReveal> createState() => _LeagueRankRevealState();
}

class _LeagueRankRevealState extends State<LeagueRankReveal> {
  bool _readyToFetch = false;

  @override
  void initState() {
    super.initState();
    // Today's league score submission runs fire-and-forget in the
    // background the moment this screen is reached (see
    // game_provider.dart's _onGameOver — deliberately not awaited, so a
    // slow network never blocks the core game flow). Give it a head
    // start before reading standings back, or "today's score" might not
    // have landed in the fetched total yet, throwing off the before/after
    // numbers this whole reveal depends on being accurate.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _readyToFetch = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_readyToFetch) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return _LeagueRankRevealContent(todayScore: widget.todayScore, isDark: widget.isDark);
  }
}

class _LeagueRankRevealContent extends ConsumerWidget {
  final int todayScore;
  final bool isDark;
  const _LeagueRankRevealContent({required this.todayScore, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(playerDocProvider).valueOrNull?.data();
    final roomId = data?['roomId'] as String?;
    final pendingJoin = data?['pendingJoin'] as bool? ?? true;
    final uid = ref.watch(uidProvider);

    if (uid == null || roomId == null || pendingJoin) {
      // Not in the league yet (or profile still mid-setup) — league
      // participation is optional, so a light nudge, not an error state.
      final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
      return MatteCard(
        isDark: isDark,
        borderRadius: 18,
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text('Join the League to see your ranking here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textMuted)),
        ]),
      );
    }

    final membersAsync = ref.watch(leagueRoomMembersProvider(roomId));
    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => const SizedBox.shrink(),
      data: (members) {
        final hasMe = members.any((m) => m.uid == uid);
        if (!hasMe) return const SizedBox.shrink();
        return _RankRevealAnimation(members: members, myUid: uid, todayScore: todayScore, isDark: isDark);
      },
    );
  }
}

class _RankRevealAnimation extends StatefulWidget {
  final List<LeagueMemberEntry> members;
  final String myUid;
  final int todayScore;
  final bool isDark;
  const _RankRevealAnimation({
    required this.members,
    required this.myUid,
    required this.todayScore,
    required this.isDark,
  });

  @override
  State<_RankRevealAnimation> createState() => _RankRevealAnimationState();
}

class _RankRevealAnimationState extends State<_RankRevealAnimation> with SingleTickerProviderStateMixin {
  static const _rowHeight = 52.0;
  static const _rowSpacing = 8.0;
  static const _preAnimateDelay = Duration(milliseconds: 600);

  late final AnimationController _controller;
  late final List<LeagueMemberEntry> _afterOrder;
  late final Map<String, int> _beforeRank;
  late final Map<String, int> _afterRank;
  late final int _myScoreBefore;
  late final int _myScoreAfter;

  @override
  void initState() {
    super.initState();

    final myEntry = widget.members.firstWhere((m) => m.uid == widget.myUid);
    _myScoreAfter = myEntry.score;
    // Clamped defensively — if the pre-fetch delay somehow wasn't enough
    // and today's submission still hadn't landed, this could otherwise
    // go negative rather than just under-animate.
    _myScoreBefore = (myEntry.score - widget.todayScore).clamp(0, 1 << 31);

    int byScoreThenStreak(LeagueMemberEntry a, LeagueMemberEntry b, int Function(LeagueMemberEntry) scoreOf) {
      final byScore = scoreOf(b).compareTo(scoreOf(a));
      return byScore != 0 ? byScore : b.streak.compareTo(a.streak);
    }

    _afterOrder = [...widget.members]..sort((a, b) => byScoreThenStreak(a, b, (m) => m.score));
    final beforeOrder = [...widget.members]
      ..sort((a, b) => byScoreThenStreak(
            a, b, (m) => m.uid == widget.myUid ? _myScoreBefore : m.score));

    _beforeRank = {for (var i = 0; i < beforeOrder.length; i++) beforeOrder[i].uid: i};
    _afterRank = {for (var i = 0; i < _afterOrder.length; i++) _afterOrder[i].uid: i};

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    // Let the player register their starting position before anything
    // starts moving, rather than animating immediately on mount.
    Future.delayed(_preAnimateDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.members.length;
    final height = n * _rowHeight + (n - 1) * _rowSpacing;

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          return Stack(
            clipBehavior: Clip.none,
            children: [for (final member in widget.members) _buildRow(member, t)],
          );
        },
      ),
    );
  }

  Widget _buildRow(LeagueMemberEntry member, double t) {
    final before = _beforeRank[member.uid] ?? 0;
    final after = _afterRank[member.uid] ?? 0;
    final y = before + (after - before) * t;
    final isMe = member.uid == widget.myUid;
    final displayScore = isMe
        ? (_myScoreBefore + (_myScoreAfter - _myScoreBefore) * t).round()
        : member.score;

    return Positioned(
      top: y * (_rowHeight + _rowSpacing),
      left: 0,
      right: 0,
      child: _RevealRow(
        rank: after + 1,
        member: member,
        displayScore: displayScore,
        isMe: isMe,
        isDark: widget.isDark,
      ),
    );
  }
}

class _RevealRow extends StatelessWidget {
  final int rank;
  final LeagueMemberEntry member;
  final int displayScore;
  final bool isMe;
  final bool isDark;
  const _RevealRow({
    required this.rank,
    required this.member,
    required this.displayScore,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final flag = findCountryByCode(member.countryCode)?.flagEmoji ?? '🏳️';

    return SizedBox(
      height: 52,
      child: MatteCard(
        isDark: isDark,
        sheen: isMe ? MatteSheen.blue : MatteSheen.none,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: Text('$rank', textAlign: TextAlign.center, style: TextStyle(
                fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: textMuted)),
          ),
          const SizedBox(width: 8),
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(member.nickname, overflow: TextOverflow.ellipsis, style: TextStyle(
                fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700,
                color: isMe ? AppColors.blue : textColor)),
          ),
          TabularNumber('$displayScore', style: TextStyle(
              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
        ]),
      ),
    );
  }
}
