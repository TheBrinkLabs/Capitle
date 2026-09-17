import 'package:shared_preferences/shared_preferences.dart';
import 'ad_service.dart';

/// GDPR/CCPA ad-consent state — shown once (see AdConsentScreen), then
/// re-applied on every subsequent launch without asking again. Also
/// re-openable from Settings (see settings_screen.dart's "Ad Preferences"
/// row) since GDPR requires consent to be withdrawable, not just a
/// one-time question.
class AdConsentService {
  static const _hasSeenKey = 'has_seen_ad_consent';
  static const _grantedKey = 'ad_consent_granted';

  static bool hasSeenAdConsent(SharedPreferences prefs) => prefs.getBool(_hasSeenKey) ?? false;
  static bool isGranted(SharedPreferences prefs) => prefs.getBool(_grantedKey) ?? false;

  /// Persists the user's choice and (re)initializes LevelPlay with it.
  /// Safe to call again later from Settings — AdService.initialize()
  /// no-ops the actual LevelPlay.init() call if already initialized, but
  /// always re-applies the consent flags first.
  static Future<void> recordAndApply(SharedPreferences prefs, bool granted) async {
    await prefs.setBool(_hasSeenKey, true);
    await prefs.setBool(_grantedKey, granted);
    await adService.initialize(consentGranted: granted);
  }

  /// Called on a normal cold start when consent was already decided in a
  /// previous session — just re-applies the stored choice.
  static Future<void> applyStoredConsent(SharedPreferences prefs) async {
    await adService.initialize(consentGranted: isGranted(prefs));
  }
}
