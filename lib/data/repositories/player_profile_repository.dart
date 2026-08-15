import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';

class PlayerProfileRepository {
  static const _prefKey = 'player_profile';

  final SharedPreferences _prefs;
  PlayerProfileRepository(this._prefs);

  PlayerProfile? load() {
    final raw = _prefs.getString(_prefKey);
    if (raw == null) return null;
    try {
      return PlayerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PlayerProfile profile) async {
    await _prefs.setString(_prefKey, jsonEncode(profile.toJson()));
  }
}
