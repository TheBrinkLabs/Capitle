import 'capital_entry.dart';

enum GameMode { guessCountry, guessCapital, guessFlag, guessNeighbours, guessPopulation, guessOutline }

extension GameModeX on GameMode {
  String get label => switch (this) {
        GameMode.guessCountry => 'Guess Country',
        GameMode.guessCapital => 'Guess Capital',
        GameMode.guessFlag => 'Guess Flag',
        GameMode.guessNeighbours => 'Neighbours',
        GameMode.guessPopulation => 'Population',
        GameMode.guessOutline => 'Outline',
      };
  String get promptText => switch (this) {
        GameMode.guessCountry => 'Which country is this the capital of?',
        GameMode.guessCapital => 'What is the capital of this country?',
        GameMode.guessFlag => 'Which country does this flag belong to?',
        GameMode.guessNeighbours => 'How many land borders does this country have?',
        GameMode.guessPopulation => 'Which capital city has the larger population?',
        GameMode.guessOutline => 'Which country has this shape?',
      };
  String get heroLabel => switch (this) {
        GameMode.guessCountry => 'Capital City',
        GameMode.guessCapital => 'Country',
        GameMode.guessFlag => 'Flag',
        GameMode.guessNeighbours => 'Country',
        GameMode.guessPopulation => 'Population',
        GameMode.guessOutline => 'Guess the Country',
      };
  String get emoji => switch (this) {
        GameMode.guessCountry => '🌍',
        GameMode.guessCapital => '🗺️',
        GameMode.guessFlag => '🚩',
        GameMode.guessNeighbours => '🤝',
        GameMode.guessPopulation => '📊',
        GameMode.guessOutline => '🧩',
      };
  String get streakKey => switch (this) {
        GameMode.guessCountry => 'country',
        GameMode.guessCapital => 'capital',
        GameMode.guessFlag => 'flag',
        GameMode.guessNeighbours => 'neighbours',
        GameMode.guessPopulation => 'population',
        GameMode.guessOutline => 'outline',
      };
  // Distance/direction hint applies to modes where you guess a country/capital
  // name and being "close" is meaningful. Not for number/binary-choice modes.
  bool get showsDistanceHint => switch (this) {
        GameMode.guessCountry => true,
        GameMode.guessCapital => true,
        GameMode.guessFlag => true,
        GameMode.guessOutline => true,
        GameMode.guessNeighbours => false,
        GameMode.guessPopulation => false,
      };
}

class GuessResult {
  final String input;
  final bool isCorrect;
  final int? distanceMiles;
  final int? distanceKm;
  final double? bearingDegrees;
  final CapitalEntry? matchedEntry;
  final bool isClue;
  final bool isFreeClue; // true if this clue was unlocked via ad, not a spent guess

  const GuessResult({
    required this.input,
    required this.isCorrect,
    this.distanceMiles,
    this.distanceKm,
    this.bearingDegrees,
    this.matchedEntry,
    this.isClue = false,
    this.isFreeClue = false,
  });

  double get closeness {
    if (isCorrect) return 1.0;
    if (distanceMiles == null) return 0.0;
    return (1 - (distanceMiles! / 12000)).clamp(0.0, 1.0);
  }

  String get directionArrow {
    if (bearingDegrees == null) return '';
    final b = bearingDegrees! % 360;
    if (b < 22.5 || b >= 337.5) return '↑';
    if (b < 67.5) return '↗';
    if (b < 112.5) return '→';
    if (b < 157.5) return '↘';
    if (b < 202.5) return '↓';
    if (b < 247.5) return '↙';
    if (b < 292.5) return '←';
    return '↖';
  }
}

class PopulationPuzzle {
  final CapitalEntry entryA;
  final CapitalEntry entryB;
  final String dateKey;

  const PopulationPuzzle({required this.entryA, required this.entryB, required this.dateKey});

  CapitalEntry get larger => entryA.capitalPopulation >= entryB.capitalPopulation ? entryA : entryB;
  String get correctAnswer => larger.capital;
}

