import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/game_models.dart';
import '../../../core/utils/providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../stats/providers/stats_provider.dart';
import '../../../core/utils/notification_service.dart';

final guessCountryGameProvider =
    NotifierProvider<GameNotifier, GameState?>(() => GameNotifier(GameMode.guessCountry));
final guessCapitalGameProvider =
    NotifierProvider<GameNotifier, GameState?>(() => GameNotifier(GameMode.guessCapital));
final guessFlagGameProvider =
    NotifierProvider<GameNotifier, GameState?>(() => GameNotifier(GameMode.guessFlag));
final guessNeighboursGameProvider =
    NotifierProvider<GameNotifier, GameState?>(() => GameNotifier(GameMode.guessNeighbours));
final guessPopulationGameProvider =
    NotifierProvider<GameNotifier, GameState?>(() => GameNotifier(GameMode.guessPopulation));
final guessOutlineGameProvider =
    NotifierProvider<GameNotifier, GameState?>(() => GameNotifier(GameMode.guessOutline));

NotifierProvider<GameNotifier, GameState?> gameProviderForMode(GameMode mode) =>
    switch (mode) {
      GameMode.guessCountry => guessCountryGameProvider,
      GameMode.guessCapital => guessCapitalGameProvider,
      GameMode.guessFlag => guessFlagGameProvider,
      GameMode.guessNeighbours => guessNeighboursGameProvider,
      GameMode.guessPopulation => guessPopulationGameProvider,
      GameMode.guessOutline => guessOutlineGameProvider,
    };

class GameNotifier extends Notifier<GameState?> {
  final GameMode mode;
  GameNotifier(this.mode);

  @override
  GameState? build() {
    final repo = ref.watch(gameRepositoryProvider);
    final puzzle = repo.getPuzzle(mode);
    final dayRecord = repo.loadDayRecord(repo.todayKey);

    if (dayRecord.completedMode(mode)) {
      return GameState(
        puzzle: puzzle,
        guesses: const [],
        status: dayRecord.wonMode(mode) ? GameStatus.won : GameStatus.lost,
      );
    }
    return GameState(puzzle: puzzle, status: GameStatus.playing);
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

    if (newStatus == GameStatus.won || newStatus == GameStatus.lost) {
      _onGameOver(isWon, realGuessCount);
    }
  }

  void useClue() {
    final current = state;
    if (current == null || current.isOver || current.clueUsed) return;
    if (current.guessesRemaining <= 1) return;

    final answer = current.puzzle.correctAnswer;
    final firstLetter = answer.isNotEmpty ? answer[0].toUpperCase() : '?';
    final clueDisplayText = 'Starts with: $firstLetter';

    state = current.copyWith(
      guesses: [...current.guesses, GuessResult(input: clueDisplayText, isCorrect: false, isClue: true)],
      clueUsed: true,
      clueText: clueDisplayText,
      clueLetter: firstLetter,
    );
  }

  /// Same clue reveal as [useClue], but unlocked by watching a rewarded ad
  /// instead of spending a guess. Call this only after the ad has actually
  /// been watched to completion.
  void useClueViaAd() {
    final current = state;
    if (current == null || current.isOver || current.clueUsed || current.freeClueUsed) return;

    final answer = current.puzzle.correctAnswer;
    final firstLetter = answer.isNotEmpty ? answer[0].toUpperCase() : '?';
    final clueDisplayText = 'Starts with: $firstLetter';

    state = current.copyWith(
      guesses: [...current.guesses, GuessResult(input: clueDisplayText, isCorrect: false, isClue: true, isFreeClue: true)],
      freeClueUsed: true,
      clueText: clueDisplayText,
      clueLetter: firstLetter,
    );
  }

  Future<void> _onGameOver(bool won, int guessesUsed) async {
    final repo = ref.read(gameRepositoryProvider);
    final statsNotifier = ref.read(statsProvider.notifier);
    await statsNotifier.recordGame(mode: mode, won: won, guessesUsed: guessesUsed);
    var record = repo.loadDayRecord(repo.todayKey);
    record = switch (mode) {
      GameMode.guessCountry => record.copyWith(completedGuessCountry: true, wonGuessCountry: won, guessesUsedCountry: guessesUsed),
      GameMode.guessCapital => record.copyWith(completedGuessCapital: true, wonGuessCapital: won, guessesUsedCapital: guessesUsed),
      GameMode.guessFlag => record.copyWith(completedGuessFlag: true, wonGuessFlag: won, guessesUsedFlag: guessesUsed),
      GameMode.guessNeighbours => record.copyWith(completedGuessNeighbours: true, wonGuessNeighbours: won, guessesUsedNeighbours: guessesUsed),
      GameMode.guessPopulation => record.copyWith(completedGuessPopulation: true, wonGuessPopulation: won, guessesUsedPopulation: guessesUsed),
      GameMode.guessOutline => record.copyWith(completedGuessOutline: true, wonGuessOutline: won, guessesUsedOutline: guessesUsed),
    };
    await repo.saveDayRecord(record);

    // If that was the last active mode for today, re-arm the streak-saver
    // alert immediately so it skips today rather than firing later on.
    // Wrapped defensively — a notification-scheduling failure should never
    // be able to crash the actual game-over flow.
    try {
      final settings = ref.read(settingsProvider);
      final completedToday = record.anyComplete(settings.activeModes);
      await notificationService.scheduleFromSettings(settings, completedToday: completedToday);
    } catch (e, st) {
      debugPrint('Notification reschedule failed (non-fatal): $e\n$st');
    }
  }

  List<String> getSuggestions(String query) {
    final repo = ref.read(gameRepositoryProvider);
    final settings = ref.read(settingsProvider);
    return repo.getSuggestions(query, mode, nameStyle: settings.countryNameStyle, clueLetter: state?.clueLetter);
  }
}
