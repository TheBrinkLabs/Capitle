import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/providers.dart';
import 'core/utils/notification_service.dart';
import 'core/utils/ad_service.dart';
import 'core/utils/update_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/home/screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Only SharedPreferences is awaited here — it's fast, local, and the
  // ProviderScope override genuinely needs it before the app can build
  // at all. Everything below this used to ALSO be awaited before
  // runApp(), which meant nothing rendered until both notification init
  // (can trigger a permission dialog) and ad SDK init (real network
  // calls — SDK config fetch, mediation adapter setup) had fully
  // finished. That's almost certainly the startup slowdown — moved both
  // to fire-and-forget below so the UI appears immediately and they
  // initialize in the background instead.
  final prefs = await SharedPreferences.getInstance();

  GoogleFonts.dmSans();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const CapitleApp(),
    ),
  );

  // Fire-and-forget — the app is already up and interactive by the time
  // these run. Each is independently wrapped in its own error handling
  // internally, so a slow/failed init here never affects the rest of
  // the app; worst case, ads or the streak-saver reminder take a moment
  // longer to become ready on a cold start, which is an acceptable
  // trade for a genuinely fast-loading app.
  notificationService.init();
  adService.initialize();
  updateService.checkForFlexibleUpdate();
}

class CapitleApp extends ConsumerStatefulWidget {
  const CapitleApp({super.key});

  @override
  ConsumerState<CapitleApp> createState() => _CapitleAppState();
}

class _CapitleAppState extends ConsumerState<CapitleApp> {
  static const _onboardingKey = 'has_seen_onboarding';

  bool _showSplash = true;

  bool get _hasSeenOnboarding =>
      ref.read(sharedPrefsProvider).getBool(_onboardingKey) ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rescheduleNotifications();
    });
  }

  // Recomputes whether today's active puzzles are already finished, and
  // reschedules the streak-saver alert accordingly. Called on app launch;
  // also call this from wherever a puzzle is completed so the alert
  // updates immediately if that was the last one for the day.
  //
  // Note: notificationService.init() is now fire-and-forget from main()
  // and may not have finished by the time this first runs on a cold
  // start. scheduleFromSettings() is already wrapped in error handling
  // internally, so a race here just means this one attempt may silently
  // no-op rather than crash — it self-corrects the next time this is
  // called (next app open, or any puzzle completion/settings change).
  void _rescheduleNotifications() {
    final settings = ref.read(settingsProvider);
    final repo = ref.read(gameRepositoryProvider);
    final dayRecord = repo.loadDayRecord(repo.todayKey);
    final completedToday = dayRecord.anyComplete(settings.activeModes);
    notificationService.scheduleFromSettings(settings, completedToday: completedToday);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Capitle',
      debugShowCheckedModeBanner: false,
      themeMode: settings.flutterThemeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Apply font scale globally via MediaQuery
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: child!,
        );
      },
      home: _showSplash
          ? SplashScreen(
              onComplete: () {
                if (mounted) setState(() => _showSplash = false);
              },
            )
          : (_hasSeenOnboarding
              ? const MainScaffold()
              : OnboardingScreen(
                  onSeen: () async {
                    await ref.read(sharedPrefsProvider).setBool(_onboardingKey, true);
                  },
                )),
    );
  }
}