class DailyPuzzle {
  final CapitalEntry entry;
  final GameMode mode;
  final String dateKey;
  final PopulationPuzzle? populationPuzzle;

  const DailyPuzzle({
    required this.entry,
    required this.mode,
    required this.dateKey,
    this.populationPuzzle,
  });

  String get heroText => switch (mode) {
        GameMode.guessCountry => entry.capital,
        GameMode.guessCapital => entry.country,
        GameMode.guessFlag => entry.flagEmoji,
        GameMode.guessNeighbours => entry.country,
        GameMode.guessPopulation => '',
        GameMode.guessOutline => '', // rendered as an image, not text
      };

  String get correctAnswer => switch (mode) {
        GameMode.guessCountry => entry.country,
        GameMode.guessCapital => entry.capital,
        GameMode.guessFlag => entry.country,
        GameMode.guessNeighbours => '${entry.neighbours}',
        GameMode.guessPopulation => populationPuzzle?.correctAnswer ?? '',
        GameMode.guessOutline => entry.country,
      };
}

enum GameStatus { idle, playing, won, lost }

class GameState {
  static const maxGuesses = 3;

  final DailyPuzzle puzzle;
  final List<GuessResult> guesses;
  final GameStatus status;
  final bool clueUsed;
  final String? clueText;
  final bool freeClueUsed; // clue unlocked via rewarded ad — doesn't cost a guess
  final String? clueLetter; // the revealed first letter, for filtering suggestions
  final DateTime startedAt; // when this puzzle was first shown — used for league speed scoring

  const GameState({
    required this.puzzle,
    required this.startedAt,
    this.guesses = const [],
    this.status = GameStatus.playing,
    this.clueUsed = false,
    this.clueText,
    this.freeClueUsed = false,
    this.clueLetter,
  });

  int get guessesUsed => guesses.where((g) => !g.isClue).length;

  // Population mode is a single binary choice — one guess ends the round.
  // Every other mode uses the shared 3-guess limit.
  int get effectiveMaxGuesses =>
      puzzle.mode == GameMode.guessPopulation ? 1 : maxGuesses;

  int get guessesRemaining {
    // Note: freeClueUsed is deliberately NOT counted here — an ad-unlocked
    // clue doesn't cost a guess, that's the whole point of watching the ad.
    final used = guessesUsed + (clueUsed ? 1 : 0);
    return (effectiveMaxGuesses - used).clamp(0, effectiveMaxGuesses);
  }
  bool get isOver => status == GameStatus.won || status == GameStatus.lost;

  GameState copyWith({
    List<GuessResult>? guesses,
    GameStatus? status,
    bool? clueUsed,
    String? clueText,
    bool? freeClueUsed,
    String? clueLetter,
  }) =>
      GameState(
        puzzle: puzzle,
        startedAt: startedAt,
        guesses: guesses ?? this.guesses,
        status: status ?? this.status,
        clueUsed: clueUsed ?? this.clueUsed,
        clueText: clueText ?? this.clueText,
        freeClueUsed: freeClueUsed ?? this.freeClueUsed,
        clueLetter: clueLetter ?? this.clueLetter,
      );
}

class DayRecord {
  final String dateKey;
  final bool completedGuessCountry;
  final bool wonGuessCountry;
  final int guessesUsedCountry;
  final int scoreGuessCountry;
  final bool completedGuessCapital;
  final bool wonGuessCapital;
  final int guessesUsedCapital;
  final int scoreGuessCapital;
  final bool completedGuessFlag;
  final bool wonGuessFlag;
  final int guessesUsedFlag;
  final int scoreGuessFlag;
  final bool completedGuessNeighbours;
  final bool wonGuessNeighbours;
  final int guessesUsedNeighbours;
  final int scoreGuessNeighbours;
  final bool completedGuessPopulation;
  final bool wonGuessPopulation;
  final int guessesUsedPopulation;
  final int scoreGuessPopulation;
  final bool completedGuessOutline;
  final bool wonGuessOutline;
  final int guessesUsedOutline;
  final int scoreGuessOutline;

