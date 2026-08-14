import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/game_models.dart';
import '../../../core/utils/providers.dart';

class StatsNotifier extends Notifier<PlayerStats> {
  @override
  PlayerStats build() {
    final repo = ref.watch(gameRepositoryProvider);
    return repo.loadStats();
  }

  Future<void> recordGame({
    required GameMode mode,
    required bool won,
    required int guessesUsed,
  }) async {
    final repo = ref.read(gameRepositoryProvider);
    final updated = await repo.recordGameComplete(
      mode: mode,
      won: won,
      guessesUsed: guessesUsed,
      currentStats: state,
    );
    state = updated;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPrefsProvider);
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('day_record_') || k == 'player_stats')
        .toList();
    for (final k in keys) await prefs.remove(k);
    state = const PlayerStats();
  }

  /// Repairs a streak broken yesterday (call only after a rewarded ad has
  /// actually been watched to completion) and refreshes the cached streak
  /// numbers so Home/Stats reflect it immediately.
  Future<void> repairStreak(GameMode mode) async {
    final repo = ref.read(gameRepositoryProvider);
    await repo.repairStreakForMode(mode);

    final newCurrent = repo.computeStreakForMode(mode);
    final existingBest = state.streakForMode(mode).best;
    final updated = state.withUpdatedStreak(
      mode,
      ModeStreak(current: newCurrent, best: newCurrent > existingBest ? newCurrent : existingBest),
    );

    await repo.saveStats(updated);
    state = updated;
  }
}

final statsProvider =
    NotifierProvider<StatsNotifier, PlayerStats>(StatsNotifier.new);
