import 'package:flutter/widgets.dart';

/// App-wide singleton, registered via MaterialApp's `navigatorObservers`.
/// Lets screens subscribe as RouteAware to learn when they become the
/// active/visible route again after the route above them is popped —
/// needed so a screen can reclaim its preferred banner-ad position
/// (see BannerPositionRoute) without relying on initState, which only
/// ever fires once per screen instance.
final routeObserver = RouteObserver<PageRoute>();