  // Modes "frozen" on this day via a streak-repair rewarded ad. A frozen
  // day preserves streak continuity (doesn't break the chain) WITHOUT
  // counting as an extra played day — mirrors how Duolingo's Streak
  // Freeze works. Stored as mode.name strings for simple JSON encoding.
  final Set<String> frozenModeNames;

  const DayRecord({
    required this.dateKey,
    this.completedGuessCountry = false,
    this.wonGuessCountry = false,
    this.guessesUsedCountry = 0,
    this.scoreGuessCountry = 0,
    this.completedGuessCapital = false,
    this.wonGuessCapital = false,
    this.guessesUsedCapital = 0,
    this.scoreGuessCapital = 0,
    this.completedGuessFlag = false,
    this.wonGuessFlag = false,
    this.guessesUsedFlag = 0,
    this.scoreGuessFlag = 0,
    this.completedGuessNeighbours = false,
    this.wonGuessNeighbours = false,
    this.guessesUsedNeighbours = 0,
    this.scoreGuessNeighbours = 0,
    this.completedGuessPopulation = false,
    this.wonGuessPopulation = false,
    this.guessesUsedPopulation = 0,
    this.scoreGuessPopulation = 0,
    this.completedGuessOutline = false,
    this.wonGuessOutline = false,
    this.guessesUsedOutline = 0,
    this.scoreGuessOutline = 0,
    this.frozenModeNames = const {},
  });

  bool completedMode(GameMode mode) => switch (mode) {
        GameMode.guessCountry => completedGuessCountry,
        GameMode.guessCapital => completedGuessCapital,
        GameMode.guessFlag => completedGuessFlag,
        GameMode.guessNeighbours => completedGuessNeighbours,
        GameMode.guessPopulation => completedGuessPopulation,
        GameMode.guessOutline => completedGuessOutline,
      };

  bool wonMode(GameMode mode) => switch (mode) {
        GameMode.guessCountry => wonGuessCountry,
        GameMode.guessCapital => wonGuessCapital,
        GameMode.guessFlag => wonGuessFlag,
        GameMode.guessNeighbours => wonGuessNeighbours,
        GameMode.guessPopulation => wonGuessPopulation,
        GameMode.guessOutline => wonGuessOutline,
      };

  int scoreForMode(GameMode mode) => switch (mode) {
        GameMode.guessCountry => scoreGuessCountry,
        GameMode.guessCapital => scoreGuessCapital,
        GameMode.guessFlag => scoreGuessFlag,
        GameMode.guessNeighbours => scoreGuessNeighbours,
        GameMode.guessPopulation => scoreGuessPopulation,
        GameMode.guessOutline => scoreGuessOutline,
      };

  /// Sum of scores across whichever of [modes] were completed today —
  /// pass `GameMode.values` for every mode, or a settings-filtered list
  /// for just the active ones.
  int totalScoreFor(List<GameMode> modes) =>
      modes.where(completedMode).fold(0, (sum, m) => sum + scoreForMode(m));

  bool isFrozenMode(GameMode mode) => frozenModeNames.contains(mode.name);

  // A day "counts" toward chain continuity only if it was WON, or frozen
  // via ad — used when walking backward for streak computation. Playing
  // and losing breaks the chain exactly like not playing at all.
  bool continuesChain(GameMode mode) => wonMode(mode) || isFrozenMode(mode);

  bool get streakCounts =>
      completedGuessCountry || completedGuessCapital || completedGuessFlag ||
      completedGuessNeighbours || completedGuessPopulation || completedGuessOutline;

  bool allComplete(List<GameMode> activeModes) => activeModes.every((m) => completedMode(m));

  // Used specifically for the streak-saver notification — suppress the
  // reminder once you've played at least one active mode today, rather
  // than requiring every single one (that stricter bar is what the "all
  // done" banner and DailyCompleteScreen use instead).
  bool anyComplete(List<GameMode> activeModes) => activeModes.any((m) => completedMode(m));

