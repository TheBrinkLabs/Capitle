import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/capital_entry.dart';
import '../../../data/models/outline_assets.dart';
import '../../../core/utils/providers.dart';
import '../../settings/providers/settings_provider.dart';

final practiceCountryProvider =
    NotifierProvider<PracticeNotifier, GameState?>(() => PracticeNotifier(GameMode.guessCountry));
final practiceCapitalProvider =
    NotifierProvider<PracticeNotifier, GameState?>(() => PracticeNotifier(GameMode.guessCapital));
final practiceFlagProvider =
    NotifierProvider<PracticeNotifier, GameState?>(() => PracticeNotifier(GameMode.guessFlag));
final practiceNeighboursProvider =
    NotifierProvider<PracticeNotifier, GameState?>(() => PracticeNotifier(GameMode.guessNeighbours));
final practicePopulationProvider =
    NotifierProvider<PracticeNotifier, GameState?>(() => PracticeNotifier(GameMode.guessPopulation));
final practiceOutlineProvider =
    NotifierProvider<PracticeNotifier, GameState?>(() => PracticeNotifier(GameMode.guessOutline));

// Helper to get the right provider for a mode
NotifierProvider<PracticeNotifier, GameState?> practiceProviderForMode(GameMode mode) =>
    switch (mode) {
      GameMode.guessCountry => practiceCountryProvider,
      GameMode.guessCapital => practiceCapitalProvider,
      GameMode.guessFlag => practiceFlagProvider,
      GameMode.guessNeighbours => practiceNeighboursProvider,
      GameMode.guessPopulation => practicePopulationProvider,
      GameMode.guessOutline => practiceOutlineProvider,
    };

// ── Region selection (shared across all scored practice modes) ────────────
//
// null means "All". Population mode ignores this entirely — it stays
// endless/unscored and always draws from the full country pool.

const List<String?> kPracticeRegions = [
  null,
  Continent.africa,
  Continent.asia,
  Continent.europe,
  Continent.northAmerica,
  Continent.southAmerica,
  Continent.oceania,
  Continent.middleEast,
];

String practiceRegionLabel(String? region) => region ?? 'All';

final practiceRegionProvider = StateProvider<String?>((ref) => null);

// Bumped whenever a scored session completes, so screens showing saved
// best scores (read via plain ref.read, since they come from
// SharedPreferences rather than a watched provider) know to rebuild —
// e.g. PracticeMenuScreen re-reading its "Best: x/y" badges after
// Navigator.pop() brings it back into view.
final practiceBestScoresVersionProvider = StateProvider<int>((ref) => 0);

class PracticeNotifier extends Notifier<GameState?> {
  final GameMode mode;
  PracticeNotifier(this.mode);

  final _rng = Random();

  static final List<CapitalEntry> _outlineEligible =
      kCapitals.where((e) => kOutlineAssetPath.containsKey(e.country)).toList();

  // Population mode auto-generates its first puzzle like before (endless,
  // unscored). Every other mode waits — its first puzzle is handed to it
  // by a PracticeSessionNotifier via nextPuzzle(forcedEntry: ...) right
  // after the screen mounts, so build() returning null just means "session
  // hasn't started yet" (the screen shows a brief loading spinner for it).
  @override
  GameState? build() => mode == GameMode.guessPopulation ? _newPuzzle() : null;

  GameState _newPuzzle({CapitalEntry? forcedEntry}) {
    if (mode == GameMode.guessPopulation) {
      final entry = kCapitals[_rng.nextInt(kCapitals.length)];
      CapitalEntry entryB;
      do {
        entryB = kCapitals[_rng.nextInt(kCapitals.length)];
      } while (entryB.capital == entry.capital);
      final puzzle = DailyPuzzle(
        entry: entry, mode: mode, dateKey: 'practice',
        populationPuzzle: PopulationPuzzle(entryA: entry, entryB: entryB, dateKey: 'practice'),
      );
      return GameState(puzzle: puzzle, status: GameStatus.playing);
    }

    CapitalEntry entry;
    if (forcedEntry != null) {
      entry = forcedEntry;
    } else {
      final repo = ref.read(gameRepositoryProvider);
      final todayEntry = repo.getPuzzle(mode).entry;
      final pool = mode == GameMode.guessOutline ? _outlineEligible : kCapitals;
      do {
        entry = pool[_rng.nextInt(pool.length)];
      } while (entry.capital == todayEntry.capital && pool.length > 1);
    }

    final puzzle = DailyPuzzle(entry: entry, mode: mode, dateKey: 'practice');
    return GameState(puzzle: puzzle, status: GameStatus.playing);
  }

