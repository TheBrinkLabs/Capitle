import 'package:flutter/foundation.dart';
import '../../data/models/game_models.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/league_repository.dart';
import 'league_scoring.dart';

// Firestore's score docs key dates as "YYYYMMDD" (see
// LeagueRepository.submitGameScore); GameRepository keys them as
// "YYYY-MM-DD". Both need converting to compare/merge the two.
String _serverDateKeyFromLocal(String localDateKey) => localDateKey.replaceAll('-', '');
String _localDateKeyFromServer(String serverDateKey) =>
    '${serverDateKey.substring(0, 4)}-${serverDateKey.substring(4, 6)}-${serverDateKey.substring(6, 8)}';

DayRecord _applyScoreDoc(DayRecord record, Map<String, dynamic> doc) {
  final mode = GameMode.values.firstWhere((m) => m.name == doc['mode']);
  final won = doc['won'] as bool? ?? false;
  final guessesUsed = doc['guessesUsed'] as int? ?? 0;
  final score = doc['score'] as int? ?? 0;
  return switch (mode) {
    GameMode.guessCountry => record.copyWith(completedGuessCountry: true, wonGuessCountry: won, guessesUsedCountry: guessesUsed, scoreGuessCountry: score),
    GameMode.guessCapital => record.copyWith(completedGuessCapital: true, wonGuessCapital: won, guessesUsedCapital: guessesUsed, scoreGuessCapital: score),
    GameMode.guessFlag => record.copyWith(completedGuessFlag: true, wonGuessFlag: won, guessesUsedFlag: guessesUsed, scoreGuessFlag: score),
    GameMode.guessNeighbours => record.copyWith(completedGuessNeighbours: true, wonGuessNeighbours: won, guessesUsedNeighbours: guessesUsed, scoreGuessNeighbours: score),
    GameMode.guessPopulation => record.copyWith(completedGuessPopulation: true, wonGuessPopulation: won, guessesUsedPopulation: guessesUsed, scoreGuessPopulation: score),
    GameMode.guessOutline => record.copyWith(completedGuessOutline: true, wonGuessOutline: won, guessesUsedOutline: guessesUsed, scoreGuessOutline: score),
  };
}

/// Patches TODAY's local day-record with anything Firestore already has
/// on record for modes not marked completed locally — guards against
/// replaying a mode already played today on a different install. Trusts
/// a doc's mere existence as proof it was genuinely played: the doc id is
/// deterministic (mode + date) and security rules forbid update/delete,
/// so a duplicate submission is rejected by Firestore itself rather than
/// ever landing twice.
///
/// Runs on every launch for any signed-in user (cheap — one week's worth
/// of docs). Returns true if anything changed, so the caller can refresh
/// whatever's reading day-record/stats state.
Future<bool> reconcileTodayFromServer({
  required GameRepository gameRepo,
  required LeagueRepository leagueRepo,
  required String uid,
}) async {
  try {
    final todayKey = gameRepo.todayKey;
    var record = gameRepo.loadDayRecord(todayKey);
    if (GameMode.values.every(record.completedMode)) return false;

    final weekId = leagueRepo.currentWeekId();
    final docs = await leagueRepo.fetchScoresForWeek(uid, weekId);
    final serverToday = _serverDateKeyFromLocal(todayKey);

    final foundModes = <GameMode>[];
    for (final doc in docs) {
      if (doc['dateKey'] != serverToday) continue;
      final mode = GameMode.values.firstWhere((m) => m.name == doc['mode']);
      if (record.completedMode(mode)) continue;
      record = _applyScoreDoc(record, doc);
      foundModes.add(mode);
    }
    if (foundModes.isEmpty) return false;
    await gameRepo.saveDayRecord(record);

    // Keep cached streaks in sync too — computeStreakForMode re-walks the
    // day-records we just patched, so this reflects the correction
    // immediately rather than waiting for the next real game to overwrite
    // the (now stale) cached value.
    var stats = gameRepo.loadStats();
    for (final mode in foundModes) {
      final current = gameRepo.computeStreakForMode(mode);
      final best = stats.streakForMode(mode).best;
      stats = stats.withUpdatedStreak(mode, ModeStreak(current: current, best: current > best ? current : best));
    }
    await gameRepo.saveStats(stats);
    return true;
  } catch (e, st) {
    debugPrint('Today reconciliation failed (non-fatal): $e\n$st');
    return false;
  }
}

