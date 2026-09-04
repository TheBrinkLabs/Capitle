import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/pending_score_repository.dart';

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

final pendingScoreRepositoryProvider = Provider<PendingScoreRepository>((ref) {
  return PendingScoreRepository(ref.watch(sharedPrefsProvider));
});

// Which bottom-nav tab MainScaffold currently has selected (Home=0,
// League=1, Stats=2, Settings=3). Lives here rather than in
// main_scaffold.dart so both MainScaffold and any tab screen that needs
// to react to becoming visible again (e.g. LeagueScreen refreshing data
// IndexedStack would otherwise leave stale — see leagueTabActiveProvider)
// can import it without main_scaffold.dart <-> league_screen.dart forming
// a circular import.
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Whether the League tab is the one currently showing. IndexedStack
/// keeps every tab's widget (and therefore its providers) alive even
/// while switched away from — a plain FutureProvider like
/// leagueRoomMembersProvider never naturally re-fetches just because
/// you've tabbed back to it, so it'd otherwise keep showing whatever it
/// first fetched, possibly stale by minutes, hours, or across app
/// sessions if the process never died. LeagueScreen listens to this to
/// force a refresh each time it regains visibility, rather than relying
/// only on manual pull-to-refresh.
final leagueTabActiveProvider = Provider<bool>((ref) => ref.watch(navIndexProvider) == 1);
