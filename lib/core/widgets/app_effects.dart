import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════
//  Capitle premium effects layer — matte black metal, glow, texture, depth
//  Rich & tactile direction. Drop-in widgets that extend AppColors.
// ════════════════════════════════════════════════════════════════════════

/// Path to the tileable slate grain texture asset.
/// Register in pubspec.yaml under flutter > assets:
///   - assets/textures/slate_grain.png
const String kSlateGrainAsset = 'assets/textures/slate_grain.png';

/// Layered shadow tokens — ambient fill + key light for real lift.
class AppShadows {
  static List<BoxShadow> card(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF1A2B4A).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: const Color(0xFF1A2B4A).withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ];

  static List<BoxShadow> glow(Color color, {double strength = 0.3}) => [
        BoxShadow(
          color: color.withOpacity(strength),
          blurRadius: 24,
          offset: const Offset(0, 6),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> lifted(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: AppColors.teal.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF1A2B4A).withOpacity(0.14),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ];
}

/// ── Matte metal card ─────────────────────────────────────────────────────
/// The core "look and feel" card: pure black/near-black gradient body,
/// no border, depth from inner top highlight + inner bottom shadow +
/// drop shadow, with an optional colored sheen (win=teal, loss=red) and
/// a textured slate-grain overlay that catches the sheen and glistens.
///
/// This is the primary building block for streak cards, puzzle cards,
/// and feature cards across the app.
enum MatteSheen { none, teal, red, gold, blue }

class MatteCard extends StatelessWidget {
  final Widget child;
  final MatteSheen sheen;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isDark;
  final bool showTexture;

  const MatteCard({
    super.key,
    required this.child,
    required this.isDark,
    this.sheen = MatteSheen.none,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.showTexture = true,
  });

  Color get _sheenColor => switch (sheen) {
        MatteSheen.none => Colors.transparent,
        MatteSheen.teal => AppColors.teal,
        MatteSheen.red => AppColors.red,
        MatteSheen.gold => const Color(0xFFFFC845),
        MatteSheen.blue => AppColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    if (!isDark) {
      // Light mode: keep the existing clean surface look — matte metal
      // is a dark-mode-only aesthetic (glisten needs true black to read).
      return _LightFallbackCard(
        padding: padding,
        borderRadius: borderRadius,
        sheen: sheen,
        onTap: onTap,
        child: child,
      );
    }

    final sheenColor = _sheenColor;
    final hasSheen = sheen != MatteSheen.none;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          if (hasSheen)
            BoxShadow(
              color: sheenColor.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 0),
              spreadRadius: -4,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base matte black gradient + optional colored sheen radial
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: hasSheen
                        ? [
                            _mix(const Color(0xFF1E1E1E), sheenColor, 0.04),
                            _mix(const Color(0xFF121212), sheenColor, 0.015),
                            const Color(0xFF0A0A0A),
                          ]
                        : const [
                            Color(0xFF1E1E1E),
                            Color(0xFF121212),
                            Color(0xFF0A0A0A),
                          ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // Soft top fade — a whisper of colour, not a wash
            if (hasSheen)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sheenColor.withOpacity(0.055),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                ),
              ),
            // Slate grain texture — subtle, properly tiled, glistens under sheen.
            // ResizeImage forces a small decode size so the grain repeats
            // finely across the card rather than showing one large blurry patch.
            if (showTexture)
              Positioned.fill(
                child: Opacity(
                  opacity: hasSheen ? 0.07 : 0.045,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: ResizeImage(
                          const AssetImage(kSlateGrainAsset),
                          width: 48,
                          height: 48,
                        ),
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                  ),
                ),
              ),
            // Inner top highlight (bevel light)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: hasSheen
                          ? sheenColor.withOpacity(0.18)
                          : Colors.white.withOpacity(0.09),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            // Inner bottom shadow (bevel dark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withOpacity(0.85),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            // Content
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}

/// Light-mode premium card — crisp white/porcelain surface that lifts off
/// the page via soft layered shadow (no hard borders). Sheen shows as a
/// gentle colour wash from the top plus a tinted shadow, so win/loss states
/// still read clearly without looking washed-out or pastel.
class _LightFallbackCard extends StatelessWidget {
  final Widget child;
  final MatteSheen sheen;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _LightFallbackCard({
    required this.child,
    required this.sheen,
    required this.borderRadius,
    required this.padding,
    this.onTap,
  });