  DayRecord copyWith({
    bool? completedGuessCountry, bool? wonGuessCountry, int? guessesUsedCountry, int? scoreGuessCountry,
    bool? completedGuessCapital, bool? wonGuessCapital, int? guessesUsedCapital, int? scoreGuessCapital,
    bool? completedGuessFlag, bool? wonGuessFlag, int? guessesUsedFlag, int? scoreGuessFlag,
    bool? completedGuessNeighbours, bool? wonGuessNeighbours, int? guessesUsedNeighbours, int? scoreGuessNeighbours,
    bool? completedGuessPopulation, bool? wonGuessPopulation, int? guessesUsedPopulation, int? scoreGuessPopulation,
    bool? completedGuessOutline, bool? wonGuessOutline, int? guessesUsedOutline, int? scoreGuessOutline,
    Set<String>? frozenModeNames,
  }) =>
      DayRecord(
        dateKey: dateKey,
        completedGuessCountry: completedGuessCountry ?? this.completedGuessCountry,
        wonGuessCountry: wonGuessCountry ?? this.wonGuessCountry,
        guessesUsedCountry: guessesUsedCountry ?? this.guessesUsedCountry,
        scoreGuessCountry: scoreGuessCountry ?? this.scoreGuessCountry,
        completedGuessCapital: completedGuessCapital ?? this.completedGuessCapital,
        wonGuessCapital: wonGuessCapital ?? this.wonGuessCapital,
        guessesUsedCapital: guessesUsedCapital ?? this.guessesUsedCapital,
        scoreGuessCapital: scoreGuessCapital ?? this.scoreGuessCapital,
        completedGuessFlag: completedGuessFlag ?? this.completedGuessFlag,
        wonGuessFlag: wonGuessFlag ?? this.wonGuessFlag,
        guessesUsedFlag: guessesUsedFlag ?? this.guessesUsedFlag,
        scoreGuessFlag: scoreGuessFlag ?? this.scoreGuessFlag,
        completedGuessNeighbours: completedGuessNeighbours ?? this.completedGuessNeighbours,
        wonGuessNeighbours: wonGuessNeighbours ?? this.wonGuessNeighbours,
        guessesUsedNeighbours: guessesUsedNeighbours ?? this.guessesUsedNeighbours,
        scoreGuessNeighbours: scoreGuessNeighbours ?? this.scoreGuessNeighbours,
        completedGuessPopulation: completedGuessPopulation ?? this.completedGuessPopulation,
        wonGuessPopulation: wonGuessPopulation ?? this.wonGuessPopulation,
        guessesUsedPopulation: guessesUsedPopulation ?? this.guessesUsedPopulation,
        scoreGuessPopulation: scoreGuessPopulation ?? this.scoreGuessPopulation,
        completedGuessOutline: completedGuessOutline ?? this.completedGuessOutline,
        wonGuessOutline: wonGuessOutline ?? this.wonGuessOutline,
        guessesUsedOutline: guessesUsedOutline ?? this.guessesUsedOutline,
        scoreGuessOutline: scoreGuessOutline ?? this.scoreGuessOutline,
        frozenModeNames: frozenModeNames ?? this.frozenModeNames,
      );

