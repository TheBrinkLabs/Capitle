import 'dart:ui';

/// Best-effort guess at the player's country from the device locale — no
/// permission required (deliberately not using GPS/geolocator for this).
/// Just a starting point; the player can always change it in profile setup
/// or Settings.
String? guessCountryCodeFromLocale() {
  final region = PlatformDispatcher.instance.locale.countryCode;
  if (region == null || region.isEmpty) return null;
  return region.toUpperCase();
}
