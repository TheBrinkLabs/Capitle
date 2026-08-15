import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../home/widgets/app_logo.dart';
import 'profile_setup_screen.dart';

/// Shown exactly once to existing users, the first time they open the app
/// after the league feature ships — a single screen (not a carousel),
/// leading straight into the same skippable profile setup new users get.
class LeagueAnnouncementScreen extends StatelessWidget {
  final VoidCallback onSeen;
  const LeagueAnnouncementScreen({super.key, required this.onSeen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textDimDark : AppColors.textDimLight;

    return Scaffold(
      body: BlackGlowBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 16),
            Row(children: [
              const SizedBox(width: 24),
              const AppLogoMark(size: 36, borderRadius: 11),
              const SizedBox(width: 10),
              const AppWordmark(fontSize: 20),
            ]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: MatteCard(
                      isDark: isDark,
                      sheen: MatteSheen.gold,
                      borderRadius: 28,
                      padding: const EdgeInsets.all(28),
                      child: const Text('🏆', style: TextStyle(fontSize: 64)),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text('The League is here!', textAlign: TextAlign.center, style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, color: textColor)),
                  const SizedBox(height: 10),
                  Text(
                    'Compete weekly against other players. Score points for every correct answer, climb from Bronze to Platinum, and get promoted or relegated each Monday — just like Duolingo leagues.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: textMuted),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: GestureDetector(
                onTap: () {
                  onSeen();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => const ProfileSetupScreen(
                          mode: ProfileSetupMode.existingUserAnnouncement)));
                },
                child: Container(
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientTealBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 5))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('🚀', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text("Let's go", style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
