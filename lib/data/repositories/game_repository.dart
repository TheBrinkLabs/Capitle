import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/capital_entry.dart';
import '../models/app_settings.dart';
import '../models/game_models.dart';
import '../models/outline_assets.dart';

class GameRepository {
  static const _prefDayRecord = 'day_record_';
  static const _prefStats = 'player_stats';
  static const _prefPracticeBest = 'practice_best_';
  static const _epoch = '2025-01-01';

  final SharedPreferences _prefs;
  GameRepository(this._prefs);

  // Countries eligible for Outline mode (excludes micro-states with no
  // distinguishable silhouette in the source map data)
  static final List<CapitalEntry> _outlineEligible =
      kCapitals.where((e) => kOutlineAssetPath.containsKey(e.country)).toList();

  // ── Daily Seed ─────────────────────────────────────────────────────────

  String get todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get yesterdayKey {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-'
        '${y.month.toString().padLeft(2, '0')}-'
        '${y.day.toString().padLeft(2, '0')}';
  }

  String _keyDaysAgo(int days) {
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // ── Streak Repair (rewarded ad) ──────────────────────────────────────
  //
  // Only offers repair for TODAY, covering a break that happened
  // YESTERDAY — i.e. a genuine "here's a one-day grace window before
  // it's gone for good" mechanic. A mode qualifies if it had an active
  // streak running into yesterday (the day before yesterday was won OR
  // itself already frozen — so this chains across consecutive broken
  // days as long as you keep repairing each one) but yesterday itself
  // wasn't won (whether it was skipped entirely OR played and lost —
  // both break the chain the same way) and isn't already frozen.
  //
  // Repair FREEZES yesterday rather than marking it as played — a frozen
  // day preserves the chain without counting as an extra day, so
  // repairing a 5-day streak shows 5 immediately (not 6), and playing
  // today then takes it to 6, matching how Duolingo's Streak Freeze
  // works.

  /// Active modes whose streak broke yesterday and are still repairable
  /// today. Empty list means nothing to offer.
  List<GameMode> modesWithRepairableStreak(List<GameMode> activeModes) {
    final yesterday = loadDayRecord(yesterdayKey);
    final dayBefore = loadDayRecord(_keyDaysAgo(2));

    return activeModes.where((mode) {
      final hadStreakGoingIn = dayBefore.continuesChain(mode);
      final yesterdayBrokeIt = !yesterday.wonMode(mode) && !yesterday.isFrozenMode(mode);
      return hadStreakGoingIn && yesterdayBrokeIt;
    }).toList();
  }

  /// Freezes yesterday for [mode], repairing the streak without counting
  /// yesterday as an extra played day. Call this only after a rewarded ad
  /// has actually been watched to completion.
  Future<void> repairStreakForMode(GameMode mode) async {
    final record = loadDayRecord(yesterdayKey).withFrozenMode(mode);
    await saveDayRecord(record);
  }

  int _dayIndex(String dateKey) {
    final parts = dateKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final epochParts = _epoch.split('-');
    final epoch = DateTime(int.parse(epochParts[0]), int.parse(epochParts[1]), int.parse(epochParts[2]));
    return date.difference(epoch).inDays;
  }

  int _hashDay(int dayIndex, int salt) {
    int h = dayIndex + salt;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = (h >> 16) ^ h;
    return h.abs();
  }

  DailyPuzzle getPuzzle(GameMode mode, {String? dateKey}) {
    final key = dateKey ?? todayKey;
    final idx = _dayIndex(key);
    final salt = switch (mode) {
      GameMode.guessCountry => 1337,
      GameMode.guessCapital => 7331,
      GameMode.guessFlag => 9173,
      GameMode.guessNeighbours => 4219,
      GameMode.guessPopulation => 6547,
      GameMode.guessOutline => 2861,
    };

    if (mode == GameMode.guessOutline) {
      final entryIndex = _hashDay(idx, salt) % _outlineEligible.length;
      final entry = _outlineEligible[entryIndex];
      return DailyPuzzle(entry: entry, mode: mode, dateKey: key);
    }

    final entryIndex = _hashDay(idx, salt) % kCapitals.length;
    final entry = kCapitals[entryIndex];

    if (mode == GameMode.guessPopulation) {
      final salt2 = salt + 1111;
      int idx2 = _hashDay(idx, salt2) % kCapitals.length;
      if (idx2 == entryIndex) idx2 = (idx2 + 1) % kCapitals.length;
      final entryB = kCapitals[idx2];
      return DailyPuzzle(
        entry: entry, mode: mode, dateKey: key,
        populationPuzzle: PopulationPuzzle(entryA: entry, entryB: entryB, dateKey: key),
      );
    }

    return DailyPuzzle(entry: entry, mode: mode, dateKey: key);
  }

  // ── Haversine Distance ─────────────────────────────────────────────────

  int distanceMiles(double lat1, double lng1, double lat2, double lng2) {
    const r = 3958.8;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (r * c).round();
  }

  double _toRad(double deg) => deg * pi / 180;

  // ── Autocomplete ───────────────────────────────────────────────────────

  List<String> getSuggestions(String query, GameMode mode,
      {CountryNameStyle nameStyle = CountryNameStyle.common, String? clueLetter}) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final useOfficial = nameStyle == CountryNameStyle.official;

    if (mode == GameMode.guessNeighbours || mode == GameMode.guessPopulation) return [];

    List<String> candidates;
    if (mode == GameMode.guessCountry || mode == GameMode.guessFlag || mode == GameMode.guessOutline) {
      candidates = kCapitals.map((e) => applyNameStyle(e.country, useOfficial)).toSet().toList();
    } else {
      final capitals = kCapitals.map((e) => e.capital).toList();
      final decoys = kCapitals.expand((e) => e.decoyCities.map((d) => d.name)).toList();
      candidates = {...capitals, ...decoys}.toList();
    }
    candidates.sort();
    var results = candidates.where((c) => c.toLowerCase().contains(lower));
    if (clueLetter != null && clueLetter.isNotEmpty) {
      final letter = clueLetter.toLowerCase();
      results = results.where((c) => c.toLowerCase().startsWith(letter));
    }
    return results.toList();
  }

