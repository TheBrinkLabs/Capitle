import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════
//  Capitle cinematic transition system
//  Fade-through-scale base motion + Hero morphs with spring physics.
// ════════════════════════════════════════════════════════════════════════

/// Spring-like curve — overshoots slightly then settles. The signature feel.
class _SpringCurve extends Curve {
  const _SpringCurve();
  @override
  double transformInternal(double t) {
    // Critically-damped-ish spring approximation
    return 1 - (1 - t) * (1 - t) * (1 - 0.18 * t);
  }
}

const springCurve = _SpringCurve();

/// Fade-through-scale page route. The outgoing screen scales down + fades,
/// the incoming screen scales up from 0.92 + fades in. Material-3 flavoured.
class FadeThroughScaleRoute<T> extends PageRoute<T> {
  final Widget page;
  final Duration duration;

  FadeThroughScaleRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 420),
    super.settings,
  });

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  bool get opaque => true;
  @override
  Duration get transitionDuration => duration;
  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 320);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      page;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Incoming
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
    );
    final scaleIn = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    // Outgoing (when a new screen covers this one)
    final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );
    final scaleOut = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: ScaleTransition(
        scale: scaleOut,
        child: FadeTransition(
          opacity: fadeIn,
          child: ScaleTransition(scale: scaleIn, child: child),
        ),
      ),
    );
  }
}

/// Convenience push helpers so call sites stay tidy.
extension CapitleNavigation on NavigatorState {
  Future<T?> pushCinematic<T>(Widget page) =>
      push<T>(FadeThroughScaleRoute<T>(page: page));
}

/// Wrap a hero element (flag, country name) so it morphs between screens.
/// Use the SAME tag on the home card and the destination hero.
class MorphHero extends StatelessWidget {
  final String tag;
  final Widget child;
  const MorphHero({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, direction,
          fromContext, toContext) {
        // Smooth scale + fade between the two hero states
        final curved =
            CurvedAnimation(parent: animation, curve: springCurve);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: toContext.widget,
        );
      },
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
