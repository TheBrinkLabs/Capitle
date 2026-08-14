import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AppLogoMark extends StatelessWidget {
  final double size;
  final double borderRadius;

  const AppLogoMark({super.key, this.size = 56, this.borderRadius = 16});

  @override
  Widget build(BuildContext context) {
    // Renders the actual app icon asset rather than a hand-drawn "C" —
    // the two had drifted into visibly different letterforms (this used
    // a font-rendered C, the real launcher icon uses a custom-drawn
    // one), so the splash/home/onboarding logo looked like a different
    // app from the one that just launched.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withOpacity(0.4),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.cover),
      ),
    );
  }
}

class AppWordmark extends StatelessWidget {
  final double fontSize;
  final bool showTagline;

  const AppWordmark({super.key, this.fontSize = 28, this.showTagline = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Capit',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: 'le',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'DAILY CAPITAL QUIZ',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 3,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
