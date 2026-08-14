# Capitle 🌍

**Daily capital city guessing game for Flutter (Android-first)**

Two puzzles per day:
- 🌍 **Guess Country** — Given a capital city, guess the country
- 🗺️ **Guess Capital** — Given a country, guess the capital

5 guesses each. Wrong guesses show distance in miles/km. Daily streak — one puzzle per day keeps it alive.

---

## Getting Started

### 1. Prerequisites

- Flutter SDK 3.x
- Android Studio / VS Code
- A connected device or emulator (Pixel 8 Pro recommended for testing)

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run on device

```bash
flutter run
```

---

## Project Structure

```
lib/
├── main.dart                        # Entry point
├── main_scaffold.dart               # Bottom nav + IndexedStack
├── core/
│   ├── theme/
│   │   └── app_theme.dart           # Colors, typography, light/dark themes
│   └── utils/
│       ├── providers.dart           # Core Riverpod providers
│       ├── notification_service.dart
│       └── ad_service.dart
├── data/
│   ├── models/
│   │   ├── capital_entry.dart       # CapitalEntry + 140+ world capitals
│   │   ├── game_models.dart         # GameState, GuessResult, DailyPuzzle, etc.
│   │   └── app_settings.dart        # AppSettings model
│   └── repositories/
│       ├── game_repository.dart     # Daily seed, haversine, persistence, stats
│       └── settings_repository.dart
└── features/
    ├── home/
    │   ├── screens/
    │   │   ├── home_screen.dart     # Two puzzle cards, streak, stats
    │   │   └── splash_screen.dart   # Animated logo splash
    │   └── widgets/
    │       ├── app_logo.dart        # AppLogoMark + AppWordmark
    │       └── buttons.dart         # GradientButton, SecondaryButton
    ├── game/
    │   ├── providers/
    │   │   └── game_provider.dart   # GameNotifier (one per mode)
    │   └── screens/
    │       ├── game_screen.dart     # Gameplay UI
    │       └── result_screen.dart   # Win/lose state
    ├── stats/
    │   ├── providers/
    │   │   └── stats_provider.dart
    │   └── screens/
    │       └── stats_screen.dart    # Streak, distribution charts
    └── settings/
        ├── providers/
        │   └── settings_provider.dart
        └── screens/
            └── settings_screen.dart # All toggles + bottom sheets
```

---

## Before Release

### AdMob
1. Create an AdMob account at admob.google.com
2. Create an Android app and get your **App ID**
3. Replace in `AndroidManifest.xml`:
   ```xml
   <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
              android:value="YOUR_REAL_APP_ID"/>
   ```
4. Create an Interstitial ad unit and replace test ID in `ad_service.dart`

### App Icon
1. Create a 1024×1024 PNG of the teal "C" logo mark
2. Save to `assets/icons/app_icon.png`
3. Create a foreground version (for adaptive icon) at `assets/icons/app_icon_foreground.png`
4. Uncomment `flutter_launcher_icons` in `pubspec.yaml`
5. Run: `flutter pub run flutter_launcher_icons`

### Fonts
Download Syne font files from Google Fonts and place in `assets/fonts/`:
- `Syne-Regular.ttf`
- `Syne-SemiBold.ttf`
- `Syne-Bold.ttf`
- `Syne-ExtraBold.ttf`

### Notifications (Android 13+)
The `POST_NOTIFICATIONS` permission requires a runtime request on Android 13+.
Add a permission request on first launch using `permission_handler` package.

---

## Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| State management | Riverpod | Clean, testable, scales well |
| Persistence | shared_preferences | No backend needed, fast, local |
| Daily seed | Date-based index | Same puzzle for all users worldwide |
| Streak rule | Option 3 — one of two daily | Forgiving for casual players |
| Distance unit | Miles default, km in settings | Configurable per user |
| Ad placement | Interstitial on loss only | Never interrupt a win |
| Fonts | Syne (display) + DM Sans (body) | Modern, distinctive, free |

---

## Streak Logic

Streak increments if **at least one** of the two daily puzzles is completed (Option 3).
Both complete = streak **✦ bonus badge** on home screen.

```dart
bool get streakCounts => completedGuessCountry || completedGuessCapital;
```

---

## Distance Calculation

Haversine formula using Earth radius of 3,958.8 miles:

```dart
int distanceMiles(double lat1, double lng1, double lat2, double lng2)
```

In hard mode, distance hints are suppressed entirely.

---

## Roadmap

- [ ] iOS build + App Store submission
- [ ] Light mode polish pass
- [ ] Leaderboard / social features
- [ ] More capitals (currently 140+)
- [ ] Difficulty tiers
- [ ] Widget for lock screen streak display
