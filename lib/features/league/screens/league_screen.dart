import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/utils/league_scoring.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../features/onboarding/screens/profile_setup_screen.dart';
import '../../../features/profile/providers/player_profile_provider.dart';
import '../providers/league_provider.dart';
import '../widgets/league_leaderboard.dart';
import '../widgets/league_promotion_celebration.dart';
import '../widgets/league_tier_badge.dart';

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
  Future<void> _checkPromotion(String tier) async {
    final promoted =
        await ref.read(playerProfileProvider.notifier).noteTierAndCheckPromotion(tier);
    if (!promoted || !mounted) return;
    showLeaguePromotionCelebration(context, newTier: tier);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerDocProvider, (previous, next) {
      final tier = next.valueOrNull?.data()?['tier'] as String?;
      if (tier == null) return;
      _checkPromotion(tier);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final profile = ref.watch(playerProfileProvider);
    final playerDocAsync = ref.watch(playerDocProvider);

    Widget body;
    if (!profile.hasCompletedProfileSetup) {
      body = _SetupPrompt(isDark: isDark);
    } else {
      body = playerDocAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _MessageCard(
          isDark: isDark,
          emoji: '📡',
          title: "Can't reach the league right now",
          subtitle: 'Check your connection and try again in a bit.',
        ),
        data: (snap) {
          final data = snap?.data();
          if (data == null) {
            return _MessageCard(
              isDark: isDark,
              emoji: '🎯',
              title: 'Setting up your league profile…',
              subtitle: 'This should only take a moment.',
            );
          }
          final tier = data['tier'] as String? ?? 'bronze';
          final roomId = data['roomId'] as String?;
          final pendingJoin = data['pendingJoin'] as bool? ?? true;

          if (roomId == null || pendingJoin) {
            return _WaitingToJoin(isDark: isDark, tier: tier);
          }

          final uid = ref.watch(uidProvider);
          final membersAsync = ref.watch(leagueRoomMembersProvider(roomId));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leagueRoomMembersProvider(roomId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: LeagueTierBadge(tier: tier, fontSize: 15)),
                const SizedBox(height: 18),
                membersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => _MessageCard(
                    isDark: isDark, emoji: '📡',
                    title: "Couldn't load standings",
                    subtitle: 'Pull down to try again.',
                  ),
                  data: (members) => LeagueLeaderboard(
                    members: members,
                    currentUid: uid ?? '',
                    tier: tier,
                    isDark: isDark,
                  ),
                ),
              ]),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('League', style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800,
                  color: textColor, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Weekly scores · Monday to Sunday', style: TextStyle(fontSize: 13, color: textMuted)),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  final bool isDark;
  const _SetupPrompt({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MatteCard(
          isDark: isDark,
          sheen: MatteSheen.teal,
          borderRadius: 22,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏆', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text('Join the League', style: TextStyle(
                fontFamily: 'Outfit', fontSize: 19, fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textDark : AppColors.textLight)),
            const SizedBox(height: 6),
            Text('Pick a nickname and country to start competing weekly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDimDark : AppColors.textDimLight)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProfileSetupScreen(mode: ProfileSetupMode.standalone))),
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(gradient: AppColors.gradientTealBlue, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Get Started', style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _WaitingToJoin extends StatelessWidget {
  final bool isDark;
  final String tier;
  const _WaitingToJoin({required this.isDark, required this.tier});

  @override
  Widget build(BuildContext context) {
    // New joiners get swept into a Bronze room together once a day (see
    // assignNewJoiners.js) rather than waiting for the next Monday
    // rollover — caps the wait at ~24h instead of up to 6 days.
    final remaining = timeUntilNextDailyJoin();
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MatteCard(
          isDark: isDark,
          sheen: MatteSheen.teal,
          borderRadius: 22,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⏳', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text("You're in!", style: TextStyle(
                fontFamily: 'Outfit', fontSize: 19, fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textDark : AppColors.textLight)),
            const SizedBox(height: 6),
            Text("You'll be placed in a room with other new players tomorrow.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDimDark : AppColors.textDimLight)),
            const SizedBox(height: 12),
            Text('$hours hr${hours == 1 ? '' : 's'} $minutes min to go',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.teal)),
            const SizedBox(height: 14),
            LeagueTierBadge(tier: tier),
          ]),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final bool isDark;
  final String emoji;
  final String title;
  final String subtitle;
  const _MessageCard({required this.isDark, required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: TextStyle(
              fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDark : AppColors.textLight)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDimDark : AppColors.textDimLight)),
        ]),
      ),
    );
  }
}
