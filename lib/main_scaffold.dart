import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'core/utils/providers.dart' show navIndexProvider;
import 'core/utils/route_observer.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/widgets/banner_ad_widget.dart';
import 'features/league/screens/league_screen.dart';
import 'features/stats/screens/stats_screen.dart';
import 'features/settings/screens/settings_screen.dart';

// Home (0), League (1) and Stats (2) show the banner; Settings (3)
// doesn't — still just the single persistent banner instance repositioned
// per tab, never more than one shown at once.
BannerPosition _bannerPositionForTab(int index) =>
    (index == 0 || index == 1 || index == 2) ? BannerPosition.bottomAboveNav : BannerPosition.hidden;

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  static const _screens = [
    HomeScreen(),
    LeagueScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> implements RouteAware {
  @override
  void initState() {
    super.initState();
    // Deferred the same way main.dart's _rescheduleNotifications is —
    // writing to another provider synchronously during initState/build
    // risks "setState during build" since PersistentBannerAd watches
    // bannerPositionProvider reactively.
    _applyBannerPosition();
  }

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

  // Popping a pushed screen (a game, a result screen, ...) back to
  // MainScaffold reveals it again without changing navIndexProvider, so
  // the ref.listen below never fires — without this, the banner keeps
  // whatever position/offset the popped screen last set (e.g. flush
  // BannerPosition.bottom instead of Home's bottomAboveNav), which visually
  // overlaps the tab bar. Re-apply the current tab's position whenever this
  // route becomes visible again.
  @override
  void didPopNext() => _applyBannerPosition();

  @override
  void didPush() {}
  @override
  void didPop() {}
  @override
  void didPushNext() {}

  void _applyBannerPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(bannerPositionProvider.notifier).state =
            _bannerPositionForTab(ref.read(navIndexProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexProvider);
    ref.listen(navIndexProvider, (previous, next) {
      ref.read(bannerPositionProvider.notifier).state = _bannerPositionForTab(next);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBg = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: MainScaffold._screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: navBg,
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: kMainNavBarHeight,
              child: Row(
                children: [
                  _NavItem(
                    icon: _NavIcon.home,
                    label: 'Home',
                    isSelected: index == 0,
                    isDark: isDark,
                    onTap: () => ref.read(navIndexProvider.notifier).state = 0,
                  ),
                  _NavItem(
                    icon: _NavIcon.league,
                    label: 'League',
                    isSelected: index == 1,
                    isDark: isDark,
                    onTap: () => ref.read(navIndexProvider.notifier).state = 1,
                  ),
                  _NavItem(
                    icon: _NavIcon.stats,
                    label: 'Stats',
                    isSelected: index == 2,
                    isDark: isDark,
                    onTap: () => ref.read(navIndexProvider.notifier).state = 2,
                  ),
                  _NavItem(
                    icon: _NavIcon.settings,
                    label: 'Settings',
                    isSelected: index == 3,
                    isDark: isDark,
                    onTap: () => ref.read(navIndexProvider.notifier).state = 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _NavIcon { home, league, stats, settings }

class _NavItem extends StatelessWidget {
  final _NavIcon icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.teal;
    final inactiveColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: _buildIcon(icon, color, isSelected),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(label.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(_NavIcon icon, Color color, bool selected) {
    switch (icon) {
      case _NavIcon.home:
        return _CustomIcon(
          selected: selected,
          color: color,
          child: Icon(
            selected ? Icons.home_rounded : Icons.home_outlined,
            color: color,
            size: 24,
          ),
        );
      case _NavIcon.league:
        return _CustomIcon(
          selected: selected,
          color: color,
          child: Icon(
            selected ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
            color: color,
            size: 24,
          ),
        );
      case _NavIcon.stats:
        return _CustomIcon(
          selected: selected,
          color: color,
          child: Icon(
            selected
                ? Icons.bar_chart_rounded
                : Icons.bar_chart_outlined,
            color: color,
            size: 24,
          ),
        );
      case _NavIcon.settings:
        return _CustomIcon(
          selected: selected,
          color: color,
          child: Icon(
            selected
                ? Icons.settings_rounded
                : Icons.settings_outlined,
            color: color,
            size: 24,
          ),
        );
    }
  }
}

class _CustomIcon extends StatelessWidget {
  final bool selected;
  final Color color;
  final Widget child;

  const _CustomIcon({
    required this.selected,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 42,
      height: 28,
      decoration: selected
          ? BoxDecoration(
              color: AppColors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Center(child: child),
    );
  }
}
