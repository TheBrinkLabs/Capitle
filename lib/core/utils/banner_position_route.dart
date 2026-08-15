import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/widgets/banner_ad_widget.dart';
import 'route_observer.dart';

/// Mix into a screen's ConsumerState to declare where the single
/// persistent banner ad should sit while that screen is the active
/// route — without the screen owning any ad instance itself. Handles
/// the RouteAware subscribe/unsubscribe boilerplate; each screen just
/// implements [bannerPosition].
///
/// Only didPush/didPopNext matter here — those are the two moments this
/// screen becomes the visible route (freshly pushed, or revealed again
/// after the route above it is popped). We don't need didPop/didPushNext:
/// whichever screen becomes active next sets its own preference the
/// same way, so there's nothing for the outgoing screen to clean up.
mixin BannerPositionRoute<T extends ConsumerStatefulWidget> on ConsumerState<T> implements RouteAware {
  BannerPosition get bannerPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => _apply();

  @override
  void didPopNext() => _apply();

  void _apply() {
    // didPush()/didPopNext() (and the didPush() that RouteObserver.subscribe()
    // fires synchronously from didChangeDependencies) can land while the
    // widget tree is still building, so defer the actual provider write to
    // the next frame rather than mutating it mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bannerPositionProvider.notifier).state = bannerPosition;
    });
  }

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
