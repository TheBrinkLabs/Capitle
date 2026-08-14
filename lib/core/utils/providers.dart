import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/settings_repository.dart';

// Initialised in main.dart via ProviderScope overrides
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(sharedPrefsProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPrefsProvider));
});
