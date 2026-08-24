import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'app_effects.dart';
import 'league_rank_reveal.dart';
import '../../features/league/providers/league_provider.dart';
import '../../features/league/widgets/league_tier_badge.dart' show LeagueTierHero;
import '../../features/home/widgets/banner_ad_widget.dart' show BannerPosition;
import '../utils/banner_position_route.dart';

/// The dedicated "next" step after DailyCompleteScreen — its own screen
/// (not just a section to scroll past) so watching today's league
/// standing update genuinely feels like something you're taken to, not
/// something buried in a recap. Hosts the same LeagueRankReveal
/// animation, framed with its own header and closing CTA.
///
/// A player who isn't in an active league room yet (fresh install, or
/// still waiting on the next room-assignment sweep) has nothing to
/// reveal — LeagueRankReveal already renders a "Join the League" prompt
/// for that case, but the surrounding "Your League" / "see where you
/// moved" framing and a "Nice work" button don't make sense around it,
/// so this screen keeps that case deliberately minimal instead.
class LeagueRevealScreen extends ConsumerStatefulWidget {
  final int todayScore;
  const LeagueRevealScreen({super.key, required this.todayScore});

  @override
  ConsumerState<LeagueRevealScreen> createState() => _LeagueRevealScreenState();
}

class _LeagueRevealScreenState extends ConsumerState<LeagueRevealScreen>
    with BannerPositionRoute<LeagueRevealScreen> {
  @override
  BannerPosition get bannerPosition => BannerPosition.hidden;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final data = ref.watch(playerDocProvider).valueOrNull?.data();
    final inLeague = data != null &&
        data['roomId'] != null &&
        data['pendingJoin'] != true;
    final tier = data?['tier'] as String? ?? 'bronze';

    void finish() {
      HapticFeedback.mediumImpact();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }

    return Scaffold(
      body: BlackGlowBackground(
        isDark: isDark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                if (inLeague) ...[
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: LeagueTierHero(tier: tier, isDark: isDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "See where today's score moved you",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                  const SizedBox(height: 28),
                ] else
                  const SizedBox(height: 80),

                LeagueRankReveal(todayScore: widget.todayScore, isDark: isDark),
                const SizedBox(height: 32),

                GestureDetector(
                  onTap: finish,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientTealBlue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.teal.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Center(
                      child: Text(inLeague ? 'Nice work' : 'Got it',
                          style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.black,
                          )),
                    ),
                  ),
                ),
                if (inLeague) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Come back tomorrow for more', style: TextStyle(fontSize: 12, color: textMuted)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
