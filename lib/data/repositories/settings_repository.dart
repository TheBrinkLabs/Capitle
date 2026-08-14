import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  static const _prefKey = 'app_settings';

  final SharedPreferences _prefs;
  SettingsRepository(this._prefs);

  AppSettings load() {
    final raw = _prefs.getString(_prefKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_prefKey, jsonEncode(settings.toJson()));
  }

  Future<void> reset() async {
    await _prefs.remove(_prefKey);
  }
}