  CapitalEntry? findEntry(String answer, GameMode mode,
      {CountryNameStyle nameStyle = CountryNameStyle.common}) {
    final lower = answer.toLowerCase().trim();
    final useOfficial = nameStyle == CountryNameStyle.official;

    if (mode == GameMode.guessCountry || mode == GameMode.guessFlag || mode == GameMode.guessOutline) {
      try {
        return kCapitals.firstWhere((e) => e.country.toLowerCase() == lower);
      } catch (_) {
        try {
          return kCapitals.firstWhere(
              (e) => applyNameStyle(e.country, useOfficial).toLowerCase() == lower);
        } catch (_) { return null; }
      }
    } else if (mode == GameMode.guessCapital) {
      try {
        return kCapitals.firstWhere((e) => e.capital.toLowerCase() == lower);
      } catch (_) {
        for (final entry in kCapitals) {
          for (final decoy in entry.decoyCities) {
            if (decoy.name.toLowerCase() == lower) {
              return CapitalEntry(
                capital: decoy.name, country: entry.country,
                continent: entry.continent, flagEmoji: entry.flagEmoji,
                lat: decoy.lat, lng: decoy.lng,
              );
            }
          }
        }
        return null;
      }
    }
    return null;
  }

  GuessResult buildGuessResult({
    required String input,
    required DailyPuzzle puzzle,
    required bool hardMode,
    CountryNameStyle nameStyle = CountryNameStyle.common,
  }) {
    final isCorrect =
        input.toLowerCase().trim() == puzzle.correctAnswer.toLowerCase().trim();
    if (isCorrect) return GuessResult(input: input, isCorrect: true);

    if (!puzzle.mode.showsDistanceHint) {
      return GuessResult(input: input, isCorrect: false);
    }

    final guessedEntry = findEntry(input, puzzle.mode, nameStyle: nameStyle);
    int? miles;
    if (!hardMode && guessedEntry != null) {
      miles = distanceMiles(
        guessedEntry.lat, guessedEntry.lng,
        puzzle.entry.lat, puzzle.entry.lng,
      );
    }

    return GuessResult(
      input: input, isCorrect: false,
      distanceMiles: miles,
      distanceKm: miles != null ? (miles * 1.60934).round() : null,
      matchedEntry: guessedEntry,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────

  DayRecord loadDayRecord(String dateKey) {
    final raw = _prefs.getString('$_prefDayRecord$dateKey');
    if (raw == null) return DayRecord(dateKey: dateKey);
    try {
      return DayRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) { return DayRecord(dateKey: dateKey); }
  }

  Future<void> saveDayRecord(DayRecord record) async {
    await _prefs.setString('$_prefDayRecord${record.dateKey}', jsonEncode(record.toJson()));
  }

  // ── Stats ──────────────────────────────────────────────────────────────

  PlayerStats loadStats() {
    final raw = _prefs.getString(_prefStats);
    if (raw == null) return const PlayerStats();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PlayerStats(
        totalPlayed: json['totalPlayed'] as int? ?? 0,
        totalWon: json['totalWon'] as int? ?? 0,
        guessDistributionCountry: _parseIntMap(json['guessDistCountry']),
        guessDistributionCapital: _parseIntMap(json['guessDistCapital']),
        guessDistributionFlag: _parseIntMap(json['guessDistFlag']),
        guessDistributionNeighbours: _parseIntMap(json['guessDistNeighbours']),
        guessDistributionPopulation: _parseIntMap(json['guessDistPopulation']),
        guessDistributionOutline: _parseIntMap(json['guessDistOutline']),
        countryStreak: json['countryStreak'] != null
            ? ModeStreak.fromJson(json['countryStreak'] as Map<String, dynamic>)
            : _legacyStreak(json),
        capitalStreak: json['capitalStreak'] != null
            ? ModeStreak.fromJson(json['capitalStreak'] as Map<String, dynamic>) : const ModeStreak(),
        flagStreak: json['flagStreak'] != null
            ? ModeStreak.fromJson(json['flagStreak'] as Map<String, dynamic>) : const ModeStreak(),
        neighboursStreak: json['neighboursStreak'] != null
            ? ModeStreak.fromJson(json['neighboursStreak'] as Map<String, dynamic>) : const ModeStreak(),
        populationStreak: json['populationStreak'] != null
            ? ModeStreak.fromJson(json['populationStreak'] as Map<String, dynamic>) : const ModeStreak(),
        outlineStreak: json['outlineStreak'] != null
            ? ModeStreak.fromJson(json['outlineStreak'] as Map<String, dynamic>) : const ModeStreak(),
      );
    } catch (_) { return const PlayerStats(); }
  }

  ModeStreak _legacyStreak(Map<String, dynamic> json) => ModeStreak(
        current: json['currentStreak'] as int? ?? 0,
        best: json['bestStreak'] as int? ?? 0,
      );

  Future<void> saveStats(PlayerStats stats) async {
    await _prefs.setString(_prefStats, jsonEncode({
      'totalPlayed': stats.totalPlayed,
      'totalWon': stats.totalWon,
      'guessDistCountry': stats.guessDistributionCountry.map((k, v) => MapEntry(k.toString(), v)),
      'guessDistCapital': stats.guessDistributionCapital.map((k, v) => MapEntry(k.toString(), v)),
      'guessDistFlag': stats.guessDistributionFlag.map((k, v) => MapEntry(k.toString(), v)),
      'guessDistNeighbours': stats.guessDistributionNeighbours.map((k, v) => MapEntry(k.toString(), v)),
      'guessDistPopulation': stats.guessDistributionPopulation.map((k, v) => MapEntry(k.toString(), v)),
      'guessDistOutline': stats.guessDistributionOutline.map((k, v) => MapEntry(k.toString(), v)),
      'countryStreak': stats.countryStreak.toJson(),
      'capitalStreak': stats.capitalStreak.toJson(),
      'flagStreak': stats.flagStreak.toJson(),
      'neighboursStreak': stats.neighboursStreak.toJson(),
      'populationStreak': stats.populationStreak.toJson(),
      'outlineStreak': stats.outlineStreak.toJson(),
    }));
  }

  // Computes the current streak by walking backward day by day.
  //
  // Three important behaviours beyond a naive walk:
  // 1. If TODAY hasn't been PLAYED yet (win or lose — just attempted),
  //    start the walk from YESTERDAY instead — a streak shouldn't drop
  //    to 0 just because you haven't opened the app yet today; it should
  //    still reflect "alive through yesterday, go play today to extend
  //    it." But once today HAS been played, it's judged immediately —
  //    see point 2.
  // 2. A day only extends the streak if it was WON. A played-but-lost
  //    day breaks the chain exactly like an unplayed day does — so if
  //    today was already played and lost, the walk starts at today (per
  //    point 1) and immediately breaks there, dropping the streak to 0
  //    right away rather than waiting for tomorrow.
  // 3. A FROZEN day (via streak-repair ad) doesn't break the chain, but
  //    also doesn't increment the count — it's a pass-through, not an
  //    extra played day. This is what makes "repair a 5-day streak" show
  //    5, not 6, until you actually play again.
  int computeStreakForMode(GameMode mode) {
    int streak = 0;
    DateTime cursor = DateTime.now();

    final todayRecord = loadDayRecord(todayKey);
    if (!todayRecord.completedMode(mode)) {
      cursor = cursor.subtract(const Duration(days: 1)); // start from yesterday
    }

    while (true) {
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      final record = loadDayRecord(key);
      if (record.wonMode(mode)) {
        streak++;
      } else if (record.isFrozenMode(mode)) {
        // Pass through — preserves the chain, doesn't count.
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<PlayerStats> recordGameComplete({
    required GameMode mode,
    required bool won,
    required int guessesUsed,
    required PlayerStats currentStats,
  }) async {
    final key = todayKey;
    var record = loadDayRecord(key);

    record = switch (mode) {
      GameMode.guessCountry => record.copyWith(completedGuessCountry: true, wonGuessCountry: won, guessesUsedCountry: guessesUsed),
      GameMode.guessCapital => record.copyWith(completedGuessCapital: true, wonGuessCapital: won, guessesUsedCapital: guessesUsed),
      GameMode.guessFlag => record.copyWith(completedGuessFlag: true, wonGuessFlag: won, guessesUsedFlag: guessesUsed),
      GameMode.guessNeighbours => record.copyWith(completedGuessNeighbours: true, wonGuessNeighbours: won, guessesUsedNeighbours: guessesUsed),
      GameMode.guessPopulation => record.copyWith(completedGuessPopulation: true, wonGuessPopulation: won, guessesUsedPopulation: guessesUsed),
      GameMode.guessOutline => record.copyWith(completedGuessOutline: true, wonGuessOutline: won, guessesUsedOutline: guessesUsed),
    };
    await saveDayRecord(record);

    final distCountry = Map<int, int>.from(currentStats.guessDistributionCountry);
    final distCapital = Map<int, int>.from(currentStats.guessDistributionCapital);
    final distFlag = Map<int, int>.from(currentStats.guessDistributionFlag);
    final distNeighbours = Map<int, int>.from(currentStats.guessDistributionNeighbours);
    final distPopulation = Map<int, int>.from(currentStats.guessDistributionPopulation);
    final distOutline = Map<int, int>.from(currentStats.guessDistributionOutline);

    if (won) {
      switch (mode) {
        case GameMode.guessCountry: distCountry[guessesUsed] = (distCountry[guessesUsed] ?? 0) + 1;
        case GameMode.guessCapital: distCapital[guessesUsed] = (distCapital[guessesUsed] ?? 0) + 1;
        case GameMode.guessFlag: distFlag[guessesUsed] = (distFlag[guessesUsed] ?? 0) + 1;
        case GameMode.guessNeighbours: distNeighbours[guessesUsed] = (distNeighbours[guessesUsed] ?? 0) + 1;
        case GameMode.guessPopulation: distPopulation[guessesUsed] = (distPopulation[guessesUsed] ?? 0) + 1;
        case GameMode.guessOutline: distOutline[guessesUsed] = (distOutline[guessesUsed] ?? 0) + 1;
      }
    }

    final newModeStreak = computeStreakForMode(mode);
    ModeStreak updatedCountry = currentStats.countryStreak;
    ModeStreak updatedCapital = currentStats.capitalStreak;
    ModeStreak updatedFlag = currentStats.flagStreak;
    ModeStreak updatedNeighbours = currentStats.neighboursStreak;
    ModeStreak updatedPopulation = currentStats.populationStreak;
    ModeStreak updatedOutline = currentStats.outlineStreak;

    switch (mode) {
      case GameMode.guessCountry: updatedCountry = ModeStreak(current: newModeStreak, best: max(newModeStreak, currentStats.countryStreak.best));
      case GameMode.guessCapital: updatedCapital = ModeStreak(current: newModeStreak, best: max(newModeStreak, currentStats.capitalStreak.best));
      case GameMode.guessFlag: updatedFlag = ModeStreak(current: newModeStreak, best: max(newModeStreak, currentStats.flagStreak.best));
      case GameMode.guessNeighbours: updatedNeighbours = ModeStreak(current: newModeStreak, best: max(newModeStreak, currentStats.neighboursStreak.best));
      case GameMode.guessPopulation: updatedPopulation = ModeStreak(current: newModeStreak, best: max(newModeStreak, currentStats.populationStreak.best));
      case GameMode.guessOutline: updatedOutline = ModeStreak(current: newModeStreak, best: max(newModeStreak, currentStats.outlineStreak.best));
    }

    final updated = PlayerStats(
      totalPlayed: currentStats.totalPlayed + 1,
      totalWon: currentStats.totalWon + (won ? 1 : 0),
      guessDistributionCountry: distCountry,
      guessDistributionCapital: distCapital,
      guessDistributionFlag: distFlag,
      guessDistributionNeighbours: distNeighbours,
      guessDistributionPopulation: distPopulation,
      guessDistributionOutline: distOutline,
      countryStreak: updatedCountry,
      capitalStreak: updatedCapital,
      flagStreak: updatedFlag,
      neighboursStreak: updatedNeighbours,
      populationStreak: updatedPopulation,
      outlineStreak: updatedOutline,
    );
    await saveStats(updated);
    return updated;
  }

  String buildShareText({
    required DailyPuzzle puzzle,
    required List<GuessResult> guesses,
    required bool won,
  }) {
    final header = 'Capitle ${puzzle.dateKey}';
    final score = won
        ? '${guesses.where((g) => !g.isClue).length}/${GameState.maxGuesses}'
        : 'X/${GameState.maxGuesses}';
    final grid = guesses.where((g) => !g.isClue).map((g) => g.isCorrect ? '🟩' : '🟥').join('');
    return '$header ${puzzle.mode.emoji} $score\n$grid\n\nhttps://play.google.com/store/apps/details?id=com.brinklabs.capitle';
  }

  // ── Practice Session Records ──────────────────────────────────────────
  //
  // Best score for a given mode+region practice session (e.g. "Guess
  // Country, Africa" -> 42/54). Region is null for "All".

  String _practiceBestKey(GameMode mode, String? region) =>
      '$_prefPracticeBest${mode.streakKey}_${(region ?? 'All').replaceAll(' ', '_')}';

  int loadPracticeBest(GameMode mode, String? region) =>
      _prefs.getInt(_practiceBestKey(mode, region)) ?? 0;

  /// Saves [score] as the new best for this mode+region if it beats the
  /// current record. Returns true if it's a new record.
  Future<bool> savePracticeBestIfHigher(GameMode mode, String? region, int score) async {
    final key = _practiceBestKey(mode, region);
    final current = _prefs.getInt(key) ?? 0;
    if (score > current) {
      await _prefs.setInt(key, score);
      return true;
    }
    return false;
  }

  Map<int, int> _parseIntMap(dynamic raw) {
    if (raw == null) return {};
    final map = raw as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(int.parse(k), v as int));
  }
}
