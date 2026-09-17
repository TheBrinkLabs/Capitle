import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../home/widgets/app_logo.dart';

/// Shown exactly once, to every user (new or existing) — the real GDPR/CCPA
/// consent choice, not a silent default. [onAnswered] is awaited (buttons
/// disable meanwhile) so the caller can persist the choice and apply it to
/// LevelPlay before navigating onward; see ad_consent.dart for that and
/// the three places this screen sits in the launch flow.
class AdConsentScreen extends StatefulWidget {
  // Takes this screen's own BuildContext (not the caller's) so whichever
  // screen navigates onward from here — main.dart or profile_setup_screen.dart,
  // each landing on a different next screen — can call Navigator.of(context)
  // on a context that's actually inside this MaterialApp's Navigator.
  final Future<void> Function(BuildContext context, bool consentGranted) onAnswered;
  const AdConsentScreen({super.key, required this.onAnswered});

  @override
  State<AdConsentScreen> createState() => _AdConsentScreenState();
}

class _AdConsentScreenState extends State<AdConsentScreen> {
  bool _submitting = false;

  Future<void> _answer(bool granted) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.onAnswered(context, granted);
  }

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
                      sheen: MatteSheen.teal,
                      borderRadius: 28,
                      padding: const EdgeInsets.all(28),
                      child: const Text('🔒', style: TextStyle(fontSize: 64)),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text('Ads keep Capitle free', textAlign: TextAlign.center, style: TextStyle(
                      fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, color: textColor)),
                  const SizedBox(height: 10),
                  Text(
                    "We'd like to show ads tailored to you, which helps them pay better. "
                    "You'll see ads either way — this just decides whether they're personalized. "
                    "You can change your mind anytime in Settings.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: textMuted),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(children: [
                GestureDetector(
                  onTap: _submitting ? null : () => _answer(true),
                  child: Opacity(
                    opacity: _submitting ? 0.6 : 1.0,
                    child: Container(
                      width: double.infinity, height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientTealBlue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 5))],
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('👍', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('Allow', style: TextStyle(
                            fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _submitting ? null : () => _answer(false),
                  child: Opacity(
                    opacity: _submitting ? 0.6 : 1.0,
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: Center(
                        child: Text('No thanks',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMuted)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
