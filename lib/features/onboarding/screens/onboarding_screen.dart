import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../home/widgets/app_logo.dart';
import '../../game/screens/game_screen.dart';
import '../../../data/models/game_models.dart';
import '../../../main_scaffold.dart';

/// Shown exactly once, on the very first launch, right after the splash
/// screen. A 4-step animated carousel (auto-advancing but swipeable) that
/// orientates new users, then drops them straight into the single
/// easiest/most visual mode (Flag) rather than presenting all 6 daily
/// streaks at once.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onSeen;
  // true = shown automatically on first launch (ends by dropping the user
  // into a live Flag puzzle). false = opened as a "How to Play" refresher
  // from Settings (ends by just closing back to wherever it was opened).
  final bool isFirstLaunch;
  const OnboardingScreen({super.key, this.onSeen, this.isFirstLaunch = true});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final String emoji;
  final String title;
  final String subtitle;
  const _Slide({required this.emoji, required this.title, required this.subtitle});
}

const _slides = [
  _Slide(
    emoji: '🌍',
    title: 'Welcome to Capitle',
    subtitle: 'Your daily geography workout — quick, fun, and surprisingly addictive.',
  ),
  _Slide(
    emoji: '🚩',
    title: 'Six daily puzzles',
    subtitle: "Capitals, flags, shapes, borders, population and more — all switched on by default. Don't want all six? Open ⚙️ Settings → Daily Streaks and toggle off any you don't want.",
  ),
  _Slide(
    emoji: '🎯',
    title: '3 guesses each',
    subtitle: "Get hints if you're close — distance, direction, or a first-letter clue.",
  ),
  _Slide(
    emoji: '🔥',
    title: 'Streaks are independent',
    subtitle: 'Miss one puzzle and the rest of your streaks keep going.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  Timer? _autoTimer;
  int _page = 0;

  static const _autoAdvanceDelay = Duration(milliseconds: 3500);
  static const _transitionDuration = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _armAutoAdvance();
  }

  void _armAutoAdvance() {
    _autoTimer?.cancel();
    if (_page >= _slides.length - 1) return; // stop looping on the last slide
    _autoTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted) return;
      _pageController.nextPage(duration: _transitionDuration, curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _start() {
    widget.onSeen?.call();
    if (widget.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameScreen(mode: GameMode.guessFlag)),
      );
    } else {
      // Opened as a refresher from Settings — just close back to it.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: BlackGlowBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(children: [
                const SizedBox(width: 24),
                const AppLogoMark(size: 36, borderRadius: 11),
                const SizedBox(width: 10),
                const AppWordmark(fontSize: 20),
              ]),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Pause auto-advance while the user is manually dragging,
                    // then resume the cycle once they let go.
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _autoTimer?.cancel();
                    } else if (notification is ScrollEndNotification) {
                      _armAutoAdvance();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) {
                      setState(() => _page = i);
                      _armAutoAdvance();
                    },
                    itemBuilder: (context, i) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double t = 0;
                          if (_pageController.position.haveDimensions) {
                            t = (_pageController.page ?? _page.toDouble()) - i;
                          } else {
                            t = (_page - i).toDouble();
                          }
                          final distance = t.abs().clamp(0.0, 1.0);
                          return Opacity(
                            opacity: 1 - distance,
                            child: Transform.scale(
                              scale: 1 - (distance * 0.12),
                              child: child,
                            ),
                          );
                        },
                        child: _SlideView(slide: _slides[i], isDark: isDark),
                      );
                    },
                  ),
                ),
              ),

              // Page indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? AppColors.teal : AppColors.teal.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // CTA — only meaningful once the story's told, but reserve
              // the space throughout so nothing jumps around while swiping.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isLast
                      ? GestureDetector(
                          key: const ValueKey('cta'),
                          onTap: _start,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientTealBlue,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.teal.withOpacity(0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(widget.isFirstLaunch ? '🚩' : '👍', style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isFirstLaunch ? "Let's guess a flag" : "Got it, thanks!",
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                              ],
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('skip'),
                          onTap: _start,
                          child: Center(
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool isDark;
  const _SlideView({required this.slide, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              child: Text(slide.emoji, style: const TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? AppColors.textDimDark : AppColors.textDimLight,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
