import 'package:collection/collection.dart';
import 'game_models.dart';

/// A game result that finished locally (the player's own stats/streak
/// already reflect it) but whose league submission hasn't been confirmed
/// on Firestore yet — persisted immediately so a network hiccup at
/// game-over can't silently and permanently lose it. See
/// PendingScoreRepository and GameStateNotifier._onGameOver.
class PendingScore {
  final GameMode mode;
  final bool won;
  final int guessesUsed;
  final int score;
  final DateTime playedAt; // UTC — pins the original day/week, not the retry's

  const PendingScore({
    required this.mode,
    required this.won,
    required this.guessesUsed,
    required this.score,
    required this.playedAt,
  });

  /// The same id `submitGameScore` derives server-side (mode + date) —
  /// used locally to dedupe the queue and to match a flushed entry back
  /// to the game it came from.
  String get id {
    final d = playedAt;
    final dateKey = '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return '${mode.name}_$dateKey';
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'won': won,
        'guessesUsed': guessesUsed,
        'score': score,
        'playedAt': playedAt.toIso8601String(),
      };

  static PendingScore? fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    final mode = GameMode.values.where((m) => m.name == modeName).firstOrNull;
    final playedAtRaw = json['playedAt'] as String?;
    final playedAt = playedAtRaw == null ? null : DateTime.tryParse(playedAtRaw);
    if (mode == null || playedAt == null) return null; // corrupt entry — drop it, never crash on it
    return PendingScore(
      mode: mode,
      won: json['won'] as bool? ?? false,
      guessesUsed: (json['guessesUsed'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      playedAt: playedAt,
    );
  }
}