/// Rebuilds local day-records/streaks from Firestore score history — the
/// only server-side record of "what did I play, did I win" that exists;
/// everything else (day-records, stats) lives purely in local
/// SharedPreferences and is lost on reinstall. By default only runs when
/// local history looks empty (a fresh install/re-login with nothing
/// played yet), so it never overwrites a device's own real data — but
/// pass [force] true when the caller already knows for certain this uid
/// has real prior history (e.g. right after AuthService.linkGoogle()
/// reports restoredExistingAccount), since in that specific case even a
/// couple of plays on a fresh anonymous session before signing in would
/// otherwise be enough to block the whole walk-back and silently drop
/// the real streak while still patching in "today" — a real bug this
/// [force] path exists to close.
///
/// Walks backward week by week from the current week, stopping at the
/// first fully-empty week (nothing played, for any mode — the same point
/// a normal streak walk would already break at) or after [maxWeeksBack]
/// as a hard cap regardless.
///
/// Known limitation: totalPlayed/totalWon/totalScore/best-streak/guess
/// distributions only reflect what's inside the restored window, not
/// full lifetime history — this fixes the visible symptom (current
/// streak, "already played today"), not a perfect restore of every
/// all-time stat.
Future<bool> restoreHistoryIfNeeded({
  required GameRepository gameRepo,
  required LeagueRepository leagueRepo,
  required String uid,
  int maxWeeksBack = 104,
  bool force = false,
}) async {
  if (!force && gameRepo.loadStats().totalPlayed > 0) return false;

  try {
    final records = <String, DayRecord>{};
    var weekStart = currentWeekStartUtc();

    for (var i = 0; i < maxWeeksBack; i++) {
      final weekId = isoWeekId(weekStart);
      final docs = await leagueRepo.fetchScoresForWeek(uid, weekId);
      if (docs.isEmpty) break;
      for (final doc in docs) {
        final dateKey = _localDateKeyFromServer(doc['dateKey'] as String);
        final existing = records[dateKey] ?? gameRepo.loadDayRecord(dateKey);
        records[dateKey] = _applyScoreDoc(existing, doc);
      }
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    if (records.isEmpty) return false;

    for (final record in records.values) {
      await gameRepo.saveDayRecord(record);
    }

    var stats = gameRepo.loadStats();
    for (final mode in GameMode.values) {
      final current = gameRepo.computeStreakForMode(mode);
      if (current > 0) {
        stats = stats.withUpdatedStreak(mode, ModeStreak(current: current, best: current));
      }
    }

    final totalPlayed = records.values.fold(0, (sum, r) => sum + GameMode.values.where(r.completedMode).length);
    final totalWon = records.values.fold(0, (sum, r) => sum + GameMode.values.where(r.wonMode).length);
    final totalScore = records.values.fold(0, (sum, r) => sum + r.totalScoreFor(GameMode.values));
    stats = PlayerStats(
      totalPlayed: totalPlayed,
      totalWon: totalWon,
      totalScore: totalScore,
      guessDistributionCountry: stats.guessDistributionCountry,
      guessDistributionCapital: stats.guessDistributionCapital,
      guessDistributionFlag: stats.guessDistributionFlag,
      guessDistributionNeighbours: stats.guessDistributionNeighbours,
      guessDistributionPopulation: stats.guessDistributionPopulation,
      guessDistributionOutline: stats.guessDistributionOutline,
      countryStreak: stats.countryStreak,
      capitalStreak: stats.capitalStreak,
      flagStreak: stats.flagStreak,
      neighboursStreak: stats.neighboursStreak,
      populationStreak: stats.populationStreak,
      outlineStreak: stats.outlineStreak,
    );
    await gameRepo.saveStats(stats);
    return true;
  } catch (e, st) {
    debugPrint('History restore failed (non-fatal): $e\n$st');
    return false;
  }
}

/// Pushes the just-restored local streak back to players/{uid}.currentStreak
/// — the field the League screen actually reads (see league_provider.dart).
/// [reconcileTodayFromServer]/[restoreHistoryIfNeeded] only fix *local*
/// state; without this, a restored streak shows correctly on Home but
/// stays stale on League until the player's next real game (the only
/// other place that field gets written — see game_provider.dart's
/// _onGameOver). Call after either restore function reports it changed
/// something.
Future<void> syncRestoredStreakToServer({
  required GameRepository gameRepo,
  required LeagueRepository leagueRepo,
  required String uid,
}) async {
  try {
    final streak = gameRepo.loadStats().currentStreak;
    await leagueRepo.syncStreak(uid: uid, streak: streak);
  } catch (e, st) {
    debugPrint('Streak sync after restore failed (non-fatal): $e\n$st');
  }
}