  Color get _sheenColor => switch (sheen) {
        MatteSheen.none => Colors.transparent,
        MatteSheen.teal => AppColors.tealDim,
        MatteSheen.red => AppColors.red,
        MatteSheen.gold => const Color(0xFFE0A800),
        MatteSheen.blue => AppColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final hasSheen = sheen != MatteSheen.none;
    final sheenColor = _sheenColor;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Ambient — soft, wide, defines the lift
          BoxShadow(
            color: const Color(0xFF15223D).withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          // Key — tighter, crisper edge
          BoxShadow(
            color: const Color(0xFF15223D).withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          if (hasSheen)
            BoxShadow(
              color: sheenColor.withOpacity(0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -8,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base porcelain-white fill
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
            ),
            // Gentle top colour wash for sheen — not pastel, just a whisper
            if (hasSheen)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sheenColor.withOpacity(0.09),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            // Hairline top highlight for crispness
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasSheen
                        ? sheenColor.withOpacity(0.18)
                        : const Color(0xFF15223D).withOpacity(0.06),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Pure black background with a soft white corner glow (top-left) and a
/// faint teal bloom (top-right). Replaces the old GlowMesh for the new
/// matte-black direction.
class BlackGlowBackground extends StatelessWidget {
  final bool isDark;
  final Widget? child;

  const BlackGlowBackground({super.key, required this.isDark, this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDark) {
      // Light mode: clean neutral backdrop (not tinted) so white cards pop
      // via shadow contrast, with a faint corner warmth for atmosphere.
      return Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFF3F5F8))),
          ),
          Positioned(
            top: -100, left: -80,
            child: Container(
              width: 340, height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.teal.withOpacity(0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            top: -80, right: -100,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.blue.withOpacity(0.04),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      );
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
        ),
        // Soft white corner glow, top-left
        Positioned(
          top: -140, left: -120,
          child: Container(
            width: 360, height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.09),
                  Colors.white.withOpacity(0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.68],
              ),
            ),
          ),
        ),
        // Faint teal bloom, top-right
        Positioned(
          top: -120, right: -140,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.teal.withOpacity(0.05),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

// ── Legacy glass/glow widgets kept for compatibility ───────────────────────
// (used on lighter surfaces / non-card contexts; still available if needed)

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isDark;
  final Color? tint;
  final double blurSigma;
  final List<BoxShadow>? shadows;
  final Border? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.tint,
    this.blurSigma = 18,
    this.shadows,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseTint = tint ??
        (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.65));
    final highlightBorder = border ??
        Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.9),
          width: 1,
        );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? AppShadows.card(isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: baseTint,
              borderRadius: BorderRadius.circular(borderRadius),
              border: highlightBorder,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.0)]
                    : [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.1)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class GlowMesh extends StatelessWidget {
  final bool isDark;
  final List<GlowPoint>? points;
  final Widget? child;

  const GlowMesh({super.key, required this.isDark, this.points, this.child});

  @override
  Widget build(BuildContext context) {
    final pts = points ??
        [
          GlowPoint(alignment: const Alignment(-0.7, -0.9), color: AppColors.teal, radius: 0.9, strength: isDark ? 0.16 : 0.10),
          GlowPoint(alignment: const Alignment(0.9, -0.5), color: AppColors.blue, radius: 0.7, strength: isDark ? 0.12 : 0.07),
          GlowPoint(alignment: const Alignment(0.2, 0.95), color: AppColors.teal, radius: 0.8, strength: isDark ? 0.10 : 0.06),
        ];

    return Stack(
      children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: isDark ? AppColors.bg : AppColors.bgLight))),
        ...pts.map((p) => Positioned.fill(
              child: Align(
                alignment: p.alignment,
                child: FractionallySizedBox(
                  widthFactor: p.radius,
                  heightFactor: p.radius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [p.color.withOpacity(p.strength), p.color.withOpacity(0)]),
                    ),
                  ),
                ),
              ),
            )),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class GlowPoint {
  final Alignment alignment;
  final Color color;
  final double radius;
  final double strength;
  const GlowPoint({required this.alignment, required this.color, required this.radius, required this.strength});
}

class MeshSurface extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final List<Color>? meshColors;
  final List<BoxShadow>? shadows;
  final Border? border;

  const MeshSurface({
    super.key,
    required this.child,
    required this.isDark,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(20),
    this.meshColors,
    this.shadows,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = meshColors ??
        (isDark
            ? [const Color(0xFF18202C), const Color(0xFF131820), const Color(0xFF11161E)]
            : [Colors.white, const Color(0xFFF7F9FC), const Color(0xFFEFF3F8)]);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? AppShadows.card(isDark),
        border: border ?? Border.all(color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.9)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: child,
    );
  }
}

/// Tabular-figure text — numbers that don't jiggle when streaks update.
class TabularNumber extends StatelessWidget {
  final String value;
  final TextStyle style;
  const TabularNumber(this.value, {super.key, required this.style});

  @override
  Widget build(BuildContext context) => Text(
        value,
        style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
}