  /// Returns a copy with [mode] added to the frozen set for this day.
  DayRecord withFrozenMode(GameMode mode) =>
      copyWith(frozenModeNames: {...frozenModeNames, mode.name});

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'completedGuessCountry': completedGuessCountry, 'wonGuessCountry': wonGuessCountry, 'guessesUsedCountry': guessesUsedCountry, 'scoreGuessCountry': scoreGuessCountry,
        'completedGuessCapital': completedGuessCapital, 'wonGuessCapital': wonGuessCapital, 'guessesUsedCapital': guessesUsedCapital, 'scoreGuessCapital': scoreGuessCapital,
        'completedGuessFlag': completedGuessFlag, 'wonGuessFlag': wonGuessFlag, 'guessesUsedFlag': guessesUsedFlag, 'scoreGuessFlag': scoreGuessFlag,
        'completedGuessNeighbours': completedGuessNeighbours, 'wonGuessNeighbours': wonGuessNeighbours, 'guessesUsedNeighbours': guessesUsedNeighbours, 'scoreGuessNeighbours': scoreGuessNeighbours,
        'completedGuessPopulation': completedGuessPopulation, 'wonGuessPopulation': wonGuessPopulation, 'guessesUsedPopulation': guessesUsedPopulation, 'scoreGuessPopulation': scoreGuessPopulation,
        'completedGuessOutline': completedGuessOutline, 'wonGuessOutline': wonGuessOutline, 'guessesUsedOutline': guessesUsedOutline, 'scoreGuessOutline': scoreGuessOutline,
        'frozenModeNames': frozenModeNames.toList(),
      };

  factory DayRecord.fromJson(Map<String, dynamic> json) => DayRecord(
        dateKey: json['dateKey'] as String,
        completedGuessCountry: json['completedGuessCountry'] as bool? ?? false,
        wonGuessCountry: json['wonGuessCountry'] as bool? ?? false,
        guessesUsedCountry: json['guessesUsedCountry'] as int? ?? 0,
        scoreGuessCountry: json['scoreGuessCountry'] as int? ?? 0,
        completedGuessCapital: json['completedGuessCapital'] as bool? ?? false,
        wonGuessCapital: json['wonGuessCapital'] as bool? ?? false,
        guessesUsedCapital: json['guessesUsedCapital'] as int? ?? 0,
        scoreGuessCapital: json['scoreGuessCapital'] as int? ?? 0,
        completedGuessFlag: json['completedGuessFlag'] as bool? ?? false,
        wonGuessFlag: json['wonGuessFlag'] as bool? ?? false,
        guessesUsedFlag: json['guessesUsedFlag'] as int? ?? 0,
        scoreGuessFlag: json['scoreGuessFlag'] as int? ?? 0,
        completedGuessNeighbours: json['completedGuessNeighbours'] as bool? ?? false,
        wonGuessNeighbours: json['wonGuessNeighbours'] as bool? ?? false,
        guessesUsedNeighbours: json['guessesUsedNeighbours'] as int? ?? 0,
        scoreGuessNeighbours: json['scoreGuessNeighbours'] as int? ?? 0,
        completedGuessPopulation: json['completedGuessPopulation'] as bool? ?? false,
        wonGuessPopulation: json['wonGuessPopulation'] as bool? ?? false,
        guessesUsedPopulation: json['guessesUsedPopulation'] as int? ?? 0,
        scoreGuessPopulation: json['scoreGuessPopulation'] as int? ?? 0,
        completedGuessOutline: json['completedGuessOutline'] as bool? ?? false,
        wonGuessOutline: json['wonGuessOutline'] as bool? ?? false,
        guessesUsedOutline: json['guessesUsedOutline'] as int? ?? 0,
        scoreGuessOutline: json['scoreGuessOutline'] as int? ?? 0,
        frozenModeNames: ((json['frozenModeNames'] as List?) ?? const [])
            .map((e) => e as String)
            .toSet(),
      );
}

class ModeStreak {
  final int current;
  final int best;
  const ModeStreak({this.current = 0, this.best = 0});
  Map<String, dynamic> toJson() => {'current': current, 'best': best};
  factory ModeStreak.fromJson(Map<String, dynamic> json) => ModeStreak(
        current: json['current'] as int? ?? 0,
        best: json['best'] as int? ?? 0,
      );
}

class PlayerStats {
  final int totalPlayed;
  final int totalWon;
  final int totalScore;
  final Map<int, int> guessDistributionCountry;
  final Map<int, int> guessDistributionCapital;
  final Map<int, int> guessDistributionFlag;
  final Map<int, int> guessDistributionNeighbours;
  final Map<int, int> guessDistributionPopulation;
  final Map<int, int> guessDistributionOutline;
  final ModeStreak countryStreak;
  final ModeStreak capitalStreak;
  final ModeStreak flagStreak;
  final ModeStreak neighboursStreak;
  final ModeStreak populationStreak;
  final ModeStreak outlineStreak;