  void nextPuzzle({CapitalEntry? forcedEntry}) {
    state = _newPuzzle(forcedEntry: forcedEntry);
  }

  // Simple flat-map direction (not great-circle navigation bearing).
  // Great-circle bearings can point counter-intuitively (e.g. north-east
  // when a country is actually due east) because the shortest sphere path
  // often bows toward the pole. Players read the arrow against a normal
  // flat map, so we compute direction from simple lat/lng differences.
  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat2 - lat1;
    double dLng = lng2 - lng1;
    if (dLng > 180) dLng -= 360;
    if (dLng < -180) dLng += 360;
    return (atan2(dLng, dLat) * 180 / pi + 360) % 360;
  }

  void submitGuess(String input) {
    final current = state;
    if (current == null || current.isOver) return;

    final repo = ref.read(gameRepositoryProvider);
    final settings = ref.read(settingsProvider);

    final result = repo.buildGuessResult(
      input: input,
      puzzle: current.puzzle,
      hardMode: settings.hardMode,
      nameStyle: settings.countryNameStyle,
    );

    GuessResult finalResult = result;
    if (!result.isCorrect && result.matchedEntry != null && mode.showsDistanceHint) {
      final bearing = _bearing(
        result.matchedEntry!.lat, result.matchedEntry!.lng,
        current.puzzle.entry.lat, current.puzzle.entry.lng,
      );
      finalResult = GuessResult(
        input: result.input, isCorrect: result.isCorrect,
        distanceMiles: result.distanceMiles, distanceKm: result.distanceKm,
        bearingDegrees: bearing, matchedEntry: result.matchedEntry,
      );
    }

    final newGuesses = [...current.guesses, finalResult];
    final isWon = finalResult.isCorrect;
    final realGuessCount = newGuesses.where((g) => !g.isClue).length;
    final effectiveUsed = realGuessCount + (current.clueUsed ? 1 : 0);
    final isLost = !isWon && effectiveUsed >= current.effectiveMaxGuesses;

    final newStatus = isWon ? GameStatus.won : isLost ? GameStatus.lost : GameStatus.playing;
    state = current.copyWith(guesses: newGuesses, status: newStatus);
  }

  void useClue() {
    final current = state;
    if (current == null || current.isOver || current.clueUsed) return;
    if (current.guessesRemaining <= 1) return;

    final answer = current.puzzle.correctAnswer;
    final firstLetter = answer.isNotEmpty ? answer[0].toUpperCase() : '?';
    final clueDisplayText = 'Starts with: $firstLetter';

    state = current.copyWith(
      guesses: [...current.guesses, GuessResult(
        input: clueDisplayText, isCorrect: false, isClue: true)],
      clueUsed: true,
      clueText: clueDisplayText,
      clueLetter: firstLetter,
    );
  }

  /// Same clue reveal as [useClue], but unlocked by watching an ad instead
  /// of spending a guess. Call this only after the ad has actually been
  /// watched/dismissed.
  void useClueViaAd() {
    final current = state;
    if (current == null || current.isOver || current.clueUsed || current.freeClueUsed) return;

    final answer = current.puzzle.correctAnswer;
    final firstLetter = answer.isNotEmpty ? answer[0].toUpperCase() : '?';
    final clueDisplayText = 'Starts with: $firstLetter';

    state = current.copyWith(
      guesses: [...current.guesses, GuessResult(
        input: clueDisplayText, isCorrect: false, isClue: true, isFreeClue: true)],
      freeClueUsed: true,
      clueText: clueDisplayText,
      clueLetter: firstLetter,
    );
  }

  List<String> getSuggestions(String query) {
    final repo = ref.read(gameRepositoryProvider);
    final settings = ref.read(settingsProvider);
    return repo.getSuggestions(query, mode, nameStyle: settings.countryNameStyle, clueLetter: state?.clueLetter);
  }
}

// ── Scored Practice Sessions ────────────────────────────────────────────
//
// A session walks through every country in the selected region exactly
// once (shuffled order), tracking a running score and — at the end —
// comparing against (and possibly beating) the saved best for that
// mode+region combo. Not used by Population mode, which stays endless
// and unscored.

class PracticeSessionState {
  final List<CapitalEntry> remaining; // not yet served, shuffled
  final int total;
  final int correct;
  final int askedCount;
  final bool complete;
  final bool started;
  final String? region;
  final int bestScore;
  final bool isNewRecord;

  const PracticeSessionState({
    this.remaining = const [],
    this.total = 0,
    this.correct = 0,
    this.askedCount = 0,
    this.complete = false,
    this.started = false,
    this.region,
    this.bestScore = 0,
    this.isNewRecord = false,
  });

