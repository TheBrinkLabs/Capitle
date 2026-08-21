import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../../stats/providers/stats_provider.dart';
import '../../../core/widgets/app_effects.dart';
import '../../../core/utils/package_info_provider.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../onboarding/screens/profile_setup_screen.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/utils/providers.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/repositories/league_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.bg : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text('Settings',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -1,
                  )),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [

                  // ── DISPLAY ──────────────────────────────────────
                  _SectionLabel(label: 'Display', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _SegmentedRow(
                      icon: '🌓',
                      iconBg: const Color(0x260099FF),
                      title: 'Theme',
                      options: const ['Light', 'Dark'],
                      selectedIndex: settings.themeMode.index,
                      onSelected: (i) => ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(themeMode: AppThemeMode.values[i])),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _SegmentedRow(
                      icon: '📏',
                      iconBg: const Color(0x260099FF),
                      title: 'Distance Unit',
                      options: const ['Miles', 'km'],
                      selectedIndex: settings.distanceUnit.index,
                      onSelected: (i) => ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(distanceUnit: DistanceUnit.values[i])),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _SegmentedRow(
                      icon: '🔤',
                      iconBg: const Color(0x260099FF),
                      title: 'Font Size',
                      options: const ['Small', 'Medium', 'Large'],
                      selectedIndex: settings.fontSize.index,
                      onSelected: (i) => ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(fontSize: FontSize.values[i])),
                      isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── DAILY STREAKS ─────────────────────────────────
                  _SectionLabel(label: 'Daily Streaks', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _ToggleRow(
                      icon: '🌍',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Guess Country',
                      subtitle: 'Daily capital → country puzzle',
                      value: settings.countryModeActive,
                      onChanged: (v) {
                        // Must keep at least one mode active
                        if (!v && !settings.capitalModeActive && !settings.flagModeActive && !settings.neighboursModeActive && !settings.populationModeActive && !settings.outlineModeActive) return;
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(countryModeActive: v));
                      },
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '🗺️',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Guess Capital',
                      subtitle: 'Daily country → capital puzzle',
                      value: settings.capitalModeActive,
                      onChanged: (v) {
                        if (!v && !settings.countryModeActive && !settings.flagModeActive && !settings.neighboursModeActive && !settings.populationModeActive && !settings.outlineModeActive) return;
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(capitalModeActive: v));
                      },
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '🚩',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Guess Flag',
                      subtitle: 'Daily flag → country puzzle',
                      value: settings.flagModeActive,
                      onChanged: (v) {
                        if (!v && !settings.countryModeActive && !settings.capitalModeActive && !settings.neighboursModeActive && !settings.populationModeActive && !settings.outlineModeActive) return;
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(flagModeActive: v));
                      },
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '🤝',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Neighbours',
                      subtitle: 'Daily land borders count puzzle',
                      value: settings.neighboursModeActive,
                      onChanged: (v) {
                        if (!v && !settings.countryModeActive && !settings.capitalModeActive && !settings.flagModeActive && !settings.populationModeActive && !settings.outlineModeActive) return;
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(neighboursModeActive: v));
                      },
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '📊',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Population',
                      subtitle: 'Daily which capital is bigger?',
                      value: settings.populationModeActive,
                      onChanged: (v) {
                        if (!v && !settings.countryModeActive && !settings.capitalModeActive && !settings.flagModeActive && !settings.neighboursModeActive && !settings.outlineModeActive) return;
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(populationModeActive: v));
                      },
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '🧩',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Outline',
                      subtitle: 'Daily country shape puzzle',
                      value: settings.outlineModeActive,
                      onChanged: (v) {
                        if (!v && !settings.countryModeActive && !settings.capitalModeActive && !settings.flagModeActive && !settings.neighboursModeActive && !settings.populationModeActive) return;
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(outlineModeActive: v));
                      },
                      isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── LEAGUE ────────────────────────────────────────
                  _SectionLabel(label: 'League', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _NavRow(
                      icon: '🏆',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Edit League Profile',
                      value: '',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(mode: ProfileSetupMode.standalone),
                        ),
                      ),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _NavRow(
                      icon: '🔗',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Back up your progress',
                      value: 'Sign in with Google',
                      onTap: () async {
                        try {
                          await authService.linkGoogle();
                          final uid = authService.uid;
                          if (uid != null) {
                            await ref.read(leagueRepositoryProvider).markLinkedGoogle(uid);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Your progress is now backed up.')),
                            );
                          }
                        } catch (e, st) {
                          debugPrint('Google sign-in link failed: $e\n$st');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Couldn't sign in — try again in a bit.")),
                            );
                          }
                        }
                      },
                      isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── GAMEPLAY ──────────────────────────────────────
                  _SectionLabel(label: 'Gameplay', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _ToggleRow(
                      icon: '🌐',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Show Continent Hint',
                      subtitle: 'Displays region below the clue',
                      value: settings.showContinentHint,
                      onChanged: (v) => ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(showContinentHint: v)),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '💀',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Hard Mode',
                      subtitle: 'No distance hints on wrong guesses',
                      value: settings.hardMode,
                      onChanged: (v) => ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(hardMode: v)),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _ToggleRow(
                      icon: '🌍',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Location Reveal',
                      subtitle: 'Fly-to-country map after a correct answer',
                      value: settings.locationRevealEnabled,
                      onChanged: (v) => ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(locationRevealEnabled: v)),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _NavRow(
                      icon: '🗺️',
                      iconBg: const Color(0x1400D4AA),
                      title: 'Country Name Style',
                      value: settings.countryNameStyle == CountryNameStyle.common
                          ? 'Common'
                          : 'Official',
                      onTap: () => _showCountryStylePicker(context, ref, settings, isDark),
                      isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── NOTIFICATIONS ─────────────────────────────────
                  _SectionLabel(label: 'Notifications', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _ToggleRow(
                      icon: '🔥',
                      iconBg: const Color(0x26FFC845),
                      title: 'Streak Saver Alert',
                      subtitle: _formatTime(settings.streakSaverTime),
                      value: settings.streakSaverAlert,
                      onChanged: (v) async {
                        final updated = settings.copyWith(streakSaverAlert: v);
                        ref.read(settingsProvider.notifier)
                            .updateField((s) => s.copyWith(streakSaverAlert: v));
                        await _rescheduleStreakSaver(ref, overrideSettings: updated);
                      },
                      isDark: isDark,
                      onSubtitleTap: settings.streakSaverAlert
                          ? () => _pickStreakSaverTime(context, ref, settings)
                          : null,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── HELP ──────────────────────────────────────────
                  _SectionLabel(label: 'Help', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _NavRow(
                      icon: '👋',
                      iconBg: const Color(0x1400D4AA),
                      title: 'How to Play',
                      value: '',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(isFirstLaunch: false),
                        ),
                      ),
                      isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── DATA ──────────────────────────────────────────
                  _SectionLabel(label: 'Data', isDark: isDark),
                  _SettingsGroup(isDark: isDark, children: [
                    _NavRow(
                      icon: '↗',
                      iconBg: const Color(0x26FF5566),
                      title: 'Share Format',
                      value: settings.shareFormat == ShareFormat.emojiGrid
                          ? 'Emoji grid'
                          : 'Text summary',
                      onTap: () => _showShareFormatPicker(context, ref, settings, isDark),
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                    _DangerRow(
                      icon: '🗑️',
                      title: 'Reset Statistics',
                      subtitle: 'Clears all history and streaks',
                      onTap: () => _confirmReset(context, ref, isDark),
                      isDark: isDark,
                    ),
                  ]),

                  const SizedBox(height: 32),

                  Center(
                    child: Column(
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final packageInfo = ref.watch(packageInfoProvider);
                            return Text(
                              packageInfo.when(
                                data: (info) => 'Capitle v${info.version}+${info.buildNumber}',
                                loading: () => 'Capitle',
                                error: (_, __) => 'Capitle',
                              ),
                              style: TextStyle(fontSize: 12, color: textMuted),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text('Made with ♥ for geography nerds',
                            style: TextStyle(
                              fontSize: 11,
                              color: (isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight)
                                  .withOpacity(0.5),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return 'Alert at $h:$m $period — tap to change';
  }

  /// Re-arms the actual scheduled notification to match current settings.
  /// Must be called any time the alert toggle or time changes — updating
  /// settings alone does NOT touch the underlying OS-level alarm.
  ///
  /// [overrideSettings], if given, is used directly instead of re-reading
  /// the provider — avoids a race where the provider hasn't finished
  /// applying an update yet when this runs immediately afterward.
  Future<void> _rescheduleStreakSaver(WidgetRef ref, {AppSettings? overrideSettings}) async {
    try {
      final AppSettings settings;
      if (overrideSettings != null) {
        settings = overrideSettings;
      } else {
        settings = ref.read(settingsProvider);
      }
      final repo = ref.read(gameRepositoryProvider);
      final dayRecord = repo.loadDayRecord(repo.todayKey);
      final completedToday = dayRecord.anyComplete(settings.activeModes);
      await notificationService.scheduleFromSettings(settings, completedToday: completedToday);
    } catch (_) {
      // Best-effort reschedule — if it fails, the next app launch or
      // puzzle completion will re-arm it correctly anyway.
    }
  }

  Future<void> _pickStreakSaverTime(
      BuildContext context, WidgetRef ref, AppSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.streakSaverTime,
    );
    if (picked != null) {
      final updated = settings.copyWith(streakSaverTime: picked);
      ref.read(settingsProvider.notifier)
          .updateField((s) => s.copyWith(streakSaverTime: picked));
      // Pass `updated` directly rather than letting the reschedule re-read
      // the provider — guarantees the just-picked time is what's actually
      // used, regardless of whether the provider update has propagated yet.
      await _rescheduleStreakSaver(ref, overrideSettings: updated);
    }
  }

  void _showCountryStylePicker(
      BuildContext context, WidgetRef ref, AppSettings settings, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Country Name Style',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDark : AppColors.textLight)),
            const SizedBox(height: 16),
            for (final style in CountryNameStyle.values)
              ListTile(
                title: Text(style == CountryNameStyle.common ? 'Common (e.g. Iran)' : 'Official (e.g. Islamic Republic of Iran)'),
                leading: Radio<CountryNameStyle>(
                  value: style,
                  groupValue: settings.countryNameStyle,
                  activeColor: AppColors.teal,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(countryNameStyle: v));
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showShareFormatPicker(
      BuildContext context, WidgetRef ref, AppSettings settings, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share Format',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDark : AppColors.textLight)),
            const SizedBox(height: 16),
            for (final fmt in ShareFormat.values)
              ListTile(
                title: Text(fmt == ShareFormat.emojiGrid ? 'Emoji grid 🟩🟥' : 'Text summary'),
                leading: Radio<ShareFormat>(
                  value: fmt,
                  groupValue: settings.shareFormat,
                  activeColor: AppColors.teal,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(settingsProvider.notifier)
                          .updateField((s) => s.copyWith(shareFormat: v));
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Statistics?',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        content: const Text('This will clear all your streaks, history and guess data. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMutedDark)),
          ),
          TextButton(
            onPressed: () {
              ref.read(statsProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            )),
      );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _SettingsGroup({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) => MatteCard(
        isDark: isDark,
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
      );
}

class _RowBase extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool isDark;
  final VoidCallback? onSubtitleTap;

  const _RowBase({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.isDark,
    this.onSubtitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSubtitleTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: onSubtitleTap != null ? AppColors.teal : textMuted,
                            fontWeight: onSubtitleTap != null ? FontWeight.w500 : FontWeight.w400,
                          )),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final VoidCallback? onSubtitleTap;

  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
    this.onSubtitleTap,
  });

  @override
  Widget build(BuildContext context) => _RowBase(
        icon: icon,
        iconBg: iconBg,
        title: title,
        subtitle: subtitle,
        isDark: isDark,
        onSubtitleTap: onSubtitleTap,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: AppColors.teal,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.withOpacity(0.3),
        ),
      );
}

class _SegmentedRow extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;

  const _SegmentedRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => _RowBase(
        icon: icon,
        iconBg: iconBg,
        title: title,
        subtitle: subtitle,
        isDark: isDark,
        trailing: _SegControl(
          options: options,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          isDark: isDark,
        ),
      );
}

class _SegControl extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;

  const _SegControl({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2 : AppColors.surface2Light,
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(options.length, (i) {
            final sel = i == selectedIndex;
            return GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(options[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.black
                          : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    )),
              ),
            );
          }),
        ),
      );
}

class _NavRow extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool isDark;

  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return GestureDetector(
      onTap: onTap,
      child: _RowBase(
        icon: icon,
        iconBg: iconBg,
        title: title,
        isDark: isDark,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _DangerRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reset Statistics',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.red)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 11, color: textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}