  const PlayerStats({
    this.totalPlayed = 0,
    this.totalWon = 0,
    this.totalScore = 0,
    this.guessDistributionCountry = const {},
    this.guessDistributionCapital = const {},
    this.guessDistributionFlag = const {},
    this.guessDistributionNeighbours = const {},
    this.guessDistributionPopulation = const {},
    this.guessDistributionOutline = const {},
    this.countryStreak = const ModeStreak(),
    this.capitalStreak = const ModeStreak(),
    this.flagStreak = const ModeStreak(),
    this.neighboursStreak = const ModeStreak(),
    this.populationStreak = const ModeStreak(),
    this.outlineStreak = const ModeStreak(),
  });

  ModeStreak streakForMode(GameMode mode) => switch (mode) {
        GameMode.guessCountry => countryStreak,
        GameMode.guessCapital => capitalStreak,
        GameMode.guessFlag => flagStreak,
        GameMode.guessNeighbours => neighboursStreak,
        GameMode.guessPopulation => populationStreak,
        GameMode.guessOutline => outlineStreak,
      };

  /// Returns a copy with just one mode's streak replaced — everything
  /// else (distributions, totals, other streaks) stays untouched.
  PlayerStats withUpdatedStreak(GameMode mode, ModeStreak streak) => PlayerStats(
        totalPlayed: totalPlayed,
        totalWon: totalWon,
        totalScore: totalScore,
        guessDistributionCountry: guessDistributionCountry,
        guessDistributionCapital: guessDistributionCapital,
        guessDistributionFlag: guessDistributionFlag,
        guessDistributionNeighbours: guessDistributionNeighbours,
        guessDistributionPopulation: guessDistributionPopulation,
        guessDistributionOutline: guessDistributionOutline,
        countryStreak: mode == GameMode.guessCountry ? streak : countryStreak,
        capitalStreak: mode == GameMode.guessCapital ? streak : capitalStreak,
        flagStreak: mode == GameMode.guessFlag ? streak : flagStreak,
        neighboursStreak: mode == GameMode.guessNeighbours ? streak : neighboursStreak,
        populationStreak: mode == GameMode.guessPopulation ? streak : populationStreak,
        outlineStreak: mode == GameMode.guessOutline ? streak : outlineStreak,
      );

  /// Returns a copy with [delta] added to the running total score —
  /// everything else stays untouched.
  PlayerStats withAddedScore(int delta) => PlayerStats(
        totalPlayed: totalPlayed,
        totalWon: totalWon,
        totalScore: totalScore + delta,
        guessDistributionCountry: guessDistributionCountry,
        guessDistributionCapital: guessDistributionCapital,
        guessDistributionFlag: guessDistributionFlag,
        guessDistributionNeighbours: guessDistributionNeighbours,
        guessDistributionPopulation: guessDistributionPopulation,
        guessDistributionOutline: guessDistributionOutline,
        countryStreak: countryStreak,
        capitalStreak: capitalStreak,
        flagStreak: flagStreak,
        neighboursStreak: neighboursStreak,
        populationStreak: populationStreak,
        outlineStreak: outlineStreak,
      );

  int get currentStreak => [
        countryStreak.current, capitalStreak.current, flagStreak.current,
        neighboursStreak.current, populationStreak.current, outlineStreak.current,
      ].reduce((a, b) => a > b ? a : b);

  int get bestStreak => [
        countryStreak.best, capitalStreak.best, flagStreak.best,
        neighboursStreak.best, populationStreak.best, outlineStreak.best,
      ].reduce((a, b) => a > b ? a : b);

  double get winRate => totalPlayed == 0 ? 0 : (totalWon / totalPlayed).clamp(0.0, 1.0);
  double get winRatePct => winRate * 100;

  double get avgGuesses {
    if (totalWon == 0) return 0;
    int total = 0, count = 0;
    for (final dist in [
      guessDistributionCountry, guessDistributionCapital, guessDistributionFlag,
      guessDistributionNeighbours, guessDistributionPopulation, guessDistributionOutline,
    ]) {
      for (final e in dist.entries) { total += e.key * e.value; count += e.value; }
    }
    return count == 0 ? 0 : total / count;
  }
}