  double get percent => askedCount == 0 ? 0 : (correct / askedCount) * 100;

  PracticeSessionState copyWith({
    List<CapitalEntry>? remaining,
    int? total,
    int? correct,
    int? askedCount,
    bool? complete,
    bool? started,
    int? bestScore,
    bool? isNewRecord,
  }) =>
      PracticeSessionState(
        remaining: remaining ?? this.remaining,
        total: total ?? this.total,
        correct: correct ?? this.correct,
        askedCount: askedCount ?? this.askedCount,
        complete: complete ?? this.complete,
        started: started ?? this.started,
        region: region,
        bestScore: bestScore ?? this.bestScore,
        isNewRecord: isNewRecord ?? this.isNewRecord,
      );
}

class PracticeSessionNotifier extends Notifier<PracticeSessionState> {
  final GameMode mode;
  PracticeSessionNotifier(this.mode);

  final _rng = Random();

  @override
  PracticeSessionState build() => const PracticeSessionState();

  List<CapitalEntry> _poolFor(String? region) {
    final base = mode == GameMode.guessOutline
        ? kCapitals.where((e) => kOutlineAssetPath.containsKey(e.country))
        : kCapitals;
    final filtered = region == null ? base : base.where((e) => e.continent == region);
    return filtered.toList();
  }

  /// Starts a fresh session for [region] and returns the first entry to
  /// play, or null if this mode+region combo has no eligible countries.
  CapitalEntry? startSession(String? region) {
    final pool = _poolFor(region)..shuffle(_rng);
    if (pool.isEmpty) {
      state = PracticeSessionState(region: region, started: true, complete: true);
      return null;
    }

    final repo = ref.read(gameRepositoryProvider);
    final best = repo.loadPracticeBest(mode, region);
    final first = pool.first;
    state = PracticeSessionState(
      remaining: pool.skip(1).toList(),
      total: pool.length,
      started: true,
      region: region,
      bestScore: best,
    );
    return first;
  }

  /// Records the outcome of the puzzle just answered and returns the next
  /// entry to play, or null once the session is complete (in which case
  /// state.isNewRecord tells the caller whether to celebrate).
  Future<CapitalEntry?> recordResultAndAdvance(bool won) async {
    final s = state;
    final newCorrect = s.correct + (won ? 1 : 0);
    final newAsked = s.askedCount + 1;

    if (s.remaining.isEmpty) {
      final repo = ref.read(gameRepositoryProvider);
      final isRecord = await repo.savePracticeBestIfHigher(mode, s.region, newCorrect);
      state = s.copyWith(
        correct: newCorrect,
        askedCount: newAsked,
        complete: true,
        bestScore: isRecord ? newCorrect : s.bestScore,
        isNewRecord: isRecord,
      );
      ref.read(practiceBestScoresVersionProvider.notifier).state++;
      return null;
    }

    final next = s.remaining.first;
    state = s.copyWith(
      correct: newCorrect,
      askedCount: newAsked,
      remaining: s.remaining.skip(1).toList(),
    );
    return next;
  }
}

final practiceCountrySessionProvider = NotifierProvider<PracticeSessionNotifier, PracticeSessionState>(
    () => PracticeSessionNotifier(GameMode.guessCountry));
final practiceCapitalSessionProvider = NotifierProvider<PracticeSessionNotifier, PracticeSessionState>(
    () => PracticeSessionNotifier(GameMode.guessCapital));
final practiceFlagSessionProvider = NotifierProvider<PracticeSessionNotifier, PracticeSessionState>(
    () => PracticeSessionNotifier(GameMode.guessFlag));
final practiceNeighboursSessionProvider = NotifierProvider<PracticeSessionNotifier, PracticeSessionState>(
    () => PracticeSessionNotifier(GameMode.guessNeighbours));
final practiceOutlineSessionProvider = NotifierProvider<PracticeSessionNotifier, PracticeSessionState>(
    () => PracticeSessionNotifier(GameMode.guessOutline));

NotifierProvider<PracticeSessionNotifier, PracticeSessionState> practiceSessionProviderForMode(GameMode mode) =>
    switch (mode) {
      GameMode.guessCountry => practiceCountrySessionProvider,
      GameMode.guessCapital => practiceCapitalSessionProvider,
      GameMode.guessFlag => practiceFlagSessionProvider,
      GameMode.guessNeighbours => practiceNeighboursSessionProvider,
      GameMode.guessOutline => practiceOutlineSessionProvider,
      GameMode.guessPopulation =>
        throw UnsupportedError('Population mode has no scored session'),
    };
